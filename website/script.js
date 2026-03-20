const API = 'https://claude-proxy.danylokv.workers.dev';

// ── Aceternity Glowing Effect — mouse-tracking conic border ───────────────
(function initGlowingCards() {
  const cards = () => document.querySelectorAll('.glow-card');
  let raf = null;

  document.addEventListener('pointermove', (e) => {
    if (raf) cancelAnimationFrame(raf);
    raf = requestAnimationFrame(() => {
      cards().forEach(card => {
        const rect = card.getBoundingClientRect();
        const cx = rect.left + rect.width  * 0.5;
        const cy = rect.top  + rect.height * 0.5;

        // Inactive zone: suppress glow when cursor is near center (0.7 ratio)
        const inactiveR = 0.5 * Math.min(rect.width, rect.height) * 0.7;
        if (Math.hypot(e.clientX - cx, e.clientY - cy) < inactiveR) {
          card.style.setProperty('--glow-active', '0');
          return;
        }

        // Proximity check — 60px margin around card
        const near = e.clientX > rect.left  - 60 && e.clientX < rect.right  + 60 &&
                     e.clientY > rect.top   - 60 && e.clientY < rect.bottom + 60;

        card.style.setProperty('--glow-active', near ? '1' : '0');
        if (!near) return;

        // Angle from card center to cursor → drives conic gradient rotation
        const angle = Math.atan2(e.clientY - cy, e.clientX - cx) * (180 / Math.PI) + 90;
        card.style.setProperty('--glow-start', angle);
      });
    });
  });

  // Reset on pointer leave
  document.addEventListener('pointerleave', () => {
    cards().forEach(c => c.style.setProperty('--glow-active', '0'));
  });
})();

// ── Scroll-based nav ──────────────────────────────────────────────────────
window.addEventListener('scroll', () => {
  document.getElementById('nav').classList.toggle('scrolled', scrollY > 20);
}, { passive: true });

// ── Reveal on scroll ──────────────────────────────────────────────────────
const observer = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      e.target.classList.add('visible');
      observer.unobserve(e.target);
    }
  });
}, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

// ── Auth state ────────────────────────────────────────────────────────────
function getUser() {
  try { return JSON.parse(localStorage.getItem('fl_user')); } catch { return null; }
}

function updateNavForUser() {
  const user = getUser();
  const navEnd = document.querySelector('.nav-end');
  if (!navEnd) return;
  if (user) {
    const initials = user.name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
    navEnd.innerHTML = `
      <a href="/welcome.html" class="nav-avatar" title="${user.name}" style="text-decoration:none">${initials}</a>
      <button class="link-btn" onclick="signOut()">Sign out</button>
    `;
  } else {
    navEnd.innerHTML = `
      <button class="link-btn" onclick="openAuth('login')">Sign in</button>
      <button class="cta-btn" onclick="openAuth('register')">Get started free</button>
    `;
  }
}

function signOut() {
  localStorage.removeItem('fl_token');
  localStorage.removeItem('fl_user');
  updateNavForUser();
  showToastMessage('✦', 'Signed out. See you soon!', '');
}

// Init nav on page load
updateNavForUser();

// ── Auth modal ────────────────────────────────────────────────────────────
let activeTab = 'login';

function openAuth(tab = 'login') {
  switchTab(tab);
  document.getElementById('authModal').classList.add('open');
  setTimeout(() => {
    const el = tab === 'forgot'
      ? document.getElementById('forgotEmail')
      : document.getElementById('emailInput');
    el?.focus();
  }, 250);
}

function closeAuth() {
  document.getElementById('authModal').classList.remove('open');
}

function handleOverlayClick(e) {
  if (e.target === document.getElementById('authModal')) closeAuth();
}

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeAuth();
});

function switchTab(tab) {
  activeTab = tab;

  const isForgot   = tab === 'forgot';
  const authForm   = document.getElementById('authForm');
  const forgotForm = document.getElementById('forgotForm');
  const authTabs   = document.getElementById('authTabs');
  const forgotLink = document.getElementById('forgotLink');
  const footerNote = document.getElementById('authFooterNote');

  // Toggle views
  authForm.classList.toggle('hidden', isForgot);
  forgotForm.classList.toggle('hidden', !isForgot);
  authTabs.classList.toggle('hidden', isForgot);
  if (forgotLink) forgotLink.classList.toggle('hidden', isForgot);
  if (footerNote) footerNote.classList.toggle('hidden', isForgot);

  if (!isForgot) {
    document.getElementById('tab-login').classList.toggle('active', tab === 'login');
    document.getElementById('tab-register').classList.toggle('active', tab === 'register');
    document.getElementById('nameGroup').classList.toggle('hidden', tab === 'login');
    document.getElementById('submitLabel').textContent = tab === 'login' ? 'Sign in' : 'Create account';
    document.getElementById('authError').classList.add('hidden');

    const pwInput = document.getElementById('passwordInput');
    pwInput.autocomplete = tab === 'login' ? 'current-password' : 'new-password';
  }

  // Reset forgot form
  if (isForgot) {
    document.getElementById('forgotEmail').value = '';
    document.getElementById('forgotError').classList.add('hidden');
    document.getElementById('forgotSuccess').classList.add('hidden');
  }
}

// ── Submit auth ───────────────────────────────────────────────────────────
async function submitAuth(e) {
  e.preventDefault();

  const submitBtn     = document.getElementById('submitBtn');
  const submitLabel   = document.getElementById('submitLabel');
  const submitSpinner = document.getElementById('submitSpinner');
  const errorEl       = document.getElementById('authError');

  const name     = document.getElementById('nameInput').value.trim();
  const email    = document.getElementById('emailInput').value.trim();
  const password = document.getElementById('passwordInput').value;

  if (!email || !password) return;
  if (activeTab === 'register' && !name) {
    showError('Please enter your name.'); return;
  }
  if (password.length < 6) {
    showError('Password must be at least 6 characters.'); return;
  }

  setLoading(true, submitBtn, submitLabel, submitSpinner);
  errorEl.classList.add('hidden');

  try {
    const path = activeTab === 'login' ? '/auth/login' : '/auth/register';
    const body = activeTab === 'login'
      ? { email, password }
      : { name, email, password };

    const r    = await fetch(API + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await r.json();

    if (!r.ok) {
      showError(data.error || 'Something went wrong. Please try again.');
      return;
    }

    localStorage.setItem('fl_token', data.token);
    localStorage.setItem('fl_user', JSON.stringify({
      userId: data.userId, name: data.name,
      email: data.email,   isPro: data.isPro,
    }));

    closeAuth();
    updateNavForUser();

    // Redirect to welcome page
    window.location.href = '/welcome.html';

  } catch {
    showError('No internet connection. Please try again.');
  } finally {
    setLoading(false, submitBtn, submitLabel, submitSpinner);
  }
}

// ── Submit forgot password ────────────────────────────────────────────────
async function submitForgot(e) {
  e.preventDefault();

  const btn     = document.getElementById('forgotBtn');
  const label   = document.getElementById('forgotLabel');
  const spinner = document.getElementById('forgotSpinner');
  const errorEl = document.getElementById('forgotError');
  const successEl = document.getElementById('forgotSuccess');

  const email = document.getElementById('forgotEmail').value.trim();
  if (!email) return;

  setLoading(true, btn, label, spinner);
  errorEl.classList.add('hidden');
  successEl.classList.add('hidden');

  try {
    const r = await fetch(API + '/auth/forgot-password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    });
    const data = await r.json();

    if (!r.ok) {
      showForgotError(data.error || 'Something went wrong. Please try again.');
      return;
    }

    // Always show success (even if email not found — security best practice)
    successEl.textContent = `If ${email} has an account, a reset link is on its way.`;
    successEl.classList.remove('hidden');
    btn.disabled = true;

  } catch {
    showForgotError('No internet connection. Please try again.');
  } finally {
    setLoading(false, btn, label, spinner);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────
function setLoading(on, btn, label, spinner) {
  btn.disabled = on;
  label.classList.toggle('hidden', on);
  spinner.classList.toggle('hidden', !on);
}

function showError(msg) {
  const el = document.getElementById('authError');
  el.textContent = msg;
  el.classList.remove('hidden');
}

function showForgotError(msg) {
  const el = document.getElementById('forgotError');
  el.textContent = msg;
  el.classList.remove('hidden');
}

// ── Toast ─────────────────────────────────────────────────────────────────
function showToastMessage(icon, title, subtitle) {
  injectToastStyle();
  const t = document.createElement('div');
  t.className = 'fl-toast';
  t.innerHTML = `
    <span class="fl-toast-icon">${icon}</span>
    <div class="fl-toast-body">
      <span class="fl-toast-title">${title}</span>
      ${subtitle ? `<span class="fl-toast-sub">${subtitle}</span>` : ''}
    </div>
  `;
  document.body.appendChild(t);
  requestAnimationFrame(() => t.classList.add('fl-toast-in'));
  setTimeout(() => {
    t.classList.remove('fl-toast-in');
    t.classList.add('fl-toast-out');
    setTimeout(() => t.remove(), 400);
  }, 4500);
}

function injectToastStyle() {
  if (document.getElementById('fl-toast-css')) return;
  const s = document.createElement('style');
  s.id = 'fl-toast-css';
  s.textContent = `
    .fl-toast {
      position: fixed; bottom: 28px; left: 50%;
      transform: translateX(-50%) translateY(20px);
      background: #0f0f1e; border: 1px solid rgba(109,76,250,.4);
      border-radius: 14px; padding: 14px 20px;
      display: flex; align-items: center; gap: 14px;
      box-shadow: 0 12px 48px rgba(0,0,0,.6), 0 0 0 1px rgba(109,76,250,.1);
      z-index: 9999; opacity: 0; transition: opacity .3s ease, transform .3s cubic-bezier(.34,1.56,.64,1);
      font-family: Inter, sans-serif; white-space: nowrap; pointer-events: none;
    }
    .fl-toast-in  { opacity: 1; transform: translateX(-50%) translateY(0); }
    .fl-toast-out { opacity: 0; transform: translateX(-50%) translateY(10px); transition: opacity .3s ease, transform .3s ease; }
    .fl-toast-icon { color: #8b6dff; font-size: 18px; flex-shrink: 0; }
    .fl-toast-body { display: flex; flex-direction: column; gap: 2px; }
    .fl-toast-title { font-size: 14px; font-weight: 600; color: #eeeef5; }
    .fl-toast-sub   { font-size: 13px; color: #6666aa; }
    .nav-avatar {
      width: 32px; height: 32px; border-radius: 50%;
      background: linear-gradient(135deg, #6d4cfa, #9b6dff);
      color: #fff; font-size: 12px; font-weight: 700;
      display: flex; align-items: center; justify-content: center;
      cursor: default; flex-shrink: 0;
    }
    .forgot-link {
      background: none; border: none; padding: 0; cursor: pointer;
      font-size: 13px; color: #6666aa; font-family: inherit;
      transition: color .2s;
    }
    .forgot-link:hover { color: #8b6dff; }
    .success-box {
      background: rgba(34,197,94,.1); border: 1px solid rgba(34,197,94,.25);
      border-radius: 8px; padding: 12px 14px;
      font-size: 14px; color: #4ade80; margin-bottom: 14px;
    }
  `;
  document.head.appendChild(s);
}
