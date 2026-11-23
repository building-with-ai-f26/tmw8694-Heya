"""Heya Wrapped: local app server.

Serves the app in this folder and makes the one real AI call:
POST /api/wrapped {"wearer": "grant" | "faith"}

The server computes every number from the tap history. The AI (via
OpenRouter) only writes the words around those numbers, so it can't
invent stats. The API key is read from ../.env and never sent to the browser.

Run:  python3 app/server.py      then open http://localhost:8000
"""

import json
import os
import posixpath
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, deque
from datetime import date, timedelta
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
ROOT = APP_DIR.parent
DATA = {"grant": APP_DIR / "data" / "grant.json", "faith": APP_DIR / "data" / "faith.json"}
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
# Fallback prices (USD per million tokens) if OpenRouter doesn't report cost.
PRICES = {"anthropic/claude-haiku-5.5": (0.10, 0.50)}
MOOD_NAMES = {"hang": "Let's hang", "quiet": "Quiet company", "wave": "Busy, but wave"}
WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

# Only these files are ever served. Everything else (server.py, data/, .env, folder listings) is 404.
PUBLIC_FILES = {"/": "index.html", "/index.html": "index.html"}
PUBLIC_FILES.update({f"/fonts/{p.name}": f"fonts/{p.name}"
                     for p in (APP_DIR / "fonts").glob("*") if p.suffix in (".woff2", ".txt")})
MAX_BODY = 1024  # bytes; the only valid body is {"wearer": "..."}


class RateLimiter:
    """In-memory sliding-window limits on the paid AI route.

    Per visitor: RATE_LIMIT_PER_VISITOR calls per RATE_WINDOW_SECONDS.
    Whole site: DAILY_AI_CAP calls per 24 hours, a backstop on spending even if
    someone rotates IPs. Counters reset when the server restarts.
    """

    def __init__(self):
        self.per_visitor = int(os.environ.get("RATE_LIMIT_PER_VISITOR", "10"))
        self.window = int(os.environ.get("RATE_WINDOW_SECONDS", "600"))
        self.daily_cap = int(os.environ.get("DAILY_AI_CAP", "300"))
        self.hits, self.all_hits, self.lock = {}, deque(), threading.Lock()

    def check(self, visitor):
        """Return 0 if allowed (and record the call), else seconds to wait."""
        now = time.time()
        with self.lock:
            while self.all_hits and now - self.all_hits[0] > 86400:
                self.all_hits.popleft()
            if len(self.all_hits) >= self.daily_cap:
                return int(86400 - (now - self.all_hits[0])) + 1
            q = self.hits.setdefault(visitor, deque())
            while q and now - q[0] > self.window:
                q.popleft()
            if len(q) >= self.per_visitor:
                return int(self.window - (now - q[0])) + 1
            q.append(now)
            self.all_hits.append(now)
            if len(self.hits) > 10000:  # drop idle visitors so memory stays small
                self.hits = {k: v for k, v in self.hits.items() if v and now - v[-1] < self.window}
            return 0


LIMITER = None  # created at startup, after .env is loaded


def load_env():
    """Read KEY=value lines from ../.env into os.environ (no extra packages needed)."""
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


# ---------- stats: all numbers come from here, not from the AI ----------

def longest_streak(dates):
    days = sorted({date.fromisoformat(d) for d in dates})
    best = run = 1 if days else 0
    best_end = days[0] if days else None
    for a, b in zip(days, days[1:]):
        run = run + 1 if b - a == timedelta(days=1) else 1
        if run > best:
            best, best_end = run, b
    start = best_end - timedelta(days=best - 1) if best_end else None
    return best, start, best_end


def top_mood(taps):
    """Name of the wearer's most common mood across these taps."""
    c = Counter(t["my_mood"] for t in taps)
    return MOOD_NAMES[c.most_common(1)[0][0]] if c else None


def compute_stats(data):
    taps = data["taps"]
    friends = Counter(t["friend"] for t in taps)
    streak, s_start, s_end = longest_streak([t["date"] for t in taps])
    streak_friends = Counter(t["friend"] for t in taps
                             if s_start and s_start.isoformat() <= t["date"] <= s_end.isoformat())
    months = Counter(date.fromisoformat(t["date"]).strftime("%B") for t in taps)
    by_month = Counter(date.fromisoformat(t["date"]).month for t in taps)
    last_month = date.fromisoformat(data["through"]).month
    weekdays = Counter(WEEKDAYS[date.fromisoformat(t["date"]).weekday()] for t in taps)
    moods = Counter(t["my_mood"] for t in taps)
    first_seen = {}
    for t in sorted(taps, key=lambda t: t["date"]):
        first_seen.setdefault(t["friend"], t["date"])

    stats = {
        "wearer": data["wearer"],
        "age": data["age"],
        "type": data["type"],
        "period": f"{data['year']}-01-01 to {data['through']}",
        "total_taps": len(taps),
        "days_with_taps": len({t["date"] for t in taps}),
        "friend_count": len(friends),
        "top_friends": [{"name": n, "taps": c} for n, c in friends.most_common(5)],
        "longest_streak_days": streak,
        "longest_streak_dates": [s_start.isoformat(), s_end.isoformat()] if s_start else None,
        "longest_streak_friend": streak_friends.most_common(1)[0][0] if streak_friends else None,
        "longest_streak_friend_days": len({t["date"] for t in taps
                                           if s_start and s_start.isoformat() <= t["date"] <= s_end.isoformat()
                                           and t["friend"] == (streak_friends.most_common(1)[0][0] if streak_friends else None)}),
        "busiest_month": months.most_common(1)[0][0],
        "busiest_weekday": weekdays.most_common(1)[0][0],
        "top_mood": MOOD_NAMES[moods.most_common(1)[0][0]],
        "mood_mix": {MOOD_NAMES[k]: v for k, v in moods.most_common()},
        "newest_friend": max(first_seen, key=first_seen.get) if first_seen else None,
        "taps_by_month": [by_month.get(m, 0) for m in range(1, last_month + 1)],
    }
    # the real mood behind each card, so card colors mean moods
    top_name = stats["top_friends"][0]["name"] if friends else None
    stats["mood_with_top_friend"] = top_mood([t for t in taps if t["friend"] == top_name])
    stats["mood_during_streak"] = top_mood([t for t in taps if s_start and
                                            s_start.isoformat() <= t["date"] <= s_end.isoformat()])

    if data["type"] == "adult":  # kids never get locations
        places = Counter(t["place"] for t in taps)
        stats["top_places"] = []
        for name, c in places.most_common():
            with_whom = Counter(t["friend"] for t in taps if t["place"] == name).most_common(1)[0][0]
            loc = data["places"][name]
            stats["top_places"].append({"name": name, "taps": c, "mostly_with": with_whom,
                                        "mostly_mood": top_mood([t for t in taps if t["place"] == name]),
                                        "lat": loc["lat"], "lng": loc["lng"]})
        stats["mood_at_top_place"] = stats["top_places"][0]["mostly_mood"]
    return stats


# ---------- the AI call ----------

KID_CARDS = ["top_friend", "streak", "friend_squad", "mood", "closing"]
ADULT_CARDS = ["top_friend", "top_place", "streak", "mood", "closing"]


def build_prompt(stats):
    kid = stats["type"] == "kid"
    cards = KID_CARDS if kid else ADULT_CARDS
    ai_stats = {k: v for k, v in stats.items() if k not in ("top_places", "taps_by_month")}
    if not kid:  # names and counts only, no coordinates
        ai_stats["top_places"] = [{k: p[k] for k in ("name", "taps", "mostly_with", "mostly_mood")}
                                  for p in stats["top_places"]]

    audience = (
        f"{stats['wearer']} is {stats['age']} and will read this on a parent's phone, maybe with the parent. "
        "Write for a 7-year-old: short, simple, warm words, one idea per sentence. "
        "Celebrate friendship and playing outside. Never compare friends negatively or rank anyone as a loser. "
        "No places or locations: this kid's data has none."
        if kid else
        f"{stats['wearer']} is {stats['age']}, lives in a city, and may post this on social media. "
        "Write playful, confident, shareable lines, like a year-in-review recap. Place names are fine; "
        "never mention addresses."
    )
    schema = {
        "title": "a 3-7 word headline that states one real fact from the stats, e.g. '75 taps with Ava' or 'A summer at Prospect Park'. Never a personality label or 'The ___er' title",
        "cards": {c: {"headline": "max 8 words", "body": "max 25 words"} for c in cards},
    }
    if not kid:
        schema["share_caption"] = "one social caption, max 20 words, may end with #HeyaWrapped"

    system = (
        "You write 'Heya Wrapped', a yearly recap of in-person hangouts for Heya, a bracelet that lights up "
        "when friends are nearby; friends tap bracelets when they meet. " + audience +
        " Use ONLY the numbers and names in the stats; do not invent or change any number. "
        "Refer to friends by name, never with he/she pronouns (you don't know their pronouns). "
        "No emoji or symbols; plain words only. "
        "Don't invent activities, places, feelings or details that aren't in the stats (no 'long walks', 'coffee', etc.). "
        "longest_streak_days counts days in a row with at least one tap with ANY friend; "
        "longest_streak_friend was there on longest_streak_friend_days of those days, so never say "
        "the streak was all with one friend or every day with them unless those two numbers are equal. "
        "Reply with a single JSON object and nothing else."
    )
    user = (
        "Stats:\n" + json.dumps(ai_stats, indent=1) +
        "\n\nReturn JSON with exactly this shape (one entry per card key, in this order):\n" +
        json.dumps(schema, indent=1)
    )
    return system, user, cards


def parse_story(text, cards, kid):
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < 0:
        raise ValueError("AI reply had no JSON object")
    story = json.loads(text[start:end + 1])
    if not isinstance(story.get("title"), str) or not isinstance(story.get("cards"), dict):
        raise ValueError("AI reply is missing title or cards")
    out_cards = []
    for key in cards:
        c = story["cards"].get(key)
        if not isinstance(c, dict) or not c.get("headline") or not c.get("body"):
            raise ValueError(f"AI reply is missing card '{key}'")
        out_cards.append({"key": key, "headline": str(c["headline"]), "body": str(c["body"])})
    result = {"title": story["title"], "cards": out_cards}
    return result


def call_openrouter(system, user):
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        raise RuntimeError("No OPENROUTER_API_KEY. Copy .env.example to .env and paste your key.")
    model = os.environ.get("HEYA_MODEL", "anthropic/claude-haiku-5.5")
    body = json.dumps({
        "model": model,
        "max_tokens": 1500,
        "temperature": 0.8,
        # Writing a recap doesn't need hidden "thinking"; with it on, the model
        # spent most of the token budget reasoning and the JSON got cut off.
        "reasoning": {"enabled": False},
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
        "usage": {"include": True},
    }).encode()
    req = urllib.request.Request(OPENROUTER_URL, data=body, method="POST", headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "X-Title": "Heya Wrapped",
    })
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            reply = json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        raise RuntimeError(f"OpenRouter returned HTTP {e.code}: {detail}") from None
    ms = int((time.time() - t0) * 1000)

    choice = reply["choices"][0]
    text = choice["message"].get("content") or ""
    if choice.get("finish_reason") == "length":
        raise RuntimeError("The AI ran out of room before finishing. Try again.")
    usage = reply.get("usage", {})
    tin, tout = usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)
    cost = usage.get("cost")
    if cost is None and model in PRICES:
        pin, pout = PRICES[model]
        cost = (tin * pin + tout * pout) / 1_000_000
    return text, {"model": reply.get("model", model), "input_tokens": tin, "output_tokens": tout,
                  "cost_usd": cost, "ms": ms}


# ---------- HTTP ----------

class Handler(SimpleHTTPRequestHandler):
    timeout = 20  # drop clients that open a connection and stall
    server_version = "Heya"
    sys_version = ""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(APP_DIR), **kwargs)

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
        if os.environ.get("RENDER"):  # only over HTTPS in production
            self.send_header("Strict-Transport-Security", "max-age=31536000")
        super().end_headers()

    def visitor(self):
        """Client IP. Behind Render's proxy the first X-Forwarded-For entry is the visitor."""
        fwd = self.headers.get("X-Forwarded-For", "")
        return fwd.split(",")[0].strip() if fwd else self.client_address[0]

    def send_json(self, code, obj, headers=None):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def send_head(self):
        """Serve only allowlisted files (used by both GET and HEAD)."""
        path = posixpath.normpath(urllib.parse.unquote(urllib.parse.urlsplit(self.path).path))
        rel = PUBLIC_FILES.get(path) or PUBLIC_FILES.get(path + "/")
        if not rel:
            self.send_error(404, "Not found")
            return None
        self.path = "/" + rel
        return super().send_head()

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        if url.path == "/api/stats":
            wearer = urllib.parse.parse_qs(url.query).get("wearer", [""])[0]
            if wearer not in DATA:
                return self.send_json(404, {"error": "unknown wearer"})
            return self.send_json(200, compute_stats(json.loads(DATA[wearer].read_text())))
        if url.path == "/healthz":
            return self.send_json(200, {"ok": True})
        return super().do_GET()

    def do_POST(self):
        if self.path != "/api/wrapped":
            return self.send_json(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            return self.send_json(400, {"error": "bad request"})
        if length > MAX_BODY:
            return self.send_json(413, {"error": "request too large"})
        try:
            wearer = json.loads(self.rfile.read(length) or b"{}").get("wearer")
        except (ValueError, AttributeError):
            return self.send_json(400, {"error": "body must be JSON like {\"wearer\": \"faith\"}"})
        if wearer not in DATA:
            return self.send_json(400, {"error": "wearer must be 'grant' or 'faith'"})
        wait = LIMITER.check(self.visitor())
        if wait:
            mins = max(1, round(wait / 60))
            print(f"[wrapped] rate limited {self.visitor()} for {wait}s")
            return self.send_json(429, {"error": f"You've made a lot of Wrappeds. Try again in about {mins} minute{'s' * (mins != 1)}."},
                                  {"Retry-After": str(wait)})
        try:
            stats = compute_stats(json.loads(DATA[wearer].read_text()))
            system, user, cards = build_prompt(stats)
            text, run = call_openrouter(system, user)
            story = parse_story(text, cards, stats["type"] == "kid")
            if stats["type"] == "adult":
                caption = json.loads(text[text.find("{"):text.rfind("}") + 1]).get("share_caption")
                if isinstance(caption, str) and caption.strip():
                    story["share_caption"], story["caption_from_ai"] = caption.strip(), True
                else:  # the AI occasionally leaves it out; build one from real stats
                    top, place = stats["top_friends"][0]["name"], stats["top_places"][0]["name"]
                    story["share_caption"] = (f"{stats['total_taps']} taps with {stats['friend_count']} friends. "
                                              f"{top} and {place} made my year. #HeyaWrapped")
                    story["caption_from_ai"] = False
            print(f"[wrapped] {wearer}: {run['model']} {run['input_tokens']} in / "
                  f"{run['output_tokens']} out, ${run['cost_usd']:.6f}, {run['ms']} ms"
                  + ("" if story.get("caption_from_ai", True) else ", caption fallback used"))
            return self.send_json(200, {"stats": stats, "story": story, "run": run})
        except Exception as e:  # details go to the server log only, never to the browser
            print(f"[wrapped] error: {e}")
            return self.send_json(502, {"error": "Couldn't write your Wrapped right now. Try again in a minute."})

    def log_message(self, fmt, *args):
        if not self.path.startswith(("/api/stats", "/healthz")):
            super().log_message(fmt, *args)


if __name__ == "__main__":
    load_env()
    LIMITER = RateLimiter()
    host = os.environ.get("HOST", "127.0.0.1")  # Render sets HOST=0.0.0.0 (see render.yaml)
    port = int(os.environ.get("PORT", "8000"))
    print(f"Heya Wrapped running at http://{host}:{port}  (Ctrl+C to stop)")
    print(f"Rate limits: {LIMITER.per_visitor} per visitor per {LIMITER.window}s, {LIMITER.daily_cap} per day site-wide")
    if not os.environ.get("OPENROUTER_API_KEY"):
        print("Warning: no OPENROUTER_API_KEY in .env yet; 'Make my Wrapped' will show an error.")
    ThreadingHTTPServer((host, port), Handler).serve_forever()
