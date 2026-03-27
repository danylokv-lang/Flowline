/**
 * Flowline Backend — Cloudflare Worker
 *
 * Routes:
 *   POST   /auth/register            — create account (email + password)
 *   POST   /auth/login               — login, returns JWT
 *   POST   /auth/forgot-password     — send password reset email
 *   POST   /auth/reset-password      — set new password via reset token
 *   DELETE /auth/account             — permanently delete account + all data (JWT required)
 *   GET    /user/profile             — get profile (JWT required)
 *   PUT    /user/profile             — update profile (JWT required)
 *   GET    /user/subscription        — check pro status (JWT required)
 *   POST   /ai                       — Claude proxy with per-user rate limit (JWT required)
 *   GET    /calendar                 — get week calendar (JWT required)
 *   POST   /calendar/sync            — save/replace days (JWT required)
 *
 * All routes require x-app-secret header (except /auth/*).
 * Authenticated routes also require Authorization: Bearer <token>
 *
 * Wrangler bindings needed:
 *   D1 database  → DB
 *   KV namespace → RATE_KV
 *   Secrets      → APP_SECRET, JWT_SECRET, CLAUDE_API_KEY, RESEND_API_KEY
 */

// ── Constants ──────────────────────────────────────────────────────────────

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-app-secret",
};

const FREE_AI_LIMIT_PER_DAY = 3;
const PRO_AI_LIMIT_PER_DAY  = 10;
const JWT_EXPIRY_SECONDS    = 90 * 24 * 60 * 60; // 90 days
const RESET_TOKEN_TTL       = 3600; // 1 hour

// ── Helpers ────────────────────────────────────────────────────────────────

function res(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

function now() {
  return Math.floor(Date.now() / 1000);
}

// ── JWT (Web Crypto — no external library needed) ──────────────────────────

function b64url(str) {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}
function fromb64url(str) {
  return atob(str.replace(/-/g, "+").replace(/_/g, "/"));
}

async function jwtSign(payload, secret) {
  const header  = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body    = b64url(JSON.stringify(payload));
  const data    = `${header}.${body}`;
  const key     = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sigBuf  = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  const sig     = b64url(String.fromCharCode(...new Uint8Array(sigBuf)));
  return `${data}.${sig}`;
}

async function jwtVerify(token, secret) {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [header, body, sig] = parts;
  const data = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["verify"]
  );
  const sigBytes = Uint8Array.from(fromb64url(sig), c => c.charCodeAt(0));
  const valid = await crypto.subtle.verify("HMAC", key, sigBytes, new TextEncoder().encode(data));
  if (!valid) return null;
  const payload = JSON.parse(fromb64url(body));
  if (payload.exp && payload.exp < now()) return null; // expired
  return payload;
}

async function getUserId(request, env) {
  const auth = request.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const payload = await jwtVerify(auth.slice(7), env.JWT_SECRET);
  return payload?.sub ?? null;
}

// ── Password Hashing (PBKDF2 — runs in Workers, no npm needed) ────────────

async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key  = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]
  );
  const hash = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: 100_000 }, key, 256
  );
  const toHex = (buf) => Array.from(buf).map(b => b.toString(16).padStart(2, "0")).join("");
  return `${toHex(salt)}:${toHex(new Uint8Array(hash))}`;
}

async function verifyPassword(password, stored) {
  const [saltHex, hashHex] = stored.split(":");
  const salt = new Uint8Array(saltHex.match(/.{2}/g).map(b => parseInt(b, 16)));
  const key  = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]
  );
  const hash = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: 100_000 }, key, 256
  );
  const newHex = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("");
  return newHex === hashHex;
}

// ── Rate Limiting (KV-backed, per-user per-day) ────────────────────────────

async function checkRateLimit(userId, env, limit) {
  const day = new Date().toISOString().slice(0, 10); // yyyy-MM-dd
  const key = `rl:${userId}:${day}`;
  const current = parseInt((await env.RATE_KV.get(key)) ?? "0");
  if (current >= limit) return false;
  await env.RATE_KV.put(key, String(current + 1), { expirationTtl: 86400 });
  return true;
}

// ── Email via Resend ───────────────────────────────────────────────────────

async function sendEmail(env, { to, subject, html, text }) {
  if (!env.RESEND_API_KEY) {
    console.warn("Email skipped — RESEND_API_KEY not configured");
    return false;
  }
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        // "hello@" is far more trusted than "noreply@" by spam filters.
        // Make sure this address is verified in your Resend domain settings.
        from: "Flowline <noreply@flowline.ink>",
        reply_to: "noreply@flowline.ink",
        to: [to],
        subject,
        html,
        // Plain-text alternative is required to avoid spam classification.
        // Gmail/Outlook heavily penalise HTML-only messages.
        text: text ?? subject,
        headers: {
          // Gives Gmail's "unsubscribe" button something to latch onto,
          // which signals you're a legitimate sender — even for transactional mail.
          "List-Unsubscribe": `<mailto:noreply@flowline.ink?subject=unsubscribe>`,
          "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
        },
      }),
    });
    if (!r.ok) {
      const body = await r.text().catch(() => "(unreadable)");
      console.error(`Email delivery failed [${r.status}] to=${to} subject="${subject}" resend_body=${body}`);
    }
    return r.ok;
  } catch (err) {
    console.error(`Email send error to=${to} subject="${subject}":`, err.message);
    return false;
  }
}

/**
 * Fire-and-forget email using ctx.waitUntil so the Worker keeps the Promise
 * alive after the HTTP response is returned. A bare sendEmail() call without
 * await and without waitUntil is killed the moment the Response is flushed.
 */
function sendEmailBackground(ctx, env, opts) {
  ctx.waitUntil(sendEmail(env, opts));
}

// All styles are inlined and table-based — the only layout that renders
// correctly in Gmail, Outlook (Windows), iOS Mail, and every other client.
// Gmail strips <style> blocks and all class-based CSS. Flexbox/grid/box-shadow
// are not supported in Outlook desktop at all.
function emailBase(content, { preheader = "" } = {}) {
  const F = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
  return `<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta name="x-apple-disable-message-reformatting"/>
<title>Flowline</title>
<!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
<style>
  body,table,td,a{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%}
  table,td{mso-table-lspace:0;mso-table-rspace:0}
  img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic}
  body{margin:0;padding:0;background-color:#07070f}
  a[x-apple-data-detectors]{color:inherit!important;text-decoration:none!important}
</style>
</head>
<body style="margin:0;padding:0;background-color:#07070f;">
${preheader ? `<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;color:#07070f;">${preheader}&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;</div>` : ""}

<!-- Outer wrapper -->
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#07070f;">
<tr><td align="center" style="padding:32px 16px 48px;">

  <!-- Inner max-width -->
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:520px;">

    <!-- Logo row -->
    <tr><td style="padding-bottom:24px;">
      <a href="https://flowline.ink" style="text-decoration:none;display:inline-block;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0">
          <tr>
            <td style="vertical-align:middle;padding-right:8px;">
              <img src="https://flowline.ink/icon-email.png" width="28" height="28" alt="Flowline"
                   style="display:block;width:28px;height:28px;"
                   onerror="this.style.display='none'"/>
              <!--[if !mso]><!-->
              <div style="display:none;">
              <svg width="28" height="28" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" style="display:block;">
                <path d="M9 1L16 5V13L9 17L2 13V5L9 1Z" fill="#6d4cfa"/>
                <path d="M9 5L13 7.5V12.5L9 15L5 12.5V7.5L9 5Z" fill="#07070f"/>
              </svg>
              </div>
              <!--<![endif]-->
            </td>
            <td style="vertical-align:middle;">
              <span style="font-family:${F};font-size:17px;font-weight:700;color:#ffffff;letter-spacing:-0.3px;">Flowline</span>
            </td>
          </tr>
        </table>
      </a>
    </td></tr>

    <!-- Card -->
    <tr><td style="background-color:#0d0d1f;border:1px solid #2a1f5a;border-radius:16px;overflow:hidden;">
      ${content}
    </td></tr>

    <!-- Footer -->
    <tr><td style="padding-top:24px;text-align:center;font-family:${F};font-size:12px;color:#44445a;line-height:1.7;">
      &copy; 2026 Flowline &nbsp;&middot;&nbsp;
      <a href="https://flowline.ink/privacy.html" style="color:#44445a;text-decoration:underline;">Privacy Policy</a><br/>
      You received this because you created a Flowline account.<br/>
      Questions? <a href="mailto:noreply@flowline.ink" style="color:#44445a;text-decoration:underline;">noreply@flowline.ink</a>
    </td></tr>

  </table>
</td></tr>
</table>

</body>
</html>`;
}

// ── Reusable email building blocks (table-safe, inline styles only) ─────────

function emailHero({ badge, title, subtitle }) {
  const F = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
  return `
    <!-- Hero -->
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
           style="background-color:#130d2e;border-bottom:1px solid #2a1f5a;">
      <tr><td style="padding:36px 36px 28px;">
        <!-- Badge -->
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin-bottom:16px;">
          <tr>
            <td style="background-color:#1e1460;border:1px solid #4a35a0;border-radius:20px;padding:4px 12px;">
              <span style="font-family:${F};font-size:11px;font-weight:600;color:#a78bfa;letter-spacing:0.6px;text-transform:uppercase;">${badge}</span>
            </td>
          </tr>
        </table>
        <!-- Title -->
        <h1 style="margin:0 0 10px;font-family:${F};font-size:26px;font-weight:800;color:#ffffff;line-height:1.25;letter-spacing:-0.5px;">${title}</h1>
        <!-- Subtitle -->
        <p style="margin:0;font-family:${F};font-size:15px;line-height:1.6;color:#8888bb;">${subtitle}</p>
      </td></tr>
    </table>`;
}

function emailStep(num, strong, rest) {
  const F = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
  return `
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom:14px;">
      <tr>
        <td width="32" style="vertical-align:top;padding-top:1px;">
          <table role="presentation" cellspacing="0" cellpadding="0" border="0">
            <tr><td width="26" height="26" style="width:26px;height:26px;background-color:#1e1460;border:1px solid #4a35a0;border-radius:50%;text-align:center;vertical-align:middle;">
              <span style="font-family:${F};font-size:12px;font-weight:700;color:#a78bfa;line-height:26px;">${num}</span>
            </td></tr>
          </table>
        </td>
        <td style="padding-left:12px;vertical-align:top;padding-top:4px;">
          <span style="font-family:${F};font-size:14px;line-height:1.55;color:#8888aa;">
            <strong style="color:#ddddee;font-weight:600;">${strong}</strong> ${rest}
          </span>
        </td>
      </tr>
    </table>`;
}

function emailButton(label, href) {
  const F = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
  return `
    <!-- Button — MSO VML fallback keeps it styled in Outlook desktop -->
    <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 auto;">
      <tr>
        <td align="center" style="border-radius:10px;background-color:#6d4cfa;">
          <!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${href}" style="height:46px;v-text-anchor:middle;width:180px;" arcsize="22%" strokecolor="#6d4cfa" fillcolor="#6d4cfa"><w:anchorlock/><center style="font-family:Arial,sans-serif;font-size:15px;font-weight:bold;color:#ffffff;">Open Flowline</center></v:roundrect><![endif]-->
          <!--[if !mso]><!-->
          <a href="${href}"
             style="display:inline-block;font-family:${F};font-size:15px;font-weight:700;color:#ffffff;text-decoration:none;padding:13px 32px;border-radius:10px;background-color:#6d4cfa;mso-hide:all;">${label}</a>
          <!--<![endif]-->
        </td>
      </tr>
    </table>`;
}


function emailDivider() {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:20px 0;">
    <tr><td style="height:1px;background-color:#1e1e38;font-size:1px;line-height:1px;">&nbsp;</td></tr>
  </table>`;
}

// ── Auth: Register ─────────────────────────────────────────────────────────

async function handleRegister(req, env, ctx) {
  const { email, password, name } = await req.json();
  if (!email || !password || !name)
    return res({ error: "email, password and name are required" }, 400);
  if (password.length < 6)
    return res({ error: "Password must be at least 6 characters" }, 400);

  const exists = await env.DB
    .prepare("SELECT id FROM users WHERE email = ?")
    .bind(email.toLowerCase()).first();
  if (exists) return res({ error: "Email already registered" }, 409);

  const userId = crypto.randomUUID();
  const hash   = await hashPassword(password);
  const ts     = now();

  await env.DB.prepare(
    "INSERT INTO users (id, email, password_hash, name, is_pro, created_at, updated_at) VALUES (?,?,?,?,0,?,?)"
  ).bind(userId, email.toLowerCase(), hash, name, ts, ts).run();

  await env.DB.prepare(
    "INSERT INTO profiles (user_id, wake_time, sleep_time, has_work_hours, bio, updated_at) VALUES (?,?,?,0,'',?)"
  ).bind(userId, "07:00", "23:00", ts).run();

  const token = await jwtSign({ sub: userId, exp: now() + JWT_EXPIRY_SECONDS }, env.JWT_SECRET);

  // Welcome email — sent after response using ctx.waitUntil so the Worker keeps
  // the Promise alive even after the response has been returned to the client.
  // A bare sendEmail() call without await/waitUntil is killed when the Response
  // flushes — that is the root cause of unreliable welcome email delivery.
  const F = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
  sendEmailBackground(ctx, env, {
    to: email.toLowerCase(),
    subject: `${name}, your Flowline account is ready`,
    text: `Hi ${name},\n\nWelcome to Flowline! Your account is ready.\n\n1. Open Flowline on your iPhone, iPad, or Mac\n2. Tell the AI what's on your plate — meetings, tasks, anything\n3. Get a realistic day plan in seconds\n\nhttps://flowline.ink\n\n— Danylo from Flowline\nnoreply@flowline.ink`,
    html: emailBase(
      emailHero({
        badge: "Account created",
        title: `Welcome to Flowline, ${name}!`,
        subtitle: "Your AI-powered day planner is ready. Let's plan your first day — it takes 60 seconds.",
      }) + `
      <!-- Body -->
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr><td style="padding:28px 36px 32px;">

          ${emailStep(1, "Open the app", "on your iPhone, iPad, or Mac.")}
          ${emailStep(2, "Tell the AI what's on your plate", "— meetings, tasks, anything.")}
          ${emailStep(3, "Get a realistic day plan", "blocked out and ready to follow.")}

          <!-- CTA -->
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:24px 0;">
            <tr><td align="center">${emailButton("Open Flowline", "https://flowline.ink")}</td></tr>
          </table>

        </td></tr>
      </table>`,
      { preheader: `Welcome, ${name}! Your Flowline account is ready — plan your first day in 60 seconds.` }
    ),
  });

  console.log(`New account created: userId=${userId} email=${email.toLowerCase()}`);
  return res({ token, userId, name, email: email.toLowerCase(), isPro: false });
}

// ── Auth: Login ────────────────────────────────────────────────────────────

async function handleLogin(req, env) {
  const { email, password } = await req.json();
  if (!email || !password) return res({ error: "Missing credentials" }, 400);

  const user = await env.DB.prepare(
    "SELECT id, name, email, password_hash, is_pro, pro_expires_at FROM users WHERE email = ?"
  ).bind(email.toLowerCase()).first();

  if (!user || !user.password_hash) return res({ error: "Invalid email or password" }, 401);

  const valid = await verifyPassword(password, user.password_hash);
  if (!valid) return res({ error: "Invalid email or password" }, 401);

  const isPro = user.is_pro === 1 && (!user.pro_expires_at || user.pro_expires_at > now());
  const token = await jwtSign({ sub: user.id, exp: now() + JWT_EXPIRY_SECONDS }, env.JWT_SECRET);
  return res({ token, userId: user.id, name: user.name, email: user.email, isPro });
}

// ── Auth: Forgot Password ──────────────────────────────────────────────────

async function handleForgotPassword(req, env) {
  const { email } = await req.json();
  if (!email) return res({ error: "Email required" }, 400);

  const user = await env.DB.prepare("SELECT id, name FROM users WHERE email = ?")
    .bind(email.toLowerCase()).first();

  // Always return success — don't reveal whether email is registered
  if (!user) return res({ success: true });

  // Delete any existing unused tokens for this user
  await env.DB.prepare("DELETE FROM password_reset_tokens WHERE user_id = ?")
    .bind(user.id).run();

  const token = crypto.randomUUID();
  const expiresAt = now() + RESET_TOKEN_TTL;

  await env.DB.prepare(
    "INSERT INTO password_reset_tokens (token, user_id, expires_at, used) VALUES (?,?,?,0)"
  ).bind(token, user.id, expiresAt).run();

  const resetUrl = `https://flowline.ink/reset-password.html?token=${token}`;

  const F2 = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
  await sendEmail(env, {
    to: email.toLowerCase(),
    subject: "Reset your Flowline password",
    text: `Hi,\n\nWe received a request to reset your Flowline password.\n\nReset link (expires in 1 hour):\n${resetUrl}\n\nIf you didn't request this, ignore this email — your password won't change.\n\n— Danylo from Flowline`,
    html: emailBase(
      emailHero({
        badge: "Password reset",
        title: "Reset your password",
        subtitle: "We received a request for your Flowline account. This link expires in 1 hour.",
      }) + `
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr><td style="padding:28px 36px 32px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom:20px;">
            <tr><td align="center">${emailButton("Reset password", resetUrl)}</td></tr>
          </table>
          ${emailDivider()}
          <p style="font-family:${F2};font-size:13px;color:#55556a;line-height:1.6;margin:0;text-align:center;">
            Didn't request this? Ignore this email — nothing will change.<br/>
            Or copy this link:<br/>
            <span style="word-break:break-all;color:#7c55ff;font-size:12px;">${resetUrl}</span>
          </p>
        </td></tr>
      </table>`,
      { preheader: "Reset your Flowline password — link expires in 1 hour." }
    ),
  });

  return res({ success: true });
}

// ── Auth: Reset Password ───────────────────────────────────────────────────

async function handleResetPassword(req, env, ctx) {
  const { token, password } = await req.json();
  if (!token || !password) return res({ error: "Token and password required" }, 400);
  if (password.length < 6) return res({ error: "Password must be at least 6 characters" }, 400);

  const record = await env.DB.prepare(
    "SELECT token, user_id, expires_at, used FROM password_reset_tokens WHERE token = ?"
  ).bind(token).first();

  if (!record)            return res({ error: "Invalid or expired reset link" }, 400);
  if (record.used)        return res({ error: "This reset link has already been used" }, 400);
  if (record.expires_at < now()) return res({ error: "Reset link has expired. Please request a new one." }, 400);

  const hash = await hashPassword(password);
  const ts   = now();

  await env.DB.prepare("UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?")
    .bind(hash, ts, record.user_id).run();

  await env.DB.prepare("UPDATE password_reset_tokens SET used = 1 WHERE token = ?")
    .bind(token).run();

  // Confirmation email
  const user = await env.DB.prepare("SELECT email, name FROM users WHERE id = ?")
    .bind(record.user_id).first();

  if (user) {
    const F3 = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
    sendEmailBackground(ctx, env, {
      to: user.email,
      subject: "Your Flowline password was changed",
      text: `Hi ${user.name},\n\nYour Flowline password was changed on ${new Date().toUTCString()}.\n\nIf you made this change, you're all set.\nIf you didn't — reset it immediately:\nhttps://flowline.ink/reset-password-request.html\n\nOr just reply to this email.\n\n— Danylo from Flowline`,
      html: emailBase(
        emailHero({
          badge: "Security notice",
          title: "Password changed",
          subtitle: `Hi ${user.name}, your Flowline password was successfully updated.`,
        }) + `
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
          <tr><td style="padding:28px 36px 32px;">
            <p style="font-family:${F3};font-size:14px;color:#8888aa;line-height:1.6;margin:0 0 16px;">
              If you made this change, you're all set — nothing else to do.<br/><br/>
              If you <strong style="color:#ddddee;">didn't</strong> make this change,
              <a href="https://flowline.ink/reset-password-request.html" style="color:#a78bfa;text-decoration:none;font-weight:600;">reset your password immediately</a>
              or reply to this email and we'll help right away.
            </p>
            ${emailDivider()}
            <p style="font-family:${F3};font-size:12px;color:#44445a;margin:0;">
              Changed on ${new Date().toUTCString()}
            </p>
          </td></tr>
        </table>`,
        { preheader: `Your Flowline password was just changed. If this wasn't you, act now.` }
      ),
    });
  }

  return res({ success: true });
}

// ── User: Get Profile ──────────────────────────────────────────────────────

async function handleGetProfile(userId, env) {
  const [user, profile] = await Promise.all([
    env.DB.prepare("SELECT id, name, email, is_pro, pro_expires_at FROM users WHERE id = ?")
      .bind(userId).first(),
    env.DB.prepare("SELECT wake_time, sleep_time, work_start, work_end, has_work_hours, bio, recurring_commitments, onboarding_done, weekly_saves, weekly_saves_monday, weekly_schedule FROM profiles WHERE user_id = ?")
      .bind(userId).first(),
  ]);
  if (!user) return res({ error: "User not found" }, 404);
  const isPro = user.is_pro === 1 && (!user.pro_expires_at || user.pro_expires_at > now());
  return res({ ...user, isPro, profile });
}

// ── User: Update Profile ───────────────────────────────────────────────────

async function handleUpdateProfile(userId, req, env) {
  const body = await req.json();
  const ts   = now();

  if (body.name) {
    await env.DB.prepare("UPDATE users SET name = ?, updated_at = ? WHERE id = ?")
      .bind(body.name, ts, userId).run();
  }

  if (body.profile) {
    const p = body.profile;
    await env.DB.prepare(`
      UPDATE profiles SET
        wake_time       = COALESCE(?, wake_time),
        sleep_time      = COALESCE(?, sleep_time),
        work_start      = COALESCE(?, work_start),
        work_end        = COALESCE(?, work_end),
        has_work_hours  = COALESCE(?, has_work_hours),
        bio             = COALESCE(?, bio),
        recurring_commitments = COALESCE(?, recurring_commitments),
        onboarding_done       = COALESCE(?, onboarding_done),
        weekly_saves          = COALESCE(?, weekly_saves),
        weekly_saves_monday   = COALESCE(?, weekly_saves_monday),
        weekly_schedule       = COALESCE(?, weekly_schedule),
        updated_at            = ?
      WHERE user_id = ?
    `).bind(
      p.wakeTime ?? null, p.sleepTime ?? null,
      p.workStart ?? null, p.workEnd ?? null,
      p.hasWorkHours ?? null, p.bio ?? null,
      p.recurringCommitments ?? null,
      p.onboardingDone ?? null,
      p.weeklySaves ?? null, p.weeklySavesMonday ?? null,
      p.weeklySchedule ?? null,
      ts, userId
    ).run();
  }

  return res({ success: true });
}

// ── User: Subscription ─────────────────────────────────────────────────────

async function handleGetSubscription(userId, env) {
  const user = await env.DB.prepare(
    "SELECT is_pro, pro_expires_at FROM users WHERE id = ?"
  ).bind(userId).first();
  if (!user) return res({ error: "Not found" }, 404);
  const isPro = user.is_pro === 1 && (!user.pro_expires_at || user.pro_expires_at > now());
  return res({ isPro, expiresAt: user.pro_expires_at });
}

// ── AI: Claude Proxy with per-user rate limit ──────────────────────────────

async function handleAI(userId, req, env) {
  const user  = await env.DB.prepare("SELECT is_pro, pro_expires_at FROM users WHERE id = ?")
    .bind(userId).first();
  const isPro = user?.is_pro === 1 && (!user.pro_expires_at || user.pro_expires_at > now());
  const limit = isPro ? PRO_AI_LIMIT_PER_DAY : FREE_AI_LIMIT_PER_DAY;

  const allowed = await checkRateLimit(userId, env, limit);
  if (!allowed) {
    return res({ error: "Daily AI message limit reached", isPro, limit }, 429);
  }

  const body     = await req.json();
  const upstream = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key":        env.CLAUDE_API_KEY,
      "anthropic-version":"2023-06-01",
      "anthropic-beta":   "prompt-caching-2024-07-31",
      "content-type":     "application/json",
    },
    body: JSON.stringify(body),
  });

  const data = await upstream.json();
  return res(data, upstream.status);
}

// ── Chat: Get Messages ─────────────────────────────────────────────────────

async function handleGetChats(userId, url, env) {
  const since = parseInt(url.searchParams.get("since") ?? "0");

  const result = await env.DB.prepare(`
    SELECT id, session_id, session_date, role, content, timestamp
    FROM chat_messages
    WHERE user_id = ? AND timestamp > ?
    ORDER BY timestamp ASC
    LIMIT 1000
  `).bind(userId, since).all();

  return res({ messages: result.results ?? [] });
}

// ── Chat: Sync Messages ────────────────────────────────────────────────────

const CHAT_TTL_DAYS = 90;

async function handleSyncChats(userId, req, env) {
  const { messages } = await req.json();
  if (!Array.isArray(messages)) return res({ error: "messages array required" }, 400);

  const valid = messages.filter(m => m.id && m.sessionId && m.role && m.content);
  if (valid.length === 0) return res({ success: true, synced: 0 });

  const cutoff = now() - CHAT_TTL_DAYS * 86400;
  const stmts = [
    env.DB.prepare("DELETE FROM chat_messages WHERE user_id = ? AND timestamp < ?")
      .bind(userId, cutoff),
    ...valid.map(msg =>
      env.DB.prepare(`
        INSERT OR IGNORE INTO chat_messages
          (id, user_id, session_id, session_date, role, content, timestamp)
        VALUES (?,?,?,?,?,?,?)
      `).bind(msg.id, userId, msg.sessionId, msg.sessionDate ?? "",
              msg.role, msg.content, msg.timestamp ?? now())
    ),
  ];
  await env.DB.batch(stmts);

  return res({ success: true, synced: valid.length });
}

// ── Reviews: Submit ───────────────────────────────────────────────────────

async function handleSubmitReview(userId, req, env) {
  const { rating, planDate } = await req.json();

  if (!rating || rating < 1 || rating > 5) return res({ error: "rating must be 1–5" }, 400);
  if (!planDate) return res({ error: "planDate required (yyyy-MM-dd)" }, 400);

  const id = crypto.randomUUID();
  await env.DB.prepare(`
    INSERT INTO plan_reviews (id, user_id, rating, plan_date, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).bind(id, userId, rating, planDate, now()).run();

  return res({ success: true });
}

// ── Reviews: Admin Stats ──────────────────────────────────────────────────
// Protected by ADMIN_SECRET env var header: X-Admin-Key

async function handleAdminStats(request, env) {
  const adminKey = request.headers.get("x-admin-key");
  if (!adminKey || adminKey !== env.ADMIN_SECRET) {
    return res({ error: "Forbidden" }, 403);
  }

  const [total, dist, daily, recent, users] = await Promise.all([
    // Total reviews
    env.DB.prepare("SELECT COUNT(*) as count, AVG(rating) as avg FROM plan_reviews").first(),

    // Rating distribution
    env.DB.prepare(`
      SELECT rating, COUNT(*) as count
      FROM plan_reviews
      GROUP BY rating ORDER BY rating
    `).all(),

    // Daily averages — last 30 days
    env.DB.prepare(`
      SELECT plan_date, ROUND(AVG(rating), 2) as avg, COUNT(*) as count
      FROM plan_reviews
      WHERE created_at > ?
      GROUP BY plan_date
      ORDER BY plan_date DESC
      LIMIT 30
    `).bind(now() - 30 * 86400).all(),

    // 20 most recent reviews
    env.DB.prepare(`
      SELECT r.plan_date, r.rating, r.created_at, u.email
      FROM plan_reviews r
      JOIN users u ON u.id = r.user_id
      ORDER BY r.created_at DESC
      LIMIT 20
    `).all(),

    // Unique reviewers count
    env.DB.prepare("SELECT COUNT(DISTINCT user_id) as count FROM plan_reviews").first(),
  ]);

  return res({
    totalReviews:  total?.count ?? 0,
    averageRating: total?.avg ? Math.round(total.avg * 10) / 10 : null,
    uniqueReviewers: users?.count ?? 0,
    distribution: dist.results ?? [],
    dailyAverages: daily.results ?? [],
    recentReviews: recent.results ?? [],
  });
}

// ── Calendar: Get Week ─────────────────────────────────────────────────────

async function handleGetCalendar(userId, url, env) {
  const weekStart = url.searchParams.get("weekStart"); // yyyy-MM-dd
  const weekEnd   = url.searchParams.get("weekEnd");

  if (!weekStart || !weekEnd) return res({ error: "weekStart and weekEnd required" }, 400);

  const days = await env.DB.prepare(`
    SELECT
      cd.id, cd.date, cd.ai_notes,
      json_group_array(json_object(
        'id', sb.id, 'title', sb.title, 'category', sb.category,
        'startTime', sb.start_time, 'endTime', sb.end_time
      )) AS blocks
    FROM calendar_days cd
    LEFT JOIN schedule_blocks sb ON sb.day_id = cd.id
    WHERE cd.user_id = ? AND cd.date >= ? AND cd.date <= ?
    GROUP BY cd.id
    ORDER BY cd.date
  `).bind(userId, weekStart, weekEnd).all();

  const result = (days.results ?? []).map(d => ({
    ...d,
    blocks: JSON.parse(d.blocks).filter(b => b.id !== null),
  }));

  return res({ days: result });
}

// ── Plan Saves: Increment (server-enforced free-tier limit) ───────────────
//
// Returns { allowed: true, weeklySaves: N, weeklySavesMonday: "yyyy-MM-dd" }
// Returns 403  { error: "Weekly plan limit reached" } when free user hits 3/week

const FREE_WEEKLY_SAVE_LIMIT = 3;

function currentMondayISO() {
  const d = new Date();
  const dayOfWeek = d.getUTCDay();
  const daysToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
  const monday = new Date(d);
  monday.setUTCDate(d.getUTCDate() + daysToMonday);
  return monday.toISOString().slice(0, 10);
}

async function handleIncrementPlanSave(userId, env) {
  const monday = currentMondayISO();

  const [user, profile] = await Promise.all([
    env.DB.prepare("SELECT is_pro, pro_expires_at FROM users WHERE id = ?").bind(userId).first(),
    env.DB.prepare("SELECT weekly_saves, weekly_saves_monday FROM profiles WHERE user_id = ?").bind(userId).first(),
  ]);
  if (!user) return res({ error: "User not found" }, 404);

  const isPro = user.is_pro === 1 && (!user.pro_expires_at || user.pro_expires_at > now());

  const savedMonday = profile?.weekly_saves_monday ?? "";
  const currentCount = savedMonday === monday ? (profile?.weekly_saves ?? 0) : 0;

  if (!isPro && currentCount >= FREE_WEEKLY_SAVE_LIMIT) {
    return res({ error: "Weekly plan limit reached", weeklySaves: currentCount, weeklySavesMonday: monday }, 403);
  }

  const newCount = currentCount + 1;
  const ts = now();
  await env.DB.prepare(`
    UPDATE profiles SET weekly_saves = ?, weekly_saves_monday = ?, updated_at = ? WHERE user_id = ?
  `).bind(newCount, monday, ts, userId).run();

  return res({ allowed: true, weeklySaves: newCount, weeklySavesMonday: monday });
}

// ── Calendar: Sync (replace days) ─────────────────────────────────────────

async function handleSyncCalendar(userId, req, env) {
  const { days } = await req.json();
  if (!Array.isArray(days)) return res({ error: "days array required" }, 400);

  const validDays = days.filter(d => d.date);
  if (validDays.length === 0) return res({ success: true, synced: 0 });

  const ts = now();
  const dates = validDays.map(d => d.date);

  // 1. Single read to get all existing day IDs for these dates
  const placeholders = dates.map(() => "?").join(",");
  const existing = await env.DB.prepare(
    `SELECT id, date FROM calendar_days WHERE user_id = ? AND date IN (${placeholders})`
  ).bind(userId, ...dates).all();

  const dateToId = Object.fromEntries((existing.results ?? []).map(r => [r.date, r.id]));

  // 2. Build one batch for all writes: upsert days + delete old blocks + insert new blocks
  const stmts = [];
  for (const day of validDays) {
    const dayId = dateToId[day.date] ?? crypto.randomUUID();
    if (dateToId[day.date]) {
      stmts.push(
        env.DB.prepare("UPDATE calendar_days SET ai_notes = ?, updated_at = ? WHERE id = ?")
          .bind(day.aiNotes ?? null, ts, dayId)
      );
    } else {
      stmts.push(
        env.DB.prepare("INSERT INTO calendar_days (id, user_id, date, ai_notes, updated_at) VALUES (?,?,?,?,?)")
          .bind(dayId, userId, day.date, day.aiNotes ?? null, ts)
      );
    }
    stmts.push(env.DB.prepare("DELETE FROM schedule_blocks WHERE day_id = ?").bind(dayId));
    for (const block of day.blocks ?? []) {
      stmts.push(
        env.DB.prepare(`
          INSERT INTO schedule_blocks (id, day_id, user_id, title, category, start_time, end_time, created_at)
          VALUES (?,?,?,?,?,?,?,?)
        `).bind(crypto.randomUUID(), dayId, userId, block.title, block.category,
                block.startTime, block.endTime, ts)
      );
    }
  }
  if (stmts.length > 0) await env.DB.batch(stmts);

  return res({ success: true, synced: validDays.length });
}

// ── Inbox: Get Tasks ───────────────────────────────────────────────────────

async function handleGetInbox(userId, env) {
  const result = await env.DB.prepare(`
    SELECT id, text, category, is_scheduled, created_at
    FROM captured_tasks
    WHERE user_id = ?
    ORDER BY created_at DESC
    LIMIT 500
  `).bind(userId).all();
  return res({ tasks: result.results ?? [] });
}

// ── Inbox: Sync Tasks ──────────────────────────────────────────────────────

async function handleSyncInbox(userId, req, env) {
  const { tasks } = await req.json();
  if (!Array.isArray(tasks)) return res({ error: "tasks array required" }, 400);

  const valid = tasks.filter(t => t.id && t.text);
  if (valid.length === 0) return res({ success: true, synced: 0 });

  const stmts = valid.map(task =>
    env.DB.prepare(`
      INSERT INTO captured_tasks (id, user_id, text, category, is_scheduled, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET is_scheduled = excluded.is_scheduled
    `).bind(
      task.id, userId,
      task.text,
      task.category ?? "work",
      task.isScheduled ? 1 : 0,
      task.createdAt ?? Math.floor(Date.now() / 1000)
    )
  );
  await env.DB.batch(stmts);

  return res({ success: true, synced: valid.length });
}

// ── Auth: Delete Account ────────────────────────────────────────────────────

async function handleDeleteAccount(userId, env) {
  // Explicitly delete in dependency order — do NOT rely on CASCADE.
  // D1 (SQLite) ignores foreign-key cascades unless PRAGMA foreign_keys = ON
  // is set per-connection, which is not guaranteed in Cloudflare D1.
  await env.DB.batch([
    env.DB.prepare("DELETE FROM schedule_blocks          WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM calendar_days            WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM chat_messages            WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM captured_tasks           WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM plan_reviews             WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM password_reset_tokens    WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM profiles                 WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM users                    WHERE id       = ?").bind(userId),
  ]);
  return res({ success: true });
}

// ── Main Router ────────────────────────────────────────────────────────────

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS });
    }

    const url    = new URL(request.url);
    const path   = url.pathname;
    const method = request.method;

    try {
      // ── Auth routes — open to website + iOS (no app-secret needed) ───
      // ctx is threaded to handlers that send background emails via ctx.waitUntil()
      if (path === "/auth/register"        && method === "POST") return handleRegister(request, env, ctx);
      if (path === "/auth/login"           && method === "POST") return handleLogin(request, env);
      if (path === "/auth/forgot-password" && method === "POST") return handleForgotPassword(request, env);
      if (path === "/auth/reset-password"  && method === "POST") return handleResetPassword(request, env, ctx);

      // ── Admin routes — protected by ADMIN_SECRET, callable from browser/curl ──
      if (path === "/admin/stats" && method === "GET") return handleAdminStats(request, env);

      // All other routes require the app secret (iOS only)
      const appSecret = request.headers.get("x-app-secret");
      if (!appSecret || appSecret !== env.APP_SECRET) {
        return res({ error: "Unauthorized" }, 401);
      }

      // ── Legacy "/" route — iOS app posts here directly (no JWT needed) ──
      if (path === "/" && method === "POST") {
        const body     = await request.json();
        const upstream = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "x-api-key":         env.CLAUDE_API_KEY,
            "anthropic-version": "2023-06-01",
            "anthropic-beta":    "prompt-caching-2024-07-31",
            "content-type":      "application/json",
          },
          body: JSON.stringify(body),
        });
        const data = await upstream.json();
        return res(data, upstream.status);
      }

      // ── Gemini proxy — no JWT needed, key stored as Worker secret ────
      if (path === "/ai/gemini" && method === "POST") {
        const body  = await request.json();
        const model = body.model ?? "gemini-2.5-flash";
        const { model: _m, ...geminiBody } = body;
        const upstream = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`,
          {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(geminiBody),
          }
        );
        const data = await upstream.json();
        return res(data, upstream.status);
      }

      // ── Protected routes (JWT required) ──────────────────────────────
      const userId = await getUserId(request, env);
      if (!userId) return res({ error: "Not authenticated — include Bearer token" }, 401);

      if (path === "/auth/account"       && method === "DELETE") return handleDeleteAccount(userId, env);
      if (path === "/user/profile"      && method === "GET") return handleGetProfile(userId, env);
      if (path === "/user/profile"      && method === "PUT") return handleUpdateProfile(userId, request, env);
      if (path === "/user/subscription" && method === "GET") return handleGetSubscription(userId, env);
      if (path === "/ai"                && method === "POST") return handleAI(userId, request, env);
      if (path === "/calendar"          && method === "GET") return handleGetCalendar(userId, url, env);
      if (path === "/calendar/sync"     && method === "POST") return handleSyncCalendar(userId, request, env);
      if (path === "/chats"             && method === "GET") return handleGetChats(userId, url, env);
      if (path === "/chats/sync"        && method === "POST") return handleSyncChats(userId, request, env);
      if (path === "/reviews"           && method === "POST") return handleSubmitReview(userId, request, env);
      if (path === "/inbox"             && method === "GET")  return handleGetInbox(userId, env);
      if (path === "/inbox/sync"        && method === "POST") return handleSyncInbox(userId, request, env);
      if (path === "/plan-saves/increment" && method === "POST") return handleIncrementPlanSave(userId, env);

      return res({ error: "Not found" }, 404);
    } catch (err) {
      console.error("Worker error:", err.message, err.stack);
      return res({ error: "Internal server error" }, 500);
    }
  },
};
