# Counter for thumbs and downloads

GitHub Pages can't store anything, so the thumbs up/down and download counts on the site live in this tiny Cloudflare Worker (free plan). Votes are anonymous, and each browser gets one vote per query.

## One-time setup

1. Make a free account at <https://dash.cloudflare.com/sign-up>.
2. On any computer with Node.js, in this `counter` folder:
   ```
   npx wrangler login
   npx wrangler kv namespace create COUNTS
   ```
   Copy the `id` it prints into `wrangler.toml` in place of `PASTE_KV_ID_HERE`.
3. `npx wrangler deploy`. It prints a URL like `https://ic-reports-counter.<you>.workers.dev`.
4. Paste that URL into `COUNTER_URL` near the top of the script in `site/index.html` and merge. The thumbs, download counts and the **Rating** sort appear on the site.

Until step 4, the site hides the ratings and works as before.
