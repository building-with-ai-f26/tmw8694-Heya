# AGENTS.md

Guidance for AI coding agents (and people) working in this repository.

## Project

- **Name:** Heya, a light-up friendship bracelet with a companion app that gets people off their phones and into real time with friends.
- **Context:** Building with AI, Fall 2026 (`building-with-ai-f26`)
- **Repo:** https://github.com/building-with-ai-f26/tmw8694-Heya
- **Product page:** https://building-with-ai-f26.github.io/tmw8694-Heya/ (GitHub Pages, served from `docs/` on `main`)
- **Wrapped app (live):** https://heya-wrapped.onrender.com (Render web service `heya-wrapped`; see "Shipping"). Security audit: `SECURITY.md`.
- **Current priorities:** `ROADMAP.md` (Xcode proximity spike first; bracelet vs. phone/watch question).
- **Product truth:** `PRODUCT.md` (users, purpose, privacy rules). **Visual system:** `DESIGN.md`. Heya's look is the iPhone app's (black ground, cards, metal LED ring, mood pills, pixel avatars, SF Pro); the product page uses it. The Wrapped app still uses the Sidewalk Chalk section until it's restyled.

## Structure

| Path | What it is |
| --- | --- |
| `docs/index.html` | Product page and PRD (v2 on top, v1 below). Static HTML and inline CSS, no build step. |
| `docs/prototype.html` | Build 1 bracelet prototype: signal → find → meet → tap. Static, runs from the file. |
| `docs/images/` | Screenshots used on the product page. |
| `docs/fonts/` | Self-hosted Inter (SIL Open Font License, `OFL.txt`): the product page's fallback for SF Pro on Windows and Android. |
| `app/server.py` | Heya Wrapped local server (Python standard library only). Serves the app, computes stats, makes the AI call. |
| `app/index.html` | Heya Wrapped page in the app look: Grant (kid) and Faith (adult) recaps, the LED ring as the card dial, map, share image. |
| `app/data/grant.json`, `app/data/faith.json` | Demo tap history (fictional people, Jan 1 – Nov 15, 2026). |
| `app/fonts/` | Self-hosted Inter (`Inter-OFL.txt`), the SF Pro fallback. Bricolage Grotesque is from the old chalk look and no longer used. |
| `ios/Heya.xcodeproj` | iPhone app that runs the same Wrapped page. The Swift server in `ios/Heya/` replaces `app/server.py` on the device. |
| `ios-native/Heya.swiftpm` | Tara's native SwiftUI app (Look, Places, Friends, You) with real Bluetooth friend-finding, bump-to-tap and Demo mode. Open the `.swiftpm` folder in Xcode. Separate from `ios/`. |
| `ios-native/HeyaApp.xcodeproj`, `ios-native/HeyaApp/Info.plist` | Xcode project that builds the same `Heya.swiftpm` files with Bluetooth background modes on (Playgrounds packages can't). Use it on real phones. It syncs the folder, so new Swift files need no project edits; `Package.swift` and `README.md` are excluded. |
| `ios-native/TEST-PLAN.md` | Two-phone Bluetooth test plan for Tara and Jorge. | Results go in its Results section.
| `ROADMAP.md` | Shared plan and priorities for Tara and Jorge. |
| `.env.example` | Template for the secret settings. Copy to `.env`. |
| `render.yaml`, `requirements.txt` | Render Blueprint for the live Wrapped app. `requirements.txt` is empty on purpose (standard library only). |
| `SECURITY.md` | Security audit: what was checked, found, fixed, and what's left. |
| `.claude/settings.json` | Agent guardrails: destructive commands need approval, `.env` can't be read. |
| `PRODUCT.md`, `DESIGN.md`, `.impeccable/` | Product and design records from the impeccable design plugin. `.impeccable/review/`, `questions/` and `mocks/` are local only and ignore themselves. |

## Set up and run the Wrapped app

Requirements: Python 3.9+ (nothing to install) and an OpenRouter API key.

1. Create your secrets file and add the key:
   ```sh
   cp .env.example .env
   # edit .env: OPENROUTER_API_KEY=sk-or-...
   ```
   `.env` is in `.gitignore`. Never commit it, paste the key into chat, or put it in browser code.
2. Start the server from the repo root:
   ```sh
   python3 app/server.py
   ```
3. Open http://localhost:8000, pick Grant or Faith, and press **Make my Wrapped**.

Optional settings in `.env`: `HEYA_MODEL` (default `anthropic/claude-haiku-5.5`), `PORT` (default `8000`), `HOST` (default `127.0.0.1`), and the rate limits `RATE_LIMIT_PER_VISITOR` (default `10`), `RATE_WINDOW_SECONDS` (default `600`) and `DAILY_AI_CAP` (default `300` site-wide per 24 h).

Demo links for screenshots: `http://localhost:8000/?wearer=faith&auto=1&card=2` opens Faith's Wrapped on square 3 (cards count from 0). When capturing with headless Chrome, add `--force-prefers-reduced-motion` so cards aren't caught mid-animation.

## Shipping

Live app: https://heya-wrapped.onrender.com (Render free web service `heya-wrapped`, Blueprint in `render.yaml`). Product page: GitHub Pages from `docs/`. Every push to `main` redeploys both.

It's an **AI app with no database**: the server needs to run Python (it holds the OpenRouter key and makes the AI call), so it's on Render, not Pages. The tap data is read-only demo JSON in the repo and nothing is saved, so there's no sign-in and no Supabase. If a feature ever needs to save data, stop and ask first (see "Ask me first"): it needs a real database with Row Level Security, and writes must go through the server.

### Steps the agent follows to ship a change

1. **Pull first:** `git pull --ff-only`. Work on a branch for big changes.
2. **Check it locally:**
   - `python3 -m py_compile app/server.py`
   - Start `python3 app/server.py`, open http://localhost:8000, run one Faith and one Grant Wrapped.
   - Blocked paths still 404: `for p in /server.py /./server.py /%73erver.py /fonts/../data/faith.json /fonts/ /.env; do curl -s -o /dev/null -w "$p %{http_code}\n" --path-as-is http://localhost:8000$p; done`
   - Don't rerun the 30-call test locally on every change (it costs money); run it after server changes to the limiter.
3. **Check for secrets before committing:** stage files by name (never `git add -A`), confirm `.env` isn't staged, and run `git diff --cached | grep -nE "sk-or-v1-|sk-ant-|sk-proj-|sk_live_|sb_secret_|service_role"`. Any real key: stop and tell the owner to rotate it.
4. **Ask** before `git commit` and `git push` (see "Ask me first"). Commit messages end with the agent's co-author line.
5. **Wait for Render:** the deploy takes 1–3 minutes. `curl -s https://heya-wrapped.onrender.com/healthz` should return `{"ok": true}`. The free plan sleeps when idle; the first request can take 60 seconds.
6. **Run the live checks** in `SECURITY.md` (secret search on the served page, blocked paths). Run the 30-call rate-limit test only after changes to `server.py`'s limiter, and say beforehand that it makes about 10 paid calls.
7. **Record it:** update `SECURITY.md` if security behavior changed, and the build log on the product page.

### One-time setup (done Nov 22, 2026; for a new service only)

1. In OpenRouter, create a key just for production (`heya-render`) with a **$2 monthly credit limit**, and keep auto top-up off. Don't reuse the local `.env` key.
2. In https://dashboard.render.com → **New** → **Blueprint**, pick `building-with-ai-f26/tmw8694-Heya`. Paste the production key when it asks for `OPENROUTER_API_KEY`; it lives only in Render's environment, never in the repo.
3. In PostHog → Settings → Session replay, make sure `https://heya-wrapped.onrender.com` is an authorized domain, or replays from the live site won't record.

### Operating notes

- Settings (`RATE_LIMIT_PER_VISITOR`, `RATE_WINDOW_SECONDS`, `DAILY_AI_CAP`, `HEYA_MODEL`) are in Render's **Environment** tab. Changing one restarts the service. For a class demo on shared Wi-Fi, raise `RATE_LIMIT_PER_VISITOR` to about 50 and put it back afterward.
- Rate-limit counters are in memory and reset on restart or redeploy.
- Rollback: Render dashboard → the service → **Events** → pick the last good deploy → **Rollback**. Ask first.

## Open the iPhone app in Xcode

The page, fonts, and tap files stay in `app/`. The Xcode app loads them in a web view and serves `/api/stats` and `/api/wrapped` from Swift, with the same rules: the server computes every number, and the model only writes the words. Grant still has no locations and no share card.

```sh
open ios/Heya.xcodeproj
```

Pick an iPhone simulator and press Run. The build copies `.env` into the app so the OpenRouter key stays out of git and out of the Swift source. The key is only inside that local build. A phone install needs an Apple developer team selected under Signing & Capabilities.

## How the AI call works

- `POST /api/wrapped {"wearer": "grant" | "faith"}`: the server computes every number from the tap data (`compute_stats`), then sends **only those stats** to OpenRouter in one chat call. The model writes the words: a title, five cards and, for adults, a share caption.
- The prompt forbids new numbers, invented activities, pronoun guesses and emoji, and asks for kid-friendly wording for Grant. Grant's data contains no locations.
- The reply is validated (`parse_story`). A missing adult caption is rebuilt from real stats. Reasoning is turned off (`"reasoning": {"enabled": false}`), because otherwise the model spends the token budget thinking and the JSON gets cut off.
- Each run's cost and tokens are printed in the server log and shown on the page. Measured cost: about $0.0003 (Grant) to $0.0004 (Faith) per run.
- `GET /api/stats?wearer=…` returns the stats without calling the AI. `GET /healthz` is Render's health check.
- The server only serves an allowlist (`index.html` and `fonts/*`); everything else, including `server.py`, `data/` and `.env`, is 404. `/api/wrapped` is rate-limited per visitor and site-wide (429 with `Retry-After`), bodies over 1 KB are refused, and AI errors are logged on the server but shown to the browser only as a generic message. Keep these when changing `server.py`.

## Product page and prototype

- Preview by opening `docs/index.html` or `docs/prototype.html` in a browser, or run `python3 -m http.server -d docs 8080`.
- Changes go live when pushed to `main` (Pages rebuilds in about a minute).

## Analytics (PostHog)

- The PostHog web snippet is in the `<head>` of `docs/index.html`, `docs/prototype.html` and `app/index.html`. It uses the **public project token** (`phc_…`) and the US host. Never use a personal API key in client code.
- Pageviews, autocaptured clicks and session replay are on. Every page shows a "Heads up, testers" notice; keep it.
- Named events: the prototype sends `mood_changed`, `bracelets_paired`, `bracelets_tapped`, `next_day`, `scenario_switched` and `prototype_reset`. Wrapped sends `wrapped_requested`, `wrapped_generated` (with cost), `wrapped_failed`, `wrapped_card_viewed`, `wrapped_completed`, `hopscotch_hop`, `wrapped_shared`, `caption_copied` and `wearer_switched`. The product page poll sends `device_preference_answered` (`choice`: `bracelet`, `phone_app` or `apple_watch`). The product page's mood pad (Hang, Quiet, Wave, Off under the ring) sends `hero_mood_tried` (`mood`).

## Ask me first

The agent stops and asks the owner before doing any of these, even if an earlier request seemed to allow it. Approval for one action doesn't carry over to the next. The commands are also on the ask list in `.claude/settings.json`.

- **Deleting data or changing the database:** deleting or overwriting files (`rm`, `git clean`, `git checkout --`, `git reset --hard`), deleting branches, force-pushing, editing `app/data/*.json`, and adding a database, a table or a migration. There's no database today; adding one is a decision for the owner.
- **Keys, secrets and permissions:** reading or editing `.env` (blocked outright), creating, rotating or pasting API keys, changing Render environment variables, GitHub repo settings, collaborators, Pages settings, PostHog settings, or `.claude/settings.json`.
- **Anything that costs money:** running the 30-call rate-limit test or any loop that calls `/api/wrapped`, changing `HEYA_MODEL`, raising `DAILY_AI_CAP` or the OpenRouter credit limit, upgrading the Render plan, and adding any paid service.
- **Shipping:** `git commit`, `git push` and Render rollbacks.

## Rules from real mistakes

Each rule comes from something an agent got wrong in this repo.

- **Serve files from an allowlist and attack it before calling it done.** The first `server.py` hid `server.py` and `data/` with a blocklist (`path.lstrip("/").startswith(...)`). It looked right, but `/./server.py`, `/%73erver.py`, `/fonts/../data/faith.json` and `HEAD /server.py` all downloaded the files (Nov 22). Any check on a path must decode and normalize it first, and must cover HEAD as well as GET.
- **Don't trust headers the visitor can set.** The rate limiter keyed visitors on the first `X-Forwarded-For` entry, and a faked header got a fresh limit on the live site (Nov 22). Don't treat a client-supplied value as identity, and always keep a site-wide cap that can't be bypassed.
- **Look for "local only" assumptions before shipping.** The server only listened on `127.0.0.1`, and the PostHog snippet hard-coded `heya_local: true`, so every live visit would have been tagged as local testing (Nov 22). Before deploying, search for `localhost`, `127.0.0.1` and `local` and make them depend on where the code is actually running.
- **Turn off model reasoning for short JSON replies.** With reasoning on, the model spent the token budget thinking and the Wrapped JSON was cut off (Nov 16).

## Working rules

- Read `README.md`, `PRODUCT.md` and this file before making changes; read `DESIGN.md` before touching `docs/index.html` or `app/index.html`.
- Keep changes small and focused; explain what you changed and why.
- Never commit secrets, API keys, or personal data. Check that `.env` is not staged before every commit.
- Production is the Render service. Test changes locally first; the agent works against the local server, not production.
- Respect the product's privacy rules: no locations or sharing for kids, no friend location sharing, no strangers.
- Mood colors mean moods (green = Let's hang, purple = Quiet company, yellow = Busy, but wave); don't use them as decoration.
- Pages must stay accessible: semantic HTML, readable contrast, light and dark mode, phone width.
