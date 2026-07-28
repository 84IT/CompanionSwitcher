-- ============================================================================
-- CompanionSwitcher: Fully Automated WotLK Native Engine Edition (3.3.5a)
-- ============================================================================

local ADDON_NAME = "CompanionSwitcher"
local frame = CreateFrame("Frame")

-- Default base configuration parameters
local defaults = {
    currentCompanionName = "",
    currentCompanionIcon = "Interface\\Icons\\INV_Box_PetCarrier_01",
    buttonX = 50, 
    buttonY = -120,
    minimapAngle = 180, 
    showMinimap = true,
    enabledCompanions = {},   
    favoriteCompanions = {}  
}

local scannedCompanions = {}
local ShowTooltip

local function ScanNativeCompanions()
    table.wipe(scannedCompanions)
    local totalCompanions = GetNumCompanions("CRITTER")
    if not totalCompanions or totalCompanions == 0 then return end
    
    for i = 1, totalCompanions do
        local _, name, _, iconTexture = GetCompanionInfo("CRITTER", i)
        if name and iconTexture then
            table.insert(scannedCompanions, { name = name, icon = iconTexture })
            if CompanionSwitcherFixedDB.enabledCompanions[name] == nil then CompanionSwitcherFixedDB.enabledCompanions[name] = true end
            if CompanionSwitcherFixedDB.favoriteCompanions[name] == nil then CompanionSwitcherFixedDB.favoriteCompanions[name] = false end
        end
    end
    table.sort(scannedCompanions, function(a, b) return a.name < b.name end)
    
    if CompanionSwitcherFixedDB and (CompanionSwitcherFixedDB.currentCompanionName == "" or not CompanionSwitcherFixedDB.currentCompanionName) and #scannedCompanions > 0 then
        CompanionSwitcherFixedDB.currentCompanionName = scannedCompanions[1].name
        CompanionSwitcherFixedDB.currentCompanionIcon = scannedCompanions[1].icon
    end
end

-- 1. Main Action Button
local actionButton = CreateFrame("CheckButton", "VanityBoxActionButton", UIParent, "ActionButtonTemplate, SecureActionButtonTemplate")
actionButton:SetSize(36, 36)
actionButton:SetClampedToScreen(true)
actionButton:SetMovable(true)
actionButton:RegisterForDrag("LeftButton")
actionButton:EnableMouseWheel(true)
actionButton:RegisterForClicks("LeftButtonUp")
actionButton:SetAttribute("type", "spell") 

local actionButtonNormalTexture = actionButton:GetNormalTexture()
if actionButtonNormalTexture then
    actionButtonNormalTexture:SetWidth(64)
    actionButtonNormalTexture:SetHeight(64)
    actionButtonNormalTexture:SetPoint("CENTER", 0, 0)
end

-- 2. Minimap Button
local minimapButton = CreateFrame("Button", "CompanionSwitcherMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 2)
minimapButton:SetToplevel(true)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:RegisterForDrag("LeftButton")

local minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("CENTER", 0, 0)

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT", 0, 0)

local dropdownMenu = CreateFrame("Frame", "CompanionSwitcherDropdown", actionButton, "UIDropDownMenuTemplate")

local function UpdateButtonVisuals()
    if not CompanionSwitcherFixedDB then return end
    local companion = CompanionSwitcherFixedDB.currentCompanionName
    local activeTexture = CompanionSwitcherFixedDB.currentCompanionIcon
    
    _G[actionButton:GetName().."Icon"]:SetTexture(activeTexture)
    minimapIcon:SetTexture(activeTexture)
    
    local nameLabel = _G[actionButton:GetName().."Name"]
    if nameLabel then nameLabel:SetText(companion and companion:gsub("Book of ", "") or "") end
    if not InCombatLockdown() and companion and companion ~= "" then actionButton:SetAttribute("spell", companion) end
end

local function UpdateMinimapPosition()
    if not CompanionSwitcherFixedDB then return end
    local angle = math.rad(CompanionSwitcherFixedDB.minimapAngle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(angle), 80 * math.sin(angle))
end

local function SetActiveCompanion(companionName, companionIcon)
    if InCombatLockdown() then return end
    CompanionSwitcherFixedDB.currentCompanionName = companionName
    CompanionSwitcherFixedDB.currentCompanionIcon = companionIcon
    UpdateButtonVisuals()
end

-- FIXED: Restored the full, favorite-prioritizing scroll cycle engine loop
local function CycleCompanions(self, direction)
    if InCombatLockdown() then return end
    if #scannedCompanions == 0 then return end
    
    -- Filter list to checked favorites first
    local cycleList = {}
    for _, pet in ipairs(scannedCompanions) do
        if CompanionSwitcherFixedDB.enabledCompanions[pet.name] and CompanionSwitcherFixedDB.favoriteCompanions[pet.name] then
            table.insert(cycleList, pet)
        end
    end
    
    -- Fall back to all enabled pets if no favorites are chosen
    if #cycleList == 0 then
        for _, pet in ipairs(scannedCompanions) do
            if CompanionSwitcherFixedDB.enabledCompanions[pet.name] then table.insert(cycleList, pet) end
        end
    end
    if #cycleList == 0 then return end

    local currentIndex = 1
    for i, pet in ipairs(cycleList) do
        if pet.name == CompanionSwitcherFixedDB.currentCompanionName then currentIndex = i break end
    end
    
    local nextIndex = currentIndex + (direction > 0 and -1 or 1)
    if nextIndex < 1 then nextIndex = #cycleList end
    if nextIndex > #cycleList then nextIndex = 1 end
    
    local target = cycleList[nextIndex]
    SetActiveCompanion(target.name, target.icon)
    if GameTooltip:IsOwned(self) then ShowTooltip(self) end
end

actionButton:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
actionButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, xOfs, yOfs = self:GetPoint()
    CompanionSwitcherFixedDB.buttonX = xOfs
    CompanionSwitcherFixedDB.buttonY = yOfs
end)
actionButton:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then ToggleDropDownMenu(1, nil, dropdownMenu, "cursor", 0, 0) end end)

-- FIXED: Wired up our corrected cycle logic directly into the mouse scroll handler script
actionButton:SetScript("OnMouseWheel", function(self, delta) CycleCompanions(self, delta) end)
ShowTooltip = function(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("CompanionSwitcher", 1, 1, 1)
    local companion = CompanionSwitcherFixedDB.currentCompanionName
    if companion and companion ~= "" then
        local isFav = CompanionSwitcherFixedDB.favoriteCompanions[companion]
        local prefix = isFav and "|cffffd700★ |r" or ""
        GameTooltip:AddLine("Active: " .. prefix .. "|cffffffff" .. companion .. "|r")
    else
        GameTooltip:AddLine("Active: |cffff8888No companion selected|r")
    end
    GameTooltip:AddLine("Left-Click: |cff00ff00Summon Companion|r")
    GameTooltip:AddLine("Right-Click: |cff00ff00Open Settings Menu|r")
    GameTooltip:AddLine("Scroll Wheel: |cff20efffCycle Selections|r")
    GameTooltip:AddLine("Shift + Drag: |cff888888Reposition Action Button|r")
    local key = GetBindingKey("CLICK VanityBoxActionButton:LeftButton")
    if key then GameTooltip:AddLine("Hotkey bound: |cfffff500" .. key .. "|r") end
    GameTooltip:Show()
end

actionButton:SetScript("OnEnter", function(self) ShowTooltip(self) end)
actionButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
minimapButton:SetScript("OnEnter", function(self) ShowTooltip(self) end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

minimapButton:SetScript("OnDragStart", function(self) self:StartMoving() end)
minimapButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local mx, my = Minimap:GetCenter()
    if cx and mx then
        local angle = math.atan2(cy - my, cx - mx)
        CompanionSwitcherFixedDB.minimapAngle = math.deg(angle)
        UpdateMinimapPosition()
    end
end)
minimapButton:SetScript("OnClick", function(self, button) if button == "LeftButton" then ToggleDropDownMenu(1, nil, dropdownMenu, "cursor", 0, 0) end end)

local function InitializeDropdown(self, level)
    level = level or 1
    if #scannedCompanions == 0 then return end
    if level == 1 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Select Active Companion"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        
        for _, pet in ipairs(scannedCompanions) do
            if CompanionSwitcherFixedDB.enabledCompanions[pet.name] then
                info = UIDropDownMenu_CreateInfo()
                local textLabel = pet.name
                if CompanionSwitcherFixedDB.favoriteCompanions[pet.name] then textLabel = "|cffffd700★|r " .. textLabel end
                info.text = textLabel
                info.value = pet.name
                info.icon = pet.icon
                info.checked = (pet.name == CompanionSwitcherFixedDB.currentCompanionName)
                info.func = function(s) CloseDropDownMenus() SetActiveCompanion(s.value, pet.icon) end
                UIDropDownMenu_AddButton(info, level)
            end
        end
        
        info = UIDropDownMenu_CreateInfo()
        info.text = " "
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        
        info = UIDropDownMenu_CreateInfo()
        info.text = "Enable/Disable List..."
        info.hasArrow = true
        info.value = "FilterMenu"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        
        info = UIDropDownMenu_CreateInfo()
        info.text = "Toggle Favorite Status..."
        info.hasArrow = true
        info.value = "FavMenu"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "FilterMenu" then
        for _, pet in ipairs(scannedCompanions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = pet.name
            info.value = pet.name
            info.icon = pet.icon
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.checked = CompanionSwitcherFixedDB.enabledCompanions[pet.name]
            info.func = function(s)
                CompanionSwitcherFixedDB.enabledCompanions[s.value] = not CompanionSwitcherFixedDB.enabledCompanions[s.value]
                s.checked = CompanionSwitcherFixedDB.enabledCompanions[s.value]
                if s.value == CompanionSwitcherFixedDB.currentCompanionName and not s.checked then
                    for _, alt in ipairs(scannedCompanions) do if CompanionSwitcherFixedDB.enabledCompanions[alt.name] then SetActiveCompanion(alt.name, alt.icon) break end end
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "FavMenu" then
        for _, pet in ipairs(scannedCompanions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = pet.name
            info.value = pet.name
            info.icon = pet.icon
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.checked = CompanionSwitcherFixedDB.favoriteCompanions[pet.name]
            info.func = function(s)
                CompanionSwitcherFixedDB.favoriteCompanions[s.value] = not CompanionSwitcherFixedDB.favoriteCompanions[s.value]
                s.checked = CompanionSwitcherFixedDB.favoriteCompanions[s.value]
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMPANION_LEARNED") 
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not CompanionSwitcherFixedDB then CompanionSwitcherFixedDB = {} end
        for k, v in pairs(defaults) do if CompanionSwitcherFixedDB[k] == nil then if type(v) == "table" then CompanionSwitcherFixedDB[k] = {} else CompanionSwitcherFixedDB[k] = v end end end
        
        _G["BINDING_HEADER_COMPANIONSWITCHER"] = "Companion"
        _G["BINDING_NAME_CLICK VanityBoxActionButton:LeftButton"] = "Summon"
        
        ScanNativeCompanions()
        actionButton:SetPoint("CENTER", UIParent, "CENTER", CompanionSwitcherFixedDB.buttonX, CompanionSwitcherFixedDB.buttonY)
        UpdateMinimapPosition()
        UpdateButtonVisuals()
        UIDropDownMenu_Initialize(dropdownMenu, InitializeDropdown, "MENU")
        if CompanionSwitcherFixedDB.showMinimap then minimapButton:Show() else minimapButton:Hide() end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "COMPANION_LEARNED" then
        ScanNativeCompanions()
        UpdateButtonVisuals()
    elseif event == "PLAYER_REGEN_DISABLED" then
        local iconTexture = _G[actionButton:GetName().."Icon"]
        if iconTexture then iconTexture:SetVertexColor(1, 0.3, 0.3, 0.6) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local iconTexture = _G[actionButton:GetName().."Icon"]
        if iconTexture then iconTexture:SetVertexColor(1, 1, 1, 1) end
        UpdateButtonVisuals()
    end
end)

-- Note: The /cs minimap command handles hiding the minimap button toggles
SLASH_COMPANIONSWITCHER1 = "/cs"
SlashCmdList["COMPANIONSWITCHER"] = function(msg)
    if msg == "minimap" then
        CompanionSwitcherFixedDB.showMinimap = not CompanionSwitcherFixedDB.showMinimap
        if CompanionSwitcherFixedDB.showMinimap then minimapButton:Show() else minimapButton:Hide() end
    end
end
