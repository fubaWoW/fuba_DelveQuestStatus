local addonName = ...

local LDB = LibStub("LibDataBroker-1.1")
local IconDB = LibStub("LibDBIcon-1.0")
local minimapDB
local wasVisibleBeforeCombat = false

--------------------------------------------------
-- Delve Quest UI (Midnight) 
--------------------------------------------------
local delveQuests = {
    { id=93384, name="Delver's Call: Collegiate Calamity", map=2393, x=0.40798, y=0.54153 },
	{ id=93385, name="Delver's Call: The Darkway", map=2393, x=0.39300, y=0.32100 },
    { id=93372, name="Delver's Call: Shadow Enclave", map=2395, x=0.45458, y=0.85998 },
    { id=93409, name="Delver's Call: Atal'Aman", map=2437, x=0.24802, y=0.52947 },
    { id=93410, name="Delver's Call: Twilight Crypts", map=2437, x=0.25411, y=0.84398 },
    { id=93416, name="Delver's Call: The Gulf of Memory", map=2413, x=0.36273, y=0.49133 },
	{ id=93421, name="Delver's Call: The Grudge Pit", map=2413, x=0.70480, y=0.64920 },    
    { id=93428, name="Delver's Call: Shadowguard Point", map=2405, x=0.37197, y=0.48999 },
	{ id=93427, name="Delver's Call: Sunkiller Sanctum", map=2405, x=0.54802, y=0.47122 },
	--	{ id=93386, name="Delver's Call: Parhelion Plaza", map=2424, x=0.47740, y=0.41580 },
}

--------------------------------------------------
-- Default Settings
--------------------------------------------------

local function ApplyDefaults(src, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            src[k] = src[k] or {}
            ApplyDefaults(src[k], v)
        else
            if src[k] == nil then
                src[k] = v
            end
        end
    end
end

local defaults = {
    minimap = {
        hide = false,
    },
}

--------------------------------------------------
-- Layout constants
--------------------------------------------------

local paddingX = 20
local paddingY = 20
local columnGap = 10

local nameColumnWidth = 240
local statusColumnWidth = 100
local buttonColumnWidth = 120

local rowHeight = 28

local headerHeight = 40
local headerLineOffset = 14
local rowStartOffset = 26

local maxFrameWidth = 1280
local maxFrameHeight = 720

local pingTex = "Interface\\AddOns\\" .. addonName .. "\\Media\\Ping.tga"
local questionMarkTex = "Interface\\AddOns\\" .. addonName .. "\\Media\\QuestionMark.tga"

--------------------------------------------------
-- Dynamic size calculation
--------------------------------------------------

local rowCount = #delveQuests

local frameWidth =
    paddingX*2 +
    nameColumnWidth +
    statusColumnWidth +
    buttonColumnWidth +
    columnGap*2

frameWidth = math.min(frameWidth, maxFrameWidth)

local frameHeight =
    paddingY*2 +
    headerHeight +
    (rowCount * rowHeight)

frameHeight = math.min(frameHeight, maxFrameHeight)

--------------------------------------------------
-- Helper
--------------------------------------------------

local function GetQuestStatus(id)

    if C_QuestLog.IsOnQuest(id) then
        return "|cff8888ffActive|r"
    elseif C_QuestLog.IsQuestFlaggedCompleted(id) then
        return "|cff00ff00Done|r"
    else
        return "|cffff5555Need|r"
    end

end

--------------------------------------------------
-- Ring / Ripple Animation
--------------------------------------------------

local pingOverlay    = nil
local pingGeneration = 0

local numRipples  = 4
local rippleDelay = 0.25
local duration    = 1.2
local ringSize    = 60

local colors = {
    { 0.2, 1.0, 0.3 },   -- green
    { 1.0, 1.0, 0.2 },   -- yellow
    { 1.0, 0.5, 0.0 },   -- orange
    { 1.0, 0.2, 0.2 },   -- red
}

local function lerpColor(ca, cb, f)
    return
        ca[1] + (cb[1] - ca[1]) * f,
        ca[2] + (cb[2] - ca[2]) * f,
        ca[3] + (cb[3] - ca[3]) * f
end

local function colorAt(t)
    local pos = (t / duration) * #colors
    local i   = math.floor(pos) % #colors
    local c1  = colors[i + 1]
    local c2  = colors[(i + 1) % #colors + 1]
    return lerpColor(c1, c2, pos % 1)
end

local function applyRing(frame, t)
    if t < 0 then
        frame:SetSize(ringSize * 0.05, ringSize * 0.05)
        frame:SetAlpha(0)
        return
    end
    local p       = math.min(1, t / duration)
    local easeOut = 1 - (1 - p) * (1 - p)
    local size    = (ringSize * 0.05) + (ringSize * 0.95) * easeOut
    frame:SetSize(size, size)
    frame:SetAlpha(1 - easeOut)
    local r, g, b = colorAt(t)
    frame.pingTex:SetVertexColor(r, g, b, 1)
end

local function ShowRipple(px, py)

    -- Create all frames once
    if not pingOverlay then

        pingOverlay = CreateFrame("Frame", nil, UIParent)
        pingOverlay:SetSize(ringSize, ringSize)
        pingOverlay:SetFrameStrata("TOOLTIP")
        pingOverlay:SetFrameLevel(2017)
        pingOverlay:SetScale(1)

        local t = pingOverlay:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture(pingTex)
        pingOverlay.pingTex = t

        pingOverlay.rippleFrames = {}
        for i = 2, numRipples do
            local rf = CreateFrame("Frame", nil, UIParent)
            rf:SetSize(ringSize, ringSize)
            rf:SetFrameStrata("TOOLTIP")
            rf:SetFrameLevel(2017 - i)
            rf:SetScale(1)

            local rt = rf:CreateTexture(nil, "OVERLAY")
            rt:SetAllPoints()
            rt:SetTexture(pingTex)
            rf.pingTex = rt

            pingOverlay.rippleFrames[i] = rf
        end

    end

    -- Position all rings on the given screen coordinates
    local function placeFrame(f)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px, py)
    end

    placeFrame(pingOverlay)
    for i = 2, numRipples do
        placeFrame(pingOverlay.rippleFrames[i])
    end

    -- Reset all to invisible/tiny before starting
    pingGeneration = pingGeneration + 1
    local currentGen = pingGeneration

    pingOverlay:SetSize(ringSize * 0.05, ringSize * 0.05)
    pingOverlay:SetAlpha(0)
    pingOverlay:Show()

    for i = 2, numRipples do
        local rf = pingOverlay.rippleFrames[i]
        rf:SetSize(ringSize * 0.05, ringSize * 0.05)
        rf:SetAlpha(0)
        rf:Show()
    end

    -- Run animation via OnUpdate
    pingOverlay.animStartTime = GetTime()
    pingOverlay:SetScript("OnUpdate", function(self)

        local t = GetTime() - self.animStartTime

        for i = 1, numRipples do
            local f  = (i == 1) and self or self.rippleFrames[i]
            local ti = t - (i - 1) * rippleDelay
            applyRing(f, ti)
        end

        if t >= (numRipples - 1) * rippleDelay + duration then
            self:SetScript("OnUpdate", nil)
            if currentGen == pingGeneration then
                self:Hide()
                for i = 2, numRipples do
                    self.rippleFrames[i]:Hide()
                end
            end
        end

    end)

end

local function SetWaypoint(map, x, y)

	if InCombatLockdown and InCombatLockdown() then
		-- Notify the user why the waypoint cannot be set during combat
		UIErrorsFrame:AddMessage("Waypoint cannot be set during combat.", 1, 0.3, 0.3)
		return
	end

    -- Ensure the World Map is visible.
    -- The Delve entrance pins only exist when the map is open.
    if (not WorldMapFrame:IsShown()) then
		C_Map.OpenWorldMap(map)
    end

    -- Switch the map to the zone where the Delve entrance is located.
    WorldMapFrame:SetMapID(map)

	C_Timer.After(0, function()
		local bestPin
		local bestDist

		-- Iterate over all Delve entrance pins currently visible on the map.
		-- "DelveEntrancePinTemplate" is the Blizzard template used for Delve POIs.
		for pin in WorldMapFrame:EnumeratePinsByTemplate("DelveEntrancePinTemplate") do

			-- Get the normalized map position of the pin (0-1 range).
			local px, py = pin:GetPosition()

			-- Calculate squared distance between the pin and the target coordinates.
			-- Squared distance is used to avoid the cost of sqrt(), since we only
			-- need to compare relative distances.
			local dist = (px - x)^2 + (py - y)^2

			-- Keep the pin with the smallest distance.
			-- This effectively finds the Delve entrance closest to our stored coordinates.
			if not bestDist or dist < bestDist then
				bestDist = dist
				bestPin = pin
			end

		end

		if bestPin and bestPin.OnClick then

			-- Always clear supertracking before clicking to prevent toggle behaviour.
			-- OnClick toggles the waypoint if the pin is already supertracked,
			-- so we reset first to ensure it always sets a fresh waypoint.
			C_SuperTrack.ClearAllSuperTracked()

			-- Wait one frame so Blizzard can process the clear before OnClick.
			C_Timer.After(0, function()
				bestPin:OnClick("LeftButton")
				C_Timer.After(0.1, function()
					local px, py = bestPin:GetCenter()
					if px and py then
						ShowRipple(px, py)
					end
				end)
			end)

		else

			-- Fallback: if no Delve pin was found (e.g. map data not loaded yet),
			-- create a standard Blizzard user waypoint at the stored coordinates.
			C_Map.SetUserWaypoint({
				uiMapID = map,
				position = CreateVector2D(x, y)
			})

			-- Enable Blizzard navigation arrow towards the waypoint.
			C_SuperTrack.SetSuperTrackedUserWaypoint(true)

			-- Convert normalized map coordinates to screen pixels for ShowRipple.
			-- Both scales must be normalized against each other to get correct pixels.
			C_Timer.After(0.1, function()
				local canvas  = WorldMapFrame:GetCanvas()
				local scale   = canvas:GetEffectiveScale()
				local uiScale = UIParent:GetEffectiveScale()

				local canvasLeft   = canvas:GetLeft()   * scale / uiScale
				local canvasBottom = canvas:GetBottom() * scale / uiScale
				local canvasWidth  = canvas:GetWidth()  * scale / uiScale
				local canvasHeight = canvas:GetHeight() * scale / uiScale

				local sx = canvasLeft   + x * canvasWidth
				local sy = canvasBottom + (1 - y) * canvasHeight

				ShowRipple(sx, sy)
			end)

		end
	end)

end

--------------------------------------------------
-- UI Frame
--------------------------------------------------

local frame = CreateFrame("Frame","fuba_DelveQuestStatusMidnightFrame",UIParent,"BackdropTemplate")

frame:SetSize(frameWidth, frameHeight)
frame:SetPoint("CENTER")

frame:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    edgeSize=12,
    insets={left=2,right=2,top=2,bottom=2}
})

frame:SetBackdropColor(0.05,0.05,0.07,0.95)

frame:SetMovable(true)
frame:EnableMouse(true)

frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetClampedToScreen(true)
end)

frame:SetClampedToScreen(true)

frame:Hide()

--------------------------------------------------
-- Close Button
--------------------------------------------------

local closeButton = CreateFrame("Button", frame:GetName() .. "CloseButton", frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

--------------------------------------------------
-- Close with ESC
--------------------------------------------------

frame:SetToplevel(true)
frame:SetFrameStrata("DIALOG")
tinsert(UISpecialFrames, frame:GetName())

--------------------------------------------------
-- Title
--------------------------------------------------

local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
title:SetPoint("TOP",0,-10)
title:SetText("Delve Quest Status (Midnight)")

--------------------------------------------------
-- Column positions
--------------------------------------------------

local nameColumnX = paddingX
local statusColumnX = nameColumnX + nameColumnWidth + columnGap
local buttonColumnX = statusColumnX + statusColumnWidth + columnGap

local tableTop = -headerHeight

--------------------------------------------------
-- Headers
--------------------------------------------------

local header1 = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
header1:SetPoint("TOPLEFT", nameColumnX, tableTop)
header1:SetWidth(nameColumnWidth)
header1:SetJustifyH("LEFT")
header1:SetText("Name")

local header2 = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
header2:SetPoint("TOPLEFT", statusColumnX, tableTop)
header2:SetWidth(statusColumnWidth)
header2:SetJustifyH("CENTER")
header2:SetText("Status")

local header3 = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
header3:SetPoint("TOPLEFT", buttonColumnX, tableTop)
header3:SetWidth(buttonColumnWidth)
header3:SetJustifyH("CENTER")
header3:SetText("Waypoint")

--------------------------------------------------
-- Header line
--------------------------------------------------

local line = frame:CreateTexture(nil,"ARTWORK")
line:SetColorTexture(1,1,1,0.15)
line:SetHeight(1)
line:SetPoint("TOPLEFT", paddingX, tableTop-headerLineOffset)
line:SetPoint("TOPRIGHT", -paddingX, tableTop-headerLineOffset)

--------------------------------------------------
-- Rows
--------------------------------------------------

local rows = {}

for i,d in ipairs(delveQuests) do

    local y = tableTop - rowStartOffset - (i-1)*rowHeight

    local name = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    name:SetPoint("TOPLEFT", nameColumnX, y)
    name:SetWidth(nameColumnWidth)
    name:SetJustifyH("LEFT")

    local status = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    status:SetPoint("TOPLEFT", statusColumnX, y)
    status:SetWidth(statusColumnWidth)
    status:SetJustifyH("CENTER")

    local button = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    button:SetSize(buttonColumnWidth,20)
    button:SetPoint("TOPLEFT", buttonColumnX, y+2)
    button:SetText("Waypoint")

    button:SetScript("OnClick",function()
        SetWaypoint(d.map,d.x,d.y)
    end)

	local iconSize = 12
	local iconPadding = 8

	local icon = button:CreateTexture(nil,"ARTWORK")
	icon:SetAtlas("Waypoint-MapPin-ChatIcon")
	icon:SetSize(iconSize,iconSize)
	icon:SetPoint("LEFT",button,"LEFT",iconPadding,0)

	local text = button:GetFontString()
	text:ClearAllPoints()
	text:SetPoint("CENTER", button, "CENTER", iconPadding/2, 0)

	-- optional: verhindert, dass sehr langer Text ins Icon läuft
	text:SetWidth(buttonColumnWidth - iconPadding - iconSize - 6)
	text:SetJustifyH("CENTER")

    rows[i] = {
        name = name,
        status = status,
        button = button,
        data = d
    }

end

--------------------------------------------------
-- Update Table
--------------------------------------------------

local function UpdateTable()

    for _,row in ipairs(rows) do

        local d = row.data
        local title = C_QuestLog.GetTitleForQuestID(d.id) or d.name

        row.name:SetText(title)
        row.status:SetText(GetQuestStatus(d.id))

    end

end

--------------------------------------------------
-- UI Visibility
--------------------------------------------------

local function ShowUI()
	if InCombatLockdown and InCombatLockdown() then
		-- Notify the user the UI cannot be opended during combat
		UIErrorsFrame:AddMessage("Can not open during combat.\nWill be opended after Combat", 1, 0.3, 0.3)
		wasVisibleBeforeCombat = true
		return
	end

    if not frame:IsShown() then
		UpdateTable()
        frame:Show()
		frame:Raise()
    end
end

local function HideUI()
    if frame:IsShown() then
        frame:Hide()
    end
end

local function ToggleUI()
    if frame:IsShown() then
        HideUI()
    else
        ShowUI()
    end
end


--------------------------------------------------
-- Databroker and Minimap Icon
--------------------------------------------------

local MINIMAP_ICON = "icon_fuba_DelveQuestStatusMidnight"
local dataObject = LDB:NewDataObject(MINIMAP_ICON, {
    type = "data source",
    text = "Delve Quest Status",
    icon = questionMarkTex,

    OnClick = function(self, button)
        if button == "LeftButton" then
            ToggleUI()
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Delve Quest Status")
        tooltip:AddLine("Left Click: Toggle Window", 1, 1, 1)
		tooltip:AddLine("/dqs minimap - toggle minimap icon",1,1,1)
    end,
})

local function ToggleMinimapIcon()

    minimapDB.hide = not minimapDB.hide

    if minimapDB.hide then
        IconDB:Hide(MINIMAP_ICON)
    else
        IconDB:Show(MINIMAP_ICON)
    end

end


--------------------------------------------------
-- Slash commands
--------------------------------------------------

local cmd = "fuba_DelveQuestStatusMidnight"
_G["SLASH_" .. cmd .. "1"] = "/delvequeststatus"
_G["SLASH_" .. cmd .. "2"] = "/dqs"

local function showHelpText()
    print("|cff33ff99DQS|r commands:")
    print("  /dqs toggle")
    print("  /dqs show")
    print("  /dqs hide")
    print("  /dqs minimap")
end

local commands = {
    minimap = ToggleMinimapIcon,
    toggle  = ToggleUI,
    show    = ShowUI,
    hide    = HideUI,
	help	= showHelpText,
}

SlashCmdList[cmd] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	
	local f = commands[msg]
	
	if f and type(f) == 'function' then
		f()
	elseif msg == "" then
		ToggleUI()
	else
		showHelpText()
	end
end

--------------------------------------------------
-- Combat checks
--------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	
	if event == "ADDON_LOADED" then
		-- Init
	
		local name = ...
		if name ~= addonName then return end

		self:UnregisterEvent("ADDON_LOADED")
		
		FubaDelveQuestStatusMidnightDB = FubaDelveQuestStatusMidnightDB or {}
		ApplyDefaults(FubaDelveQuestStatusMidnightDB, defaults)

		minimapDB = FubaDelveQuestStatusMidnightDB.minimap
		
		IconDB:Register(MINIMAP_ICON, dataObject, minimapDB)

		if minimapDB.hide then
			IconDB:Hide(MINIMAP_ICON)
		end
		
    elseif event == "PLAYER_REGEN_DISABLED" then

        wasVisibleBeforeCombat = frame:IsShown()
        HideUI()

    elseif event == "PLAYER_REGEN_ENABLED" then

        if wasVisibleBeforeCombat then
            ShowUI()
			wasVisibleBeforeCombat = false
        end

    end

end)
