-- Runs under standalone Lua (tests/run.lua), not the WoW client.
---@diagnostic disable: undefined-global
-- Climate.lua is a copy of ImmerseMe: Weather's temperature model. These tests prove the copy
-- still gives exactly Weather's outdoor temperature, so frost never disagrees with its thermometer.

local WEATHER = "../ImmerseMe_Weather/"
local wns
do
	local data = loadfile(WEATHER .. "Data.lua")
	local core = loadfile(WEATHER .. "Core.lua")
	if data and core then
		wns = {}
		data("ImmerseMe_Weather", wns)
		core("ImmerseMe_Weather", wns)
	else
		print("SKIP parity: ImmerseMe_Weather not found")
	end
end

local function zones()
	local list = { "Nowhere" }
	for z in pairs(ns.Zones) do list[#list + 1] = z end
	table.sort(list)
	return list
end

local GAME = { false, { kind = "snow", intensity = 0.6 }, { kind = "rain", intensity = 0.3 },
               { kind = "clear", intensity = 0 } }

test("outdoor temperature matches Weather's", function()
	if not wns then return end
	for _, zone in ipairs(zones()) do
		for k = 0, 199 do
			local t, hour = 1700000000 + k * 7919, (k * 2.37) % 24
			local opts = { weather = GAME[k % 4 + 1] or nil }
			near(ns.OutdoorTemp(zone, t, hour, opts), wns.Simulate(zone, t, hour, opts).outside, 1e-9,
				("%s t=%d h=%.2f"):format(zone, t, hour))
		end
	end
end)

test("outdoor temperature matches Weather's in instances", function()
	if not wns then return end
	for k = 0, 49 do
		local t, hour = 1700000000 + k * 7919, (k * 2.37) % 24
		local opts = { instance = true }
		near(ns.OutdoorTemp("Zul'Farrak", t, hour, opts), wns.Simulate("Zul'Farrak", t, hour, opts).outside, 1e-9)
	end
end)

test("shelter and fires don't change the outdoor temperature", function()
	local t = 1700000000
	eq(ns.OutdoorTemp("Dun Morogh", t, 7, { sheltered = true, heated = true, heat = "forge" }),
	   ns.OutdoorTemp("Dun Morogh", t, 7, {}))
end)

test("climate for a zone", function()
	eq(ns.ClimateFor("Dun Morogh", false), "alpine")
	eq(ns.ClimateFor("Nowhere", false), ns.DEFAULT_CLIMATE)
	eq(ns.ClimateFor("Dun Morogh", true), ns.INSTANCE_CLIMATE)
end)
