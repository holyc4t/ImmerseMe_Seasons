# Customizing

The wording and colours live in [`Data.lua`](../Data.lua) and the dates in
[`Almanac.lua`](../Almanac.lua). Both are safe to edit; `/reload` in game afterwards.

> Seasons is shared because everyone runs the same data. If you change the dates or frost
> thresholds for yourself, your rim will differ from other players'. Send changes upstream as a
> pull request so everyone gets them. Wording and colours only change what you see.

Don't edit `Climate.lua`: it's a copy of ImmerseMe: Weather's temperature model, and the tests check it
still matches. To change a zone's climate, change it in Weather and copy the tables across.

## Season names, zone lines and flavour

`ns.SeasonNames[style][season][part]`, `ns.ZoneLines[style][season]` and `ns.Flavor[style][season]`
(a list; one line is picked per zone per day). Styles are `temperate`, `snowbound` and `hot`; which
climate uses which style is `ns.ClimateStyle`.

```lua
ns.Flavor.temperate.autumn = {
	"Apples are pressed for cider in every village.",
	"Geese pass overhead, heading south.",
}
```

## Rim colours

`ns.Tints[style][season]` as `{ r, g, b }` from 0 to 1. `ns.TINT_BLEND_DAYS` is how long each
season takes to blend in from the last one. `ns.ArcTints[style]` colours the season arc under the
minimap (gold for most lands, frost for snowy ones).

## Drift

`ns.DriftLanes` are the paths the flakes and leaves travel: `from` and `sweep` in degrees
(counter-clockwise from the right; a negative sweep falls down the right side), `r` the radius as a
fraction of the rim, `dur` seconds per pass, `delay` seconds before the first pass, `size` pixels.
`ns.DriftCount[style][season]` is how many lanes play (the first n), and `ns.DriftKind` which
sprite. Lanes must stay clear of the sibling addons' orbs, the N and Weather's readout:
`lua tests/run.lua` checks.

## Frost

```lua
ns.FROST_ON, ns.FROST_OFF, ns.FROST_ALLDAY = 1, 2, -4     -- Celsius
ns.MorningEnd = { winter = 11, spring = 9.5, summer = 9, autumn = 9.5 }
ns.FROST_LEAD = 2                                         -- hours before sunrise
```

## Festival dates

`Almanac.FESTIVALS` lists each festival with its start and length in days. Fixed dates use
`fixed(month, day)`; Noblegarden uses `A.Easter` and the Lunar Festival `A.LunarNewYear`. Set
`notch = false` to keep a festival in the tooltip but off the season arc.

```lua
{ key = "harvest", name = "Harvest Festival", notch = true, start = fixed(9, 13), days = 7 },
```

The dates are Blizzard's usual windows. If this year's in-game dates differ, adjust them here.

## Textures

Run `python tools/make_textures.py` (or `py -3` on Windows) to regenerate `Media/`. The ring geometry
constants at the top of the script must match the ones at the top of `UI.lua`. The paintings live in
`tools/decor.py`: `SEASONS` for most lands, `SNOWBOUND` for the alpine ones, `drift_atlas` for the
drifting sprites. New texture files need a full client restart.
