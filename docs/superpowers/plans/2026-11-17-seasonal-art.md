# Seasonal Rim Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (chosen: native). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Paint a seasonal decoration layer for the rim (approach A) and pull the ring and year-arc inside the stock frame and clear of Weather's readout.

**Architecture:**
- `tools/make_textures.py` gains painted `decor_<season>.tga` (512²) and a preview PNG writer.
- `UI.lua` gains one untinted decor texture, switched by `state.season`.
- Geometry constants move to `RING_INNER 0.90`, `ARC_RADIUS 0.95`, arc 235–325°.

**Tech Stack:** Lua 5.1, Python 3 run as `py -3` (no dependencies), 32-bit TGA.

**Spec:** `docs/superpowers/specs/2026-11-17-seasonal-art-design.md`

## Global Constraints

- Shared geometry, identical in the script and `UI.lua`:
  - `RING_INNER = 0.90`, `ARC_RADIUS = 0.95`;
  - `ARC_FROM = 235`, `ARC_SPAN = 90` (UI), which the script writes as `ARC_FROM, ARC_TO = 235.0, 325.0`.
- Readout sector 195–235° holds no decoration and no arc.
- Decor art style: dark outline ≈ 3 px at 512² (≈ 1.5 px on screen), 2–3 tone shading lit from the top-left, a rim light, chunky shapes.
- Decor is drawn untinted: layer `OVERLAY` sublevel 0. Frost is sublevel 1, arc 2, notches 3, dot 4.

## Review Focus

1. **Decor in the wrong spot.** Decorations land on the Weather orb, the "N", the Geography orb or the readout. → T2 preview image plus the sector check in `tests/geometry_spec.lua`.
2. **Geometry drift.** The ring constants drift between the script and `UI.lua`. → T1 geometry test.
3. **Season change.** The decor texture doesn't switch when the season changes. → T3 smoke assertion.

---

### Task 1: Geometry inside the stock frame

**Files:**
- Modify: `tools/make_textures.py` (constants), `UI.lua` (constants).
- Create: `tests/geometry_spec.lua`, registered in `tests/run.lua`.

- [ ] Write the test `geometry matches the texture script`. It reads both files as text and extracts `RING_INNER`, `ARC_RADIUS` and the arc angles with patterns, then asserts that:
  - they are equal between the two files;
  - `RING_INNER == 0.90`;
  - the arc sector [235, 325] doesn't intersect [195, 235).
- [ ] Run it and watch it fail (constants still 0.86 and 200/340).
- [ ] Change the constants, regenerate the textures and run the suite. Expected: all pass.
- [ ] Commit: `fix: ring and year-arc inside the stock frame, clear of Weather's readout`.

### Task 2: Painted seasonal decorations and preview

**Files:** Modify `tools/make_textures.py`. Create `Media/decor_{spring,summer,autumn,winter}.tga` and `docs/images/seasons.png`.

**Interfaces:** Produces `Media/decor_<season>.tga`, 512×512 RGBA, in the same polar frame as `ring.tga` (centre of the texture = centre of the minimap).

- [ ] Add painting helpers to the script: an outlined shape with shading from a signed-distance function (fill + top-left light + a darker edge + a 3 px dark outline), and leaf, maple, blossom, wheat, sun, snow cap, icicle and snowflake shapes in the sectors from the spec table.
- [ ] Add a `decor_sectors` table in the script and assert (inside the script) that no shape's anchor angle falls in 195–235°, 30–60°, 82–98° or 165–195°.
- [ ] Write the preview `docs/images/seasons.png`: four rims (map disc, tinted ring, decor, arc), with the sibling orbs and readout bars drawn in.
- [ ] Look at the preview image and iterate until it reads as Warcraft-painted.
- [ ] Commit: `feat: painted seasonal decorations for the rim`.

### Task 3: Decor layer in the UI

**Files:** Modify `UI.lua` and `tests/ui_smoke.lua`.

- [ ] Add a smoke assertion: after login in January, `ImmerseMeSeasonsRim.decor._texture` ends with `decor_winter`. After switching the stubbed server time to 14 October and running `ZONE_CHANGED`, it ends with `decor_autumn`. (The stub's `SetTexture` records `_texture`.) Watch it fail.
- [ ] Add a `decor` texture (`OVERLAY`, 0) with `SetAllPoints(rim)` and, in `Draw`, `decor:SetTexture(ns.MEDIA .. "decor_" .. s.season)`, shown when `db.show`. Add `/ims decor on|off` (default on) and document it in the README.
- [ ] Run the suite. Expected: all pass. Deploy to the game folder.
- [ ] Commit: `feat: seasonal decoration layer on the rim`.
