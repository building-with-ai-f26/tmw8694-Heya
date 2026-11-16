---
name: Heya Wrapped
description: A year of real-life hangouts, drawn in sidewalk chalk on the pavement where they happened.
colors:
  chalk-green: "#69d99a"
  chalk-purple: "#b39bff"
  chalk-yellow: "#ffd25a"
  green-ink: "#17703f"
  concrete: "#d5d2ca"
  asphalt: "#2b2d30"
  graphite: "#1f2124"
  graphite-soft: "#3f4247"
  line-graphite: "#2b2d31"
  chalk-white: "#f7f5ef"
  on-chalk: "#18191b"
  night-chalk: "#f1eee7"
  night-chalk-soft: "#d3cfc7"
  line-night: "#ece8df"
typography:
  display:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontSize: "clamp(2.8rem, 8vw, 4.8rem)"
    fontWeight: 800
    lineHeight: 0.9
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontSize: "clamp(2.6rem, 7vw, 3.6rem)"
    fontWeight: 800
    lineHeight: 0.95
    letterSpacing: "-0.03em"
  title:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.15
  title-heavy:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontSize: "1.9rem"
    fontWeight: 800
    lineHeight: 1
  statement:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontSize: "1.35rem"
    fontWeight: 600
    lineHeight: 1.45
  body:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1rem"
    fontWeight: 700
    lineHeight: 1.5
  control:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1rem"
    fontWeight: 600
    lineHeight: 1
  caption:
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "0.85rem"
    fontWeight: 600
    lineHeight: 1.5
rounded:
  map: "4px"
  focus: "6px"
spacing:
  xs: "0.4rem"
  sm: "0.6rem"
  md: "1rem"
  lg: "1.6rem"
  xl: "2rem"
components:
  button-chalk:
    textColor: "{colors.graphite}"
    typography: "{typography.control}"
    padding: "0 1.25rem"
    height: "46px"
  button-chalk-pressed:
    backgroundColor: "{colors.graphite}"
    textColor: "{colors.concrete}"
    typography: "{typography.control}"
    padding: "0 1.25rem"
    height: "46px"
  button-go:
    backgroundColor: "{colors.graphite}"
    textColor: "{colors.concrete}"
    padding: "0 1.7rem"
    height: "62px"
  card-slab:
    textColor: "{colors.on-chalk}"
    padding: "2rem 1.9rem 1.6rem"
  card-slab-white:
    backgroundColor: "{colors.chalk-white}"
    textColor: "{colors.on-chalk}"
    padding: "2rem 1.9rem 1.6rem"
  card-cover:
    textColor: "{colors.graphite}"
    padding: "2rem 1.9rem 1.6rem"
  hop-square:
    textColor: "{colors.graphite}"
    size: "66px"
  hop-square-mobile:
    textColor: "{colors.graphite}"
    size: "48px"
---

# Design System: Heya Wrapped

## Overview

**Creative North Star: "Sidewalk Chalk"**

Your year of hangouts is drawn in chalk on the ground where it happened. The ground is pavement: sunlit pale concrete in light mode, charcoal asphalt with stone speckle in dark. Everything that is drawn (outlines, tallies, circled names, arrows, the year band, card fills, the hopscotch) is chalk, rendered as rough SVG strokes passed through turbulence filters so edges wobble and pavement pits show through. Nothing is a clean vector box, nothing glows, and nothing is a gradient.

The page is paged like a story, but the story is a hopscotch: numbered chalk squares on the left, the current one scrubbed in with chalk, and the current card at phone scale beside it. Each card is a chalked rectangle committed to one chalk colour, and that colour carries a mood when the card is about a mood. Hierarchy comes from scale in one display face, never from extra faces or decoration. Lines draw themselves in when a card arrives and are already drawn under reduced motion.

The world refuses the category default for year-in-review: full-bleed gradient story slides with giant neon numbers. It should feel like something a kid and a parent chalked after playing outside, not something built to keep you scrolling. Scope: this system covers the Wrapped app (`app/`). The product page (`docs/index.html`) is an older, separate surface that stays on its own plain style.

**Key Characteristics:**
- Pavement ground with SVG-noise aggregate in both colour schemes; chalk does all the drawing.
- Every outline is a hand-wobbled path through a chalk filter; no CSS borders on world elements.
- Three mood chalks plus white and graphite chalk. Mood chalk always means a mood.
- One display face (Bricolage Grotesque) with chalk-textured lettering; system UI for controls and body.
- Hopscotch navigation as the signature interaction; arrows and keys work too.
- Draw-in motion on arrival, fully pre-drawn under reduced motion.

## Colors

Pale and dusty: neutral pavement grounds, graphite or white chalk for everything structural, and three saturated pastel chalks reserved for the bracelet moods.

### Primary
- **Let's Hang Green** (chalk-green): the "Let's hang" mood. Fills a card slab, hopscotch square, mood swatch, map marker, or mood bubble only when the data behind it is that mood.
- **Quiet Company Lilac** (chalk-purple): the "Quiet company" mood, under the same rule.
- **Busy-But-Wave Marigold** (chalk-yellow): the "Busy, but wave" mood, under the same rule.

### Secondary
- **Leaf Ink** (green-ink): a darker green that stays legible as text on light concrete; in dark mode it resolves back to chalk-green. Currently used only for "Heya" in the wordmark (see Do's and Don'ts).

### Neutral
- **Sunlit Concrete** (concrete): the light-mode ground, always under the aggregate texture.
- **Night Asphalt** (asphalt): the dark-mode ground, under a darker aggregate with pale stone speckle. Also the share image's ground.
- **Graphite Chalk** (graphite): light-mode text on the ground, and the fill of pressed or primary chalk buttons.
- **Soft Graphite** (graphite-soft): light-mode secondary text (intros, captions, notes, map key).
- **Line Graphite** (line-graphite): light-mode drawn lines: outlines, tallies, hop squares, year band.
- **White Chalk** (chalk-white): the slab colour for cards that carry no mood, and map popups.
- **Slab Ink** (on-chalk): text drawn on any chalk slab, coloured or white, in both schemes.
- **Night Chalk** (night-chalk), **Night Chalk Soft** (night-chalk-soft), **Night Line** (line-night): the dark-mode swaps for graphite, graphite-soft and line-graphite. Lines and text become pale chalk on asphalt.

### Named Rules
**The Mood Chalk Rule.** Green, purple and yellow mean Let's hang, Quiet company and Busy, but wave, and nothing else. A slab, square, swatch or marker takes a mood chalk only when the data under it is that mood. Cards and squares with no mood are white chalk. A mood colour is always paired with the mood's name in text.

**The Same-Chalk Swatch Rule.** A mood swatch that sits on a slab of its own mood is scribbled in slab ink instead, so it never disappears into the slab.

**The Ground Is Pavement Rule.** The page background is always ground colour plus aggregate texture. Never a flat fill, a gradient, or a white page.

## Typography

**Display Font:** Bricolage Grotesque (self-hosted variable woff2, weights 200 to 800; fallback system-ui)
**Body Font:** system-ui stack (-apple-system, Segoe UI, Roboto, sans-serif)

**Character:** One bold grotesque does all the chalked lettering, roughened by a displacement filter so it reads as chalk on stone; the plain system face handles controls and reading text so the chalk stays special.

### Hierarchy
- **Display** (800, clamp(2.8rem, 8vw, 4.8rem), 0.9): the wordmark only. Heavy chalk-text filter.
- **Headline** (800, clamp(2.6rem, 7vw, 3.6rem), 0.95, -0.03em): the big chalked number or name on each card ("12 days in a row", a circled friend name). Balanced wrapping, breaks anywhere rather than overflowing. The title card sets it up to clamp(2.8rem, 8vw, 4rem).
- **Title** (700, 1.5rem, 1.15): card headlines under the big figure. Light chalk-text filter.
- **Title Heavy** (800, 1.9rem, 1): the cover card heading; side-panel headings use the same weight at 1.35rem.
- **Statement** (600, 1.35rem, 1.45): the cover sentence, max 24ch, with the true numbers inline at 800 and 1.55em.
- **Body** (400, 17px, 1.5): reading text. Card body copy at 1.05rem, max 34ch.
- **Label** (700, 1rem): card annotations and mood tags; figure captions at 0.9rem.
- **Control** (600, 1rem, 1): chalk buttons. The primary "Make my Wrapped" button switches to the display face at 800, 1.3rem.
- **Caption** (600, 0.85rem): card footers ("Square 3 of 6"), hop caption, run details (tabular numerals).

### Named Rules
**The One Chalk Face Rule.** Bricolage Grotesque is the only display face. Hierarchy comes from scale and weight, not from a second face or decorative styling.

**The Chalk Lettering Rule.** Display and headline type carry the heavier chalk-text filter; titles, side headings and captions in the display face carry the lite filter. System-UI text is never filtered.

## Layout

A centered column, max 70rem, padded 2rem 1.25rem 4rem. Under the masthead and wearer picker sits the story grid: hopscotch column (auto) | card (up to 27rem, phone scale) | side panel (remaining space), 2rem gap, top-aligned. Below 62rem the side panel drops under the hopscotch and card. Below 40rem everything stacks with a 1rem gap and the hopscotch becomes one horizontal row of six 48px squares above the card.

The hopscotch on wide screens is a real hopscotch: 66px squares in two 66px columns with an 8px gap, singles centered and pairs side by side, numbered bottom to top so square 1 sits at the bottom. Cards are tall (min 33rem) flex columns with a 0.8rem gap and the footer pushed to the bottom. Spacing steps in use are 0.4, 0.6, 1, 1.6 and 2rem.

## Elevation & Depth

The world is flat: everything is chalk on the same ground, and depth comes only from chalk density (a scrubbed fill over a pitted ground) and from the slight rotation on hover. There are no card shadows, no lifted panels, and no glows. The one shadow in the build is under the share-image preview, which reads as a printed photo lying on the pavement, rotated -1.5deg.

### Shadow Vocabulary
- **Print on pavement** (`box-shadow: 0 10px 24px -8px rgb(0 0 0 / .45)`): only for a raster object placed on the ground (the share preview). Never for chalk elements.

### Named Rules
**The Same-Ground Rule.** Chalk lies on the ground. It never casts a shadow and never floats above another layer.

## Shapes

There are no geometric rectangles in the world. Every box (buttons, the map frame, map zoom controls, hop squares, the cover card) is a `roughRect` path: four jittered corners joined by wobbly quadratic curves, with the stroke overshooting its start like a hand would, drawn at 2.6 to 3.2px with round caps through the `chalk-line` filter. Circles are `roughEllipse` loops with slow wobble and a closing overshoot. Mood-coloured slabs have no outline: their edge is made of the ends of diagonal scrub strokes. Shapes are drawn at the element's real size with a seeded random, so redraws on resize never jump. The only CSS radii are the 6px focus ring and the 4px clip on the map tiles.

## Components

### Buttons
Chalk-outlined and tactile: a drawn outline, not a CSS border.
- **Shape:** a rough chalk rectangle in line colour, sized to the button (min height 46px, padding 0 1.25rem).
- **Default:** transparent, graphite text, control type. Inline SVG arrows are hand-drawn chalk strokes.
- **Pressed (aria-pressed) and primary:** the outline is filled with a graphite chalk scrub and the text turns to ground colour at 700.
- **Go (primary call to action):** display face 800 at 1.3rem, min height 62px, filled graphite scrub.
- **Hover:** rotate -1deg and lift 1px over 0.25s on cubic-bezier(.16, 1, .3, 1). No colour change.
- **Focus:** 3px dashed outline in ink, 5px offset, 6px radius.
- **Disabled:** 45% opacity, not-allowed cursor.

### Cards / Containers
- **Mood card slab:** the whole card is a scrubbed chalk fill in its one chalk (a mood chalk or white chalk). It has two passes: a dense bed under the copy, and loose diagonal strokes on top through the `chalk-scrub` filter so pavement pits show through. Text is slab ink.
- **Cover card:** no fill. A graphite (night chalk in dark mode) rough outline at 3.2px, ink text, chalk tallies and the year band.
- **Padding:** 2rem 1.9rem 1.6rem, min height 33rem. No border, no shadow.
- **Arrival:** the card settles in (from 6px down, 0.6deg rotation, 40% opacity, over 0.45s) while its chalk lines draw in over 0.8s, staggered.

### Navigation
- **Hopscotch:** 66px chalk squares (48px on phones) with display-face numerals at 800. The current square is scrubbed in with its card's chalk and its numeral switches to slab ink. Squares already visited get a small chalk tick. Squares stay disabled until the Wrapped is made. It has a caption underneath ("Hop to any square"), and arrow keys and the Back and Next chalk buttons do the same thing.

### Chalk Figures (signature)
- **Tallies:** groups of four uprights with a diagonal fifth, 3.5px strokes, for counts of friends and streak days.
- **Year band:** one chalk baseline from January to now, with a vertical stroke per month and the busiest month heavier (9px vs 5.5px). Month initials sit below it.
- **Circled name:** a rough ellipse drawn around the top friend's name.
- **Mood swatch and mood bubbles:** rough chalk circles filled with mood chalk and outlined in slab ink, always next to the mood name.
- **Lanes:** per-friend chalk bars, 7px strokes, with the name and count on either side.

### Map
- **Frame:** a rough chalk rectangle around a 290px Leaflet map whose tiles are greyscaled (and inverted in dark mode) so the pavement still owns the colour. Zoom controls are ground-coloured with chalk outlines. Places are mood-filled circles outlined in line colour, sized by taps, with a mood key paired with names. Adult Wrapped only.

### Share Image
- **Canvas:** 1080x1350 PNG on night asphalt with speckle. It shows a white-chalk hopscotch of the year, mood-scrubbed squares only where a mood applies, and coarse erosion over the chalk layer so grain survives at small size.

## Do's and Don'ts

### Do:
- **Do** draw every outline and figure as a rough path through the chalk-line filter, sized to the element and seeded, so it never jumps on redraw.
- **Do** commit each card to exactly one chalk: its mood's chalk if the card is about a mood, white chalk otherwise.
- **Do** pair every mood colour with the mood's name in text.
- **Do** keep the ground as ground colour plus aggregate texture in both colour schemes.
- **Do** let chalk lines draw in on arrival (0.8s, cubic-bezier(.16, 1, .3, 1)) and render them already drawn under prefers-reduced-motion.
- **Do** use Bricolage Grotesque for chalked lettering and system UI for controls and body, with hierarchy by scale.

### Don't:
- **Don't** use green, purple or yellow decoratively. They mean Let's hang, Quiet company and Busy, but wave.
- **Don't** use full-bleed gradient story slides, giant neon numbers, or anything that reads as Spotify Wrapped.
- **Don't** put CSS borders, border-radius boxes or drop shadows on chalk elements. Chalk lies flat on the ground.
- **Don't** add a second display face or render display text without the chalk filter.
- **Don't** show locations, maps or sharing on a kid's Wrapped.
