---
version: 1
slug: "docs-index-html"
primary_target: "docs/index.html"
related_targets: []
---

# Heya product page (PRD)

Scope: docs/index.html, the public product page and PRD (v2 on top, v1 below) on GitHub Pages. Visitor mode: Read, with a masthead that shows the product at work.

Audience: the course professor, classmates and testers. Job: understand what Heya is, read the PRD and build logs, try the prototype, answer the device poll. Must keep: all PRD content and anchors, PostHog snippet, tester notice, device poll (`device_preference_answered`), screenshots, light and dark mode, phone width. Mood colors mean moods.

## Direction contract

THESIS: The page wears the Heya iPhone app: the document opens on the band itself, lit, the way the app's Look tab does. Refuses the category default of a generic GitHub-README PRD with a blue button.

OWN-WORLD: Dark-first like the app: pure black ground, #171717 rounded cards (22px), #2b2b2b hairlines, white SF Pro at bold weights, quiet gray secondary text (#a3a3a3). Light version: iOS grouped gray ground, white cards, black text. The 12-LED brushed-metal ring and 12x12 one-bit pixel avatars on black tiles are the signature objects. Pill controls; the selected pill fills with its mood colour, neutral actions fill with the text colour. Colour appears only where it means a mood.

STORY: The visitor sees the band glow, tries the four moods, then reads the PRD in a calm column, tries the prototype and answers the poll.

FIRST VIEWPORT: Desktop: left, "Heya" at display size, tagline, PRD meta links, white "Try the prototype" pill; right, the metal ring at about 260px with LEDs chasing on in Let's hang green, the mood name with its dot, and a four-pill mood pad (Hang, Quiet, Wave, Off) that relights the ring. Tester notice below. Phone: copy, then ring at about 200px, pad full width.

FORM: seed: none (pinned). "align the aesthetics of the product page to match the app" (the native SwiftUI app in ios-native/Heya.swiftpm); user chose "The glowing ring, like the app" for the top of the page and "Dark-first, matching light version". Signature interaction: the mood pad relights the ring with the app's LED chase; Quiet pulses as in the app.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
