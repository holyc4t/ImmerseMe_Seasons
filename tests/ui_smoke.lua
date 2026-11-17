-- Runs under standalone Lua, not the WoW client:  lua tests/ui_smoke.lua  (from the addon folder)
-- Loads UI.lua against a stubbed WoW API and drives events, hover and every slash command.
---@diagnostic disable: undefined-global, lowercase-global
-- Loads the addon against a stubbed WoW API and drives its events and commands.
date, time = os.date, os.time
local scripts = {}
local function obj(name)
	local o = { _shown = true, _alpha = 1, _w = 140, _h = 140, _name = name }
	return setmetatable(o, { __index = function(t, k)
		if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
		local m = {
			SetScript = function(self, ev, fn) self._scripts = self._scripts or {}; self._scripts[ev] = fn end,
			HookScript = function(self, ev, fn) self._hooks = fn end,
			GetScript = function(self, ev) return self._scripts and self._scripts[ev] end,
			CreateTexture = function() return obj("tex") end,
			GetWidth = function(self) return self._w end, GetHeight = function(self) return self._h end,
			SetSize = function(self, w, h) self._w, self._h = w, h end,
			GetAlpha = function(self) return self._alpha end, SetAlpha = function(self, a) self._alpha = a end,
			IsShown = function(self) return self._shown end, IsVisible = function(self) return self._shown and self._visible ~= false end,
			SetPoint = function(self, ...) self._point = { ... } end,
			SetTexture = function(self, path) self._texture = path end,
			Show = function(self) self._shown = true end, Hide = function(self) self._shown = false end,
			SetShown = function(self, v) self._shown = v and true or false end,
			GetCenter = function() return 500, 500 end, GetEffectiveScale = function() return 1 end,
			GetFrameLevel = function(self) return self._level or 2 end,
			SetFrameLevel = function(self, l) self._level = l end, GetOwner = function(self) return self._owner end,
			SetOwner = function(self, o) self._owner = o end,
			AddLine = function(self, text) self._lines = (self._lines or 0) + 1 end,
			RegisterEvent = function(self, e) end,
			CreateAnimationGroup = function(self) local g = obj("ag"); g._anims = {}; self._ag = g; return g end,
			CreateAnimation = function(self, kind) local a = obj(kind); self._anims[#self._anims + 1] = a; return a end,
			SetOffset = function(self, x, y) self._offset = { x, y } end,
			SetDesaturated = function(self, v) self._desat = v end,
			SetVertexColor = function(self, r, g, b) self._color = { r, g, b } end,
			SetTexCoord = function(self, ...) self._tc = { ... } end,
			Play = function(self) self._playing = true end, Stop = function(self) self._playing = false end,
			IsPlaying = function(self) return self._playing or false end,
		}
		return m[k] or function() end
	end })
end
frames = {}
function CreateFrame(_, name) local f = obj(name or "frame"); frames[#frames + 1] = f; if name then _G[name] = f end; return f end
Minimap, UIParent, WorldFrame, GameTooltip, MinimapCluster = obj("Minimap"), obj(), obj("World"), obj(), obj()
MinimapCompassTexture = obj("compass")
MinimapZoomIn, MinimapZoomOut = obj("MinimapZoomIn"), obj("MinimapZoomOut")
chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
SlashCmdList = {}
GetGameTime = function() return 7, 30 end
GetServerTime = function() return os.time({ year = 2027, month = 1, day = 14, hour = 7, min = 30 }) end
IsInInstance = function() return false end
IsIndoors = function() return false end
IsResting = function() return false end
UnitName = function() return "Thorin" end
GetRealmName = function() return "Realm" end
GetRealZoneText = function() return "Dun Morogh" end
GetZoneText = function() return "Dun Morogh" end
GetSubZoneText = function() return "Coldridge Valley" end
local cursor = { 500 + 75, 500 }
GetCursorPosition = function() return cursor[1], cursor[2] end
GetMouseFoci = function() return { Minimap } end
SendChatMessage = function(msg, kind) assert(kind == "EMOTE" and #msg > 10, msg) end
local ns = {}
for _, f in ipairs({ "Data.lua", "Almanac.lua", "Climate.lua", "Core.lua", "UI.lua" }) do
	assert(loadfile(f))("ImmerseMe_Seasons", ns)
end
local function each(script, ...) for _, f in ipairs(frames) do local s = f._scripts and f._scripts[script]; if s then s(f, ...) end end end
each("OnEvent", "ADDON_LOADED", "ImmerseMe_Seasons")
each("OnEvent", "PLAYER_ENTERING_WORLD")
assert(ImmerseMeSeasonsRim._shown and ImmerseMeSeasonsRim._w > 140, "rim shown and sized")
-- frost doesn't fade in again after a login or /reload: it is simply there
local fa = ImmerseMeSeasonsRim.frost:GetAlpha()
assert(fa > 0.3 and fa <= 0.6, "frost shows at once, light enough for the bronze to show through, alpha " .. fa)
-- travelling to a new land plays a short transition: the colour slides, the old painting fades
-- into the new one, the frost thaws or creeps in. It's over in a few seconds; nothing pops.
local rimF = ImmerseMeSeasonsRim
local function settle(seconds) for _ = 1, seconds * 10 do each("OnUpdate", 0.1) end end
local function tintIs(t) local c = rimF.ring._color; return c and math.abs(c[1] - t[1]) < 1e-6 and math.abs(c[3] - t[3]) < 1e-6 end
GetRealZoneText = function() return "Tanaris" end; GetZoneText = GetRealZoneText
each("OnEvent", "ZONE_CHANGED_NEW_AREA")
assert(rimF.frost:GetAlpha() == fa, "the frost doesn't vanish at once")
assert(rimF.decorOld._shown and rimF.decorOld._alpha == 1 and rimF.decor._alpha == 0, "the old painting fades into the new")
settle(1.5)
local mid = rimF.frost:GetAlpha()
assert(mid > 0 and mid < fa, "half way through the thaw: " .. mid)
settle(2)
assert(rimF.frost:GetAlpha() == 0, "no frost in Tanaris once it has settled")
assert(tintIs(ns.Tints.hot.winter), "Tanaris's colour once it has settled")
local arcC = ImmerseMeSeasonsYear.line._color
assert(arcC and arcC[1] == ns.ArcTints.hot[1] and arcC[3] == ns.ArcTints.hot[3], "a gold season arc in Tanaris")
assert(not rimF.decorOld._shown and rimF.decor._alpha == 1, "the new painting alone")
GetRealZoneText = function() return "Dun Morogh" end; GetZoneText = GetRealZoneText
each("OnEvent", "ZONE_CHANGED_NEW_AREA")
assert(rimF.frost:GetAlpha() == 0, "the frost creeps in, it doesn't pop")
settle(3.5)
assert(rimF.frost:GetAlpha() == fa, "Dun Morogh frozen over, alpha " .. rimF.frost:GetAlpha())
assert(tintIs(ns.Tints.snowbound.winter), "Dun Morogh's colour")
arcC = ImmerseMeSeasonsYear.line._color
assert(arcC[1] == ns.ArcTints.snowbound[1] and arcC[3] == ns.ArcTints.snowbound[3], "a frosty season arc in Dun Morogh")
-- the season arc: in mid-January the winter icon stands near the left end, bright and larger;
-- the others rest, dimmed, further right; all of it below the minimap
do
	local path = ImmerseMeSeasonsYear
	assert(path and path._shown, "season arc shown")
	local rm = Minimap._w / 2
	local w, sp = path.icons.winter, path.icons.spring
	local wp, spp = w._point, sp._point
	assert(wp and wp[1] == "CENTER" and wp[2] == Minimap and wp[3] == "CENTER", "icon placed round the minimap")
	assert(wp[4] < 0 and wp[4] < spp[4], "winter at the left, before spring: " .. wp[4] .. ", " .. spp[4])
	assert(wp[5] < -1.15 * rm and spp[5] < -1.15 * rm, "below the minimap and its coordinates")
	assert(w._w > sp._w, "the current season's icon is larger")
	assert(w._desat ~= true and sp._desat == true, "the others are dimmed")
	assert(w._tc and w._tc[3] == 0.5, "wintry icons in a snowbound land (second row)")
	-- hovering it shows the season; leaving hides it
	path._scripts.OnEnter(path)
	assert(GameTooltip._owner == path and GameTooltip._shown, "tooltip on the season arc")
	path._scripts.OnLeave(path)
	assert(GameTooltip._shown == false, "tooltip gone on leave")
end
-- the painted accents follow the season
local decor = ImmerseMeSeasonsRim.decor
assert(decor and tostring(decor._texture):find("decor_snowbound_winter$"), "snowy winter decor: " .. tostring(decor and decor._texture))
-- drifting flakes: one sprite per lane, the engine plays as many as the season asks for
local function playing()
	local n = 0
	for _, t in ipairs(ImmerseMeSeasonsRim.drift) do
		if t._ag:IsPlaying() then assert(t._shown, "a playing sprite is shown"); n = n + 1 end
	end
	return n
end
assert(#ImmerseMeSeasonsRim.drift == #ns.DriftLanes, "a sprite per lane")
assert(playing() == ns.DriftCount.snowbound.winter, "snowy winter flakes: " .. playing())
-- the moves add up to the lane's path: from its start to its end on the rim
do
	local tex, lane = ImmerseMeSeasonsRim.drift[1], ns.DriftLanes[1]
	local R = ImmerseMeSeasonsRim._w / 2 * lane.r
	local sx, sy = 0, 0
	for _, a in ipairs(tex._ag._anims) do
		if a._name == "Translation" then sx, sy = sx + a._offset[1], sy + a._offset[2] end
	end
	local a0, a1 = math.rad(lane.from), math.rad(lane.from + lane.sweep)
	assert(math.abs(sx - R * (math.cos(a1) - math.cos(a0))) < 0.01 and math.abs(sy - R * (math.sin(a1) - math.sin(a0))) < 0.01,
		("moves follow the rim: %.1f, %.1f"):format(sx, sy))
end
assert(decor._w > ImmerseMeSeasonsRim._w, "decor texture is larger than the rim so accents aren't clipped")
local realTime = GetServerTime
GetServerTime = function() return os.time({ year = 2026, month = 10, day = 14, hour = 7, min = 30 }) end
each("OnEvent", "ZONE_CHANGED")
assert(tostring(decor._texture):find("decor_snowbound_autumn$"), "snowy autumn decor: " .. tostring(decor._texture))
assert(playing() == ns.DriftCount.snowbound.autumn, "snowy autumn flakes")
GetRealZoneText = function() return "Elwynn Forest" end; GetZoneText = GetRealZoneText
each("OnEvent", "ZONE_CHANGED_NEW_AREA")
assert(tostring(decor._texture):find("[\\/]decor_autumn$"), "Elwynn autumn decor: " .. tostring(decor._texture))
assert(playing() == ns.DriftCount.temperate.autumn, "Elwynn leaves")
GetRealZoneText = function() return "Dun Morogh" end; GetZoneText = GetRealZoneText
each("OnEvent", "ZONE_CHANGED_NEW_AREA")
GetServerTime = realTime
each("OnEvent", "ZONE_CHANGED")
-- what a /reload needs to carry on is in the saved variables
local mine = ImmerseMeSeasonsDB.chars and ImmerseMeSeasonsDB.chars["Thorin-Realm"]
assert(mine and mine.lastZone == "Dun Morogh", "last zone saved for this character")
assert(mine.resume and mine.resume.zone == "Dun Morogh" and mine.resume.on == true, "frost saved for this character")
-- another character logging in at an inn before the game reports the zone doesn't get Thorin's
UnitName = function() return "Anna" end
GetRealZoneText = function() return "" end; GetZoneText = GetRealZoneText; IsResting = function() return true end
each("OnEvent", "ZONE_CHANGED")
SlashCmdList.IMMERSEMESEASONS("debug")
local annaLine = chat[#chat - 1]
assert(not annaLine:find("Dun Morogh"), "Anna doesn't inherit Thorin's zone: " .. annaLine)
UnitName = function() return "Thorin" end; IsResting = function() return false end
GetRealZoneText = function() return "Dun Morogh" end; GetZoneText = GetRealZoneText
each("OnEvent", "ZONE_CHANGED")
cursor[1] = 500 + 30; each("OnUpdate", 0.1)              -- come onto the rim from the map
cursor[1] = 500 + 75; each("OnUpdate", 0.1)
assert(GameTooltip._owner == ImmerseMeSeasonsRim and GameTooltip._lines > 5, "tooltip on the rim band")
cursor[1] = 500 + 30      -- map interior: tooltip must go
each("OnUpdate", 0.1)
assert(GameTooltip._shown == false, "no tooltip over the map interior")
cursor[1] = 500 + 75; GetMouseFoci = function() return { obj("MinimapZoomIn") } end
GameTooltip._owner = nil; GameTooltip._shown = true
each("OnUpdate", 0.1)
assert(GameTooltip._owner ~= ImmerseMeSeasonsRim, "no rim tooltip over a stock button")
SlashCmdList.IMMERSEMESEASONS("drift off")
assert(playing() == 0, "drift off stops every sprite")
for _, t in ipairs(ImmerseMeSeasonsRim.drift) do assert(not t._shown, "drift off hides every sprite") end
SlashCmdList.IMMERSEMESEASONS("drift on")
assert(playing() == ns.DriftCount.snowbound.winter, "drift on plays again")
SlashCmdList.IMMERSEMESEASONS("hide")
assert(playing() == 0, "hiding the rim stops the drift")
SlashCmdList.IMMERSEMESEASONS("show")
for _, c in ipairs({ "", "emote", "debug", "arc off", "frost off", "time local", "nudge 5 -3", "decor off", "decor on", "drift test", "drift off", "drift on", "hide", "show", "nonsense" }) do
	local before = #chat
	SlashCmdList.IMMERSEMESEASONS(c)
	local usage = chat[before + 1] and chat[before + 1]:find("/ims %- the season")
	assert((c == "nonsense") == (usage and true or false), "/ims " .. c .. " -> " .. tostring(chat[before + 1]))
end
for i = 1, 2000 do each("OnUpdate", 0.1) end   -- let the frost fade run
-- the season arc: "arc off" hid it, "nudge 5 -3" moved it from its place under the minimap
assert(ImmerseMeSeasonsDB.arcX == 5 and ImmerseMeSeasonsDB.arcY == -3, "nudge saved")
local path = ImmerseMeSeasonsYear
assert(path._shown == false, "arc off hides the season arc")
local pp = path._point
assert(pp and pp[1] == "CENTER" and pp[2] == Minimap and pp[4] == 5 and pp[5] < -3 - Minimap._w / 2,
	"season arc under the minimap, nudged")
SlashCmdList.IMMERSEMESEASONS("arc on")
assert(path._shown, "arc on shows it again")
-- a skin that hides the border's parent: Seasons draws its own ring
MinimapCompassTexture._visible = false
SlashCmdList.IMMERSEMESEASONS("debug")
assert(chat[#chat - 1]:find("own ring"), chat[#chat - 1])
MinimapCompassTexture._visible = nil
-- an error inside a refresh is caught, not thrown every minute
local realState = ns.State
ns.State = function() error("boom") end
assert(pcall(each, "OnEvent", "ZONE_CHANGED"), "refresh errors are contained")
ns.State = realState
IsInInstance = function() return true end; GetRealZoneText = function() return "Zul'Farrak" end
local before = #chat
each("OnEvent", "ZONE_CHANGED_NEW_AREA"); SlashCmdList.IMMERSEMESEASONS("debug")
local line = chat[before + 1]
assert(line:find("zone Dun Morogh") and line:find("frost false"), line)
assert(chat[#chat]:find("last error: .*boom"), "debug shows the last refresh error: " .. chat[#chat])
-- the minimap's own buttons stay above the rim, so zoom still shows and clicks
assert(MinimapZoomIn:GetFrameLevel() > ImmerseMeSeasonsRim:GetFrameLevel(), "zoom in above the rim")
assert(MinimapZoomOut:GetFrameLevel() > ImmerseMeSeasonsRim:GetFrameLevel(), "zoom out above the rim")
-- indoors the game hides the round border: the ring stays light, it doesn't turn into a bold own ring
IsInInstance = function() return false end; GetRealZoneText = function() return "Dun Morogh" end
MinimapCompassTexture._visible = false; IsIndoors = function() return true end
each("OnEvent", "ZONE_CHANGED_INDOORS")
assert(ImmerseMeSeasonsRim.ring:GetAlpha() < 1, "light ring indoors, alpha " .. ImmerseMeSeasonsRim.ring:GetAlpha())
print("ui smoke: ok")
