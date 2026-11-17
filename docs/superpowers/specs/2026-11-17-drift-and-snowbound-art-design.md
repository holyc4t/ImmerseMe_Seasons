# ImmerseMe: Seasons — drifting flakes and leaves, snowbound art, Warcraft colours (design)

Date: 2026-11-17 · Author: holyc4t · Status: draft for approval · Builds on `2026-11-17-seasonal-art-design.md`

## Why

In Dun Morogh on 17 November the rim showed a pale grey-white ring (the snowbound *autumn* tint)
with *maple leaves* (the one autumn painting every land shares). It reads as "winter ring, autumn
leaves": the art follows only the calendar, not the land. The user wants:

1. snowy lands to get their own seasonal paintings;
2. the rim to come alive: **snowflakes falling and leaves drifting slowly across the rim**;
3. colours that look like Blizzard's Warcraft art, not soft pastels;
4. **zero performance impact**.

## Goals

- **Snowbound art set.** Lands whose climate style is `snowbound` (today: Dun Morogh, Alterac
  Mountains, Winterspring — every `alpine` climate) get four paintings of their own:
  `Media/decor_snowbound_<season>.tga`. Everything else keeps `decor_<season>.tga`.
  - spring: a melting snow cap (shorter, with drips) on the top-left rim, a pine sprig and a few
    small blue/white mountain flowers on the right;
  - summer: a pine sprig with cones on the right, a thin line of snow left on the top-left rim;
  - autumn: snow-dusted pine on the right, a fresh snow cap on the top-left rim, one or two flakes;
  - winter: the heaviest look: deep snow cap with icicles, frosted pine, flakes.
- **Drift.** A few small sprites travel slowly along the rim band and fade in and out:

  | Style | Spring | Summer | Autumn | Winter |
  |---|---|---|---|---|
  | temperate | blossom petals | none | leaves (orange, red, yellow) | snowflakes |
  | snowbound | a few snowflakes | none | snowflakes | snowflakes (most) |
  | hot | none | none | none | none |

- **Warcraft colours.** Deeper, more saturated rim tints closer to the stock bronze-gold frame:
  mossy green, Blizzard gold, burnt orange, frost-mage ice blue. Snowbound autumn becomes a cold
  steel blue instead of grey-white, so it no longer reads as a plain white ring. The decor
  paintings get deeper colours to match (crimson/burnt-orange leaves, dark pine greens, cold blue
  snow shading), keeping the bold dark outline and top-left lighting.
- `/ims drift on | off` (saved as `db.drift`, default on).

## Non-goals

- Separate art for hot lands (they keep the shared set, no drift).
- Any change to Weather or Geography, the frost layer, the year-arc or the tooltip.
- Weather-driven drift (snowing only when Weather says it snows). The drift is seasonal decoration.

## Anti-goals

- Any per-frame Lua cost. Measurable FPS impact is a failure even if it looks good.
- Sprites crossing the siblings' orbs, the compass "N" or Weather's readout.
- Busy, blizzard-like motion that pulls the eye from the map. It must stay slow and sparse.

## Approaches considered (drift)

| | Approach | Trade-off |
|---|---|---|
| A | Sprites moved by Lua in `OnUpdate` | Full control, but Lua runs every frame. Fails "zero impact" |
| **B** | **Blizzard AnimationGroups, rotated around the minimap centre** | **Picked.** Runs entirely in the engine; no Lua per frame or per loop. Paths are arcs along the rim |
| C | Flipbook (pre-drawn frames cycled with `SetTexCoord`) | Large textures, choppy at minimap size, needs a timer to step frames |

**The trick:** a `Rotation` animation with `SetOrigin("CENTER", dx, dy)`, where (dx, dy) is the offset
from the sprite to the minimap centre, swings the sprite along a circle round the map, i.e. along the rim.
The sprite also turns as it goes, which looks like a leaf or flake tumbling.

## The drift in detail

- **Lanes, fixed in `Data.lua`.** About 6 lanes (`ns.DriftLanes`), each `{ from = deg, sweep = deg,
  r = radius fraction, dur = seconds, delay = seconds, size = px }`. Sweeps are negative (clockwise:
  falling down the right side) or positive on the top-left (falling down that side). Every lane's
  `from .. from + sweep` stays inside the quiet arcs (≈ 240–25° and 100–160°), never crossing the
  blocked sectors listed in `tools/decor.py`. Durations differ and don't share factors (e.g. 11, 13,
  17, 19, 23 s), so the pattern never visibly repeats.
- **Each sprite:** one texture on the rim frame, layer `OVERLAY` sublevel 0 (with the decor, under the
  frost), one AnimationGroup set to `REPEAT` with:
  - `Rotation`: `SetDegrees(sweep)`, origin at the minimap centre, duration `dur`, `SetStartDelay(delay)`;
  - `Alpha` 0 → 1 over the first 20 %, and `Alpha` 1 → 0 over the last 25 % (order/offsets so they
    overlap the rotation);
  - optionally a small `Translation` inward/outward for a sway (builder's call, only if it looks better).
- **Sprite art:** one new atlas `Media/drift.tga` (e.g. 128×32, four 32×32 cells: snowflake, leaf,
  petal, a spare). Each lane picks its cell and, for leaves, a vertex colour from a short list
  (orange/red/yellow) so one leaf cell gives three leaves. Painted with the same `decor.py` style.
- **Lua cost:** sprites and groups are built once at load. A season or zone change only re-sets the
  texture coordinates, colours and how many lanes play (`Play`/`Stop`, `Show`/`Hide`). Nothing else runs.
  Hidden regions don't animate, so a hidden minimap costs nothing.
- **Resize:** the origin offsets depend on the rim size, so `Layout()` re-sets them when the minimap
  size changes (existing hook).
- **Lane count per season:** `ns.DriftCount[style][season]` (e.g. temperate winter 5, snowbound
  winter 6, snowbound spring 2, summer 0). Tweakable in `Data.lua`.

## Choosing the art set

`ns.State` already returns `style` (from the land, never an instance). UI picks
`decor_snowbound_<season>` when `style == "snowbound"`, otherwise `decor_<season>`, and caches on
`style .. season` instead of `season` alone. The drift uses the same key.

## How we check it

- `tools/make_textures.py` also writes the four snowbound paintings and `drift.tga`, and the preview
  `docs/images/seasons.png` grows a second row (snowbound) with the lane arcs drawn in.
- Tests: every lane's arc (`from` to `from + sweep`) stays outside the blocked sectors; every
  style/season in `DriftCount` has a cell; drift counts never exceed the number of lanes; snowbound
  decor files are listed for all four seasons.
- `ui_smoke.lua` stubs `CreateAnimationGroup` and checks that a refresh with drift on and off makes no
  error and that `/ims drift off` stops every group.
- In game: Dun Morogh shows the snowbound autumn art with falling flakes; Elwynn shows leaves.
  New textures need a full client restart.

## Left to the builder

Exact tint values (within "deeper, closer to the stock bronze-gold"), the painting details, lane
angles, sizes and timings, and whether a sway translation helps.
