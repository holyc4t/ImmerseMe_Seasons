-- ImmerseMe: Seasons - the season, the frost and what the tooltip says.
-- Pure logic: no frames, so tests/run.lua can load it outside the game.
local _, ns = ...

-- Which zone the season belongs to. names: candidates in the order Weather looks for them (zone
-- texts, then the map and its parents). memo: a table the caller keeps, holding memo.lastZone.
-- Like Weather's CurrentZone, except that in an instance the season stays the one of the last
-- outdoor zone: inside Zul'Farrak it is still Tanaris's cool season.
function ns.ResolveZone(names, inInstance, roofed, memo)
	if inInstance then
		-- the instance map's parents may name the land it lies in
		for _, name in ipairs(names) do
			if ns.Zones[name] then
				memo.lastZone = name
				return name
			end
		end
		if memo.lastZone then return memo.lastZone end
		return names[1] or ""
	end
	for _, name in ipairs(names) do
		if ns.Zones[name] then
			memo.lastZone = name
			return name
		end
	end
	if roofed then
		if memo.lastZone then return memo.lastZone end
	else
		memo.lastZone = nil      -- out in the open in a land the data doesn't know
	end
	return names[1] or ""
end

-- Frost -----------------------------------------------------------------------------------------

-- One step of the frost state. temp: outdoor Celsius, hour: 0-24, season: Almanac key,
-- rise: today's sunrise hour, wasOn: frost at the previous step.
function ns.FrostStep(temp, hour, season, rise, wasOn)
	if temp < ns.FROST_ALLDAY then return true end
	local morning = hour >= rise - ns.FROST_LEAD and hour < (ns.MorningEnd[season] or 10)
	if not morning then return false end
	return temp < ns.FROST_ON or (wasOn and temp <= ns.FROST_OFF) or false
end

local STEP = 600            -- seconds between frost steps
local REPLAY = 24 * 6       -- at most a day of steps looking back

local function stepAt(zone, t, hour, opts, wasOn)
	local d = date("*t", t)
	local season = ns.Almanac.Season(d)
	local rise = ns.Almanac.SunTimes(d)
	return ns.FrostStep(ns.OutdoorTemp(zone, t, hour, opts), hour, season, rise, wasOn)
end

-- Whether frost is on now. prevOn: the state one step ago, or nil on a fresh start (login,
-- /reload). A fresh start walks back through the plain model until the state doesn't depend
-- on what came before, then replays forward, so a reload never changes what you see.
function ns.Frost(zone, t, hour, opts, prevOn)
	opts = opts or {}
	local _, climate = ns.ClimateFor(zone, opts.instance)
	if opts.instance or climate.indoor then return false end
	if prevOn == nil then
		local plain = {}
		local k = 1
		while k < REPLAY do
			local tk, hk = t - k * STEP, (hour - k * STEP / 3600) % 24
			if stepAt(zone, tk, hk, plain, true) == stepAt(zone, tk, hk, plain, false) then break end
			k = k + 1
		end
		local on = false
		for j = k, 1, -1 do
			on = stepAt(zone, t - j * STEP, (hour - j * STEP / 3600) % 24, plain, on)
		end
		prevOn = on
	end
	return stepAt(zone, t, hour, opts, prevOn)
end

-- The frost state saved at the last refresh, if it is recent and for this zone: lets a /reload
-- carry on exactly where it left off, including history shaped by the game's live weather.
ns.RESUME_SECONDS = 120
-- What one character remembers between sessions: its last outdoor zone (memo.lastZone) and the
-- frost at its last refresh (memo.resume). Saved variables are account-wide, so each character
-- gets its own table under db.chars; the old shared db.memo / db.resume are dropped.
function ns.CharMemo(db, who)
	db.memo, db.resume = nil, nil
	if type(db.chars) ~= "table" then db.chars = {} end
	local m = db.chars[who]
	if type(m) ~= "table" then
		m = {}
		db.chars[who] = m
	end
	return m
end

function ns.ResumeFrost(saved, zone, t)
	if type(saved) ~= "table" or saved.zone ~= zone or type(saved.t) ~= "number" then return nil end
	if t < saved.t or t - saved.t > ns.RESUME_SECONDS then return nil end
	return saved.on and true or false
end

-- What the frost will do, stepping the plain model (no live weather) forward like Weather's
-- Outlook. startOn: the frost state now (as shown); nil works it out from the plain model.
-- { now = bool, liftsAt = hour (when on now), at = hour (when it is expected next, if not now) }
function ns.FrostForecast(zone, t, hour, startOn)
	local now = startOn
	if now == nil then now = ns.Frost(zone, t, hour, {}, nil) end
	local f = { now = now }
	local on = now
	for k = 1, 48 do
		local tk, hk = t + k * 1800, (hour + k / 2) % 24
		on = ns.Frost(zone, tk, hk, {}, on)
		if now and not on then f.liftsAt = hour + k / 2 break end
		if not now and on then f.at = hk break end
	end
	return f
end

-- Season state ----------------------------------------------------------------------------------

local PREV = { spring = "winter", summer = "spring", autumn = "summer", winter = "autumn" }

local function lerp3(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- A stable pick from a list for a key (one flavour line per zone per day).
local function pick(list, key)
	local h = 5381
	for i = 1, #key do h = (h * 33 + key:byte(i)) % 2147483647 end
	return list[h % #list + 1]
end

local function seasonStartDay(season, d)
	local s = ns.Almanac.SEASON_STARTS[season]
	local y = d.year
	if season == "winter" and d.month < 12 then y = y - 1 end
	return ns.Almanac.DayNumber(y, s[1], s[2])
end

-- Everything the rim and tooltip show.
-- zone: the resolved zone (the last outdoor zone while in an instance).
-- climateKey: the climate the player is in right now (Weather's instance climate in instances).
-- prevFrost: the frost state from the last refresh, or nil on a fresh start.
function ns.State(zone, climateKey, t, hour, opts, prevFrost)
	opts = opts or {}
	local A = ns.Almanac
	local now = date("*t", t)
	local d = { year = now.year, month = now.month, day = now.day }
	local season, part = A.Season(d)
	-- wording and colour come from the land itself, never from an instance's climate
	local landKey = ns.ClimateFor(zone, false)
	local style = ns.ClimateStyle[landKey] or "temperate"
	local here = ns.Climates[climateKey] or ns.Climates[landKey]

	local tint = ns.Tints[style][season]
	local into = A.DayNumber(d.year, d.month, d.day) - seasonStartDay(season, d)
	if into < ns.TINT_BLEND_DAYS then
		local f = (into + 1) / (ns.TINT_BLEND_DAYS + 1)
		f = f * f * (3 - 2 * f)
		tint = lerp3(ns.Tints[style][PREV[season]], tint, f)
	end

	local indoor = (opts.instance or here.indoor) and true or false
	local rise, set = A.SunTimes(d)
	local flavors = ns.Flavor[style][season]
	local frost = (not indoor) and ns.Frost(zone, t, hour, opts, prevFrost) or false
	return {
		date = d, season = season, part = part, style = style,
		seasonName = ns.SeasonNames[style][season][part],
		tint = tint,
		frost = frost,
		forecast = (not indoor) and ns.FrostForecast(zone, t, hour, frost) or { now = false },
		hour = hour, rise = rise, set = set, trend = A.DayTrend(d),
		arc = A.YearFraction(d), notches = A.NotchFractions(d.year),
		festivals = A.Upcoming(t, 45), marker = A.Marker(d),
		zoneLine = ns.ZoneLines[style][season],
		flavor = flavors and pick(flavors, zone .. d.year .. "-" .. d.month .. "-" .. d.day) or nil,
		indoor = indoor,
	}
end

-- Tooltip ---------------------------------------------------------------------------------------

-- 8.09 -> "08:05"
function ns.Clock(h)
	h = h % 24
	local hh = math.floor(h)
	local mm = math.floor((h - hh) * 60 + 0.5)
	if mm == 60 then hh, mm = (hh + 1) % 24, 0 end
	return ("%02d:%02d"):format(hh, mm)
end

local function add(list, text, color, extra)
	local c = ns.COLORS[color]
	local l = { text = text, r = c[1], g = c[2], b = c[3] }
	if extra then for k, v in pairs(extra) do l[k] = v end end
	list[#list + 1] = l
end

local function when(days)
	if days == 1 then return "tomorrow" end
	if days < 14 then return "in " .. days .. " days" end
	return "in " .. math.floor(days / 7 + 0.5) .. " weeks"
end

-- The tooltip as lines: { text, r, g, b, gap = blank line before, italic = bool }.
function ns.TooltipLines(s)
	local L = {}
	add(L, s.seasonName, "header")
	add(L, ("%d %s · %s"):format(s.date.day, ns.MONTHS[s.date.month], ns.YEAR_LABEL), "grey")

	local f = s.forecast or { now = false }
	local frostLine = false
	if s.frost then
		if f.liftsAt and f.liftsAt < 24 then
			add(L, "Hoarfrost on the ground; it will lift by " .. ns.Clock(f.liftsAt) .. ".", "frost", { gap = true })
		else
			add(L, "Frost lies hard on the ground all day.", "frost", { gap = true })
		end
		frostLine = true
	elseif f.at then
		local later = f.at > (s.hour or 0)
		add(L, later and "Frost likely by morning." or "Frost likely tomorrow morning.", "frost", { gap = true })
		frostLine = true
	end
	if s.zoneLine then add(L, s.zoneLine, "white", { gap = not frostLine }) end

	add(L, ("Sunrise %s · Sunset %s"):format(ns.Clock(s.rise), ns.Clock(s.set)), "white", { gap = true })
	local mins = math.floor(math.abs(s.trend) + 0.5)
	local way = s.trend > 0 and "lengthening" or "shortening"
	if mins >= 1 then
		add(L, ("Days are %s, %d minute%s a day."):format(way, mins, mins == 1 and "" or "s"), "grey")
	else
		add(L, "Days are " .. way .. ", slowly.", "grey")
	end
	if s.marker then add(L, ns.MarkerNames[s.marker], "grey") end

	local shown, first = 0, true
	for _, fest in ipairs(s.festivals or {}) do
		if shown >= 3 then break end
		if fest.notch or fest.active or fest.days <= 14 then
			local gap = shown == 0
			if fest.active then
				add(L, fest.name .. " is on now", "green", { gap = gap })
			elseif first then
				add(L, fest.name .. " begins " .. when(fest.days), "green", { gap = gap })
				first = false
			else
				add(L, fest.name .. " " .. when(fest.days), "grey", { gap = gap })
			end
			shown = shown + 1
		end
	end

	if s.flavor then add(L, '"' .. s.flavor .. '"', "flavor", { gap = true, italic = true }) end
	return L
end

-- For /ims emote, said as "<name> <text>".
function ns.EmoteText(s)
	local text = "notes the " .. s.seasonName:lower():gsub("^the ", "")
	if s.frost then return text .. "; frost lies on the ground this morning." end
	if s.zoneLine then return text .. ". " .. s.zoneLine end
	return text .. "."
end

-- The season arc under the minimap ----------------------------------------------------------------
-- Where things sit on the year, as fractions (0 = 1 January, 1 = 31 December):
-- icons[season]: the middle of that season's stretch of the year (winter: 1 January .. spring);
-- borders: the four season starts, in calendar order (spring, summer, autumn, winter).
function ns.SeasonMarks(year)
	local A = ns.Almanac
	local function frac(key)
		local s = A.SEASON_STARTS[key]
		return A.YearFraction({ year = year, month = s[1], day = s[2] })
	end
	local sp, su, au, wi = frac("spring"), frac("summer"), frac("autumn"), frac("winter")
	return {
		icons = { winter = sp / 2, spring = (sp + su) / 2, summer = (su + au) / 2, autumn = (au + wi) / 2 },
		borders = { sp, su, au, wi },
	}
end
