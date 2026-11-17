# ImmerseMe: Seasons — the sun path under the minimap (design)

Date: 2026-11-17 · Author: holyc4t · Status: superseded · Replaces the year-arc on the rim

> **Superseded (same day).** In game the free-floating arch looked detached, ran into the quest
> tracker, and a "hill" didn't read as seasons. Replaced by the **season arc**: a bronze line
> concentric with the minimap, just below the client's coordinates (radius 1.36 x the minimap's,
> 240-296 degrees, clear of Weather's readout and the zoom buttons), with the four season icons on
> it. The current season's icon is bright and larger and stands where today is; the others rest,
> dimmed, mid-season. Ticks mark the season starts; festival notches stay. Hover the arc for the
> tooltip. The sun arch, `sunpath.tga` and `sun.tga` are gone.

## Why

The year-arc on the lower rim (a faint line, a small gold dot for today and festival notches) is
hard to read. The dot looks like a stray light, nothing says it is the sun, and it crowded the zoom
buttons and the client's coordinates. The season tooltip is also hard to find: it only shows on
the thin rim band. The user wants the year's sun to be **obvious at a glance** and **lower, apart
from the minimap**, with an easy place to hover for the season.

## Goals

- **A sun path below the minimap:** a small, shallow arch like the sun's path across the sky. Its
  left end is 1 January, its right end 31 December, and its top is midsummer.
- **A painted sun rides it:** horizontal position = day of the year; height = the arch, so it sits
  low at the ends in winter and high in the middle in summer. It's the same Warcraft-painted sun
  as the summer decoration (gold disc, rays, dark outline), about 16 px.
- **Festival notches on the arch**, as on today's rim arc; festivals on now glow gently.
- Small marks at the solstices and equinoxes, so the seasons read as quarters of the arch.
- **Hover the arch or the sun** to get the season tooltip (same content as now). The rim band keeps
  its tooltip too.
- `/ims arc on|off` now turns the sun path on or off, and `/ims nudge x y` moves it.

## Placement

- Anchored under the minimap, centred, below the client's coordinates text: the arch's top edge is
  about 22 px below the minimap's bottom at the stock size, and it scales with the minimap.
- About 0.75 × the minimap's width and 26 px tall (sun included).
- Clear of Weather's readout (lower-left of the minimap) and of the zoom buttons (lower-right).

## What goes away

The rim's year-arc line, its dot and its notches (`arc.tga`; `dot.tga` is replaced by the painted
sun). The rim keeps its tint, frost, paintings and drift.

## Non-goals

- A real astronomical sun altitude per zone (the arch is a stylised year, the same everywhere).
- A moon or day/night: the sky is Weather's job.

## Anti-goals

- Anything that takes clicks from the minimap or the stock buttons.
- A numbers panel: no dates or labels drawn on screen; detail stays in the tooltip.

## Approaches considered

| | Approach | Trade-off |
|---|---|---|
| **A** | **Sun path under the map** | **Picked by the user.** Obvious at a glance, an easy hover target; uses space below the minimap |
| B | Sun badge on the rim, replacing the dot | Compact, but stays crowded with the buttons, the coordinates and Weather's readout |

## How we check it

- Tests: the sun's position for 1 January, midsummer and 31 December (left low, middle high, right
  low); notches placed on the arch; hover shows the tooltip; `/ims arc off` hides the sun path.
- The texture script writes the arch and the sun, and the preview shows the sun path under one rim.
- In game: the user checks it reads as "the sun through the year" and doesn't collide with the
  quest tracker or other frames below the minimap (nudge if it does).

## Left to the builder

The arch's exact curve and colours (bronze-gold line, dark outline, soft glow), the sizes within the
numbers above, and the solstice/equinox mark style.
