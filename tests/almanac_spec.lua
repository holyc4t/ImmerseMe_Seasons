-- Runs under standalone Lua (tests/run.lua), not the WoW client.
---@diagnostic disable: undefined-global
-- ns.Almanac: calendar maths.

local function season(y, m, d) return ns.Almanac.Season({ year = y, month = m, day = d }) end

test("season boundaries", function()
	eq(({ season(2026, 3, 19) })[1], "winter")
	eq(({ season(2026, 3, 20) })[1], "spring")
	eq(({ season(2026, 6, 21) })[1], "summer")
	eq(({ season(2026, 9, 22) })[1], "autumn")
	eq(({ season(2026, 12, 21) })[1], "winter")
	eq(({ season(2026, 1, 14) })[1], "winter")
end)

test("season parts", function()
	eq(({ season(2026, 1, 14) })[2], "early")    -- ~24 of 89 winter days
	eq(({ season(2026, 2, 10) })[2], "mid")
	eq(({ season(2026, 3, 10) })[2], "late")
end)

test("year fraction ends", function()
	near(ns.Almanac.YearFraction({ year = 2026, month = 1, day = 1 }), 0)
	near(ns.Almanac.YearFraction({ year = 2026, month = 12, day = 31 }), 1)
end)

test("sun at midwinter and midsummer", function()
	local r, s = ns.Almanac.SunTimes({ year = 2026, month = 12, day = 21 })
	near(r, 8.09, 0.1, "midwinter rise"); near(s, 15.91, 0.1, "midwinter set")
	r, s = ns.Almanac.SunTimes({ year = 2026, month = 6, day = 21 })
	near(r, 3.68, 0.1, "midsummer rise"); near(s, 20.32, 0.1, "midsummer set")
	r, s = ns.Almanac.SunTimes({ year = 2026, month = 3, day = 20 })
	near(r, 6.0, 0.15, "equinox rise"); near(s, 18.0, 0.15, "equinox set")
end)

test("days lengthen after midwinter", function()
	ok(ns.Almanac.DayTrend({ year = 2026, month = 1, day = 14 }) > 0, "january")
	ok(ns.Almanac.DayTrend({ year = 2026, month = 8, day = 1 }) < 0, "august")
	near(ns.Almanac.DayLength({ year = 2026, month = 6, day = 21 }), (20.32 - 3.68) * 60, 10)
end)

test("leap day and day 366", function()
	for _, d in ipairs({ { year = 2028, month = 2, day = 29 }, { year = 2028, month = 12, day = 31 } }) do
		ok(ns.Almanac.Season(d), "season"); ok(ns.Almanac.SunTimes(d), "sun")
		local f = ns.Almanac.YearFraction(d); ok(f >= 0 and f <= 1, f)
	end
	eq(ns.Almanac.DayOfYear({ year = 2028, month = 12, day = 31 }), 366)
end)

test("solstice marker", function()
	eq(ns.Almanac.Marker({ year = 2026, month = 12, day = 18 }), "midwinter")
	eq(ns.Almanac.Marker({ year = 2026, month = 6, day = 25 }), "midsummer")
	eq(ns.Almanac.Marker({ year = 2026, month = 3, day = 22 }), "spring_equinox")
	eq(ns.Almanac.Marker({ year = 2026, month = 11, day = 1 }), nil)
	eq(ns.Almanac.Marker({ year = 2027, month = 1, day = 2 }), nil)
	eq(ns.Almanac.Marker({ year = 2026, month = 12, day = 27 }), "midwinter")
end)

test("easter", function()
	eq({ ns.Almanac.Easter(2025) }, { 4, 20 })
	eq({ ns.Almanac.Easter(2026) }, { 4, 5 })
	eq({ ns.Almanac.Easter(2027) }, { 3, 28 })
end)

test("lunar new year within a day", function()
	local function doy(y, m, d) return ns.Almanac.DayOfYear({ year = y, month = m, day = d }) end
	for _, c in ipairs({ { 2025, 1, 29 }, { 2026, 2, 17 }, { 2027, 2, 6 } }) do
		local m, d = ns.Almanac.LunarNewYear(c[1])
		ok(math.abs(doy(c[1], m, d) - doy(c[1], c[2], c[3])) <= 1, c[1] .. ": got " .. tostring(m) .. "/" .. tostring(d))
	end
end)

local function at(y, m, d) return time({ year = y, month = m, day = d, hour = 12 }) end

test("upcoming wraps the year", function()
	local list = ns.Almanac.Upcoming(at(2026, 12, 30), 60)
	eq(list[1].key, "veil"); ok(list[1].active, "veil active 30 Dec")
	list = ns.Almanac.Upcoming(at(2027, 1, 1), 60)
	eq(list[1].key, "veil"); ok(list[1].active, "veil active 1 Jan")
	local found
	for _, f in ipairs(ns.Almanac.Upcoming(at(2026, 12, 31), 60)) do if f.key == "lunar" then found = f end end
	ok(found and not found.active and found.days > 20, "lunar 2027 ahead")
end)

test("hallow's end ahead in mid october", function()
	local h
	for _, f in ipairs(ns.Almanac.Upcoming(at(2026, 10, 14), 30)) do if f.key == "hallow" then h = f end end
	eq(h.days, 4); ok(not h.active, "not yet")
end)

test("upcoming is sorted, active first", function()
	local list = ns.Almanac.Upcoming(at(2026, 10, 20), 60)
	eq(list[1].key, "hallow"); ok(list[1].active, "hallow active"); eq(list[1].days, 0)
	for i = 2, #list do ok(list[i].active or list[i].days >= list[i - 1].days or list[i - 1].active, i) end
end)

test("notches are in the year", function()
	local n = ns.Almanac.NotchFractions(2026)
	eq(#n, 8)
	for _, x in ipairs(n) do ok(x.frac >= 0 and x.frac <= 1, x.key) end
end)
