# Security audit: Heya Wrapped

Audit date: November 22, 2026. Scope: the live Wrapped app (`app/server.py` + `app/index.html` on Render), the product page on GitHub Pages (`docs/`), and the repo.

Live app: https://heya-wrapped.onrender.com (Render free web service `heya-wrapped`)
Product page: https://building-with-ai-f26.github.io/tmw8694-Heya/

## What kind of app this is

**AI app, no database.** There's no sign-in and nothing is saved. The server reads two fictional demo tap histories (`app/data/*.json`), computes the stats itself, and makes one OpenRouter call so the AI can write the words. The only secret is the OpenRouter API key, and the only paid route is `POST /api/wrapped`. The product page is static HTML with no secrets.

So the tests that apply are: **the API key isn't exposed**, and **30 calls in a row to the AI route trigger a 429**.

## Summary

| Check | Result |
| --- | --- |
| Secret search, repo + full git history | Clean. `.env` was never committed. Only hit is the `sk-or-...` placeholder in AGENTS.md. |
| Secret search, live site | Clean on https://heya-wrapped.onrender.com. Only the `phc_` PostHog token, which is meant to be public. |
| Rate limit, 30 calls to `/api/wrapped` | **Fixed.** Was unlimited. Live: calls 1–10 got 200, calls 11–30 got 429 with `Retry-After`. |
| Server source / data files reachable over HTTP | **Fixed.** Blocklist was bypassable 5 ways; replaced with an allowlist. |
| Dependency audit (`pip-audit`) | No known vulnerabilities (standard library only, no packages). |
| Spending cap on AI provider | Separate production OpenRouter key with a $2 monthly credit limit, auto top-up off. Plus a site-wide cap of 300 AI calls/day in code. |
| Agent guardrails | Added `.claude/settings.json`: destructive commands need approval; agent can't read `.env`. |
| Database backup / RLS / storage buckets | Not applicable: no database, no file uploads. |

## What I checked and found

### 1. Secret keys

Searched for `sb_secret_`, `service_role`, `sk-or-`, `sk-ant-`, `sk-proj-`, `sk_live_` in:

- **Working tree** (`grep -rnE ... --exclude-dir=.git .`, excluding the local `.env`): one hit, the `sk-or-...` placeholder text in AGENTS.md. Not a key.
- **Every commit on every branch** (`git log -p --all | grep -E ...` with real key shapes like `sk-or-v1-[a-f0-9]{8}`): no hits.
- **Was `.env` ever committed?** `git log --all -- .env`: no. It's in `.gitignore`.
- **Served page** (`curl <site>/ | grep -E ...`): no hits. The key is read from the environment by `server.py` and only ever sent from the server to OpenRouter, never to the browser.
- **Can the browser fetch `.env` or `server.py`?** Before the fix, `server.py` and the data files could be downloaded (see attack log). `.env` sits one folder above the served folder so it wasn't reachable, but now everything outside the allowlist is 404.

The PostHog `phc_` project token is in the page on purpose; it's a public write-only token.

No keys were exposed, so none needed rotating. The production key on Render is a separate key from the local `.env` one.

### 2. Rate limiting and spending

Before: `POST /api/wrapped` had no limit. Anyone could script it and spend the OpenRouter balance (about $0.0004 per call).

Fixed in `app/server.py` (`RateLimiter`):

- **Per visitor:** 10 AI calls per 10 minutes, keyed by client IP (first `X-Forwarded-For` entry on Render). Extra calls get HTTP 429, a `Retry-After` header, and a friendly message the page shows ("Try again in about 10 minutes").
- **Site-wide:** 300 AI calls per 24 hours, a backstop even if someone rotates IPs or fakes `X-Forwarded-For`. At current prices that caps spending at roughly $0.12/day.
- All three numbers are environment variables (`RATE_LIMIT_PER_VISITOR`, `RATE_WINDOW_SECONDS`, `DAILY_AI_CAP`), so they can be changed on Render without a code change.
- `/api/stats` doesn't call a paid API and there's no database, so it isn't limited.
- **Provider cap:** the production OpenRouter key should have a credit limit (AGENTS.md, Deploy step 2). This is the hard stop if the code limits ever fail.

Test (local, limit set to 5 at the time; repeat on live):

```sh
for i in $(seq 1 30); do curl -s -o /dev/null -w "%{http_code} " -X POST "$SITE/api/wrapped" \
  -H 'Content-Type: application/json' -d '{"wearer":"grant"}'; done
```

Local result (limit was 5 then): 5 × 200, then 25 × 429.

**Live result** on https://heya-wrapped.onrender.com (limit 10): `200` × 10, then `429` × 20. The 31st call returned `HTTP/2 429`, `retry-after: 573` and `{"error": "You've made a lot of Wrappeds. Try again in about 10 minutes."}`.

### 3. Agent security review (trying to break it)

I read `server.py` and `index.html` looking for ways in, then attacked the running server. Findings and fixes:

| Finding | Severity | Fix |
| --- | --- | --- |
| File blocklist (`path.lstrip("/").startswith(("server.py","data/"))`) bypassed by `/./server.py`, `/%73erver.py`, `/fonts/../data/faith.json`, and `HEAD /server.py` (HEAD skipped the check entirely) | Medium: leaked source and data (no secrets in them, but the intent was to hide them) | Replaced with an allowlist in `send_head()`, which GET and HEAD both use. Path is URL-decoded and normalized first. Only `/`, `/index.html` and `/fonts/*.woff2|txt` are served. |
| Directory listing at `/fonts/` | Low | Allowlist; folder paths are 404. |
| No rate limit on the paid AI route | High (cost) | See section 2. |
| Raw OpenRouter error text (`HTTP 401: {...}`) sent to the browser | Low (info leak) | Browser gets a generic message; details go to the server log only. |
| No body size limit; non-numeric `Content-Length` crashed into a 502 | Low | Bodies over 1 KB get 413; bad JSON or length gets 400. |
| No socket timeout (slow clients could tie up threads) | Low | 20-second handler timeout. |
| Server header revealed Python version (`SimpleHTTP/0.6 Python/3.9.6`) | Info | Now just `Heya`. |
| No security headers | Low | Added `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, and HSTS on Render. API responses are `Cache-Control: no-store`. |
| Leaflet map library loaded from unpkg with no integrity check | Low (supply chain) | Added SRI `integrity` hashes (checked against Leaflet's published hashes). |
| Server only listened on `127.0.0.1` | Deploy blocker | `HOST` env var; Render sets `0.0.0.0`. Local default stays `127.0.0.1`. |

Things checked that were already fine:

- **XSS from AI output:** the page escapes every AI string with `esc()` before putting it in HTML, and uses `textContent` for the caption. A prompt-injected `<script>` in a card would show as text.
- **Prompt injection from visitors:** visitors can't send any text to the AI. The only input is `wearer`, which must be exactly `grant` or `faith`; everything in the prompt comes from server-side files.
- **Path traversal through `wearer`:** `{"wearer":"../../.env"}` gets 400, because it's checked against a fixed dictionary, not used as a path.
- **Kids' privacy:** Grant's data has no locations, and the server never sends coordinates to the AI.
- **iPhone app (`ios/`):** its Swift server listens on loopback only (`requiredLocalEndpoint = .loopback`), so other devices on the Wi-Fi can't reach it.

### 4. Dependencies

- Python: standard library only. `requirements.txt` is intentionally empty. `pip-audit -r requirements.txt`: **No known vulnerabilities found.**
- Browser: Leaflet 1.9.4 and PostHog from CDNs. No npm project, so `npm audit` doesn't apply. Leaflet 1.9.4 is the current stable release and is now pinned with SRI.

### 5. Protecting production from the agent

- `.claude/settings.json` (committed, so it applies to Jorge's agent too) puts `rm -rf`, `rm -r`, `git push` (incl. `--force`), `git reset --hard`, `git clean`, `git checkout --`, `git branch -D`, `gh repo delete`, DELETE API calls, and the `render` CLI on the **ask first** list, and **denies** reading or editing `.env`.
- AGENTS.md says production is the Render service and agents test locally first.
- No database, so there's nothing to back up. The demo data is version-controlled in git.

## Attack log

| # | Attack | Before fix | After fix |
| --- | --- | --- | --- |
| 1 | `GET /./server.py` and `GET /%73erver.py` to download the server source | 200, source served | 404 |
| 2 | `GET /fonts/../data/faith.json` to read the data folder by traversal | 200, data served | 404 |
| 3 | `HEAD /server.py` (HEAD skipped the GET check) | 200 | 404 |
| 4 | 30 × `POST /api/wrapped` in a row to burn AI credits | 30 × 200 (30 paid calls) | 5 × 200, then 429 with `Retry-After` |
| 5 | Malformed / oversized bodies: `notjson`, a 5 KB body, `{"wearer":"../../.env"}` | 502 with internal error text / processed | 400, 413, 400 with plain messages |
| 6 | After being rate-limited, resend with a fake `X-Forwarded-For: 1.2.3.4` header to get a new bucket (live) | n/a | **Worked**: got 200. Known gap (see Remaining issues); spending is still bounded by the 300/day site cap and the $2 OpenRouter limit. |

## Live checks (run after each deploy)

```sh
SITE=https://heya-wrapped.onrender.com
# 1. No secrets in what the browser gets
curl -s $SITE/ | grep -nE "sb_secret_|service_role|sk-or-|sk-ant-|sk-proj-|sk_live_" || echo "clean"
# 2. Private files are 404
for p in /server.py /./server.py /data/faith.json /fonts/ /.env; do curl -s -o /dev/null -w "$p %{http_code}\n" --path-as-is $SITE$p; done
# 3. Rate limit: expect 10 x 200 then 429s
for i in $(seq 1 30); do curl -s -o /dev/null -w "%{http_code} " -X POST $SITE/api/wrapped -H 'Content-Type: application/json' -d '{"wearer":"grant"}'; done; echo
```

Live results, November 22, 2026:

| Check | Result |
| --- | --- |
| `/healthz` | `{"ok": true}` |
| Secret search on served page | clean (only `phc_` PostHog token) |
| `/server.py`, `/./server.py`, `/%73erver.py`, `/fonts/../data/faith.json`, `/data/faith.json`, `/fonts/`, `/.env`, `HEAD /server.py` | all 404 (`/../.env` is rejected with 400 by Render's edge before reaching the app) |
| `/`, font file, `/api/stats?wearer=faith` | 200 |
| Headers | `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Strict-Transport-Security` present |
| 30 × `POST /api/wrapped` | 10 × 200, 20 × 429 |

## Remaining issues

- **Rate limit is per IP and in memory.** Classmates on the same campus Wi-Fi share one IP, so they share the 10-per-10-minutes limit; raise `RATE_LIMIT_PER_VISITOR` on Render for a class demo. `X-Forwarded-For` can be faked to get a fresh per-visitor bucket (confirmed live, attack 6), but the site-wide daily cap and the OpenRouter credit limit still bound spending. Counters reset on restart or redeploy. A shared store (e.g. Redis) would fix this, but it's not worth it for a demo.
- **OpenRouter credit limit is a manual step.** It's set in the OpenRouter dashboard and can't be checked from the repo; re-check it if the key is ever replaced.
- **iPhone build includes the key.** `ios/` copies `.env` into the app bundle so the simulator can call OpenRouter. Anyone with the built app could extract it. Fine for local builds; before sharing the app (TestFlight etc.), it should call the Render server instead of holding a key.
- **No Content-Security-Policy yet.** The page uses inline scripts and styles plus PostHog and Leaflet CDNs, so a strict CSP needs some refactoring. SRI covers Leaflet in the meantime.
- **Session replay is on in PostHog.** The page shows the "Heads up, testers" notice. The demo data is fictional, so no real personal data is recorded.
