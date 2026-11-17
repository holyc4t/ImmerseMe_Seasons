# ImmerseMe: Seasons — design

Date: 2026-11-16 · Author: holyc4t · Status: draft for approval

## Intent

The third addon in the ImmerseMe family for WoW: Forever (interface 16001). Weather is the sky,
Geography is the land; **Seasons is the year**. The goal is that the world feels real: not just a
clock, but a year turning around you. Shorter days, frost on cold mornings, festivals coming up, snow
lying deep in winter.

The game itself can't do any of this: day length, lighting and weather are fixed by the client and
server. Seasons tells you about them. It never pretends to change the world.

## Goals

- **The minimap rim shows the season.** No new icon. The minimap's own border takes a seasonal tint,
  frosts over on cold mornings, and a faint year-arc on its lower edge shows where in the year you are
  and which festivals are coming.
- **A rich hover tooltip** on the rim holds the detail: date in seasonal words, frost note, sunrise and
  sunset, which way the days are going, upcoming festivals, a flavour line.
- **Earth calendar, one Azerothian year per real year**, so it agrees with Weather (which already uses
  the real month for temperature and the real moon), with Blizzard's holidays, and with every other
  player running the addon.
- **Frost agrees with Weather.** Seasons carries its own copy of Weather's temperature maths, so frost
  appears exactly when Weather (if installed) would read near or below freezing.
- **Standalone.** Works with no other ImmerseMe addon installed, and installing it changes nothing in
  Weather or Geography.

## Non-goals

- Changing game lighting, real weather, or anything server-side.
- Reading Blizzard's live in-game calendar, per-server events, or the southern hemisphere.
- Following the lore timeline. The year is a fixed label.
- Any change to Weather or Geography in this work. (The almanac is written so they *could* copy it
  later as their own separate upgrade.)
- Network sync between players. Agreement comes from deterministic maths.
- Localisation beyond English in v1 (follows Weather: English zone names).

## Anti-goals (failure even if it "works")

- A numbers or text panel on screen. The rim is felt, not read.
- Seasons and Weather disagreeing (a frosted rim while Weather reads 6°C).
- "Winter" in Tanaris. Seasonal wording must fit the zone.
- Flicker: frost or season state that changes on `/reload` or between update ticks.
- Getting in the way of the minimap: blocking clicks, pings, tracking or other addons' minimap buttons.
- Impact on another addon just because Seasons is installed.

## Approaches considered

How the seasonal knowledge is shared across the family:

| | Approach | Trade-off |
|---|---|---|
| **1** | **Shared almanac file copied into each addon that needs it** | **Picked.** Every addon stays standalone and they agree because the maths is identical. Cost: keeping copies in sync, guarded by a parity test |
| 2 | Seasons is the source; Weather/Geography query it when installed | Simpler code, but siblings behave differently with and without Seasons (two modes to test), and installing Seasons would change them |
| 3 | Put seasonal effects inside Weather; Seasons is only a calendar | Least work, but Seasons becomes thin and "short days" isn't Seasons at all |

Chosen by the user: **1**, with the further rule that in this work only Seasons is built (nothing in
Weather/Geography changes).

Placement on screen (from mockups):

| | Option | Trade-off |
|---|---|---|
| A | Third gold-ringed orb, bottom-right | Matches siblings; one more icon on screen |
| **B** | **The minimap rim itself: seasonal tint, frost layer, year-arc** | **Picked.** Most subtle and most "felt"; needs care with skinned/square minimaps |
| C | A date line under the zone name | Easiest to read, but it's text on screen, which the family avoids |

Calendar naming: **real month names with seasonal flavour** (picked) vs invented Azerothian months
(more immersive but fan-made lore and needs translating). Year: **fixed "Year 25 after the Dark
Portal"** (picked) vs a year that ticks each 1 January (would drift past Classic's setting).

Frost model: **copy Weather's temperature maths** (picked) vs a simple three-group table of Seasons'
own (would sometimes disagree with Weather's thermometer).

## What it shows

### The rim (always on)

1. **Season tint.** The minimap border colour follows the season: fresh green in spring, warm gold in
   summer, russet in autumn, grey-blue in winter. Tints blend gradually across the boundary weeks rather
   than snapping on the equinox. In hot zones (Weather's `arid`, `desert`, `jungle`, `volcanic`,
   `wastes` climates) winter is a muted dry tone, not icy blue.
2. **Frost layer.** A silvered rim with a few rime sparkles, drawn on top of the tint when frost is on
   (see Frost). It fades in and out over a few minutes of game time, never pops.
3. **Year-arc.** A faint arc along the lower rim representing the whole year: 1 January at its left
   end, 31 December at its right. A bright dot marks today. Small gold notches mark the start of each
   in-game festival (see Festivals). "A festival is coming" reads as the dot approaching a notch.
   A notch whose festival is running now glows softly.

Mockups: `.superpowers/brainstorm/1047-1794858350/content/rim-seasons.html` (four seasons + frost) and
`placement.html` (option B and the tooltip).

### The tooltip (hover the rim)

```
Deep Winter                                   <- season name, zone-aware
14 January · Year 25 after the Dark Portal    <- grey
Hoarfrost on the ground; it will lift by midmorning.   <- frost line, only when frost is on/expected
Snow lies deep in the passes.                 <- seasonal zone line (snowbound zones in winter etc.)
Sunrise 08:02 · Sunset 16:05
Days are lengthening, two minutes a day.      <- grey
Lunar Festival begins in 9 days               <- green; "is on now" when running
Love is in the Air in 3 weeks                 <- grey
Darkmoon Faire ... / The longest day ...      <- tooltip-only markers, when within ~2 weeks
"The dwarves bank the forge fires ..."        <- flavour, italic grey
```

Styling follows Weather/Geography: Blizzard gold header, grey label / white value lines.

## The calendar

- **Date** is the real date. Read time the same way Weather does (`GetServerTime()` and `date("*t", t)`),
  so both addons always land on the same day.
- **Seasons**: northern hemisphere astronomical seasons. Spring from ~20 March, summer ~21 June, autumn
  ~22 September, winter ~21 December. Fixed day-of-year boundaries are fine. Each season splits into
  early / mid / late, with flavour names (e.g. *first thaw*, *high summer*, *the turning of the leaves*,
  *deep winter*).
- **Zone-aware wording**: hot climates get softened names (*the cool season*, *the hot season*);
  snowbound zones may say *the long winter*. Data table, safe to tweak.
- **Year**: always the fixed label "Year 25 after the Dark Portal".
- **Sunrise/sunset**: standard solar declination formula for a fixed latitude of about 51.5°N, in
  local mean time with solar noon at 12:00 and no daylight saving. That gives ~08:00/16:00 in late
  December and ~03:45/20:15 in late June. Flavour only: game lighting does not follow it. Tooltip also
  says whether days are lengthening or shortening and by roughly how many minutes a day, plus the
  solstice and equinox names when they're close.

## Festivals

Notches on the rim only for holidays that really happen in the game, so a notch always means
something you can attend:

| Festival | Rule (Blizzard's usual window; verify against current Classic Era dates) |
|---|---|
| Lunar Festival | Starts on the lunar new year: second new moon after the winter solstice, from the same mean-lunar formula Weather uses for moon phases. Runs ~2 weeks |
| Love is in the Air | ~7–20 February |
| Noblegarden | The week of Easter Sunday (computed from the Easter algorithm) |
| Children's Week | ~1–7 May |
| Midsummer Fire Festival | ~21 June – 5 July |
| Harvest Festival | ~13–19 September |
| Hallow's End | ~18 October – 1 November |
| Feast of Winter Veil | ~15 December – 2 January (wraps the year: notch at 15 Dec, glow continues into January) |

Tooltip-only markers (no notch): the **Darkmoon Faire** (monthly; current Classic Era schedule to be
confirmed by the builder), and the **solstices and equinoxes** ("the longest day", "the year's turning").

All dates live in `Data.lua` as a table, safe to tweak.

## Frost

**Rule:** frost is on when the outdoor temperature from the copied Weather model is below about 1°C
during the morning window (from before dawn until midmorning: roughly 10:00, later in deep winter and
earlier in spring and autumn). On the coldest days (below about −4°C at midmorning) it stays all day.

That one rule produces the groups we discussed, from Weather's climates rather than a separate table:

- **Snowbound** (`alpine`: Dun Morogh, Winterspring, Alterac Mountains): rime most mornings all year;
  coldest winter days frosted all day.
- **Cold winters** (`temperate`, `highland`, `plains`, `elven`, `undead`, `blight`, `gloom`, `coast`,
  `swamp`): frost on many winter mornings, sometimes late autumn and early spring.
- **Never** (`desert`, `arid`, `jungle`, `volcanic`, `wastes`): the maths never gets there.

The builder should confirm these behaviours with a test sweep. **Agreement with Weather wins over the
groups** *(design call)*: the threshold stays "near or below freezing" (about 1°C). If that means
Snowbound zones are frost-free on some warm summer mornings, that is accepted, and the group
descriptions are adjusted to match. The user's explicit reason for copying Weather's maths was "so they
agree".

**Live, not once per morning** *(design call)*: frost follows the current outdoor temperature from the
copied model, including live game weather exactly as Weather uses it. No flicker comes from this,
because the model is deterministic (the same moment always gives the same answer, before or after a
`/reload`), plus two guards:
- **Hysteresis:** frost turns on below about 1°C and only turns off above about 2°C.
- **Fade:** it fades in and out over a few minutes rather than switching.

The time words in the tooltip ("it will lift by midmorning", "frost expected tomorrow morning") are a
forecast from the plain model with no live weather, worked out like Weather's `Outlook`.

**Indoors, instances, cities under stone** (Weather's indoor climates `forge`, `crypt`, `underground`,
and `IsInInstance()`): no frost; the rim shows the season tint only.

**Which zone drives season wording and tint** *(design call)*: always the **last outdoor zone**. Inside
Zul'Farrak you still get Tanaris's "cool season" and dry tint, not the `underground` climate's icy
winter. Seasons copies the pure part of Weather's zone resolution, which lives in Weather's `UI.lua`
(`CurrentZone` / remembering the last zone), into its own Core.

**Under a roof** (an inn or a barn in an outdoor zone) *(design call)*: frost still shows, because frost
is about outside. This matches Weather's tooltip, which shows an "Outside" temperature line while you
are sheltered. In instances and indoor-climate cities it doesn't show, as above.

**Live game weather:** Weather bends its sky and temperature to what the client reports
(`C_Weather.GetCurrentWeather` → `opts.weather`), e.g. real snow caps temperature at 0°C. Seasons reads
the same input the same way, so its copy gives the same temperature.

## The copy of Weather's maths

- A file in Seasons (e.g. `Climate.lua`) holds a **verbatim copy** of what's needed from Weather:
  `ns.Climates`, `ns.Zones`, `DEFAULT_CLIMATE`/`INSTANCE_CLIMATE`, `ns.Conditions` (the `temp` field at
  least), the hash/smooth noise, `wetness`, `pickCondition`, FREEZE/THAW, `observed`, and the outdoor
  temperature path of `ns.Simulate` (no shelter/hearth/heat-source adjustments: frost is outside).
- Header comment states the source: `ImmerseMe_Weather` version and file, and "do not edit here; re-copy
  from Weather".
- **Parity test**: when `../ImmerseMe_Weather` exists next to it in the workspace, the test loads both and
  checks that Seasons' outdoor temperature equals Weather's `outside` for a sweep of zones × dates ×
  hours (with and without a reported game weather). Skipped with a notice when Weather isn't present.

## Commands and settings

`/ims` or `/seasons`:

| Command | What it does |
|---|---|
| `/ims` | Describe the season, date, sun and next festival in chat |
| `/ims emote` | Share the season and the morning as an emote (like `/imw emote`) |
| `/ims show` / `/ims hide` | Turn the rim effects on or off |
| `/ims arc on\|off` | Show or hide the year-arc |
| `/ims frost on\|off` | Show or hide the frost layer |
| `/ims time realm\|local` | Which clock drives morning/evening (default realm, like Weather) |

Saved variables: `ImmerseMeSeasonsDB`.

## Constraints

- WoW Forever, interface 16001, Lua 5.1, classic-era API (see `types/WoWForever.lua` for stubs).
- File layout: `Data.lua` → `Almanac.lua` → `Climate.lua` (copy) → `Core.lua` (pure, testable) →
  `UI.lua`.
- **`Almanac.lua` stands alone and is ready to copy** *(design call)*. It holds all the calendar maths:
  - date → season, early/mid/late part of the season;
  - sunrise and sunset, day-length trend;
  - Easter, lunar new year (with its own copy of the mean-lunar constant);
  - festival windows from a table.

  It carries its own festival and season data table and has no dependency on Seasons' names, frames
  or saved settings. It has a header noting it may be copied verbatim into other ImmerseMe addons, and
  its own tests. Seasons-specific wording such as zone-aware season names and flavour stays in `Data.lua`. Tests runnable with `lua tests/run.lua`, same output format; add a "Test: Seasons" task to
  `.vscode/tasks.json`.
- Rim drawing must not take mouse input from the minimap. The hover target is a ring-shaped area on the
  border only, and must leave minimap clicks, pings, zoom and buttons working.
- Must restore the minimap border exactly when hidden or disabled.
- **Skinned/square minimaps**: if the stock round border isn't there (another addon hid or replaced
  it), draw Seasons' own thin ring around the minimap instead.
- The year-arc stays on the lower rim, clear of Weather's readout and Geography's orb at their default
  positions. Offsets configurable.
- Textures are generated TGA files from a Python script in `tools/`, like the siblings.
- Cheap: rim state only needs recomputing every minute or on zone change, not per frame (except
  fades).

## Stage 2 (later, separate spec): seasonal dressing

Recorded here so the core is built with it in mind; **not part of this build**.

Seasonal touches spread beyond the minimap: in winter a thin line of snow settled on the top edges of
the action bars, chat frame and unit frames; frost creeping in from the screen corners on bitter
mornings; a few leaves drifting past the chat in autumn. Constraints already agreed:

- **Off by default**, each surface switched on individually (bars, chat, unit frames, screen edges).
- Only adds Seasons' own textures over frames; never modifies Blizzard's secure frames; safe in combat.
- Must cope with UI replacements (ElvUI, Bartender) that move or hide those frames.
- Driven by the same season/frost state as the rim, so it adds no new logic, only drawing.

## Repo and workspace

`ImmerseMe_Seasons/` will be its own git repo like its siblings. This spec lives in the workspace's
`docs/superpowers/specs/` until that repo exists, then moves to `ImmerseMe_Seasons/docs/superpowers/`.

## Left to the builder

- Exact tint colours, blend curves, frost texture and sparkle placement (match the mockups' spirit).
- How the border is tinted: recolouring the stock border texture vs an overlay ring, as long as it
  restores cleanly.
- Exact festival dates after checking current Classic Era behaviour; the Darkmoon Faire schedule.
- Flavour text and seasonal zone lines (data tables).
- Exact frost thresholds and morning-window times after the test sweep.
