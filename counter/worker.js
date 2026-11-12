// Counter for the query site: thumbs up, thumbs down and downloads per query.
// GET  /counts            -> { "<query id>": { "up": 3, "down": 1, "dl": 12 }, ... }
// POST /hit?id=<id>&k=<k> -> k is up, down, dl, -up or -down (taking a vote back)
const ORIGIN = "https://adukes40.github.io";
const KINDS = new Set(["up", "down", "dl", "-up", "-down"]);
const cors = { "Access-Control-Allow-Origin": ORIGIN, "Access-Control-Allow-Methods": "GET, POST", "Content-Type": "application/json" };

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === "OPTIONS") return new Response(null, { headers: cors });
    // shortcut: all counts live in one KV value, so two clicks in the same second can lose one; move to a Durable Object if traffic grows.
    const counts = (await env.COUNTS.get("counts", "json")) || {};
    if (req.method === "GET" && url.pathname === "/counts") return new Response(JSON.stringify(counts), { headers: cors });
    if (req.method === "POST" && url.pathname === "/hit") {
      const id = url.searchParams.get("id") || "", k = url.searchParams.get("k") || "";
      if (!/^[a-z0-9-]{1,80}$/.test(id) || !KINDS.has(k)) return new Response('{"error":"bad id or k"}', { status: 400, headers: cors });
      const c = counts[id] = counts[id] || {}, key = k.replace("-", "");
      c[key] = Math.max(0, (c[key] || 0) + (k[0] === "-" ? -1 : 1));
      await env.COUNTS.put("counts", JSON.stringify(counts));
      return new Response(JSON.stringify(c), { headers: cors });
    }
    return new Response('{"error":"not found"}', { status: 404, headers: cors });
  },
};
