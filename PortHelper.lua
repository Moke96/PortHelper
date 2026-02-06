-- PortHelper: Track raid members who need ports
local addonName, addon = ...

-- Default settings
local defaults = {
    selectedRaid = nil,
    portMessage = "Porting %s to %s!",
    whisperMessage = "Incoming port to %s! Please accept.",
    autoAnnounce = true,  -- Auto-announce when using Meeting Stone
}

-- Classic Era Raid locations with their instance IDs (language-independent)
-- instanceID is used by GetInstanceInfo() and is the same across all locales
local RAIDS = {
    ["Molten Core"] = { 
        instanceID = 409,  -- Instance ID from GetInstanceInfo()
        mapID = 232,       -- UI Map ID
        entranceMapIDs = {35, 36}, -- Burning Steppes (35), Badlands area, Blackrock Mountain
        entranceZoneIDs = {1428, 1427, 1430}, -- Burning Steppes, Searing Gorge, Blackrock Mountain (UI Map IDs)
    },
    ["Blackwing Lair"] = { 
        instanceID = 469, 
        mapID = 287,
        entranceMapIDs = {35, 36},
        entranceZoneIDs = {1428, 1427, 1430},
    },
    ["Onyxia's Lair"] = { 
        instanceID = 249, 
        mapID = 248,
        entranceMapIDs = {15},
        entranceZoneIDs = {1445}, -- Dustwallow Marsh
    },
    ["Zul'Gurub"] = { 
        instanceID = 309, 
        mapID = 337,
        entranceMapIDs = {33},
        entranceZoneIDs = {1434}, -- Stranglethorn Vale
    },
    ["Ruins of Ahn'Qiraj"] = { 
        instanceID = 509, 
        mapID = 717,
        entranceMapIDs = {81},
        entranceZoneIDs = {1451}, -- Silithus
    },
    ["Temple of Ahn'Qiraj"] = { 
        instanceID = 531, 
        mapID = 766,
        entranceMapIDs = {81},
        entranceZoneIDs = {1451}, -- Silithus
    },
    ["Naxxramas"] = { 
        instanceID = 533, 
        mapID = 535,
        entranceMapIDs = {23},
        entranceZoneIDs = {1423}, -- Eastern Plaguelands
    },
    ["Other (Nearby Check)"] = {
        instanceID = nil,  -- No specific instance
        mapID = nil,
        entranceMapIDs = {},
        entranceZoneIDs = {},
        isOther = true,  -- Flag to identify this as the "other" option
    },
}

-- Localized entrance zone names for display purposes only
local L = {}
local locale = GetLocale()

if locale == "deDE" then
    L["Burning Steppes"] = "Brennende Steppe"
    L["Searing Gorge"] = "Sengende Schlucht"
    L["Blackrock Mountain"] = "Schwarzfels"
    L["Dustwallow Marsh"] = "Düstermarschen"
    L["Stranglethorn Vale"] = "Schlingendorntal"
    L["Silithus"] = "Silithus"
    L["Eastern Plaguelands"] = "Östliche Pestländer"
elseif locale == "frFR" then
    L["Burning Steppes"] = "Steppes ardentes"
    L["Searing Gorge"] = "Gorge des Vents brûlants"
    L["Blackrock Mountain"] = "Mont Rochenoire"
    L["Dustwallow Marsh"] = "Marécage d'Âprefange"
    L["Stranglethorn Vale"] = "Vallée de Strangleronce"
    L["Silithus"] = "Silithus"
    L["Eastern Plaguelands"] = "Maleterres de l'est"
elseif locale == "esES" or locale == "esMX" then
    L["Burning Steppes"] = "Las Estepas Ardientes"
    L["Searing Gorge"] = "La Garganta de Fuego"
    L["Blackrock Mountain"] = "Montaña Roca Negra"
    L["Dustwallow Marsh"] = "Marjal Revolcafango"
    L["Stranglethorn Vale"] = "Vega de Tuercespina"
    L["Silithus"] = "Silithus"
    L["Eastern Plaguelands"] = "Tierras de la Peste del Este"
elseif locale == "ruRU" then
    L["Burning Steppes"] = "Пылающие степи"
    L["Searing Gorge"] = "Тлеющее ущелье"
    L["Blackrock Mountain"] = "Черная гора"
    L["Dustwallow Marsh"] = "Пылевые топи"
    L["Stranglethorn Vale"] = "Тернистая долина"
    L["Silithus"] = "Силитус"
    L["Eastern Plaguelands"] = "Восточные Чумные земли"
else -- Default English (enUS, enGB)
    L["Burning Steppes"] = "Burning Steppes"
    L["Searing Gorge"] = "Searing Gorge"
    L["Blackrock Mountain"] = "Blackrock Mountain"
    L["Dustwallow Marsh"] = "Dustwallow Marsh"
    L["Stranglethorn Vale"] = "Stranglethorn Vale"
    L["Silithus"] = "Silithus"
    L["Eastern Plaguelands"] = "Eastern Plaguelands"
end

-- Proximity distance (in yards) to consider someone "close"
local PROXIMITY_DISTANCE = 100

-- Addon frame and variables
local PortHelper = CreateFrame("Frame", "PortHelperFrame", UIParent, "BackdropTemplate")
local needsPortList = {}
local updateTimer = 0
local UPDATE_INTERVAL = 2 -- seconds

-- Initialize saved variables
local function InitializeDB()
    if not PortHelperDB then
        PortHelperDB = CopyTable(defaults)
    end
    -- Ensure all defaults exist
    for k, v in pairs(defaults) do
        if PortHelperDB[k] == nil then
            PortHelperDB[k] = v
        end
    end
end

-- Create the main UI frame
local function CreateMainFrame()
    PortHelper:SetSize(250, 350)
    PortHelper:SetPoint("CENTER")
    PortHelper:SetMovable(true)
    PortHelper:EnableMouse(true)
    PortHelper:RegisterForDrag("LeftButton")
    PortHelper:SetScript("OnDragStart", PortHelper.StartMoving)
    PortHelper:SetScript("OnDragStop", PortHelper.StopMovingOrSizing)
    PortHelper:SetClampedToScreen(true)
    
    PortHelper:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    PortHelper:SetBackdropColor(0, 0, 0, 0.9)
    
    -- Title
    local title = PortHelper:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("PortHelper")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, PortHelper, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Raid selector dropdown
    local raidLabel = PortHelper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", 15, -40)
    raidLabel:SetText("Select Raid:")
    
    local raidDropdown = CreateFrame("Frame", "PortHelperRaidDropdown", PortHelper, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("TOPLEFT", raidLabel, "BOTTOMLEFT", -15, -5)
    
    local function RaidDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for raidName, _ in pairs(RAIDS) do
            info.text = raidName
            info.value = raidName
            info.func = function(self)
                PortHelperDB.selectedRaid = self.value
                UIDropDownMenu_SetText(raidDropdown, self.value)
                CloseDropDownMenus()
            end
            info.checked = (PortHelperDB.selectedRaid == raidName)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_SetWidth(raidDropdown, 180)
    UIDropDownMenu_Initialize(raidDropdown, RaidDropdown_Initialize)
    UIDropDownMenu_SetText(raidDropdown, PortHelperDB.selectedRaid or "Select a raid...")
    
    -- Scan button
    local scanBtn = CreateFrame("Button", nil, PortHelper, "GameMenuButtonTemplate")
    scanBtn:SetSize(100, 25)
    scanBtn:SetPoint("TOPLEFT", raidDropdown, "BOTTOMLEFT", 20, -10)
    scanBtn:SetText("Scan Raid")
    scanBtn:SetScript("OnClick", function()
        addon:ScanRaidMembers()
    end)
    
    -- Auto-scan checkbox
    local autoScan = CreateFrame("CheckButton", "PortHelperAutoScan", PortHelper, "UICheckButtonTemplate")
    autoScan:SetPoint("LEFT", scanBtn, "RIGHT", 10, 0)
    autoScan.text = autoScan:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoScan.text:SetPoint("LEFT", autoScan, "RIGHT", 0, 0)
    autoScan.text:SetText("Auto")
    autoScan:SetScript("OnClick", function(self)
        PortHelperDB.autoScan = self:GetChecked()
    end)
    
    -- Auto-announce checkbox (for Meeting Stone auto-detection)
    local autoAnnounce = CreateFrame("CheckButton", "PortHelperAutoAnnounce", PortHelper, "UICheckButtonTemplate")
    autoAnnounce:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", -5, -5)
    autoAnnounce.text = autoAnnounce:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoAnnounce.text:SetPoint("LEFT", autoAnnounce, "RIGHT", 0, 0)
    autoAnnounce.text:SetText("Auto-announce (Meeting Stone)")
    autoAnnounce:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto-announce Meeting Stone", 1, 1, 1)
        GameTooltip:AddLine("When enabled, automatically announces", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("the port when you use a Meeting Stone", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("to summon a raid member.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    autoAnnounce:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    autoAnnounce:SetScript("OnClick", function(self)
        PortHelperDB.autoAnnounce = self:GetChecked()
        if self:GetChecked() then
            print("|cFFFFAA00PortHelper:|r Auto-announce |cFF00FF00enabled|r - will announce when you use a Meeting Stone")
        else
            print("|cFFFFAA00PortHelper:|r Auto-announce |cFFFF0000disabled|r")
        end
    end)
    
    -- Needs port list header (adjusted position for new checkbox)
    local listHeader = PortHelper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", 15, -155)
    listHeader:SetText("Needs Port:")
    
    -- Count display
    local countText = PortHelper:CreateFontString("PortHelperCount", "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", listHeader, "RIGHT", 10, 0)
    countText:SetText("(0)")
    
    -- Scroll frame for the list
    local scrollFrame = CreateFrame("ScrollFrame", "PortHelperScrollFrame", PortHelper, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local scrollChild = CreateFrame("Frame", "PortHelperScrollChild", scrollFrame)
    scrollChild:SetSize(190, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    PortHelper.scrollChild = scrollChild
    PortHelper.raidDropdown = raidDropdown
    PortHelper.autoScan = autoScan
    PortHelper.autoAnnounce = autoAnnounce
    
    -- Help text
    local helpText = PortHelper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("BOTTOM", 0, 15)
    helpText:SetText("L: Target | R: Summon | M: Announce")
    helpText:SetTextColor(0.7, 0.7, 0.7)
    
    PortHelper:Hide()
end

-- Check if a unit is in the raid instance or near entrance (using IDs, not localized strings)
local function IsUnitInRaidInstance(unit)
    if not UnitExists(unit) then return false end
    
    local selectedRaid = PortHelperDB.selectedRaid
    if not selectedRaid or not RAIDS[selectedRaid] then return false end
    
    local raidInfo = RAIDS[selectedRaid]
    
    -- Check using map ID (works across all locales)
    local unitMap = C_Map.GetBestMapForUnit(unit)
    if unitMap then
        -- Check if in the raid instance itself
        if unitMap == raidInfo.mapID then
            return true
        end
        -- Check if in entrance zone
        for _, entranceMapID in ipairs(raidInfo.entranceZoneIDs or {}) do
            if unitMap == entranceMapID then
                return true
            end
        end
    end
    
    return false
end

-- Check if player is in the raid instance using GetInstanceInfo (most reliable)
local function IsPlayerInRaidInstance()
    local selectedRaid = PortHelperDB.selectedRaid
    if not selectedRaid or not RAIDS[selectedRaid] then return false end
    
    local raidInfo = RAIDS[selectedRaid]
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    
    return instanceID == raidInfo.instanceID
end

-- Check if a unit is close to the player
local function IsUnitClose(unit)
    if not UnitExists(unit) or not UnitIsConnected(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end
    
    -- Check if unit is in range (visible)
    if not UnitIsVisible(unit) then return false end
    
    -- Use CheckInteractDistance for proximity check
    -- 1 = Inspect (28 yards), 2 = Trade (11 yards), 3 = Duel (10 yards), 4 = Follow (28 yards)
    if CheckInteractDistance(unit, 4) then
        return true
    end
    
    return false
end

-- Get unit info for display
local function GetUnitInfo(unit)
    local name, realm = UnitName(unit)
    local _, class = UnitClass(unit)
    local level = UnitLevel(unit)
    local online = UnitIsConnected(unit)
    local zone = nil
    
    -- Try to get zone from raid roster info
    for i = 1, MAX_RAID_MEMBERS do
        local rName, _, _, _, _, _, rZone = GetRaidRosterInfo(i)
        if rName and rName == name then
            zone = rZone
            break
        end
    end
    
    return {
        name = name,
        realm = realm,
        class = class,
        level = level,
        online = online,
        zone = zone or "Unknown",
        unit = unit
    }
end

-- Scan raid members
function addon:ScanRaidMembers()
    if not IsInRaid() then
        print("|cFFFFAA00PortHelper:|r You are not in a raid group.")
        return
    end
    
    if not PortHelperDB.selectedRaid then
        print("|cFFFFAA00PortHelper:|r Please select a raid first.")
        return
    end
    
    local selectedRaid = PortHelperDB.selectedRaid
    local raidInfo = RAIDS[selectedRaid]
    
    wipe(needsPortList)
    
    -- Handle "Other" option - just check if players are NOT nearby
    if raidInfo and raidInfo.isOther then
        for i = 1, MAX_RAID_MEMBERS do
            local name, _, _, _, _, _, zone, online = GetRaidRosterInfo(i)
            if name and online then
                local unit = "raid" .. i
                if not UnitIsUnit(unit, "player") then
                    local isClose = IsUnitClose(unit)
                    
                    if not isClose then
                        local info = GetUnitInfo(unit)
                        info.raidIndex = i
                        table.insert(needsPortList, info)
                    end
                end
            end
        end
        
        -- Sort by name
        table.sort(needsPortList, function(a, b) return a.name < b.name end)
        
        addon:UpdateListDisplay()
        print("|cFFFFAA00PortHelper:|r Found " .. #needsPortList .. " members not nearby")
        return
    end
    
    -- Normal raid instance check
    if not raidInfo then
        print("|cFFFFAA00PortHelper:|r Invalid raid selection.")
        return
    end
    
    -- Check player location using instance ID (locale-independent)
    local playerInRaid = IsPlayerInRaidInstance()
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerNearEntrance = false
    
    -- Check if player is near entrance using map IDs
    if playerMapID then
        for _, entranceMapID in ipairs(raidInfo.entranceZoneIDs or {}) do
            if playerMapID == entranceMapID then
                playerNearEntrance = true
                break
            end
        end
    end
    
    for i = 1, MAX_RAID_MEMBERS do
        local name, _, _, _, _, _, zone, online = GetRaidRosterInfo(i)
        if name and online then
            local unit = "raid" .. i
            if not UnitIsUnit(unit, "player") then
                -- Check if member is in raid or near entrance using map IDs
                local memberMapID = C_Map.GetBestMapForUnit(unit)
                local inRaidZone = false
                
                if memberMapID then
                    -- Check if in raid instance
                    if memberMapID == raidInfo.mapID then
                        inRaidZone = true
                    end
                    -- Check if near entrance
                    if not inRaidZone then
                        for _, entranceMapID in ipairs(raidInfo.entranceZoneIDs or {}) do
                            if memberMapID == entranceMapID then
                                inRaidZone = true
                                break
                            end
                        end
                    end
                end
                
                local isClose = IsUnitClose(unit)
                
                if not inRaidZone and not isClose then
                    local info = GetUnitInfo(unit)
                    info.raidIndex = i
                    table.insert(needsPortList, info)
                end
            end
        end
    end
    
    -- Sort by name
    table.sort(needsPortList, function(a, b) return a.name < b.name end)
    
    addon:UpdateListDisplay()
    print("|cFFFFAA00PortHelper:|r Found " .. #needsPortList .. " members needing ports to " .. selectedRaid)
end

-- Class colors
local CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45},
    ROGUE = {1.00, 0.96, 0.41},
    PRIEST = {1.00, 1.00, 1.00},
    SHAMAN = {0.00, 0.44, 0.87},
    MAGE = {0.41, 0.80, 0.94},
    WARLOCK = {0.58, 0.51, 0.79},
    DRUID = {1.00, 0.49, 0.04},
}

-- Button pool for reuse - secure buttons must be parented to UIParent
local buttonPool = {}

-- Helper function to position buttons based on main frame
local function PositionButtons()
    if InCombatLockdown() then return end
    
    local scrollChild = PortHelper.scrollChild
    if not scrollChild then return end
    
    for i, btn in pairs(buttonPool) do
        if btn:IsShown() then
            local x, y = scrollChild:GetLeft(), scrollChild:GetTop()
            if x and y then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y - ((i-1) * 24))
            end
        end
    end
end

-- Update the list display
function addon:UpdateListDisplay()
    local scrollChild = PortHelper.scrollChild
    if not scrollChild then
        print("|cFFFFAA00PortHelper:|r Error - scroll child not found")
        return
    end
    
    -- Check if in combat (secure buttons can't be modified in combat)
    if InCombatLockdown() then
        print("|cFFFFAA00PortHelper:|r Cannot update list during combat. Try again after combat.")
        return
    end
    
    -- Hide all existing buttons in the pool
    for _, btn in pairs(buttonPool) do
        btn:Hide()
        btn:SetAttribute("unit", nil)
    end
    
    -- Update count
    local countText = _G["PortHelperCount"]
    if countText then
        countText:SetText("(" .. #needsPortList .. ")")
    end
    
    -- Create/reuse buttons for each member
    for i, info in ipairs(needsPortList) do
        local btn = buttonPool[i]
        
        -- Create button if it doesn't exist
        if not btn then
            -- Create secure button parented to UIParent (secure frames can only anchor to UIParent)
            btn = CreateFrame("Button", "PortHelperPlayerBtn"..i, UIParent, "SecureActionButtonTemplate,BackdropTemplate")
            btn:SetSize(190, 22)
            btn:SetFrameStrata("DIALOG")
            btn:SetFrameLevel(100)
            
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            
            -- Create font strings once
            btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.nameText:SetPoint("LEFT", 5, 0)
            
            btn.zoneText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.zoneText:SetPoint("RIGHT", -5, 0)
            btn.zoneText:SetWidth(80)
            btn.zoneText:SetJustifyH("RIGHT")
            
            btn:RegisterForClicks("AnyUp")  -- Only fire on mouse up, not down+up (prevents double trigger)
            btn:EnableMouse(true)
            
            buttonPool[i] = btn
        end
        
        -- Position using absolute coordinates from scrollChild
        local x, y = scrollChild:GetLeft(), scrollChild:GetTop()
        if x and y then
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y - ((i-1) * 24))
        end
        
        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        
        -- Store info and index for callbacks
        btn.info = info
        btn.listIndex = i
        btn.isPorting = false  -- Reset porting state when list updates
        
        -- Highlight on mouseover
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.3, 0.9)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.info.name, 1, 1, 1)
            GameTooltip:AddLine("Zone: " .. self.info.zone, 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Left-click: Target", 0.5, 1, 0.5)
            GameTooltip:AddLine("Right-click: Cast Ritual of Summoning", 1, 0.5, 0.5)
            GameTooltip:AddLine("Middle-click: Announce port (Meeting Stone)", 0.5, 0.8, 1)
            GameTooltip:AddLine("(Target first with left-click)", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            GameTooltip:Hide()
        end)
        
        -- Update name text with class color
        local color = CLASS_COLORS[info.class] or {1, 1, 1}
        btn.nameText:SetTextColor(color[1], color[2], color[3])
        btn.nameText:SetText(info.name)
        btn.nameText:Show()
        
        -- Update zone text
        btn.zoneText:SetTextColor(0.6, 0.6, 0.6)
        btn.zoneText:SetText(info.zone)
        btn.zoneText:Show()
        
        -- Set up secure attributes BEFORE click (like RaidSummon does)
        -- These must be set outside of combat
        btn:SetAttribute("type1", "target")  -- Left-click targets
        btn:SetAttribute("unit", info.unit)  -- The unit to target
        
        -- Right-click: cast summon spell (target must be selected first via left-click)
        btn:SetAttribute("type2", "spell")
        btn:SetAttribute("spell", "698")  -- 698 = Ritual of Summoning spell ID
        
        -- Middle-click: just announce (for Meeting Stone usage)
        btn:SetAttribute("type3", "target")  -- Middle-click also targets first
        
        -- PreClick handler - updates attributes dynamically like RaidSummon
        btn:SetScript("PreClick", function(self, button)
            if InCombatLockdown() then return end
            -- Update attributes based on current info (in case list was refreshed)
            self:SetAttribute("unit", self.info.unit)
            self:SetAttribute("type2", "spell")
            self:SetAttribute("spell", "698")  -- 698 = Ritual of Summoning
        end)
        
        -- PostClick handler for feedback and port messages
        btn:SetScript("PostClick", function(self, button)
            if button == "LeftButton" then
                print("|cFFFFAA00PortHelper:|r Targeting " .. self.info.name)
            elseif button == "RightButton" then
                -- Check if already porting this person
                if self.isPorting then
                    print("|cFFFFAA00PortHelper:|r Already summoning " .. self.info.name .. "!")
                    return
                end
                
                -- Mark as porting and update visual
                self.isPorting = true
                self:SetBackdropColor(0.3, 0.15, 0.0, 0.9)  -- Orange/brown to indicate porting
                self:SetBackdropBorderColor(1.0, 0.5, 0.0, 1)  -- Orange border
                self.nameText:SetText("|cFFFF8800>>|r " .. self.info.name)  -- Add >> prefix
                
                print("|cFFFFAA00PortHelper:|r |cFF00FF00Summoning " .. self.info.name .. "|r - Cast your ritual!")
                -- Send port messages after the spell cast initiates
                C_Timer.After(0.1, function()
                    addon:SendPortMessages(self.info, false)
                end)
            elseif button == "MiddleButton" then
                -- Middle-click: Announce port for Meeting Stone usage (no spell cast)
                -- Check if already porting this person
                if self.isPorting then
                    print("|cFFFFAA00PortHelper:|r Already summoning " .. self.info.name .. "!")
                    return
                end
                
                -- Mark as porting and update visual
                self.isPorting = true
                self:SetBackdropColor(0.0, 0.2, 0.3, 0.9)  -- Blue-ish to indicate Meeting Stone port
                self:SetBackdropBorderColor(0.3, 0.7, 1.0, 1)  -- Blue border
                self.nameText:SetText("|cFF00AAFF>>|r " .. self.info.name)  -- Add blue >> prefix
                
                print("|cFFFFAA00PortHelper:|r |cFF00AAFFAnnouncing port for " .. self.info.name .. "|r - Use the Meeting Stone!")
                -- Send port messages for Meeting Stone usage
                addon:SendPortMessages(self.info, true)
            end
        end)
        
        btn:Show()
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(24, #needsPortList * 24))
    
    -- Update button positions when main frame moves
    PortHelper:HookScript("OnUpdate", function()
        if not InCombatLockdown() then
            PositionButtons()
        end
    end)
end

-- Send port messages (called after secure targeting)
function addon:SendPortMessages(info, isMeetingStone)
    local selectedRaid = PortHelperDB.selectedRaid
    if not selectedRaid then return end
    
    local raidMsg = string.format(PortHelperDB.portMessage, info.name, selectedRaid)
    local whisperMsg = string.format(PortHelperDB.whisperMessage, selectedRaid)
    
    -- Send raid message
    SendChatMessage(raidMsg, "RAID")
    
    -- Send whisper
    SendChatMessage(whisperMsg, "WHISPER", nil, info.name)
    
    if isMeetingStone then
        print("|cFFFFAA00PortHelper:|r Porting " .. info.name .. " - Use the Meeting Stone!")
    else
        print("|cFFFFAA00PortHelper:|r Porting " .. info.name .. " - Cast your Ritual of Summoning!")
    end
end

-- Legacy function for compatibility
function addon:PortPlayer(info)
    addon:SendPortMessages(info)
end

-- Slash commands
SLASH_PORTHELPER1 = "/porthelper"
SLASH_PORTHELPER2 = "/ph"
SlashCmdList["PORTHELPER"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "scan" then
        addon:ScanRaidMembers()
    elseif msg == "config" or msg == "options" then
        -- Future: open config
        print("|cFFFFAA00PortHelper:|r Config not yet implemented")
    else
        if PortHelper:IsShown() then
            PortHelper:Hide()
        else
            PortHelper:Show()
        end
    end
end

-- Minimap button
local function CreateMinimapButton()
    local minimapBtn = CreateFrame("Button", "PortHelperMinimapButton", Minimap)
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetFrameStrata("MEDIUM")
    minimapBtn:SetFrameLevel(8)
    minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local overlay = minimapBtn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    
    local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\Spell_Arcane_PortalDalaran")
    icon:SetPoint("CENTER", 0, 0)
    
    -- Position around minimap
    local angle = math.rad(PortHelperDB and PortHelperDB.minimapAngle or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    -- Dragging
    minimapBtn:SetMovable(true)
    minimapBtn:RegisterForDrag("LeftButton")
    minimapBtn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    minimapBtn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Calculate angle for saved position
        local mx, my = Minimap:GetCenter()
        local bx, by = self:GetCenter()
        local angle = math.deg(math.atan2(by - my, bx - mx))
        PortHelperDB.minimapAngle = angle
    end)
    
    minimapBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if PortHelper:IsShown() then
                PortHelper:Hide()
            else
                PortHelper:Show()
            end
        elseif button == "RightButton" then
            addon:ScanRaidMembers()
        end
    end)
    
    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("PortHelper")
        GameTooltip:AddLine("Left-click: Toggle window", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Scan raid", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    minimapBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
end

-- Track recently announced summons to prevent duplicates
local recentSummons = {}
local SUMMON_COOLDOWN = 10 -- seconds before allowing re-announcement for same player

-- Auto-announce summon for target (used by auto-detection)
function addon:AutoAnnounceSummon(targetName, targetUnit)
    -- Check if we recently announced for this player
    local now = GetTime()
    if recentSummons[targetName] and (now - recentSummons[targetName]) < SUMMON_COOLDOWN then
        return false -- Already announced recently
    end
    
    -- Find player info from needsPortList or create basic info
    local info = nil
    for _, playerInfo in ipairs(needsPortList) do
        if playerInfo.name == targetName then
            info = playerInfo
            break
        end
    end
    
    -- If not in list, create basic info from target
    if not info and targetUnit and UnitExists(targetUnit) then
        info = {
            name = targetName,
            unit = targetUnit,
        }
    end
    
    if not info then
        return false
    end
    
    -- Mark as recently announced
    recentSummons[targetName] = now
    
    -- Send the port messages (auto-detected as Meeting Stone)
    addon:SendPortMessages(info, true)
    print("|cFFFFAA00PortHelper:|r |cFF00AAFFAuto-detected summon for " .. targetName .. "|r")
    
    return true
end

-- Event handler
PortHelper:RegisterEvent("ADDON_LOADED")
PortHelper:RegisterEvent("GROUP_ROSTER_UPDATE")
PortHelper:RegisterEvent("UNIT_SPELLCAST_SENT")
PortHelper:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
PortHelper:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDB()
        CreateMainFrame()
        CreateMinimapButton()
        
        -- Restore auto-scan state
        if PortHelper.autoScan then
            PortHelper.autoScan:SetChecked(PortHelperDB.autoScan)
        end
        
        -- Restore auto-announce state
        if PortHelper.autoAnnounce then
            PortHelper.autoAnnounce:SetChecked(PortHelperDB.autoAnnounce)
        end
        
        print("|cFFFFAA00PortHelper|r loaded! Type |cFF00FF00/ph|r or |cFF00FF00/porthelper|r to toggle.")
    elseif event == "GROUP_ROSTER_UPDATE" then
        if PortHelperDB.autoScan and IsInRaid() and PortHelper:IsShown() then
            addon:ScanRaidMembers()
        end
    elseif event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        -- These events fire when the player casts or channels a spell
        -- Meeting Stone summoning triggers these events with the target player
        local unit = arg1
        
        -- Common validation
        if unit ~= "player" then return end
        if not PortHelperDB.autoAnnounce then return end
        if not IsInRaid() then return end
        
        -- Get target name based on event type
        local targetName = nil
        if event == "UNIT_SPELLCAST_SENT" then
            -- arg2 is the target name for UNIT_SPELLCAST_SENT
            targetName = arg2
        else
            -- For channeling, use current target
            targetName = UnitName("target")
        end
        
        if not targetName or targetName == "" then return end
        
        -- Check if target is a raid member and announce
        for i = 1, MAX_RAID_MEMBERS do
            local name = GetRaidRosterInfo(i)
            if name and name == targetName then
                addon:AutoAnnounceSummon(targetName, "raid" .. i)
                break
            end
        end
    end
end)

-- Auto-scan timer
PortHelper:SetScript("OnUpdate", function(self, elapsed)
    if not PortHelperDB.autoScan or not PortHelper:IsShown() then return end
    
    updateTimer = updateTimer + elapsed
    if updateTimer >= UPDATE_INTERVAL then
        updateTimer = 0
        if IsInRaid() then
            addon:ScanRaidMembers()
        end
    end
end)
