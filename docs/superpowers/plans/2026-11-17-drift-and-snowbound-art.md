# Drift, snowbound art and Warcraft colours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Snowy lands get their own seasonal paintings, flakes/leaves/petals drift along the rim with
zero per-frame Lua, and rim tints and paintings use deeper Warcraft colours.

**Architecture:** Lanes and counts are data in `Data.lua`; `UI.lua` builds one sprite + AnimationGroup
per lane once (a `Rotation` whose origin is the minimap centre, plus two `Alpha` fades, looping), and a
refresh only picks the atlas cell, colour and which lanes play. Art is painted by `tools/decor.py`.

**Tech Stack:** Lua 5.1 (WoW classic-era API, `## Interface: 16001`), Python 3 (texture script), tests
with `lua tests/run.lua`.

**Spec:** `docs/superpowers/specs/2026-11-17-drift-and-snowbound-art-design.md`

## Global Constraints

- No `OnUpdate` or timer for the drift. Lua runs only at build time and on refresh.
- Nothing drifts or is anchored inside the blocked sectors: 30–60 (Weather orb), 82–98 (N),
  165–195 (Geography orb), 195–235 (Weather readout), degrees CCW from the right.
- Snowbound = `ns.ClimateStyle[...] == "snowbound"` (the alpine lands). Hot lands: no drift, shared art.
- New textures: `Media/decor_snowbound_<season>.tga` (512×512), `Media/drift.tga`. Need a client restart.
- `db.drift` default `true`; `/ims drift on | off`.

## Review Focus

- A lane whose sweep crosses a blocked sector: a flake over Weather's orb. Test checks every lane's whole arc.
- Minimap resized (`OnSizeChanged`): origin offsets must be recomputed or sprites orbit the wrong point.
- Season/zone change while playing: no group must keep playing with the old cell; lanes above the count stop.
- `/ims hide` or `drift off`: every group stopped and every sprite hidden.
- Client without `CreateAnimationGroup` on textures (stubbed/old): drift silently off, no error.

---

### Task 1: Drift data and Warcraft tints

**Files:**
- Modify: `Data.lua` (tints; add `ns.DriftLanes`, `ns.DriftCount`, `ns.DriftKind`, `ns.DRIFT_CELLS`)
- Create: `tests/drift_spec.lua`; Modify: `tests/run.lua` (add the spec)

**Interfaces — Produces:**
- `ns.DriftLanes[i] = { from = deg, sweep = deg, r = fraction of rim half size, dur = s, delay = s, size = px }`
- `ns.DriftCount[style][season] = integer` (0..#DriftLanes), all three styles × four seasons
- `ns.DriftKind[style][season] = "flake" | "leaf" | "petal" | nil`
- `ns.DRIFT_CELLS = { flake = 1, leaf = 2, petal = 3 }` (cells of a 4×1 atlas)
- `ns.LEAF_COLORS = { {r,g,b}, ... }` (three: orange, red, yellow)

- [ ] **Step 1: Write `tests/drift_spec.lua`** with tests:
  - "lanes stay clear of the siblings": for each lane, sample every degree of `from .. from + sweep`
    (mod 360) and assert none lies in the blocked sectors above; `0.88 <= r <= 1.0`; `dur >= 8`; `size <= 16`.
  - "drift counts and kinds": for every style in {temperate, snowbound, hot} and season, count is an
    integer in `0..#DriftLanes`; count > 0 implies `DriftKind` set and `DRIFT_CELLS[kind]` set;
    every summer and every hot count is 0; snowbound winter count is the largest of all.
  - "drift timings don't line up": all `dur` values distinct.
  - "Warcraft tints": snowbound autumn's blue channel > red channel (cold, not grey-white).
- [ ] **Step 2:** `lua tests/run.lua` → FAIL (DriftLanes nil).
- [ ] **Step 3: Fill `Data.lua`.** About 6 lanes: four on the right going clockwise (sweep −25..−40,
  starting 15..−10 i.e. 15°/5°/350°/335°, ending above 240), two on the top-left going CCW (from ≈105,
  sweep +40..+50, ending < 160). Durations 11, 13, 17, 19, 23, 29; delays spread 0..9. Counts:
  temperate spring 4 / summer 0 / autumn 5 / winter 5; snowbound 2 / 0 / 5 / 6; hot all 0.
  Tints (deeper, warmer): temperate spring {0.42,0.60,0.22}, summer {0.96,0.72,0.22},
  autumn {0.80,0.36,0.12}, winter {0.50,0.68,0.92}; snowbound spring {0.50,0.68,0.58},
  summer {0.68,0.70,0.50}, autumn {0.56,0.66,0.80}, winter {0.66,0.84,1.00}; hot spring
  {0.82,0.66,0.30}, summer {0.96,0.62,0.18}, autumn {0.80,0.48,0.20}, winter {0.70,0.56,0.36}.
- [ ] **Step 4:** `lua tests/run.lua` → all pass.
- [ ] **Step 5: Commit** `feat: drift lanes and Warcraft rim tints`

### Task 2: Paintings (snowbound set, drift atlas, deeper colours) and preview

**Files:**
- Modify: `tools/decor.py`, `tools/make_textures.py`
- Output: `Media/decor_snowbound_{spring,summer,autumn,winter}.tga`, `Media/drift.tga`, re-painted
  `Media/decor_*.tga`, `docs/images/seasons.png` (two rows: temperate, snowbound)

**Interfaces — Produces:** `decor.SNOWBOUND` (dict season → painter, like `decor.SEASONS`),
`decor.drift_atlas(canvas)` painting a 128×32 atlas in cells flake | leaf | petal | spare (white/grey
leaf so it can be vertex-coloured; flake white-blue; petal pink-white).

- [ ] **Step 1:** Deepen the shared palette in `decor.py` (`GREEN`, `ORANGE`, `RED`, `YELLOW`, `BROWN`,
  blossom): darker darks, more saturated mid tones, crimson/burnt orange rather than light orange.
- [ ] **Step 2:** Add `pine(p, a, size, tilt, snow=0..1)` (a needled sprig lying along the rim, dark
  green, optional snow on its top edge), `alpine_flower(p, cx, cy, size)` (small blue/white), and
  `snowcap(..., depth=1.0, drips=False, icicles=True)` parameters. Paint the four snowbound seasons
  per the spec using `check_sector` for every anchor.
- [ ] **Step 3:** `make_textures.py`: write `decor_snowbound_*`, `drift.tga` (Canvas sized 128×32 —
  extend Canvas or paint into a 128-wide canvas), preview second row with snowbound tints, and lane
  arcs drawn as faint dotted lines (read lanes by importing values duplicated in a `DRIFT_PREVIEW`
  list; the drift_spec test from Task 1 is the authority on clearance).
- [ ] **Step 4:** `py -3 tools/make_textures.py <scratch>`; look at `docs/images/seasons.png` and the
  zoom: outlines bold, colours deep, nothing in blocked sectors.
- [ ] **Step 5: Commit** `feat: snowbound paintings, drift sprites, deeper colours`

### Task 3: UI — style-aware decor, engine-driven drift, `/ims drift`

**Files:**
- Modify: `UI.lua`, `tests/ui_smoke.lua`

**Interfaces — Consumes:** Task 1 tables; `state.style`, `state.season`.

- [ ] **Step 1: Extend `tests/ui_smoke.lua`:** stub `CreateAnimationGroup` on objects returning a group
  whose `CreateAnimation` returns an obj, with `Play`/`Stop`/`IsPlaying` tracked. Assert:
  - in Dun Morogh (snowbound) in January: decor texture ends with `decor_snowbound_winter`;
    `#ImmerseMeSeasonsRim.drift == #ns.DriftLanes`; exactly `DriftCount.snowbound.winter` groups playing;
  - October date: `decor_snowbound_autumn`;
  - `/ims drift off` → no group playing, all sprites hidden; `drift on` → playing again;
  - `/ims hide` → none playing;
  - `"drift on"`/`"drift off"` added to the command loop list.
- [ ] **Step 2:** `lua tests/run.lua` → FAIL.
- [ ] **Step 3: Implement in `UI.lua`.**
  - `DEFAULTS.drift = true`; usage line `"/ims drift on | off - snowflakes and leaves drifting along the rim"`.
  - Decor key: `local key = (s.style == "snowbound" and "snowbound_" or "") .. s.season`, texture
    `"decor_" .. key`, cache on `decor.key`.
  - `BuildDrift()` once (guard `rim.drift`): per lane a texture (`OVERLAY` sublevel 0, `drift` atlas),
    `ag = tex:CreateAnimationGroup()`, `ag:SetLooping("REPEAT")`; `rot = ag:CreateAnimation("Rotation")`
    with `SetDegrees(lane.sweep)`, `SetDuration(lane.dur)`, `SetStartDelay(lane.delay)` (first loop
    only is fine); `fadeIn = Alpha` 0→1 duration `dur*0.2`; `fadeOut = Alpha` 1→0 duration `dur*0.25`,
    `SetStartDelay(lane.delay + dur*0.75)`; `tex:SetAlpha(0)` baseline. If `tex.CreateAnimationGroup`
    is missing, set `rim.drift = {}` and return.
  - `LayoutDrift()` (called from `Layout`): `half = rim:GetWidth()/2`; for each lane
    `x, y = half*r*cos(from), half*r*sin(from)`; `tex:SetPoint("CENTER", rim, "CENTER", x, y)`;
    `tex:SetSize(size, size)`; `rot:SetOrigin("CENTER", -x, -y)`.
  - `DrawDrift(s)` in `Draw`: `kind = ns.DriftKind[s.style][s.season]`, `count` (0 if `not db.drift`
    or no kind); for lane i ≤ count: `SetTexCoord` of the cell `((c-1)/4, c/4, 0, 1)`, vertex colour
    (leaf: `LEAF_COLORS[(i-1) % 3 + 1]`, else white), show, `Play()` if not playing; for i > count:
    `Stop()`, hide. Re-play from start only when the key `style..season` changes.
  - `/ims drift on|off` command like `decor`; `debug` line adds `drift <count>`.
- [ ] **Step 4:** `lua tests/run.lua` → all pass.
- [ ] **Step 5: Commit** `feat: drifting flakes and leaves along the rim`

### Task 4: Docs and deploy

**Files:** `README.md`, `docs/customizing.md`, `docs/how-it-works.md`, `CHANGELOG.md`

- [ ] **Step 1:** Document `/ims drift`, the snowbound set, the lane table in customizing, and the
  "engine-driven, no per-frame code" note in how-it-works; changelog entry.
- [ ] **Step 2:** `lua tests/run.lua` → all pass; copy `*.lua`, `*.toc`, `Media/*` to
  `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ImmerseMe_Seasons\`.
- [ ] **Step 3: Commit** `docs: drift and snowbound art`
