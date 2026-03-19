const API = 'https://claude-proxy.danylokv.workers.dev';

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

// ── Auth modal ────────────────────────────────────────────────────────────
let activeTab = 'login';

function openAuth(tab = 'login') {
  switchTab(tab);
  document.getElementById('authModal').classList.add('open');
  setTimeout(() => document.getElementById('emailInput').focus(), 250);
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
  document.getElementById('tab-login').classList.toggle('active', tab === 'login');
  document.getElementById('tab-register').classList.toggle('active', tab === 'register');
  document.getElementById('nameGroup').classList.toggle('hidden', tab === 'login');
  document.getElementById('submitLabel').textContent = tab === 'login' ? 'Sign in' : 'Create account';
  document.getElementById('authError').classList.add('hidden');

  const pwInput = document.getElementById('passwordInput');
  pwInput.autocomplete = tab === 'login' ? 'current-password' : 'new-password';
}

// ── Submit ────────────────────────────────────────────────────────────────
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

    const res  = await fetch(API + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await res.json();

    if (!res.ok) {
      showError(data.error || 'Something went wrong. Please try again.');
      return;
    }

    localStorage.setItem('fl_token', data.token);
    localStorage.setItem('fl_user', JSON.stringify({
      userId: data.userId, name: data.name,
      email: data.email,   isPro: data.isPro,
    }));

    closeAuth();
    showToast(data.name, activeTab === 'register');

  } catch {
    showError('No internet connection. Please try again.');
  } finally {
    setLoading(false, submitBtn, submitLabel, submitSpinner);
  }
}

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

// ── Toast ─────────────────────────────────────────────────────────────────
function showToast(name, isNew) {
  const t = document.createElement('div');
  t.style.cssText = `
    position:fixed; bottom:28px; left:50%; transform:translateX(-50%) translateY(8px);
    background:#14142a; border:1px solid rgba(109,76,250,.35); border-radius:12px;
    padding:13px 20px; font-family:Inter,sans-serif; font-size:14px; font-weight:500;
    color:#eeeef5; box-shadow:0 8px 40px rgba(0,0,0,.5); z-index:300;
    display:flex; align-items:center; gap:12px; white-space:nowrap;
    animation:toastIn .3s cubic-bezier(.34,1.56,.64,1) forwards;
  `;
  t.innerHTML = `
    <span style="color:#8b6dff;font-size:16px">✦</span>
    <span>${isNew ? `Welcome, ${name}!` : `Welcome back, ${name}!`}</span>
    <span style="color:#44445a;font-size:13px">Open Flowline on your Mac to get started.</span>
  `;

  if (!document.getElementById('toast-style')) {
    const s = document.createElement('style');
    s.id = 'toast-style';
    s.textContent = `@keyframes toastIn{from{opacity:0;transform:translateX(-50%) translateY(16px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}`;
    document.head.appendChild(s);
  }

  document.body.appendChild(t);
  setTimeout(() => t.remove(), 5000);
}
