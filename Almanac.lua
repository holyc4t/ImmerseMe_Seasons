-- ImmerseMe: Almanac - self-contained calendar maths for ImmerseMe.
-- May be copied verbatim into other ImmerseMe addons; it depends only on `ns` and Lua 5.1
-- (plus the game's date()/time(), which standalone Lua also has).
-- Earth calendar, northern hemisphere. Dates are { year, month, day } tables.
local _, ns = ...

local A = {}
ns.Almanac = A

local floor = math.floor

-- Season start dates (month, day). Winter runs on into the next year.
A.SEASON_STARTS = { spring = { 3, 20 }, summer = { 6, 21 }, autumn = { 9, 22 }, winter = { 12, 21 } }
local ORDER = { "spring", "summer", "autumn", "winter" }

local function isLeap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
A.IsLeap = isLeap

-- Days since 1970-01-01 for a civil date (proleptic Gregorian), no time zones involved.
function A.DayNumber(y, m, d)
	if m <= 2 then y = y - 1 end
	local era = floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

-- The civil date of a day number (inverse of DayNumber).
function A.FromDayNumber(z)
	z = z + 719468
	local era = floor(z / 146097)
	local doe = z - era * 146097
	local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
	local mp = floor((5 * doy + 2) / 153)
	local d = doy - floor((153 * mp + 2) / 5) + 1
	local m = mp < 10 and mp + 3 or mp - 9
	if m <= 2 then y = y + 1 end
	return { year = y, month = m, day = d }
end

function A.DayOfYear(d)
	return A.DayNumber(d.year, d.month, d.day) - A.DayNumber(d.year, 1, 1) + 1
end

-- 0 on 1 January, 1 on 31 December.
function A.YearFraction(d)
	local days = isLeap(d.year) and 366 or 365
	return (A.DayOfYear(d) - 1) / (days - 1)
end

local function startDay(key, year)
	local s = A.SEASON_STARTS[key]
	return A.DayNumber(year, s[1], s[2])
end

-- Season key, part of it ("early" | "mid" | "late") and progress 0..1 through it.
function A.Season(d)
	local today = A.DayNumber(d.year, d.month, d.day)
	local key, from, to
	if today < startDay("spring", d.year) then
		key, from, to = "winter", startDay("winter", d.year - 1), startDay("spring", d.year)
	else
		for i = #ORDER, 1, -1 do
			local k = ORDER[i]
			if today >= startDay(k, d.year) then
				key, from = k, startDay(k, d.year)
				local nextKey = ORDER[i % 4 + 1]
				to = startDay(nextKey, nextKey == "spring" and d.year + 1 or d.year)
				break
			end
		end
	end
	local progress = (today - from) / (to - from)
	local part = progress < 1 / 3 and "early" or progress < 2 / 3 and "mid" or "late"
	return key, part, progress
end

-- Sunrise and sunset ---------------------------------------------------------------------------
-- A mid-northern place (about London's latitude), solar noon at 12:00, no daylight saving.
-- Flavour only: the game's own lighting does not follow it.
A.LATITUDE = 51.5
local rad = math.pi / 180

-- Sunrise and sunset as fractional hours (8.09 = 08:05).
function A.SunTimes(d)
	local n = A.DayOfYear(d)
	local decl = -23.44 * math.cos(2 * math.pi / 365 * (n + 10)) * rad
	local lat = A.LATITUDE * rad
	local c = (math.sin(-0.833 * rad) - math.sin(lat) * math.sin(decl)) / (math.cos(lat) * math.cos(decl))
	c = math.max(-1, math.min(1, c))
	local half = math.acos(c) / rad / 15
	return 12 - half, 12 + half
end

-- Minutes of daylight.
function A.DayLength(d)
	local rise, set = A.SunTimes(d)
	return (set - rise) * 60
end

-- Minutes of daylight gained (+) or lost (-) by tomorrow.
function A.DayTrend(d)
	local tomorrow = A.FromDayNumber(A.DayNumber(d.year, d.month, d.day) + 1)
	return A.DayLength(tomorrow) - A.DayLength(d)
end

-- Solstices and equinoxes: a key when the date is within MARKER_DAYS of one.
A.MARKERS = {
	{ "spring_equinox", 3, 20 }, { "midsummer", 6, 21 }, { "autumn_equinox", 9, 22 }, { "midwinter", 12, 21 },
}
A.MARKER_DAYS = 7

function A.Marker(d)
	local today = A.DayNumber(d.year, d.month, d.day)
	for y = d.year - 1, d.year + 1 do
		for _, m in ipairs(A.MARKERS) do
			if math.abs(A.DayNumber(y, m[2], m[3]) - today) <= A.MARKER_DAYS then return m[1] end
		end
	end
	return nil
end

-- Moveable feasts -------------------------------------------------------------------------------

-- Easter Sunday (anonymous Gregorian algorithm): month, day.
function A.Easter(y)
	local a, b, c = y % 19, floor(y / 100), y % 100
	local d, e = floor(b / 4), b % 4
	local f = floor((b + 8) / 25)
	local g = floor((b - f + 1) / 3)
	local h = (19 * a + b - d - g + 15) % 30
	local i, k = floor(c / 4), c % 4
	local l = (32 + 2 * e + 2 * i - h - k) % 7
	local m = floor((a + 11 * h + 22 * l) / 451)
	local month = floor((h + l - 7 * m + 114) / 31)
	local day = (h + l - 7 * m + 114) % 31 + 1
	return month, day
end

-- Mean lunar cycle (the same constants ImmerseMe: Weather uses for moon phases).
A.NEW_MOON_EPOCH = 947182440      -- a new moon, 6 January 2000 18:14 UTC (epoch seconds)
A.SYNODIC = 29.530588             -- days

-- Lunar new year: the second new moon after the winter solstice of the year before. Month, day.
-- Mean moon, so it can be a day off the true date; worked in UTC days.
function A.LunarNewYear(y)
	local solstice = (A.DayNumber(y - 1, 12, 21) + 0.5) * 86400
	local period = A.SYNODIC * 86400
	local k = math.ceil((solstice - A.NEW_MOON_EPOCH) / period)
	local second = A.NEW_MOON_EPOCH + (k + 1) * period
	local d = A.FromDayNumber(floor(second / 86400))
	return d.month, d.day
end

-- Festivals -------------------------------------------------------------------------------------
-- Blizzard's usual windows for the in-game holidays. These are approximations: check them against
-- current Classic Era behaviour and adjust here. notch = shown on the year-arc.
local function fixed(m, d) return function() return m, d end end

A.FESTIVALS = {
	{ key = "lunar",     name = "Lunar Festival",          notch = true,  start = A.LunarNewYear, days = 14 },
	{ key = "love",      name = "Love is in the Air",      notch = true,  start = fixed(2, 7),    days = 14 },
	{ key = "noble",     name = "Noblegarden",             notch = true,  start = A.Easter,       days = 7 },
	{ key = "children",  name = "Children's Week",         notch = true,  start = fixed(5, 1),    days = 7 },
	{ key = "midsummer", name = "Midsummer Fire Festival", notch = true,  start = fixed(6, 21),   days = 15 },
	{ key = "harvest",   name = "Harvest Festival",        notch = true,  start = fixed(9, 13),   days = 7 },
	{ key = "hallow",    name = "Hallow's End",            notch = true,  start = fixed(10, 18),  days = 15 },
	{ key = "veil",      name = "Feast of Winter Veil",    notch = true,  start = fixed(12, 15),  days = 19 },
	-- monthly: the week from the first Sunday of every month
	{ key = "darkmoon",  name = "Darkmoon Faire",          notch = false, monthly = true,         days = 7 },
}

-- First Sunday of a month as a day number (day 0, 1 Jan 1970, was a Thursday).
local function firstSunday(y, m)
	local first = A.DayNumber(y, m, 1)
	return first + (3 - first) % 7
end

-- Every window of a festival that starts in year y, as { startDay, endDay } day numbers.
local function windows(f, y)
	local list = {}
	if f.monthly then
		for m = 1, 12 do
			local s = firstSunday(y, m)
			list[#list + 1] = { s, s + f.days - 1 }
		end
	else
		local m, d = f.start(y)
		local s = A.DayNumber(y, m, d)
		list[1] = { s, s + f.days - 1 }
	end
	return list
end

-- Festivals running now or starting within horizonDays of the realm time t.
-- Each: { key, name, notch, active, days } (days until the start, 0 when active).
-- Sorted: active first, then soonest. One entry per festival.
function A.Upcoming(t, horizonDays)
	local now = date("*t", t)
	local today = A.DayNumber(now.year, now.month, now.day)
	local best = {}
	for _, f in ipairs(A.FESTIVALS) do
		for y = now.year - 1, now.year + 1 do
			for _, w in ipairs(windows(f, y)) do
				local active = today >= w[1] and today <= w[2]
				local days = active and 0 or w[1] - today
				if active or (days > 0 and days <= horizonDays) then
					local cur = best[f.key]
					if not cur or (active and not cur.active) or (not cur.active and days < cur.days) then
						best[f.key] = { key = f.key, name = f.name, notch = f.notch, active = active, days = days }
					end
				end
			end
		end
	end
	local list = {}
	for _, f in ipairs(A.FESTIVALS) do if best[f.key] then list[#list + 1] = best[f.key] end end
	table.sort(list, function(a, b)
		if a.active ~= b.active then return a.active end
		if a.days ~= b.days then return a.days < b.days end
		return a.key < b.key
	end)
	return list
end

-- Where each notched festival starts on the year-arc: { key, frac } with frac 0..1.
function A.NotchFractions(y)
	local list = {}
	for _, f in ipairs(A.FESTIVALS) do
		if f.notch then
			local d = A.FromDayNumber(windows(f, y)[1][1])
			list[#list + 1] = { key = f.key, frac = A.YearFraction(d) }
		end
	end
	return list
end
