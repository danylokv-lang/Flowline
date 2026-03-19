/**
 * Flowline — Claude API Proxy (Cloudflare Worker)
 *
 * SETUP (5 min):
 * 1. Go to https://workers.cloudflare.com → Create Worker
 * 2. Paste this file
 * 3. Settings → Variables → Add: CLAUDE_API_KEY = your key, APP_SECRET = any random string
 * 4. Deploy → copy the worker URL (e.g. https://flowline-proxy.yourname.workers.dev)
 * 5. In Xcode: Config.swift → set proxyURL = "https://flowline-proxy.yourname.workers.dev/v1/messages"
 * 6. In Xcode: Config.swift → set appSecret = the same APP_SECRET you set above
 * 7. Delete Config.claudeAPIKey from the app — it's no longer needed
 */

export default {
  async fetch(request, env) {
    // ── CORS preflight ────────────────────────────────────────────────────
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    // ── Auth: verify app secret ───────────────────────────────────────────
    const appSecret = request.headers.get("x-app-secret");
    if (!appSecret || appSecret !== env.APP_SECRET) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // ── Forward to Claude ─────────────────────────────────────────────────
    try {
      const body = await request.json();

      const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": env.CLAUDE_API_KEY,
          "anthropic-version": "2023-06-01",
          "anthropic-beta": "prompt-caching-2024-07-31",
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      });

      const data = await claudeResponse.json();

      return new Response(JSON.stringify(data), {
        status: claudeResponse.status,
        headers: {
          "Content-Type": "application/json",
          ...corsHeaders(),
        },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: "Proxy error", detail: err.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  },
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, x-app-secret",
  };
}
