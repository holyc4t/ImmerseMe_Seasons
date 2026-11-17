-- ImmerseMe: Seasons - the minimap rim, its tooltip and the slash commands.
local ADDON, ns = ...

local floor, rad, cos, sin = math.floor, math.rad, math.cos, math.sin

-- Geometry. Must match tools/make_textures.py: the band runs from RING_INNER to 1.0 of the
-- texture's half size, so the frame is sized for the inner edge to sit on the map's edge.
local RING_INNER = 0.90
-- The season arc under the minimap, concentric with it (as in yeararc.tga): radius YEAR_R x the
-- minimap's radius, below the client's coordinates; its texture's half size is YEAR_TEX x that
-- radius. It runs from YEAR_FROM degrees (1 January, lower left) over YEAR_SPAN degrees, between
-- Weather's readout (195-235) and the zoom buttons (298-334).
local YEAR_R, YEAR_TEX = 1.36, 1.45
local YEAR_FROM, YEAR_SPAN = 240, 56
local ICON_NOW, ICON_REST = 0.26, 0.19      -- season icon sizes, x the minimap's radius
local SEASON_CELLS = { winter = 0, spring = 1, summer = 2, autumn = 3 }   -- seasonicons.tga columns;
                                            -- row 0 most lands, row 1 snowbound lands
local RIM_SCALE = 1 / RING_INNER            -- rim frame size / minimap size
local DECOR_SCALE = 1.15                    -- painted accents texture size / rim size (tools/decor.py)
local DRIFT_RIM = 156                       -- rim width (px) the drift sprite sizes in Data.lua are for
local OVER_STOCK_ALPHA = 0.55               -- ring over the stock gold border
local FROST_FADE = 180                      -- seconds to fade frost in or out
local FROST_ALPHA = 0.55                    -- full frost: light enough for the bronze to show through
local MORPH = 3                             -- seconds of transition when you arrive in another land
local REFRESH = 60                          -- seconds between refreshes

local DEFAULTS = {
	show      = true,
	arc       = true,
	frost     = true,
	decor     = true,     -- the painted seasonal accents (leaves, blossoms, sun, snow)
	drift     = true,     -- snowflakes, leaves and petals drifting along the rim
	localTime = false,    -- false = realm time (matches the in-game sky), true = your PC clock
	arcX      = 0,        -- nudge the season arc (pixels)
	arcY      = 0,
}
local db

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ImmerseMe: Seasons|r " .. msg)
end

---------------------------------------------------------------------------
-- What the world is doing (copied from ImmerseMe_Weather/UI.lua)
---------------------------------------------------------------------------
local function GetHour()
	local h, m
	if not db.localTime and GetGameTime then
		h, m = GetGameTime()
	end
	if not h then
		local d = date("*t")
		h, m = d.hour, d.min
	end
	return h + m / 60, h, m
end

-- What the game is really doing, on clients that can tell (C_Weather):
-- { kind = "clear" | "rain" | "snow" | "sandstorm" | ..., intensity = number }, or nil.
local function GameWeather()
	if not (C_Weather and C_Weather.GetCurrentWeather and Enum and Enum.WeatherType) then return nil end
	local ok, info = pcall(C_Weather.GetCurrentWeather)
	if not ok or type(info) ~= "table" then return nil end
	local kind, intensity = info.type, info.intensity
	if issecretvalue and (issecretvalue(kind) or issecretvalue(intensity)) then return nil end
	if type(kind) ~= "number" then return nil end
	for name, id in pairs(Enum.WeatherType) do
		if id == kind then
			name = name:lower()
			if name == "none" then name = "clear" end     -- whichever the client calls a dry sky
			return { kind = name, intensity = type(intensity) == "number" and intensity or 0 }
		end
	end
end

local function ZoneNames()
	local names = {}
	local function add(name)
		if type(name) == "string" and name ~= "" then names[#names + 1] = name end
	end
	add(GetRealZoneText and GetRealZoneText())
	add(GetZoneText and GetZoneText())
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
		local id, depth = C_Map.GetBestMapForUnit("player"), 0
		while id and id ~= 0 and depth < 6 do
			local info = C_Map.GetMapInfo(id)
			if type(info) ~= "table" then break end
			add(info.name)
			id, depth = info.parentMapID, depth + 1
		end
	end
	return names
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- What survives a /reload lives in the saved variables, per character (ns.CharMemo): lastZone
-- (ResolveZone's last outdoor zone, so an instance keeps its land's season) and resume (the frost
-- at the last refresh).
local prevFrost          -- frost at the last refresh in this session
local state

local function Compute()
	local hour = GetHour()
	local t = (GetServerTime and GetServerTime()) or time()
	local inInstance = IsInInstance and IsInInstance() or false
	local roofed = (IsIndoors and IsIndoors()) or (IsResting and IsResting()) or false
	local who = ((UnitName and UnitName("player")) or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?")
	local memo = ns.CharMemo(db, who)
	local zone = ns.ResolveZone(ZoneNames(), inInstance, roofed, memo)
	local climateKey = ns.ClimateFor(zone, inInstance)
	local opts = { instance = inInstance, weather = GameWeather() }
	-- a new zone starts afresh: its frost doesn't carry over from the last one
	if state and state.zone ~= zone then prevFrost = nil end
	-- just logged in or reloaded: carry on from the saved frost if it is recent and for this zone
	if not state and prevFrost == nil then prevFrost = ns.ResumeFrost(memo.resume, zone, t) end
	local s = ns.State(zone, climateKey, t, hour, opts, prevFrost)
	prevFrost = s.frost
	memo.resume = { zone = zone, t = t, on = s.frost }
	s.zone = zone
	return s
end

---------------------------------------------------------------------------
-- The rim
---------------------------------------------------------------------------
local rim = CreateFrame("Frame", "ImmerseMeSeasonsRim", Minimap)
rim:SetPoint("CENTER", Minimap, "CENTER")
rim:EnableMouse(false)                       -- never takes clicks, pings or zoom from the map
rim:SetFrameLevel(Minimap:GetFrameLevel() + 5)

local ring = rim:CreateTexture(nil, "ARTWORK")
ring:SetTexture(ns.MEDIA .. "ring")
ring:SetAllPoints()

local frost = rim:CreateTexture(nil, "OVERLAY", nil, 0)
frost:SetTexture(ns.MEDIA .. "frost")
frost:SetAllPoints()
frost:SetAlpha(0)

-- painted seasonal accents: full colour, never tinted, above the frost (snow lies on the rime)
local decor = rim:CreateTexture(nil, "OVERLAY", nil, 1)
decor:SetPoint("CENTER", rim, "CENTER")
-- the painting being left behind, fading out while the new one fades in (see the transition)
local decorOld = rim:CreateTexture(nil, "OVERLAY", nil, 1)
decorOld:SetPoint("CENTER", rim, "CENTER")
decorOld:Hide()
rim.decorOld = decorOld
rim.ring, rim.frost, rim.decor = ring, frost, decor

-- Drift: one small sprite per lane (Data.lua). Each has a looping animation of DRIFT_STEPS short
-- straight moves that together follow the rim's curve, a gentle spin and a fade in and out. The
-- game engine plays it: no Lua runs per frame or per pass. Lua only starts and stops lanes when
-- the season or the land changes, and re-measures the moves when the minimap changes size.
-- (A rotation around the minimap's centre would be one animation, but on a texture this client
-- turns the image inside its own box, so the sprite drew nothing.)
local DRIFT_STEPS = 6
local function BuildDrift()
	rim.drift = {}
	for i, lane in ipairs(ns.DriftLanes) do
		local tex = rim:CreateTexture(nil, "OVERLAY", nil, 1)
		tex:Hide()
		if not tex.CreateAnimationGroup then return end      -- no animations here: no drift
		tex:SetTexture(ns.MEDIA .. "drift")
		local ag = tex:CreateAnimationGroup()
		ag:SetLooping("REPEAT")
		local step = lane.dur / DRIFT_STEPS
		tex.moves = {}
		for k = 1, DRIFT_STEPS do
			local move = ag:CreateAnimation("Translation")
			move:SetOrder(k)
			move:SetDuration(step)
			tex.moves[k] = move
			local spin = ag:CreateAnimation("Rotation")        -- tumble round its own centre
			spin:SetOrder(k)
			spin:SetDuration(step)
			spin:SetDegrees(lane.sweep < 0 and -25 or 25)
		end
		local fadeIn = ag:CreateAnimation("Alpha")
		fadeIn:SetOrder(1)
		fadeIn:SetFromAlpha(0)
		fadeIn:SetToAlpha(1)
		fadeIn:SetDuration(step)
		local fadeOut = ag:CreateAnimation("Alpha")
		fadeOut:SetOrder(DRIFT_STEPS)
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0)
		fadeOut:SetDuration(step)
		tex.ag, tex.lane = ag, lane
		rim.drift[i] = tex
	end
end
BuildDrift()

local function LayoutDrift(size)
	local R = size / 2
	for _, tex in ipairs(rim.drift) do
		local lane = tex.lane
		local function at(k)                                  -- point k of the lane's path
			local a = rad(lane.from + lane.sweep * k / DRIFT_STEPS)
			return R * lane.r * cos(a), R * lane.r * sin(a)
		end
		local x, y = at(0)
		local px = lane.size * size / DRIFT_RIM
		tex:SetSize(px, px)
		tex:ClearAllPoints()
		tex:SetPoint("CENTER", rim, "CENTER", x, y)
		for k, move in ipairs(tex.moves) do
			local x2, y2 = at(k)
			move:SetOffset(x2 - x, y2 - y)
			x, y = x2, y2
		end
	end
end

local driftKey, driftGen = nil, 0
local function StopDrift()
	driftGen = driftGen + 1          -- lanes still waiting for their start delay won't start
	driftKey = nil
	for _, tex in ipairs(rim.drift) do
		tex.on = false
		tex.ag:Stop()
		tex:Hide()
	end
end

local function DrawDrift(s)
	local kinds = ns.DriftKind[s.style]
	local kind = db.drift and kinds and kinds[s.season]
	local key = kind and (s.style .. s.season) or nil
	if key ~= driftKey then StopDrift() end
	if not key then return end
	driftKey = key
	local count = ns.DriftCount[s.style][s.season] or 0
	local cell = ns.DRIFT_CELLS[kind] - 1                    -- 2x2 atlas
	local col, row = cell % 2, floor(cell / 2)
	for i, tex in ipairs(rim.drift) do
		if i <= count and not tex.on then
			tex.on = true
			tex:SetTexCoord(col / 2, (col + 1) / 2, row / 2, (row + 1) / 2)
			local c = kind == "leaf" and ns.LEAF_COLORS[(i - 1) % #ns.LEAF_COLORS + 1] or { 1, 1, 1 }
			tex:SetVertexColor(c[1], c[2], c[3])
			local gen = driftGen
			local function start()
				if gen ~= driftGen or not tex.on then return end
				tex:Show()
				tex.ag:Play()
			end
			-- lanes start a little apart so they never move in step (a one-off timer, not per frame)
			if tex.lane.delay > 0 and C_Timer and C_Timer.After then C_Timer.After(tex.lane.delay, start) else start() end
		end
	end
end

-- The season arc: a bronze line hugging the minimap's bottom, from 1 January (left) to 31 December
-- (right), with the four season icons on it. The current season's icon is bright and larger and
-- stands where today is; the others rest, dimmed, in the middle of their seasons. Festival notches
-- sit on it too. The frame covers the arc so hovering it shows the season; it belongs to the rim,
-- so /ims hide hides it as well.
local path = CreateFrame("Frame", "ImmerseMeSeasonsYear", rim)
path:SetFrameLevel(rim:GetFrameLevel() + 1)
path:EnableMouse(true)                       -- only for its tooltip; it lies below the map
local line = path:CreateTexture(nil, "ARTWORK")
line:SetTexture(ns.MEDIA .. "yeararc")
path.line, path.icons = line, {}
for season, cell in pairs(SEASON_CELLS) do
	local icon = path:CreateTexture(nil, "OVERLAY", nil, 2)
	icon:SetTexture(ns.MEDIA .. "seasonicons")
	icon.cell = cell
	path.icons[season] = icon
end

local notches = {}

-- The stock round border, if this client and the player's UI have one showing.
local function StockBorder()
	for _, name in ipairs({ "MinimapCompassTexture", "MinimapBorder" }) do
		local tex = _G[name]
		-- IsVisible: a skin may hide the border's parent rather than the border itself
		if type(tex) == "table" and tex.IsVisible and tex:IsVisible() then return tex, name end
	end
end

-- The minimap's own buttons sit on the rim; keep them above it so they show and take clicks.
local STOCK_BUTTONS = { "MinimapZoomIn", "MinimapZoomOut", "MiniMapTracking", "MiniMapTrackingFrame",
	"MiniMapMailFrame", "MiniMapBattlefieldFrame", "MinimapToggleButton" }
local function RaiseStockButtons()
	local above = rim:GetFrameLevel() + 2
	for _, name in ipairs(STOCK_BUTTONS) do
		local b = _G[name]
		if type(b) == "table" and b.GetFrameLevel and b:GetFrameLevel() < above then b:SetFrameLevel(above) end
	end
end

local function Layout()
	local size = Minimap:GetWidth() * RIM_SCALE
	rim:SetSize(size, size)
	decor:SetSize(size * DECOR_SCALE, size * DECOR_SCALE)
	decorOld:SetSize(size * DECOR_SCALE, size * DECOR_SCALE)
	LayoutDrift(size)
	-- the season arc, round the minimap's centre (db.arcX / arcY: /ims nudge)
	local rm = Minimap:GetWidth() / 2
	line:SetSize(2 * YEAR_TEX * rm, 2 * YEAR_TEX * rm)
	line:ClearAllPoints()
	line:SetPoint("CENTER", Minimap, "CENTER", db.arcX, db.arcY)
	-- the hover area: the arc's bounding box, with room for the icons
	local R, icon = YEAR_R * rm, ICON_NOW * rm
	local lo, hi = rad(YEAR_FROM), rad(YEAR_FROM + YEAR_SPAN)
	local yTop = math.max(sin(lo), sin(hi)) * R + icon / 2
	local yBottom = -R - icon / 2
	path:SetSize(2 * math.max(math.abs(cos(lo)), math.abs(cos(hi))) * R + icon, yTop - yBottom)
	path:ClearAllPoints()
	path:SetPoint("CENTER", Minimap, "CENTER", db.arcX, (yTop + yBottom) / 2 + db.arcY)
end

-- Places a texture on the season arc at year fraction f (0 = 1 January, 1 = 31 December).
local function OnYear(tex, f)
	local a = rad(YEAR_FROM + f * YEAR_SPAN)
	local R = YEAR_R * Minimap:GetWidth() / 2
	tex:ClearAllPoints()
	tex:SetPoint("CENTER", Minimap, "CENTER", R * cos(a) + db.arcX, R * sin(a) + db.arcY)
end

local function Notch(i)
	local n = notches[i]
	if not n then
		n = path:CreateTexture(nil, "OVERLAY", nil, 1)
		n:SetTexture(ns.MEDIA .. "notch")
		n:SetVertexColor(1, 0.82, 0.3)
		notches[i] = n
	end
	local px = 0.08 * Minimap:GetWidth()
	n:SetSize(px, px)
	return n
end

-- The transition when you arrive in another land: over MORPH seconds the rim's colour slides to the
-- new land's, the old painting fades into the new one and the frost thaws or creeps in ("the
-- season freezes"). It runs only during those seconds; a login or /reload shows the land at once.
local shownTint, shownArc            -- the rim's and the season arc's colours on screen now
local morph = CreateFrame("Frame")
morph:Hide()
local function lerp(a, b, t) return a + (b - a) * t end
morph:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + elapsed
	local p = math.min(1, self.t / MORPH)
	local e = p * p * (3 - 2 * p)
	local f, to = self.fromTint, self.toTint
	shownTint = { lerp(f[1], to[1], e), lerp(f[2], to[2], e), lerp(f[3], to[3], e) }
	ring:SetVertexColor(shownTint[1], shownTint[2], shownTint[3])
	local fa, ta = self.fromArc, self.toArc
	shownArc = { lerp(fa[1], ta[1], e), lerp(fa[2], ta[2], e), lerp(fa[3], ta[3], e) }
	path.line:SetVertexColor(shownArc[1], shownArc[2], shownArc[3])
	frost:SetAlpha(lerp(self.fromFrost, self.toFrost, e))
	decor:SetAlpha(e)
	decorOld:SetAlpha(1 - e)
	if p >= 1 then
		ring:SetVertexColor(to[1], to[2], to[3])
		path.line:SetVertexColor(ta[1], ta[2], ta[3])
		frost:SetAlpha(self.toFrost)
		decor:SetAlpha(1)
		decorOld:Hide()
		self:Hide()
	end
end)

local frostTarget, pulse = 0, 0
local fader = CreateFrame("Frame")
fader:Hide()
fader:SetScript("OnUpdate", function(self, elapsed)
	local a = frost:GetAlpha()
	if not morph:IsShown() then          -- the transition owns the frost while it runs
		local step = elapsed / FROST_FADE
		if a < frostTarget then a = math.min(frostTarget, a + step) else a = math.max(frostTarget, a - step) end
		frost:SetAlpha(a)
	end
	-- festivals on now glow gently
	pulse = pulse + elapsed
	local glow = 0.65 + 0.35 * sin(pulse * 1.5)
	local any = false
	for _, n in ipairs(notches) do
		if n.active and n:IsShown() then n:SetAlpha(glow) any = true end
	end
	if a == frostTarget and not any then self:Hide() end
end)

local drawnZone          -- the zone of the last draw: nil until the first draw after a login or /reload,
                         -- which shows everything at once; a new zone plays the transition; frost
                         -- forming or lifting where you stand fades slowly

local function Draw(s)
	if not db.show then StopDrift() rim:Hide() return end
	rim:Show()
	Layout()
	RaiseStockButtons()
	-- indoors the game hides the round border; it is still the stock minimap, so keep the light ring
	local stock = StockBorder() or (IsIndoors and IsIndoors())
	ring:SetAlpha(stock and OVER_STOCK_ALPHA or 1)
	local arriving = drawnZone ~= nil and drawnZone ~= s.zone
	frostTarget = (db.frost and s.frost) and FROST_ALPHA or 0
	local arcTint = ns.ArcTints[s.style] or ns.ArcTints.temperate

	-- snowbound lands have their own paintings
	local key = (s.style == "snowbound" and "snowbound_" or "") .. s.season
	if decor.key ~= key then
		if arriving and decor.key and db.decor then
			decorOld:SetTexture(ns.MEDIA .. "decor_" .. decor.key)
			decorOld:SetAlpha(1)
			decorOld:Show()
			decor:SetAlpha(0)
		end
		decor:SetTexture(ns.MEDIA .. "decor_" .. key)
		decor.key = key
	end
	decor:SetShown(db.decor)
	DrawDrift(s)

	if arriving then
		-- a new land: colour, painting and frost move over together
		morph.t = 0
		morph.fromTint = shownTint or s.tint
		morph.toTint = s.tint
		morph.fromArc, morph.toArc = shownArc or arcTint, arcTint
		morph.fromFrost, morph.toFrost = frost:GetAlpha(), frostTarget
		morph:Show()
	elseif morph:IsShown() then
		morph.toTint, morph.toFrost, morph.toArc = s.tint, frostTarget, arcTint   -- still on the way
	else
		shownTint, shownArc = s.tint, arcTint
		ring:SetVertexColor(s.tint[1], s.tint[2], s.tint[3])
		path.line:SetVertexColor(arcTint[1], arcTint[2], arcTint[3])
		if drawnZone == nil then
			frost:SetAlpha(frostTarget)      -- after a login or /reload the land is simply there
		elseif frost:GetAlpha() ~= frostTarget then
			fader:Show()
		end
	end
	drawnZone = s.zone

	path:SetShown(db.arc)
	-- the season's own icon stands where today is, bright; the others rest, dimmed, mid-season
	local rm, marks = Minimap:GetWidth() / 2, ns.SeasonMarks(s.date.year)
	local row = s.style == "snowbound" and 1 or 0         -- wintry icons in snowbound lands
	for season, icon in pairs(path.icons) do
		local now = season == s.season
		icon:SetTexCoord(icon.cell / 4, (icon.cell + 1) / 4, row / 2, (row + 1) / 2)
		local px = (now and ICON_NOW or ICON_REST) * rm
		icon:SetSize(px, px)
		OnYear(icon, now and s.arc or marks.icons[season])
		icon:SetDrawLayer("OVERLAY", now and 3 or 2)
		if icon.SetDesaturated then icon:SetDesaturated(not now) end
		local v = now and 1 or 0.8
		icon:SetVertexColor(v, v, v)
		icon:SetAlpha(now and 1 or 0.85)
	end

	local active = {}
	for _, f in ipairs(s.festivals) do if f.active then active[f.key] = true end end
	for i, n in ipairs(s.notches) do
		local tex = Notch(i)
		OnYear(tex, n.frac)
		tex.active = active[n.key] or false
		tex:SetAlpha(1)
		tex:Show()
		if tex.active then fader:Show() end
	end
	for i = #s.notches + 1, #notches do notches[i]:Hide() end
end

---------------------------------------------------------------------------
-- Tooltip: shown while the cursor is on the rim band. Nothing here takes the mouse: we only
-- look at where the cursor is and what it is over, so the map keeps every click and the
-- stock minimap buttons keep their own tooltips.
---------------------------------------------------------------------------
local function ShowTooltip(owner)
	if not state then return end
	GameTooltip:SetOwner(owner or rim, "ANCHOR_BOTTOMLEFT")
	for _, l in ipairs(ns.TooltipLines(state)) do
		if l.gap then GameTooltip:AddLine(" ") end
		GameTooltip:AddLine(l.text, l.r, l.g, l.b, true)
	end
	GameTooltip:Show()
end

local function MouseFocus()
	if GetMouseFoci then
		local foci = GetMouseFoci()
		return foci and foci[1]
	end
	return GetMouseFocus and GetMouseFocus()
end

-- Is the cursor on the rim band, over nothing but the map or the world?
local function OverRim()
	if not rim:IsVisible() then return false end
	local x, y = GetCursorPosition()
	local scale = rim:GetEffectiveScale()
	local cx, cy = rim:GetCenter()
	if not cx then return false end
	local half = rim:GetWidth() / 2
	local d = math.sqrt((x / scale - cx) ^ 2 + (y / scale - cy) ^ 2)
	if d < half * RING_INNER - 2 or d > half then return false end
	local focus = MouseFocus()
	return focus == nil or focus == Minimap or focus == WorldFrame or focus == MinimapCluster
		or focus == (MinimapBackdrop or false)
end

local hovering, sinceCheck = false, 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, elapsed)
	sinceCheck = sinceCheck + elapsed
	if sinceCheck < 0.05 then return end
	sinceCheck = 0
	local over = OverRim()
	if over and not hovering then
		hovering = true
		ShowTooltip()
	elseif not over and hovering then
		hovering = false
		if GameTooltip:GetOwner() == rim then GameTooltip:Hide() end
	end
end)

-- the season arc is its own hover target: the line and the icons on it
path:SetScript("OnEnter", function(self) ShowTooltip(self) end)
path:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
local function RefreshNow()
	state = Compute()
	Draw(state)
	local owner = GameTooltip:GetOwner()
	if (hovering and owner == rim) or (owner == path and GameTooltip:IsShown()) then ShowTooltip(owner) end
end

-- Like Weather's SafeRefresh: an error is reported once, not thrown again every minute.
local reported, lastError = false, nil
local function Refresh()
	if not db then return end
	local ok, err = pcall(RefreshNow)
	if not ok then lastError = tostring(err) end
	if not ok and not reported then
		reported = true
		Print("|cffff6060something went wrong:|r " .. tostring(err))
	end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local USAGE = {
	"/ims - the season, the date, the sun and the next festival",
	"/ims emote - share the season as an emote",
	"/ims show | hide - turn the rim on or off",
	"/ims arc on | off - the season arc under the minimap (the year, its seasons and festivals)",
	"/ims frost on | off - the frost on cold mornings",
	"/ims decor on | off - the painted leaves, blossoms, sun and snow",
	"/ims drift on | off - snowflakes and leaves drifting along the rim",
	"/ims time realm | local - which clock decides the morning",
	"/ims nudge <x> <y> - move the season arc by pixels (0 0 resets)",
	"/ims debug - what the addon sees (zone, border, frost)",
}

local function OnOff(v)
	if v == "on" then return true end
	if v == "off" then return false end
	return nil
end

local function Command(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if not state then Refresh() end
	if not state then Print("not ready yet.") return end
	if cmd == "" then
		for _, l in ipairs(ns.TooltipLines(state)) do
			DEFAULT_CHAT_FRAME:AddMessage(l.text, l.r, l.g, l.b)
		end
	elseif cmd == "emote" then
		local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
		send(ns.EmoteText(state), "EMOTE")
	elseif cmd == "show" or cmd == "hide" then
		db.show = cmd == "show"
		Print(db.show and "The rim shows the season." or "The rim is back to normal.")
	elseif cmd == "arc" and OnOff(arg) ~= nil then
		db.arc = OnOff(arg)
		Print(db.arc and "Season arc on." or "Season arc off.")
	elseif cmd == "frost" and OnOff(arg) ~= nil then
		db.frost = OnOff(arg)
		Print(db.frost and "Frost on." or "Frost off.")
	elseif cmd == "decor" and OnOff(arg) ~= nil then
		db.decor = OnOff(arg)
		Print(db.decor and "Seasonal decorations on." or "Seasonal decorations off.")
	elseif cmd == "drift" and arg == "test" then
		-- until the next refresh (a minute at most): every lane big and red, to see where they go.
		-- Lane 1 stands still, so a missing sprite can be told apart from a broken animation.
		StopDrift()                      -- the next refresh starts the normal drift afresh
		for i, tex in ipairs(rim.drift) do
			tex:SetVertexColor(1, 0.1, 0.1)
			tex:SetSize(32, 32)
			tex:Show()
			if i > 1 then tex.ag:Play() end
		end
		Print("Drift test: sprites are big and red until the next refresh; the first one stands still.")
		return
	elseif cmd == "drift" and OnOff(arg) ~= nil then
		db.drift = OnOff(arg)
		Print(db.drift and "Drifting flakes and leaves on." or "Drifting flakes and leaves off.")
	elseif cmd == "time" and (arg == "realm" or arg == "local") then
		db.localTime = arg == "local"
		Print("Mornings now follow " .. (db.localTime and "your local clock." or "realm time."))
	elseif cmd == "nudge" and arg:match("^%-?%d+%s+%-?%d+$") then
		local x, y = arg:match("^(%-?%d+)%s+(%-?%d+)$")
		db.arcX, db.arcY = math.max(-60, math.min(60, tonumber(x))), math.max(-60, math.min(60, tonumber(y)))
		Print(("Season arc moved to %d, %d."):format(db.arcX, db.arcY))
	elseif cmd == "debug" then
		local _, border = StockBorder()
		local drifting = 0
		for _, tex in ipairs(rim.drift) do if tex.on then drifting = drifting + 1 end end
		Print(("zone %s (%s), %s, frost %s, drift %d, border %s, minimap %d px"):format(
			tostring(state.zone), state.style, state.seasonName, tostring(state.frost), drifting,
			border or "none (own ring)", floor(Minimap:GetWidth())))
		-- each drift sprite: shown / playing, alpha, where it sits now
		local parts = {}
		for i, tex in ipairs(rim.drift) do
			local _, _, _, x, y = tex:GetPoint(1)
			parts[#parts + 1] = ("%d:%s%s a%.1f @%d,%d"):format(i, tex:IsVisible() and "V" or "-",
				tex.ag:IsPlaying() and "P" or "-", tex:GetAlpha(), floor((x or 0) + 0.5), floor((y or 0) + 0.5))
		end
		Print(("decor %s, lanes %d/%d, %s"):format(tostring(rim.decor.key), #rim.drift, #ns.DriftLanes,
			#parts > 0 and table.concat(parts, "  ") or "no sprites"))
		if lastError then Print("last error: " .. lastError) end
	else
		for _, l in ipairs(USAGE) do Print(l) end
		return
	end
	Refresh()
end

SLASH_IMMERSEMESEASONS1, SLASH_IMMERSEMESEASONS2 = "/ims", "/seasons"
SlashCmdList.IMMERSEMESEASONS = Command

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		ImmerseMeSeasonsDB = ImmerseMeSeasonsDB or {}
		db = ImmerseMeSeasonsDB
		for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
		if C_Timer and C_Timer.NewTicker then
			C_Timer.NewTicker(REFRESH, Refresh)
		else
			local acc = 0
			events:SetScript("OnUpdate", function(_, e) acc = acc + e if acc >= REFRESH then acc = 0 Refresh() end end)
		end
		return
	end
	Refresh()
	-- at login the game may not know the zone yet: look again once it has settled
	if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then C_Timer.After(3, Refresh) end
end)

Minimap:HookScript("OnSizeChanged", function() if state then Draw(state) end end)
