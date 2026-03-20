/**
 * Flowline Backend — Cloudflare Worker
 *
 * Routes:
 *   POST /auth/register            — create account (email + password)
 *   POST /auth/login               — login, returns JWT
 *   POST /auth/forgot-password     — send password reset email
 *   POST /auth/reset-password      — set new password via reset token
 *   GET  /user/profile             — get profile (JWT required)
 *   PUT  /user/profile             — update profile (JWT required)
 *   GET  /user/subscription        — check pro status (JWT required)
 *   POST /ai                       — Claude proxy with per-user rate limit (JWT required)
 *   GET  /calendar                 — get week calendar (JWT required)
 *   POST /calendar/sync            — save/replace days (JWT required)
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

async function sendEmail(env, { to, subject, html }) {
  if (!env.RESEND_API_KEY) return false;
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Flowline <noreply@flowline.ink>",
        to: [to],
        subject,
        html,
      }),
    });
    return r.ok;
  } catch { return false; }
}

function emailBase(content) {
  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<style>
  body{margin:0;padding:0;background:#080810;font-family:Inter,-apple-system,sans-serif;color:#eeeef5}
  .wrap{max-width:480px;margin:40px auto;padding:0 20px}
  .logo{display:flex;align-items:center;gap:10px;margin-bottom:32px;font-weight:700;font-size:17px;color:#eeeef5;text-decoration:none}
  .card{background:#0f0f1e;border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:36px}
  h2{margin:0 0 12px;font-size:22px;font-weight:700;color:#eeeef5}
  p{margin:0 0 20px;font-size:15px;line-height:1.6;color:#aaaacc}
  .btn{display:inline-block;background:#6d4cfa;color:#fff;text-decoration:none;padding:13px 28px;border-radius:10px;font-weight:600;font-size:15px;margin:4px 0 20px}
  .note{font-size:13px;color:#55556a;line-height:1.5}
  .footer{margin-top:28px;font-size:12px;color:#44445a;text-align:center}
</style></head>
<body><div class="wrap">
  <a class="logo" href="https://flowline.ink">
    <svg width="20" height="20" viewBox="0 0 18 18" fill="none"><path d="M9 1L16 5V13L9 17L2 13V5L9 1Z" fill="#6d4cfa" opacity=".9"/><path d="M9 5L13 7.5V12.5L9 15L5 12.5V7.5L9 5Z" fill="#080810"/></svg>
    Flowline
  </a>
  <div class="card">${content}</div>
  <div class="footer">© 2026 Flowline · <a href="https://flowline.ink/privacy.html" style="color:#55556a">Privacy Policy</a></div>
</div></body></html>`;
}

// ── Auth: Register ─────────────────────────────────────────────────────────

async function handleRegister(req, env) {
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

  // Welcome email (non-blocking)
  sendEmail(env, {
    to: email.toLowerCase(),
    subject: "Welcome to Flowline ✦",
    html: emailBase(`
      <h2>Welcome, ${name}! ✦</h2>
      <p>You're all set. Open Flowline on your Mac to start planning your first day with AI — it only takes 60 seconds.</p>
      <a class="btn" href="https://flowline.ink">Open Flowline</a>
      <p class="note">You're on the Free plan — 3 AI messages per day to plan your schedule. Upgrade to Pro anytime for 10 messages/day and all features unlocked.</p>
    `),
  });

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

  await sendEmail(env, {
    to: email.toLowerCase(),
    subject: "Reset your Flowline password",
    html: emailBase(`
      <h2>Reset your password</h2>
      <p>We got a request to reset the password for your Flowline account. Click the button below — this link expires in 1 hour.</p>
      <a class="btn" href="${resetUrl}">Reset password</a>
      <p class="note">If you didn't request this, you can ignore this email — your password won't change.<br/><br/>Or copy this link: <span style="word-break:break-all;color:#8b6dff">${resetUrl}</span></p>
    `),
  });

  return res({ success: true });
}

// ── Auth: Reset Password ───────────────────────────────────────────────────

async function handleResetPassword(req, env) {
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
    sendEmail(env, {
      to: user.email,
      subject: "Your Flowline password has been changed",
      html: emailBase(`
        <h2>Password changed ✓</h2>
        <p>Hi ${user.name}, your Flowline password was successfully changed.</p>
        <p>If you made this change, you're all set. If you didn't, <a href="https://flowline.ink/reset-password-request.html" style="color:#8b6dff">reset your password immediately</a> or contact us at <a href="mailto:support@flowlineapp.com" style="color:#8b6dff">support@flowlineapp.com</a>.</p>
        <p class="note">This change was made on ${new Date().toUTCString()}.</p>
      `),
    });
  }

  return res({ success: true });
}

// ── User: Get Profile ──────────────────────────────────────────────────────

async function handleGetProfile(userId, env) {
  const [user, profile] = await Promise.all([
    env.DB.prepare("SELECT id, name, email, is_pro, pro_expires_at FROM users WHERE id = ?")
      .bind(userId).first(),
    env.DB.prepare("SELECT wake_time, sleep_time, work_start, work_end, has_work_hours, bio FROM profiles WHERE user_id = ?")
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
        wake_time      = COALESCE(?, wake_time),
        sleep_time     = COALESCE(?, sleep_time),
        work_start     = COALESCE(?, work_start),
        work_end       = COALESCE(?, work_end),
        has_work_hours = COALESCE(?, has_work_hours),
        bio            = COALESCE(?, bio),
        updated_at     = ?
      WHERE user_id = ?
    `).bind(
      p.wakeTime ?? null, p.sleepTime ?? null,
      p.workStart ?? null, p.workEnd ?? null,
      p.hasWorkHours ?? null, p.bio ?? null,
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

// ── Calendar: Sync (replace days) ─────────────────────────────────────────

async function handleSyncCalendar(userId, req, env) {
  const { days } = await req.json();
  if (!Array.isArray(days)) return res({ error: "days array required" }, 400);

  const ts = now();

  for (const day of days) {
    if (!day.date) continue;

    const existing = await env.DB.prepare(
      "SELECT id FROM calendar_days WHERE user_id = ? AND date = ?"
    ).bind(userId, day.date).first();

    const dayId = existing?.id ?? crypto.randomUUID();

    if (existing) {
      await env.DB.prepare("UPDATE calendar_days SET ai_notes = ?, updated_at = ? WHERE id = ?")
        .bind(day.aiNotes ?? null, ts, dayId).run();
      await env.DB.prepare("DELETE FROM schedule_blocks WHERE day_id = ?")
        .bind(dayId).run();
    } else {
      await env.DB.prepare(
        "INSERT INTO calendar_days (id, user_id, date, ai_notes, updated_at) VALUES (?,?,?,?,?)"
      ).bind(dayId, userId, day.date, day.aiNotes ?? null, ts).run();
    }

    for (const block of day.blocks ?? []) {
      await env.DB.prepare(`
        INSERT INTO schedule_blocks (id, day_id, user_id, title, category, start_time, end_time, created_at)
        VALUES (?,?,?,?,?,?,?,?)
      `).bind(crypto.randomUUID(), dayId, userId, block.title, block.category,
              block.startTime, block.endTime, ts).run();
    }
  }

  return res({ success: true, synced: days.length });
}

// ── Main Router ────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS });
    }

    const url    = new URL(request.url);
    const path   = url.pathname;
    const method = request.method;

    try {
      // ── Auth routes — open to website + iOS (no app-secret needed) ───
      if (path === "/auth/register"        && method === "POST") return handleRegister(request, env);
      if (path === "/auth/login"           && method === "POST") return handleLogin(request, env);
      if (path === "/auth/forgot-password" && method === "POST") return handleForgotPassword(request, env);
      if (path === "/auth/reset-password"  && method === "POST") return handleResetPassword(request, env);

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

      // ── Protected routes (JWT required) ──────────────────────────────
      const userId = await getUserId(request, env);
      if (!userId) return res({ error: "Not authenticated — include Bearer token" }, 401);

      if (path === "/user/profile"      && method === "GET") return handleGetProfile(userId, env);
      if (path === "/user/profile"      && method === "PUT") return handleUpdateProfile(userId, request, env);
      if (path === "/user/subscription" && method === "GET") return handleGetSubscription(userId, env);
      if (path === "/ai"                && method === "POST") return handleAI(userId, request, env);
      if (path === "/calendar"          && method === "GET") return handleGetCalendar(userId, url, env);
      if (path === "/calendar/sync"     && method === "POST") return handleSyncCalendar(userId, request, env);

      return res({ error: "Not found" }, 404);
    } catch (err) {
      console.error("Worker error:", err.message, err.stack);
      return res({ error: "Internal server error" }, 500);
    }
  },
};
