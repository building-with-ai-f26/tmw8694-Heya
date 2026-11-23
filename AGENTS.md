# AGENTS.md

Guidance for AI coding agents (and people) working in this repository.

## Project

- **Name:** Heya, a light-up friendship bracelet with a companion app that gets people off their phones and into real time with friends.
- **Context:** Building with AI, Fall 2026 (`building-with-ai-f26`)
- **Repo:** https://github.com/building-with-ai-f26/tmw8694-Heya
- **Product page:** https://building-with-ai-f26.github.io/tmw8694-Heya/ (GitHub Pages, served from `docs/` on `main`)
- **Wrapped app (live):** https://heya-wrapped.onrender.com (Render web service `heya-wrapped`; see "Deploy the Wrapped app"). Security audit: `SECURITY.md`.
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
| `ios-native/TEST-PLAN.md` | Two-phone Bluetooth test plan for Tara and Jorge. |
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

## Deploy the Wrapped app (Render)

The Wrapped app needs a running Python server (it holds the OpenRouter key and makes the AI call), so it's on Render, not GitHub Pages. It's an **AI app with no database**: the tap data is read-only demo JSON in the repo, nothing is saved, so there's no sign-in and no Supabase.

First deploy (once, in the Render dashboard):

1. Push `main` with `render.yaml` in the repo root.
2. In OpenRouter, create a **new key just for production** named `heya-render`, and set a **credit limit** on it (e.g. $2). Also check the account has no auto top-up. Don't reuse your local `.env` key.
3. Go to https://dashboard.render.com → **New** → **Blueprint**, connect GitHub, pick `building-with-ai-f26/tmw8694-Heya`. Render reads `render.yaml` and creates the free web service `heya-wrapped`.
4. When it asks for `OPENROUTER_API_KEY`, paste the production key. It lives only in Render's environment settings, never in the repo.
5. Wait for the deploy to go **Live**, then open `https://<service>.onrender.com/healthz` (should say `{"ok": true}`) and the home page.
6. Put the live URL in this file (Project section) and in `SECURITY.md`.

After that, every push to `main` redeploys automatically. To change a setting (e.g. raise `RATE_LIMIT_PER_VISITOR` for a class demo on shared Wi-Fi), edit it under the service's **Environment** tab; Render restarts the service.

Check a deploy works (on a phone, not just a laptop):

1. Open the live URL, pick Faith, press **Make my Wrapped**, swipe through all five cards, and check the map and share image load. Do the same for Grant.
2. Run the live checks in `SECURITY.md` (secret search on the served page, 30-call rate-limit test, blocked file paths).

Notes: the free plan sleeps after ~15 minutes idle, so the first visit takes 30–60 seconds to wake up; open it once before a demo. Rate-limit counters are in memory and reset when the service restarts or redeploys.

Demo links for screenshots: `http://localhost:8000/?wearer=faith&auto=1&card=2` opens Faith's Wrapped on square 3 (cards count from 0). When capturing with headless Chrome, add `--force-prefers-reduced-motion` so cards aren't caught mid-animation.

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

## Working rules

- Read `README.md`, `PRODUCT.md` and this file before making changes; read `DESIGN.md` before touching `docs/index.html` or `app/index.html`.
- Keep changes small and focused; explain what you changed and why.
- Ask before deleting or overwriting existing files.
- Don't commit or push unless explicitly asked.
- Never commit secrets, API keys, or personal data. Check that `.env` is not staged before every commit.
- Production is the Render service. Agents don't change Render settings, push, force-push, or delete branches or files without asking (enforced in `.claude/settings.json`). Test changes locally first.
- Respect the product's privacy rules: no locations or sharing for kids, no friend location sharing, no strangers.
- Mood colors mean moods (green = Let's hang, purple = Quiet company, yellow = Busy, but wave); don't use them as decoration.
- Pages must stay accessible: semantic HTML, readable contrast, light and dark mode, phone width.
