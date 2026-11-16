# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Kids without phones (about 7–12), and their parents.** Example: Grant, 7, very social, always wants to see his friends. Parents buy the bracelet because they want to know where their kid is without handing over a phone, and they want less screen time. Kid Wrapped is read by the **kid and parent together** on the parent's phone.
- **Gen Z and young adults with phones.** Example: Faith, 30, very social, always out in the city and happy to say hi. Wants to see friends in person without texting "anyone around?" or sharing her location all day.

## Product Purpose

Heya is a slim light-up bracelet with a companion app that gets people off their phones and into real time with friends. Success is more in-person hangouts and less screen time. Heya Wrapped turns a year of bracelet taps into a recap that makes looking back on real-life time rewarding, so people keep tapping (and adults share it).

## Positioning

Friendship measured in the physical world: a year-in-review built only from moments two friends actually met and tapped bracelets in person, never from screen activity.

## Operating Context

- The bracelet has one button that cycles moods: **Let's hang** (green), **Quiet company** (purple), **Busy, but wave** (yellow), **Off**. Friends nearby see the glow; it warms as they approach and both bands pulse when they meet; they tap bracelets to save the hang.
- Kids' data shows on a parent's phone app. Adults use their own phone app.
- Heya Wrapped is opened in the app and paged through like a story.

## Capabilities and Constraints

- Local web app (`app/`): Python standard-library server plus a static page. One real AI call per Wrapped through OpenRouter (`anthropic/claude-haiku-5.5`); the server computes every number and the AI writes only the words.
- Product page is static HTML on GitHub Pages (`docs/`).
- **Kid Wrapped:** friends and taps only. No locations, no maps, no social sharing.
- **Adult Wrapped:** map of tap places (saved only at the moment of a tap), top friends, and a shareable image with a caption.
- Friends are only added by tapping in person. No strangers, no messaging, no feeds.
- PostHog analytics and session replay on both pages, with a visible notice to testers.

## Brand Commitments

- Name: **Heya**.
- The four bracelet moods and their colors (green, purple, yellow, off) are product meanings, not decoration.

## Evidence on Hand

- Demo tap data only (`app/data/grant.json`, `app/data/faith.json`): fictional users Grant and Faith, Jan 1 – Nov 15, 2026. No real user data, testimonials or usage numbers yet; do not fabricate them.

## Product Principles

1. Real life first: every screen should push toward meeting up, not more scrolling.
2. Kids' privacy is non-negotiable: no locations or public sharing for kids.
3. True numbers only: stats come from taps, never invented by AI.
4. Warm, never competitive: celebrate friends without ranking anyone as a loser.

## Accessibility & Inclusion

- Kid Wrapped must be readable by a 7-year-old with a parent: big type, short sentences.
- Mood colors must never be the only way meaning is shown (always paired with the mood name).
- Works in light and dark mode and at phone width.
