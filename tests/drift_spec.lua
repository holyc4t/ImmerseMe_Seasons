-- Runs under standalone Lua (tests/run.lua), not the WoW client.
---@diagnostic disable: undefined-global
-- The drifting flakes and leaves: where they travel and how many play per land and season.

-- Must match BLOCKED in tools/decor.py (degrees counter-clockwise from the right).
local BLOCKED = { { 30, 60, "Weather's orb" }, { 82, 98, "the compass N" }, { 165, 195, "Geography's orb" },
                  { 195, 235, "Weather's readout" }, { 298, 334, "the zoom buttons" } }
local STYLES = { "temperate", "snowbound", "hot" }
local SEASONS = { "spring", "summer", "autumn", "winter" }

test("drift lanes stay clear of the siblings", function()
	ok(#ns.DriftLanes >= 4, "some lanes")
	for i, l in ipairs(ns.DriftLanes) do
		local step = l.sweep < 0 and -1 or 1
		for a = l.from, l.from + l.sweep, step do
			local m = a % 360
			for _, b in ipairs(BLOCKED) do
				ok(not (m >= b[1] and m < b[2]), ("lane %d passes %s at %d"):format(i, b[3], m))
			end
		end
		ok(l.r >= 0.88 and l.r <= 1.0, "lane " .. i .. " on the rim band")
		ok(l.dur >= 8, "lane " .. i .. " is slow")
		ok(l.size <= 16, "lane " .. i .. " is small")
		ok(l.delay >= 0, "lane " .. i .. " delay")
	end
end)

test("drift timings don't line up", function()
	local seen = {}
	for i, l in ipairs(ns.DriftLanes) do
		ok(not seen[l.dur], "lane " .. i .. " repeats duration " .. l.dur)
		seen[l.dur] = true
	end
end)

test("drift counts and kinds", function()
	local most = 0
	for _, style in ipairs(STYLES) do
		for _, season in ipairs(SEASONS) do
			local n = ns.DriftCount[style][season]
			ok(type(n) == "number" and n % 1 == 0 and n >= 0 and n <= #ns.DriftLanes, style .. " " .. season)
			if n > 0 then
				local kind = ns.DriftKind[style][season]
				ok(kind and ns.DRIFT_CELLS[kind], style .. " " .. season .. " has a sprite")
			end
			if season == "summer" or style == "hot" then eq(n, 0, style .. " " .. season) end
			most = math.max(most, n)
		end
	end
	eq(ns.DriftCount.snowbound.winter, most, "snowbound winter drifts most")
	eq(#ns.LEAF_COLORS, 3, "three leaf colours")
end)

test("Warcraft tints: snowy autumn is cold, not grey-white", function()
	local t = ns.Tints.snowbound.autumn
	ok(t[3] > t[1] + 0.15, "blue over red")
end)
