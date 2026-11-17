# ImmerseMe: Seasons — seasonal rim art and readout overlap (design)

Date: 2026-11-17 · Author: holyc4t · Status: draft for approval · Builds on `2026-11-16-seasons-design.md`

## Why

In game, the rim already makes the world feel seasonal, but a plain tinted ring reads as "a white
or orange circle". The seasons should be **visible as things**: leaves, blossoms, wheat and sun, snow
and icicles. They should be painted to look like they belong on WoW Forever's own minimap frame, not
like generic clip-art.

Separately, Seasons' ring is wider than the stock frame and runs under ImmerseMe: Weather's
readout, and the year-arc's notches sit in the same spot.

## Goals

- **Approach A, "Accents"** (picked from mockups `.superpowers/brainstorm/.../seasonal-rim.html`):
  two small decorative clusters per season in the quiet spots of the rim. The rest of the rim stays
  clean metal in the season's tint.
- **Warcraft style:** match the stock minimap frame in the user's screenshots:
  - warm bronze-gold;
  - bold dark outlines (≈1.5 px at screen size);
  - painterly 2–3 tone shading lit from the top-left, with a bright rim light on the upper edges;
  - saturated but not neon colours;
  - chunky readable shapes, no thin detail that vanishes at minimap size.
- **No overlap:** nothing Seasons draws reaches past the stock frame's outer edge, or into Weather's
  readout area on the lower-left.
- Everything else stays as it is: tint, frost layer, year-arc, tooltip, commands, standalone rule.

## Non-goals

- Animation (falling leaves or snow). Possible later; not now.
- Garland or weathered-metal looks (options B and C).
- Any change to Weather or Geography.

## Anti-goals

- Clip-art look: flat vector shapes, gradients without outlines, photo textures.
- Clutter that competes with the map, the siblings' orbs or the readout.
- Decorations covering the stock minimap buttons (zoom, tracking, mail, the compass "N").

## Approaches considered

| | Approach | Trade-off |
|---|---|---|
| **A** | **Accents: two clusters per season in the quiet spots** | **Picked.** Seasonal at a glance, calm, keeps clear of the siblings |
| B | Garland most of the way round | Richest, but busy and always on screen |
| C | Weathered metal (frost speckles, moss, rust) + one emblem | Subtlest; the season reads less clearly |

Art source: painted procedurally by the existing Python tool, in the Warcraft hand-painted style
(our call). Reusing Blizzard textures from the client was considered and dropped: we can't browse
the client's files from here, so we can't know which art exists or how it looks, and the family's
rule is original generated art.

## The decorations

Angles are degrees counter-clockwise from the right (as in `UI.lua`). Occupied areas to avoid:
- Weather's orb ≈ 30–60°;
- the compass "N" ≈ 82–98°;
- Geography's orb ≈ 165–195°;
- Weather's readout ≈ 195–235°.

The decorations go in the right-hand quiet arc (≈ 330–25°), plus the top-left arc for winter's snow.

| Season | Cluster 1 | Cluster 2 |
|---|---|---|
| Spring | A green sprig along the rim with 5–6 leaves and 3 pink-white blossoms, ≈ 335–20° | Two small leaves and a bud, ≈ 300° |
| Summer | A small radiant sun emblem in Warcraft-gold, ≈ 5° | Three ripe wheat ears fanned out, ≈ 315° |
| Autumn | Three overlapping maple/oak leaves (orange, red, yellow), ≈ 345° | Two leaves, one curling, ≈ 10° … 20° |
| Winter | A snow cap lying on the top-left rim with 3–4 icicles hanging inward, ≈ 100–150° | Two or three snowflake crystals with a cold glow, ≈ 330–10° |

Each season is one full-colour texture (`Media/decor_<season>.tga`, 512×512 so the painting stays
crisp on large UI scales). It is drawn untinted, above the tinted ring and frost, below the
year-arc's dot and notches. The frost layer keeps working on top in every season.

## The overlap fix

Measured from the user's screenshot: map radius ≈ 113.5 px, stock frame outer edge ≈ 126 px
(≈ 1.11× the map radius). Seasons' ring reached ≈ 131.5 px (1.16×).

- Ring band: inner edge at the map edge, outer edge at 1.11× the map radius. `RING_INNER` changes
  from 0.86 to 0.90, in both `tools/make_textures.py` and `UI.lua`.
- Year-arc: moved off the readout, from 200–340° to **235–325°**, at `ARC_RADIUS` 0.95 (the middle of
  the new band). Dot and notches follow.
- Decorations may poke past the outer edge by at most ≈ 4 px (a snow cap's crown, a leaf tip), and
  never in the readout's 195–235° sector.

## How we check it

- The texture script also writes a preview PNG of the rim in all four seasons
  (`docs/images/seasons.png`), with the siblings' orbs and the readout area drawn in, to review
  before deploying.
- Tests: ring geometry constants match between the script and `UI.lua`; the arc's angles stay
  outside 195–235°.
- In game: the user checks the look and that the readout is clear in each season (`/ims debug`
  helps).

## Left to the builder

Exact shapes, colours and placement within the stated sectors; leaf species; snowflake design; the
sun's ray count.
