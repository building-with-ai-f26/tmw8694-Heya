---
version: 1
slug: "app-index-html"
primary_target: "app/index.html"
related_targets: []
---

# Heya Wrapped (local app)

Scope: app/index.html, the Wrapped recap for Grant (kid, read with a parent on the parent's phone) and Faith (adult, with map and share card). Visitor mode: Experience.

Job: flip through a year of real-life hangouts; kids leave wanting to see friends, adults leave wanting to share and go out. Must keep: mood colors mean moods (green let's hang, purple quiet company, yellow busy but wave). Avoid: screen-y/addictive energy, anything that looks like Spotify Wrapped. Keep: /api/stats and /api/wrapped calls, PostHog events, demo URL params, Leaflet map, share image, kid privacy (no map, no sharing for Grant).

## Direction contract

THESIS: Your year plays back on the Heya band itself: the app's 12-LED ring is the story's progress dial, lighting each card's LEDs in the mood behind it. Refuses full-bleed gradient story slides with giant neon numbers, and replaces the retired Sidewalk Chalk hopscotch.

OWN-WORLD: The Heya app look from DESIGN.md: black ground (#f2f2f7 in light), #171717 cards at 22px, #2b2b2b hairlines, quiet #a3a3a3 text, SF Pro (Heya Inter fallback), brushed-metal ring with LED glow, mood-filled pills only for moods, neutral white/black action pill, 12x12 one-bit pixel avatars on black tiles, app-style friend rows. Colour appears only where it means a mood.

STORY: The visitor picks Grant or Faith, sees the year so far, presses Make my Wrapped, watches the LEDs chase while the AI writes, then steps around the ring card by card; Faith ends at her map and a shareable image of her lit band.

FIRST VIEWPORT: Desktop: large "Heya Wrapped" title and a two-pill wearer switch; below, left the ring dial (about 240px) with "1 of 6" in its centre and Back/Next pills under it; centre the current card at phone width (cover: sentence with real numbers, stat rows, month bars, white "Make my Wrapped" pill); right the family note, or map and share cards. Phone: ring at about 150px above the card.

FORM: seed: none (pinned). "restyle the wrapped page so that it matches the aesthetics of the app"; user chose "The ring is the progress dial". Signature interaction: tapping a ring segment jumps to that card; LEDs chase while the AI writes.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
