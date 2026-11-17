-- ImmerseMe: Seasons - Weather's temperature model.
-- Copied from ImmerseMe_Weather 1.0.0 (Data.lua, Core.lua). Do not edit here: re-copy from Weather
-- and keep tests/climate_spec.lua green. Only ns.ClimateFor and ns.OutdoorTemp at the bottom are
-- Seasons' own: they expose the outdoor-temperature path of Weather's ns.Simulate.
local _, ns = ...

----------------------------------------------------------------------- Weather Data.lua (copy)

-- What the game itself reports (C_Weather) -> our sky condition. Each kind is a
-- ladder of { intensity below this, condition }. When the game says the sky is
-- clear, any simulated rain / snow / dust falls back to the nearest dry sky.
ns.GameWeather = {
	rain      = { { 0.4, "drizzle" },  { 0.7, "rain" }, { 1e9, "storm" } },
	snow      = { { 0.4, "flurries" }, { 0.7, "snow" }, { 1e9, "blizzard" } },
	sandstorm = { { 1e9, "sandstorm" } },
}
-- Conditions the game would show as weather; never invented while the game reports a clear sky.
ns.Precipitation = { drizzle = true, rain = true, storm = true, flurries = true, snow = true,
                     blizzard = true, sandstorm = true }


local ICON = "Interface\\Icons\\"

-- Sky conditions. temp/hum/wind are modifiers applied on top of the zone climate.
-- windMul scales the zone's base wind, wind adds km/h on top.
ns.Conditions = {
	clear     = { day = "Clear skies",        night = "Clear and starlit",   temp = 1.5,  hum = -8,  windMul = 1.0, wind = 0,
	              flavor = { day = "Not a cloud troubles the sky.", night = "The stars burn cold and sharp overhead." } },
	fair      = { day = "Scattered clouds",   night = "Broken, moonlit cloud", temp = 0.5, hum = -3, windMul = 1.0, wind = 0,
	              flavor = { day = "Cloud shadows drift lazily across the land.", night = "Clouds slide across the face of the moon." } },
	overcast  = { day = "Overcast",           night = "Starless, heavy cloud", temp = -1, hum = 5,  windMul = 1.0, wind = 0, icon = "Spell_Frost_Wisp",
	              flavor = { day = "A grey lid of cloud presses down on the world.", night = "No star shows; the dark is close and total." } },
	mist      = { day = "Mist",               night = "Night mist",          temp = -1,   hum = 9,  windMul = 0.5, wind = 0, icon = "Spell_Magic_LesserInvisibilty",
	              flavor = { day = "Thin mist softens every outline.", night = "Mist coils low between the trees." } },
	fog       = { day = "Thick fog",          night = "Dense night fog",     temp = -1.5, hum = 14,  windMul = 0.3, wind = 0, icon = "Spell_Magic_LesserInvisibilty",
	              flavor = { day = "The fog swallows sound and distance alike.", night = "You can scarcely see your own hand before you." } },
	drizzle   = { day = "Drizzle",            night = "Night drizzle",       temp = -1.5, hum = 10,  windMul = 0.9, wind = 0, icon = "Spell_Nature_Tranquility",
	              flavor = { day = "A fine rain beads on cloak and steel.", night = "A fine cold rain whispers in the dark." } },
	rain      = { day = "Steady rain",        night = "Rain in the dark",    temp = -2.5, hum = 15,  windMul = 1.2, wind = 4, icon = "Spell_Nature_Tranquility",
	              flavor = { day = "Rain drums steadily; the roads turn to mud.", night = "Rain hammers down unseen in the blackness." } },
	storm     = { day = "Thunderstorm",       night = "Night thunderstorm",  temp = -3.5, hum = 17,  windMul = 1.5, wind = 22, icon = "Spell_Nature_CallStorm",
	              flavor = { day = "Thunder rolls across the land.", night = "Lightning tears the night open, again and again." } },
	flurries  = { day = "Snow flurries",      night = "Flurries in the dark", temp = -1.5, hum = 8,  windMul = 1.0, wind = 2, icon = "Spell_Frost_FrostBolt02",
	              flavor = { day = "Loose snowflakes wander down from a pale sky.", night = "Snowflakes drift silently out of the dark." } },
	snow      = { day = "Snowfall",           night = "Night snowfall",      temp = -3,   hum = 10,  windMul = 1.1, wind = 4, icon = "Spell_Frost_FrostNova",
	              flavor = { day = "Snow falls thick and steady, muffling the world.", night = "Snow buries your tracks almost as you make them." } },
	blizzard  = { day = "Blizzard",           night = "Night blizzard",      temp = -6,   hum = 12,  windMul = 1.6, wind = 35, icon = "Spell_Frost_IceStorm",
	              flavor = { day = "The wind screams; snow flies sideways.", night = "A white, howling dark. No night to be abroad." } },
	haze      = { day = "Heat haze",          night = "Dry, dusty air",      temp = 2,    hum = -4,  windMul = 0.8, wind = 0, icon = "Spell_Holy_SearingLight",
	              flavor = { day = "The horizon shimmers and swims in the heat.", night = "The baked earth gives its heat back to the night." } },
	sandstorm = { day = "Dust storm",         night = "Night dust storm",    temp = 1,    hum = -6,  windMul = 1.6, wind = 40, icon = "Spell_Nature_Cyclone",
	              flavor = { day = "Grit stings every inch of bare skin.", night = "Sand hisses against everything in the dark." } },
	ashfall   = { day = "Ashfall",            night = "Glowing ashfall",     temp = 3,    hum = -5,  windMul = 1.0, wind = 3, icon = "Spell_Fire_Immolation",
	              flavor = { day = "Grey ash sifts down; the air tastes of cinders.", night = "Embers ride the wind like slow red stars." } },
	miasma    = { day = "Plague miasma",      night = "Rank night miasma",   temp = 0,    hum = 12,  windMul = 0.5, wind = 0, icon = "Spell_Shadow_PlagueCloud",
	              flavor = { day = "A sickly haze hangs in the air. Breathe shallow.", night = "The dark itself smells of rot." } },
	indoors   = { day = "Under stone",        night = "Under stone",         temp = 0,    hum = 0,   windMul = 0,   wind = 0, icon = "INV_Misc_Lantern_01",
	              flavor = { day = "No sky here; only stone and lamplight.", night = "No sky here; only stone and lamplight." } },
}
for _, c in pairs(ns.Conditions) do
	if c.icon then c.icon = ICON .. c.icon end
end

-- Climates.
--   temp   = yearly mean (Celsius)      swing = day/night range
--   season = summer/winter amplitude    hum   = mean relative humidity (%)
--   wind   = mean wind (km/h)           dir   = prevailing wind bearing (degrees, where it blows FROM)
--   sky    = ladder from fairest to foulest weather, with relative weights
ns.Climates = {
	temperate = { temp = 14, swing = 9,  season = 8, hum = 62, wind = 12, dir = 250,
	              sky = { {"clear",3}, {"fair",3}, {"overcast",2}, {"drizzle",1}, {"rain",1.2}, {"storm",0.5} } },
	gloom     = { temp = 8,  swing = 5,  season = 5, hum = 80, wind = 6,  dir = 200,
	              sky = { {"overcast",1.5}, {"mist",3}, {"fog",2.5}, {"drizzle",1.5}, {"rain",1} } },
	undead    = { temp = 7,  swing = 6,  season = 7, hum = 80, wind = 10, dir = 300,
	              sky = { {"fair",0.5}, {"overcast",3}, {"mist",2}, {"drizzle",1.5}, {"rain",1.5}, {"storm",0.4} } },
	alpine    = { temp = -6, swing = 7,  season = 8, hum = 70, wind = 18, dir = 340,
	              sky = { {"clear",2}, {"fair",2}, {"overcast",2}, {"flurries",2}, {"snow",2}, {"blizzard",0.8} } },
	highland  = { temp = 10, swing = 10, season = 9, hum = 58, wind = 18, dir = 280,
	              sky = { {"clear",2.5}, {"fair",3}, {"overcast",2}, {"drizzle",1}, {"rain",1.2}, {"storm",0.5} } },
	coast     = { temp = 16, swing = 8,  season = 6, hum = 68, wind = 24, dir = 260,
	              sky = { {"clear",3}, {"fair",3}, {"overcast",1.5}, {"rain",1}, {"storm",0.6} } },
	plains    = { temp = 17, swing = 12, season = 9, hum = 48, wind = 22, dir = 230,
	              sky = { {"clear",3}, {"fair",3}, {"overcast",1.5}, {"rain",1}, {"storm",0.7} } },
	arid      = { temp = 27, swing = 16, season = 6, hum = 22, wind = 14, dir = 90,
	              sky = { {"clear",5}, {"fair",2}, {"haze",2}, {"sandstorm",0.6}, {"storm",0.2} } },
	desert    = { temp = 33, swing = 20, season = 5, hum = 10, wind = 16, dir = 110,
	              sky = { {"clear",5}, {"haze",3}, {"sandstorm",1.2} } },
	jungle    = { temp = 28, swing = 6,  season = 2, hum = 82, wind = 6,  dir = 150,
	              sky = { {"fair",2}, {"overcast",2}, {"mist",1.5}, {"rain",3}, {"storm",1.5} } },
	swamp     = { temp = 19, swing = 6,  season = 5, hum = 84, wind = 7,  dir = 170,
	              sky = { {"fair",1}, {"overcast",2}, {"mist",2.5}, {"fog",1.5}, {"drizzle",2}, {"rain",2}, {"storm",0.5} } },
	elven     = { temp = 12, swing = 6,  season = 5, hum = 74, wind = 8,  dir = 290,
	              sky = { {"clear",2}, {"fair",2.5}, {"mist",2}, {"overcast",1.5}, {"drizzle",1}, {"rain",1} } },
	volcanic  = { temp = 38, swing = 6,  season = 2, hum = 12, wind = 14, dir = 60,
	              sky = { {"haze",3}, {"overcast",1}, {"ashfall",4} } },
	blight    = { temp = 9,  swing = 6,  season = 7, hum = 72, wind = 9,  dir = 320,
	              sky = { {"overcast",3}, {"mist",1}, {"miasma",4}, {"drizzle",1.5} } },
	wastes    = { temp = 24, swing = 12, season = 4, hum = 20, wind = 20, dir = 130,
	              sky = { {"haze",3}, {"overcast",3}, {"sandstorm",1}, {"storm",1} } },
	-- enclosed places: no sky, no wind
	forge       = { temp = 24, swing = 1, season = 1, hum = 35, wind = 0, indoor = true },
	crypt       = { temp = 9,  swing = 1, season = 1, hum = 85, wind = 0, indoor = true },
	underground = { temp = 12, swing = 1, season = 2, hum = 70, wind = 0, indoor = true },
}

ns.DEFAULT_CLIMATE  = "temperate"
ns.INSTANCE_CLIMATE = "underground"

-- Zone -> climate (English zone names). Zones not listed here get the default
-- climate with a small per-zone offset, so they still feel distinct.
ns.Zones = {
	-- Eastern Kingdoms
	["Elwynn Forest"] = "temperate", ["Stormwind City"] = "temperate", ["Redridge Mountains"] = "highland",
	["Westfall"] = "coast", ["Duskwood"] = "gloom", ["Deadwind Pass"] = "wastes",
	["Stranglethorn Vale"] = "jungle", ["Swamp of Sorrows"] = "swamp", ["Blasted Lands"] = "wastes",
	["Burning Steppes"] = "volcanic", ["Searing Gorge"] = "volcanic", ["Badlands"] = "arid",
	["Dun Morogh"] = "alpine", ["Ironforge"] = "forge", ["Loch Modan"] = "highland", ["Wetlands"] = "swamp",
	["Arathi Highlands"] = "highland", ["Hillsbrad Foothills"] = "highland", ["Alterac Mountains"] = "alpine",
	["The Hinterlands"] = "highland", ["Silverpine Forest"] = "undead", ["Tirisfal Glades"] = "undead",
	["Undercity"] = "crypt", ["Western Plaguelands"] = "blight", ["Eastern Plaguelands"] = "blight",
	-- Kalimdor
	["Durotar"] = "arid", ["Orgrimmar"] = "arid", ["The Barrens"] = "arid", ["Mulgore"] = "plains",
	["Thunder Bluff"] = "plains", ["Teldrassil"] = "elven", ["Darnassus"] = "elven", ["Darkshore"] = "elven",
	["Ashenvale"] = "elven", ["Moonglade"] = "elven", ["Stonetalon Mountains"] = "highland",
	["Desolace"] = "wastes", ["Feralas"] = "jungle", ["Dustwallow Marsh"] = "swamp",
	["Thousand Needles"] = "arid", ["Tanaris"] = "desert", ["Un'Goro Crater"] = "jungle",
	["Silithus"] = "desert", ["Felwood"] = "blight", ["Azshara"] = "coast", ["Winterspring"] = "alpine",
}

----------------------------------------------------------------------- Weather Core.lua (copy)
local floor, sin, cos, pi, max, min = math.floor, math.sin, math.cos, math.pi, math.max, math.min

local function clamp(v, lo, hi) return max(lo, min(hi, v)) end

-- Deterministic pseudo-random number in [0,1) from a string key and an integer.
local M = 2147483647
local function hash01(key, n)
	local h = 5381
	for i = 1, #key do h = (h * 33 + key:byte(i)) % M end
	h = (h + n * 2654435) % M
	h = (h * 48271) % M
	local x = sin((h % 1000003) * 0.6180339 + 0.1) * 43758.5453
	return x - floor(x)
end

-- Smoothly varying noise in [0,1): one new random value per unit of x.
local function smooth(key, x)
	local i = floor(x)
	local f = x - i
	f = f * f * (3 - 2 * f)
	local a, b = hash01(key, i), hash01(key, i + 1)
	return a + (b - a) * f
end

ns.Phases = {
	{ 0,    "Dead of Night" },
	{ 4,    "Before Dawn" },
	{ 5.5,  "Dawn",    twilight = true },
	{ 7,    "Morning" },
	{ 11,   "Midday" },
	{ 14,   "Afternoon" },
	{ 18,   "Evening" },
	{ 19.5, "Dusk",    twilight = true },
	{ 21,   "Night" },
}

function ns.GetPhase(hour)
	local phase = ns.Phases[1]
	for _, p in ipairs(ns.Phases) do
		if hour >= p[1] then phase = p end
	end
	return phase[2], (hour < 5.5 or hour >= 21), phase.twilight or false
end

local function climateFor(zone, inInstance)
	if inInstance then return ns.Climates[ns.INSTANCE_CLIMATE] end
	return ns.Climates[ns.Zones[zone] or ns.DEFAULT_CLIMATE] or ns.Climates[ns.DEFAULT_CLIMATE]
end

-- 0 = fairest weather the zone gets, 1 = foulest. Drifts slowly over hours.
local function wetness(zone, t)
	local w = 0.8 * smooth(zone .. ":w", t / 21600) + 0.2 * smooth(zone .. ":w2", t / 5400)
	return clamp(0.5 + (w - 0.5) * 1.6, 0, 0.9999)
end

local function pickCondition(climate, wet)
	local total = 0
	for _, s in ipairs(climate.sky) do total = total + s[2] end
	local acc = 0
	for _, s in ipairs(climate.sky) do
		acc = acc + s[2] / total
		if wet < acc then return s[1] end
	end
	return climate.sky[#climate.sky][1]
end

local FREEZE = { drizzle = "flurries", rain = "snow", storm = "blizzard" }
local THAW   = { flurries = "drizzle", snow = "rain", blizzard = "storm" }

-- Bends the simulated sky to what the game is really doing.
-- real = { kind = "clear" | "rain" | "snow" | "sandstorm", intensity = number }
local function observed(climate, key, real)
	local ladder = ns.GameWeather[real.kind]
	if ladder then
		for _, step in ipairs(ladder) do
			if real.intensity < step[1] then return step[2] end
		end
		return ladder[#ladder][2]
	end
	if real.kind ~= "clear" or not ns.Precipitation[key] then return key end
	-- the game shows a dry sky: step down the zone's ladder to its nearest dry condition
	local dry = "overcast"
	for _, s in ipairs(climate.sky) do
		if s[1] == key then break end
		if not ns.Precipitation[s[1]] then dry = s[1] end
	end
	return dry
end

----------------------------------------------------------------------- Seasons' own
-- Climate key for a zone (Weather's climateFor, which is local there).
function ns.ClimateFor(zone, inInstance)
	if inInstance then return ns.INSTANCE_CLIMATE, ns.Climates[ns.INSTANCE_CLIMATE] end
	local key = ns.Zones[zone] or ns.DEFAULT_CLIMATE
	if not ns.Climates[key] then key = ns.DEFAULT_CLIMATE end
	return key, ns.Climates[key]
end

-- The temperature outside: Weather's ns.Simulate up to its `outside` value (before any roof,
-- hearth or fire). opts.instance and opts.weather count; opts.sheltered / heated / heat don't.
-- Mirrors Weather's Core.lua lines 112-143; keep the two in step.
function ns.OutdoorTemp(zone, t, hour, opts)
	opts = opts or {}
	zone = (zone and zone ~= "") and zone or "Unknown"
	local climate = climateFor(zone, opts.instance)
	local _, isNight = ns.GetPhase(hour)
	local d = date("*t", t)
	local yearPos = ((d.month - 1) + (d.day - 1) / 30) / 12

	local quirkT = (hash01(zone .. ":qt", 0) - 0.5) * 4

	local seasonal = -cos((yearPos - 0.04) * 2 * pi) * climate.season
	local diurnal  = cos((hour - 15) / 24 * 2 * pi) * climate.swing / 2
	local drift    = (smooth(zone .. ":t", t / 21600) - 0.5) * 6
	local temp     = climate.temp + quirkT + seasonal + diurnal + drift

	local wet = wetness(zone, t)
	local key = climate.indoor and "indoors" or pickCondition(climate, wet)
	if temp < -1 and FREEZE[key] then key = FREEZE[key] end
	if temp > 3 and THAW[key] then key = THAW[key] end
	local real = not climate.indoor and opts.weather or nil
	if real then key = observed(climate, key, real) end
	local cond = ns.Conditions[key]

	local condTemp = cond.temp
	if isNight and (key == "clear" or key == "haze") then condTemp = -condTemp end
	temp = temp + condTemp
	if real and real.kind == "snow" then temp = min(temp, 0) end
	if real and real.kind == "rain" then temp = max(temp, 1) end
	return temp
end
