# AGENTS.md

Guidance for AI coding agents (and people) working in this repository.

## Project

- **Name:** Heya, a light-up friendship bracelet with a companion app that gets people off their phones and into real time with friends.
- **Context:** Building with AI, Fall 2026 (`building-with-ai-f26`)
- **Repo:** https://github.com/building-with-ai-f26/tmw8694-Heya
- **Product page:** https://building-with-ai-f26.github.io/tmw8694-Heya/ (GitHub Pages, served from `docs/` on `main`)
- **Current priorities:** `ROADMAP.md` (Xcode proximity spike first; bracelet vs. phone/watch question).
- **Product truth:** `PRODUCT.md` (users, purpose, privacy rules). **Visual system** for the Wrapped app: `DESIGN.md`.

## Structure

| Path | What it is |
| --- | --- |
| `docs/index.html` | Product page and PRD (v2 on top, v1 below). Static HTML and inline CSS, no build step. |
| `docs/prototype.html` | Build 1 bracelet prototype: signal → find → meet → tap. Static, runs from the file. |
| `docs/images/` | Screenshots used on the product page. |
| `app/server.py` | Heya Wrapped local server (Python standard library only). Serves the app, computes stats, makes the AI call. |
| `app/index.html` | Heya Wrapped page: Grant (kid) and Faith (adult) recaps, hopscotch navigation, map, share image. |
| `app/data/grant.json`, `app/data/faith.json` | Demo tap history (fictional people, Jan 1 – Nov 15, 2026). |
| `app/fonts/` | Self-hosted Bricolage Grotesque (SIL Open Font License; see `README.txt`). |
| `ROADMAP.md` | Shared plan and priorities for Tara and Jorge. |
| `.env.example` | Template for the secret settings. Copy to `.env`. |
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

Optional settings in `.env`: `HEYA_MODEL` (default `anthropic/claude-haiku-5.5`) and `PORT` (default `8000`).

Demo links for screenshots: `http://localhost:8000/?wearer=faith&auto=1&card=2` opens Faith's Wrapped on square 3 (cards count from 0). When capturing with headless Chrome, add `--force-prefers-reduced-motion` so cards aren't caught mid-animation.

## How the AI call works

- `POST /api/wrapped {"wearer": "grant" | "faith"}`: the server computes every number from the tap data (`compute_stats`), then sends **only those stats** to OpenRouter in one chat call. The model writes the words: a title, five cards and, for adults, a share caption.
- The prompt forbids new numbers, invented activities, pronoun guesses and emoji, and asks for kid-friendly wording for Grant. Grant's data contains no locations.
- The reply is validated (`parse_story`). A missing adult caption is rebuilt from real stats. Reasoning is turned off (`"reasoning": {"enabled": false}`), because otherwise the model spends the token budget thinking and the JSON gets cut off.
- Each run's cost and tokens are printed in the server log and shown on the page. Measured cost: about $0.0003 (Grant) to $0.0004 (Faith) per run.
- `GET /api/stats?wearer=…` returns the stats without calling the AI. The server refuses to serve `server.py` and `data/`.

## Product page and prototype

- Preview by opening `docs/index.html` or `docs/prototype.html` in a browser, or run `python3 -m http.server -d docs 8080`.
- Changes go live when pushed to `main` (Pages rebuilds in about a minute).

## Analytics (PostHog)

- The PostHog web snippet is in the `<head>` of `docs/index.html`, `docs/prototype.html` and `app/index.html`. It uses the **public project token** (`phc_…`) and the US host. Never use a personal API key in client code.
- Pageviews, autocaptured clicks and session replay are on. Every page shows a "Heads up, testers" notice; keep it.
- Named events: the prototype sends `mood_changed`, `bracelets_paired`, `bracelets_tapped`, `next_day`, `scenario_switched` and `prototype_reset`. Wrapped sends `wrapped_requested`, `wrapped_generated` (with cost), `wrapped_failed`, `wrapped_card_viewed`, `wrapped_completed`, `hopscotch_hop`, `wrapped_shared`, `caption_copied` and `wearer_switched`. The product page poll sends `device_preference_answered` (`choice`: `bracelet`, `phone_app` or `apple_watch`).

## Working rules

- Read `README.md`, `PRODUCT.md` and this file before making changes; read `DESIGN.md` before touching `app/index.html`.
- Keep changes small and focused; explain what you changed and why.
- Ask before deleting or overwriting existing files.
- Don't commit or push unless explicitly asked.
- Never commit secrets, API keys, or personal data. Check that `.env` is not staged before every commit.
- Respect the product's privacy rules: no locations or sharing for kids, no friend location sharing, no strangers.
- Mood colors mean moods (green = Let's hang, purple = Quiet company, yellow = Busy, but wave); don't use them as decoration.
- Pages must stay accessible: semantic HTML, readable contrast, light and dark mode, phone width.
