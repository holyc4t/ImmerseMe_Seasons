-- Runs under standalone Lua (tests/run.lua), not the WoW client.
---@diagnostic disable: undefined-global
-- Core.lua: zone, frost and season state.

test("resolve known zone and remember it", function()
	local memo = {}
	eq(ns.ResolveZone({ "Lion's Pride Inn", "Elwynn Forest" }, false, true, memo), "Elwynn Forest")
	eq(memo.lastZone, "Elwynn Forest")
end)

test("roofed in an unknown building keeps the last zone", function()
	local memo = { lastZone = "Duskwood" }
	eq(ns.ResolveZone({ "Scarlet Raven Tavern" }, false, true, memo), "Duskwood")
end)

test("out in an unknown land forgets the last zone", function()
	local memo = { lastZone = "Duskwood" }
	eq(ns.ResolveZone({ "Somewhere New" }, false, false, memo), "Somewhere New")
	eq(memo.lastZone, nil)
end)

test("instance follows last outdoor zone", function()
	local memo = { lastZone = "Tanaris" }
	eq(ns.ResolveZone({ "Zul'Farrak" }, true, false, memo), "Tanaris")
	eq(memo.lastZone, "Tanaris")
end)

test("instance with no last zone", function()
	local memo = {}
	local z = ns.ResolveZone({ "Zul'Farrak" }, true, false, memo)
	eq(z, "Zul'Farrak")
	ok(ns.OutdoorTemp(z, 1700000000, 6, { instance = true }), "no error")
	eq(ns.ResolveZone({}, true, false, {}), "")
end)

test("every climate has a style", function()
	for k in pairs(ns.Climates) do ok(ns.ClimateStyle[k], k) end
	eq(ns.ClimateStyle.desert, "hot"); eq(ns.ClimateStyle.alpine, "snowbound")
	eq(ns.ClimateStyle.temperate, "temperate"); eq(ns.ClimateStyle.forge, "temperate")
end)

test("hysteresis keeps frost between 1 and 2", function()
	ok(ns.FrostStep(1.5, 7, "winter", 8, true), "stays on")
	ok(not ns.FrostStep(1.5, 7, "winter", 8, false), "doesn't start")
	ok(ns.FrostStep(0.5, 7, "winter", 8, false), "starts below 1")
	ok(not ns.FrostStep(2.5, 7, "winter", 8, true), "goes above 2")
	ok(not ns.FrostStep(-2, 13, "winter", 8, true), "lifted after midmorning")
	ok(ns.FrostStep(-5, 13, "winter", 8, true), "bitter day: all day")
	ok(not ns.FrostStep(-2, 4, "winter", 8, false), "before the morning window")
end)

local function hourOf(t) local d = date("*t", t) return d.hour + d.min / 60 end

test("fresh state equals continuous state", function()
	for k = 0, 300 do
		local zone, t = (k % 2 == 0) and "Elwynn Forest" or "Dun Morogh", 1767000000 + k * 600
		local prev = ns.Frost(zone, t - 600, hourOf(t - 600), {}, nil)
		eq(ns.Frost(zone, t, hourOf(t), {}, nil), ns.Frost(zone, t, hourOf(t), {}, prev), zone .. " " .. t)
	end
end)

test("no frost indoors or in instances", function()
	for day = 0, 29 do
		local t = 1767225600 + day * 86400 + 7 * 3600
		ok(not ns.Frost("Ironforge", t, 7, {}, nil), "ironforge")
		ok(not ns.Frost("Dun Morogh", t, 7, { instance = true }, nil), "instance")
	end
end)

test("frost groups emerge from the model", function()
	-- January mornings at 07:00 over 30 days: alpine mostly frosty, temperate sometimes, hot never
	local function count(zone)
		local n = 0
		for day = 0, 29 do if ns.Frost(zone, 1767225600 + day * 86400 + 7 * 3600, 7, {}, nil) then n = n + 1 end end
		return n
	end
	ok(count("Dun Morogh") >= 20, "alpine " .. count("Dun Morogh"))
	ok(count("Elwynn Forest") >= 3, "temperate " .. count("Elwynn Forest"))
	eq(count("Tanaris"), 0); eq(count("The Barrens"), 0)
end)

test("frost follows the live game weather", function()
	-- real snow caps the temperature at 0, so a snowy morning in Elwynn is always frosty
	for day = 0, 29 do
		local t = 1767225600 + day * 86400 + 8 * 3600
		ok(ns.Frost("Elwynn Forest", t, 8, { weather = { kind = "snow", intensity = 0.6 } }, nil), day)
	end
end)

test("forecast", function()
	for day = 0, 29 do
		local t = 1767225600 + day * 86400 + 7 * 3600
		local f = ns.FrostForecast("Dun Morogh", t, 7)
		eq(f.now, ns.Frost("Dun Morogh", t, 7, {}, nil), day)
		if f.now and f.liftsAt then ok(f.liftsAt > 7 and f.liftsAt <= 24, f.liftsAt) end
		eq(ns.FrostForecast("Tanaris", t, 7), { now = false })
	end
end)

local JAN14 = time({ year = 2027, month = 1, day = 14, hour = 7 })

local function texts(lines)
	local out = {}
	for _, l in ipairs(lines) do out[#out + 1] = l.text end
	return table.concat(out, "\n")
end

test("tanaris never says winter", function()
	for m = 1, 12 do
		local t = time({ year = 2027, month = m, day = 14, hour = 7 })
		local s = ns.State("Tanaris", "desert", t, 7, {}, nil)
		-- festival names may say winter (Feast of Winter Veil); the land's own words must not
		local own = (s.seasonName .. " " .. (s.zoneLine or "") .. " " .. (s.flavor or "")):lower()
		ok(not own:find("winter"), m .. ": " .. own)
	end
end)

test("tooltip lines in order", function()
	local s = ns.State("Dun Morogh", "alpine", JAN14, 7, {}, nil)
	local lines = ns.TooltipLines(s)
	eq(lines[1].text, s.seasonName)
	eq(lines[2].text, "14 January · Year 25 after the Dark Portal")
	local joined = texts(lines)
	ok(joined:find("Sunrise %d%d:%d%d · Sunset %d%d:%d%d"), joined)
	ok(joined:find("lengthening"), joined)
	ok(joined:find("Lunar Festival begins in"), joined)
end)

test("frost line when frosty", function()
	local s = ns.State("Dun Morogh", "alpine", JAN14, 7, {}, nil)
	ok(s.frost, "dun morogh frosty on a january morning")
	ok(texts(ns.TooltipLines(s)):find("[Ff]rost"), texts(ns.TooltipLines(s)))
end)

test("festival on now is green and first", function()
	local s = ns.State("Elwynn Forest", "temperate", time({ year = 2026, month = 10, day = 20, hour = 12 }), 12, {}, nil)
	local found
	for _, l in ipairs(ns.TooltipLines(s)) do
		if l.text == "Hallow's End is on now" then found = l end
	end
	ok(found, texts(ns.TooltipLines(s))); ok(found.g > found.r, "green")
end)

test("tint blends across the boundary", function()
	local a = ns.State("Elwynn Forest", "temperate", time({ year = 2026, month = 3, day = 20, hour = 12 }), 12, {}, nil).tint
	local b = ns.State("Elwynn Forest", "temperate", time({ year = 2026, month = 4, day = 10, hour = 12 }), 12, {}, nil).tint
	eq(b, ns.Tints.temperate.spring)
	ok(a[1] ~= b[1] or a[2] ~= b[2] or a[3] ~= b[3], "start of spring is still blending")
end)

test("hot lands have a dry winter tint", function()
	local s = ns.State("Tanaris", "desert", JAN14, 12, {}, nil)
	eq(s.tint, ns.Tints.hot.winter)
	ok(not deepEq(ns.Tints.hot.winter, ns.Tints.temperate.winter), "not icy blue")
end)

test("state is stable", function()
	eq(ns.State("Duskwood", "gloom", JAN14, 7, {}, nil), ns.State("Duskwood", "gloom", JAN14, 7, {}, nil))
end)

test("every style and season has wording and a tint", function()
	for _, style in ipairs({ "temperate", "hot", "snowbound" }) do
		for _, season in ipairs({ "spring", "summer", "autumn", "winter" }) do
			ok(ns.Tints[style][season], style .. " " .. season .. " tint")
			ok(ns.Flavor[style][season] and #ns.Flavor[style][season] > 0, style .. " " .. season .. " flavor")
			for _, part in ipairs({ "early", "mid", "late" }) do
				ok(ns.SeasonNames[style][season][part], style .. " " .. season .. " " .. part)
			end
		end
	end
end)

test("indoor state has no frost but keeps the season", function()
	local s = ns.State("Tanaris", "underground", JAN14, 7, { instance = true }, nil)
	ok(not s.frost, "no frost"); ok(s.seasonName, "season")
end)

test("emote text", function()
	local s = ns.State("Dun Morogh", "alpine", JAN14, 7, {}, nil)
	local e = ns.EmoteText(s)
	ok(type(e) == "string" and #e > 10 and #e <= 255, e)
	ok(e:find("frost"), e)
	ok(not e:lower():find("the the"), e)
end)

-- Final review fixes ------------------------------------------------------------------------

test("forecast starts from the live frost state", function()
	-- live snow makes Elwynn frosty; the tooltip must not then claim frost lasts all day
	local snow = { weather = { kind = "snow", intensity = 0.6 } }
	for day = 0, 29 do
		for _, h in ipairs({ 6.5, 7, 8, 9 }) do
			local t = 1767225600 + day * 86400 + math.floor(h * 3600)
			local s = ns.State("Elwynn Forest", "temperate", t, h, snow, nil)
			eq(s.forecast.now, s.frost, day .. " " .. h)
			if s.frost and ns.OutdoorTemp("Elwynn Forest", t, h, snow) >= ns.FROST_ALLDAY then
				ok(s.forecast.liftsAt, "a lift time on an ordinary frosty morning " .. day .. " " .. h)
			end
		end
	end
end)

test("instance with a known parent map uses it", function()
	eq(ns.ResolveZone({ "Zul'Farrak", "Tanaris", "Kalimdor" }, true, false, {}), "Tanaris")
end)

test("each character keeps its own last zone and frost", function()
	-- saved variables are account-wide: one character's Dun Morogh must not leak into another's login
	local db = { memo = { lastZone = "Dun Morogh" }, resume = { zone = "Dun Morogh", t = 1, on = true } }
	local thorin = ns.CharMemo(db, "Thorin-Realm")
	eq(db.memo, nil, "the old shared memory is dropped")
	eq(db.resume, nil, "the old shared frost is dropped")
	thorin.lastZone = "Dun Morogh"
	local anna = ns.CharMemo(db, "Anna-Realm")
	eq(anna.lastZone, nil, "another character starts with nothing")
	eq(ns.CharMemo(db, "Thorin-Realm").lastZone, "Dun Morogh", "and Thorin keeps his")
end)

test("resume frost from a saved record", function()
	local saved = { zone = "Duskwood", t = 1767254400, on = true }
	eq(ns.ResumeFrost(saved, "Duskwood", 1767254400 + 90), true)
	eq(ns.ResumeFrost(saved, "Elwynn Forest", 1767254400 + 90), nil)     -- another zone
	eq(ns.ResumeFrost(saved, "Duskwood", 1767254400 + 3600), nil)        -- too old
	eq(ns.ResumeFrost(nil, "Duskwood", 1767254400), nil)
	eq(ns.ResumeFrost({ zone = "Duskwood", t = 1767254400, on = false }, "Duskwood", 1767254400 + 60), false)
end)

test("season arc: each season's icon sits in the middle of its stretch of the year", function()
	local m = ns.SeasonMarks(2026)
	-- winter's icon is in the middle of 1 January .. 20 March, the others in their own seasons
	near(m.icons.winter, ns.Almanac.YearFraction({ year = 2026, month = 2, day = 9 }), 0.01, "winter")
	ok(m.icons.winter < m.icons.spring and m.icons.spring < m.icons.summer and m.icons.summer < m.icons.autumn,
		"in calendar order, left to right")
	ok(m.icons.autumn > 0.75 and m.icons.autumn < 0.95, "autumn near the right: " .. m.icons.autumn)
	-- borders at 20 March, 21 June, 22 September, 21 December
	eq(#m.borders, 4)
	near(m.borders[1], ns.Almanac.YearFraction({ year = 2026, month = 3, day = 20 }), 1e-9, "spring starts")
	near(m.borders[4], ns.Almanac.YearFraction({ year = 2026, month = 12, day = 21 }), 1e-9, "winter starts")
end)
