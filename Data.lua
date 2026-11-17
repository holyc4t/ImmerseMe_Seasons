-- ImmerseMe: Seasons - wording, colours and thresholds. Everything in here is safe to tweak.
local ADDON, ns = ...

ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- How each of Weather's climates (copied in Climate.lua) talks about the year:
-- "hot" lands get a cool season instead of a winter, "snowbound" ones a long winter.
ns.ClimateStyle = {
	temperate = "temperate", gloom = "temperate", undead = "temperate", highland = "temperate",
	coast = "temperate", plains = "temperate", swamp = "temperate", elven = "temperate",
	blight = "temperate",
	alpine = "snowbound",
	arid = "hot", desert = "hot", jungle = "hot", volcanic = "hot", wastes = "hot",
	forge = "temperate", crypt = "temperate", underground = "temperate",
}

-- Frost. On below FROST_ON (Celsius), off again only above FROST_OFF, so it never flickers
-- around one number. Below FROST_ALLDAY it lasts all day.
ns.FROST_ON, ns.FROST_OFF, ns.FROST_ALLDAY = 1, 2, -4
-- Frost forms from two hours before sunrise and lifts by this hour, by season.
ns.MorningEnd = { winter = 11, spring = 9.5, summer = 9, autumn = 9.5 }
ns.FROST_LEAD = 2           -- hours before sunrise the morning window opens

-- The year is a label, not a timeline.
ns.YEAR_LABEL = "Year 25 after the Dark Portal"

-- Season names by style, season and part of the season.
ns.SeasonNames = {
	temperate = {
		spring = { early = "Early Spring", mid = "Spring",      late = "Late Spring" },
		summer = { early = "Early Summer", mid = "High Summer", late = "Late Summer" },
		autumn = { early = "Early Autumn", mid = "Autumn",      late = "Late Autumn, the turning of the leaves" },
		winter = { early = "Early Winter", mid = "Deep Winter", late = "Late Winter, first thaw" },
	},
	snowbound = {
		spring = { early = "The Long Winter's End", mid = "The Brief Thaw",  late = "The Short Spring" },
		summer = { early = "The Short Summer",      mid = "Midsummer Light", late = "The Summer's Ebb" },
		autumn = { early = "The First Snows",       mid = "Autumn Snows",    late = "The Closing Passes" },
		winter = { early = "The Long Winter",       mid = "Deep Winter",     late = "The Long Winter" },
	},
	hot = {
		spring = { early = "The Warming Season", mid = "The Warming Season", late = "The Hot Season Nears" },
		summer = { early = "The Hot Season",     mid = "The Height of Heat", late = "The Hot Season" },
		autumn = { early = "The Cooling Season", mid = "The Cooling Season", late = "The Cool Season Nears" },
		winter = { early = "The Cool Season",    mid = "The Cool Season",    late = "The Cool Season" },
	},
}

-- One line about the land in this season.
ns.ZoneLines = {
	temperate = {
		spring = "Fields are green and the lambs are out.",
		summer = "The days are long and the roads are dusty.",
		autumn = "Leaves turn and the harvest comes in.",
		winter = "The fields lie bare under a low sun.",
	},
	snowbound = {
		spring = "Meltwater runs loud in every gully.",
		summer = "Snow still lies on the high peaks.",
		autumn = "The first snows creep down the slopes.",
		winter = "Snow lies deep in the passes.",
	},
	hot = {
		spring = "The heat builds a little more each day.",
		summer = "The sun is merciless at midday.",
		autumn = "The worst of the heat has broken.",
		winter = "The nights are cold; the days are kind.",
	},
}

-- Flavour lines. One is picked per zone per day, so it stays put all day.
ns.Flavor = {
	temperate = {
		spring = { "Farmers walk the furrows, sowing by hand.", "Blossom drifts across the road." },
		summer = { "Haymakers rest in the shade at noon.", "Swallows skim the millpond." },
		autumn = { "Apples are pressed for cider in every village.", "Woodsmoke hangs over the farms at dusk." },
		winter = { "Folk stay close to the hearth and the ale.", "Breath steams in the cold air." },
	},
	snowbound = {
		spring = { "The roads reopen and the first caravans come through." },
		summer = { "Herders drive the rams up to the high pastures." },
		autumn = { "Larders are stocked against the long dark." },
		winter = { "The dwarves bank the forge fires and tell long stories.", "Snow muffles every sound." },
	},
	hot = {
		spring = { "Travellers start moving in the cool of the morning." },
		summer = { "No one with sense walks the dunes at noon." },
		autumn = { "Caravans set out again now the heat has eased." },
		winter = { "Cold nights bring the traders in to the fires." },
	},
}

-- Rim colours, deep and warm like the stock bronze-gold frame. Blended over the first
-- TINT_BLEND_DAYS of each season from the last one.
ns.Tints = {
	temperate = {
		spring = { 0.42, 0.60, 0.22 }, summer = { 0.96, 0.72, 0.22 },
		autumn = { 0.80, 0.36, 0.12 }, winter = { 0.50, 0.68, 0.92 },
	},
	snowbound = {
		spring = { 0.50, 0.68, 0.58 }, summer = { 0.68, 0.70, 0.50 },
		autumn = { 0.56, 0.66, 0.80 }, winter = { 0.66, 0.84, 1.00 },
	},
	hot = {
		spring = { 0.82, 0.66, 0.30 }, summer = { 0.96, 0.62, 0.18 },
		autumn = { 0.80, 0.48, 0.20 }, winter = { 0.70, 0.56, 0.36 },
	},
}
ns.TINT_BLEND_DAYS = 14

-- The season arc under the minimap, by land: warm gold, or frost in snowy lands.
ns.ArcTints = {
	temperate = { 1, 0.80, 0.36 },
	snowbound = { 0.80, 0.92, 1.00 },
	hot       = { 1, 0.80, 0.36 },
}

-- Drift: small flakes, leaves or petals travelling slowly along the rim. The game engine moves
-- them (a looping rotation around the minimap's centre), so they cost no Lua while they play.
-- from/sweep: degrees counter-clockwise from the right (negative sweep = clockwise, falling down
-- the right side). No lane may cross Weather's orb (30-60), the N (82-98), Geography's orb
-- (165-195), Weather's readout (195-235) or the zoom buttons (298-334): tests/drift_spec.lua checks.
-- r: radius as a fraction of the rim's half size; dur: seconds per pass; size: pixels.
-- A season with n drifting uses the first n lanes.
ns.DriftLanes = {
	{ from = 24,  sweep = -36, r = 0.95, dur = 11, delay = 0, size = 12 },
	{ from = 104, sweep = 50,  r = 0.96, dur = 13, delay = 4, size = 11 },
	{ from = 14,  sweep = -36, r = 0.93, dur = 17, delay = 6, size = 10 },
	{ from = 6,   sweep = -30, r = 0.97, dur = 19, delay = 2, size = 13 },
	{ from = 115, sweep = 42,  r = 0.93, dur = 23, delay = 9, size = 10 },
	{ from = 99,  sweep = 62,  r = 0.95, dur = 29, delay = 5, size = 12 },
}
ns.DriftCount = {
	temperate = { spring = 4, summer = 0, autumn = 5, winter = 5 },
	snowbound = { spring = 2, summer = 0, autumn = 5, winter = 6 },
	hot       = { spring = 0, summer = 0, autumn = 0, winter = 0 },
}
ns.DriftKind = {
	temperate = { spring = "petal", autumn = "leaf", winter = "flake" },
	snowbound = { spring = "flake", autumn = "flake", winter = "flake" },
	hot       = {},
}
ns.DRIFT_CELLS = { flake = 1, leaf = 2, petal = 3 }   -- cells of Media/drift.tga (2x2, row by row)
ns.LEAF_COLORS = { { 1, 0.55, 0.15 }, { 0.90, 0.22, 0.10 }, { 1, 0.80, 0.25 } }

ns.MarkerNames = {
	midwinter      = "The longest night of the year is close.",
	midsummer      = "The longest day of the year is close.",
	spring_equinox = "Day and night stand equal: the year turns to spring.",
	autumn_equinox = "Day and night stand equal: the year turns to autumn.",
}

ns.MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August",
              "September", "October", "November", "December" }

-- Tooltip colours.
ns.COLORS = {
	header = { 1, 0.82, 0 }, grey = { 0.6, 0.6, 0.6 }, white = { 1, 1, 1 },
	frost = { 0.6, 0.85, 1 }, green = { 0.5, 0.85, 0.5 }, flavor = { 0.7, 0.7, 0.6 },
}
