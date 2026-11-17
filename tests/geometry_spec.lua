-- Runs under standalone Lua (tests/run.lua), not the WoW client.
---@diagnostic disable: undefined-global
-- The rim's and the sun path's geometry live in two places: the texture script draws them,
-- UI.lua places them.

local function read(path)
	local f = assert(io.open(path, "r"))
	local s = f:read("*a")
	f:close()
	return s
end

local function num(text, pattern, what)
	local v = text:match(pattern)
	ok(v, what .. " not found")
	return tonumber(v)
end

test("geometry matches the texture script", function()
	local py, ui = read("tools/make_textures.py"), read("UI.lua")
	local pyInner = num(py, "RING_INNER, RING_OUTER = ([%d%.]+)", "script RING_INNER")
	local uiInner = num(ui, "local RING_INNER = ([%d%.]+)", "UI RING_INNER")
	local pyDecor = num(read("tools/decor.py"), "\nDECOR_SCALE = ([%d%.]+)", "decor.py DECOR_SCALE")
	local uiDecor = num(ui, "local DECOR_SCALE = ([%d%.]+)", "UI DECOR_SCALE")
	eq(uiDecor, pyDecor, "DECOR_SCALE")
	eq(uiInner, pyInner, "RING_INNER")
	near(uiInner, 0.90, 1e-9, "ring ends where the stock frame ends")
end)

test("season arc geometry matches the texture script", function()
	local py, ui = read("tools/make_textures.py"), read("UI.lua")
	local vals = {}
	for _, name in ipairs({ "YEAR_R, YEAR_TEX", "YEAR_FROM, YEAR_SPAN" }) do
		local pat = name:gsub("%W", "%%%0")
		local pa, pb = py:match(pat .. " = ([%d%.]+), ([%d%.]+)")
		local ua, ub = ui:match("local " .. pat .. " = ([%d%.]+), ([%d%.]+)")
		ok(pa and ua, name .. " found in both")
		eq(tonumber(ua), tonumber(pa), name)
		eq(tonumber(ub), tonumber(pb), name)
		vals[#vals + 1] = { tonumber(ua), tonumber(ub) }
	end
	local from, span = vals[2][1], vals[2][2]
	ok(from >= 236, "clear of Weather's readout (195-235)")
	ok(from + span <= 298, "clear of the zoom buttons (298-334)")
	ok(vals[1][1] > 1.15, "below the rim and the client's coordinates")
end)
