-- The engine is load-on-demand: a blocked startup creates no Atr_* globals,
-- frames, event handlers, price queries or writes to its SavedVariables.
local addonName = ...
if addonName ~= "AuctionatorRemastered_Startup" then return end
local ENGINE = "AuctionatorRemastered"
local Policy = AuctionatorRemasteredConflictPolicy
local Startup = {name = addonName, engine = ENGINE, blocked = false, started = false}
AuctionatorRemasteredStartup = Startup
local frame = CreateFrame("Frame")
local loggedIn = IsLoggedIn and IsLoggedIn() or false
local delay,announced

local function conflicts()
    return Policy.Find({GetNumAddOns = GetNumAddOns, GetAddOnInfo = GetAddOnInfo,
        GetAddOnMetadata = GetAddOnMetadata, IsAddOnLoaded = IsAddOnLoaded})
end

local function safeText(value)
    return tostring(value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "||"):gsub("[\r\n]", " ")
end

local function button(name, parent, text, width, x, callback)
    local control = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 28)
    control:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 18)
    control:SetText(text)
    control:SetScript("OnClick", callback)
    return control
end

local function skins()
    local engine=type(ElvUI)=="table" and ElvUI[1]
    if not engine or type(engine.GetModule)~="function" then return nil end
    local ok,module=pcall(engine.GetModule,engine,"Skins",true)
    return ok and module or nil
end

local function style(dialog)
    local module=skins()
    if not module or dialog.skin==module then return end
    if type(dialog.SetTemplate)=="function" then pcall(dialog.SetTemplate,dialog,"Transparent") end
    if type(module.HandleButton)=="function" then
        for _,control in ipairs({dialog.useRemastered,dialog.useOther,dialog.later}) do pcall(module.HandleButton,module,control) end
    end
    local bar=_G.AuctionatorRemasteredConflictScrollScrollBar
    if bar and type(module.HandleScrollBar)=="function" then pcall(module.HandleScrollBar,module,bar) end
    dialog.skin=module
end

local function layers(node,level)
    node:SetFrameLevel(level)
    for _,child in ipairs({node:GetChildren()}) do
        -- ElvUI creates opaque child backdrops below controls. They must stay
        -- behind their text/thumbs; interactive descendants stay above parents.
        if child==node.backdrop then layers(child,math.max(0,level-1))
        elseif child==node.iborder or child==node.oborder then layers(child,level)
        else layers(child,level+1) end
    end
end

function Startup.Status()
    if not DEFAULT_CHAT_FRAME or type(DEFAULT_CHAT_FRAME.AddMessage)~="function" then return end
    local message
    if Startup.blocked then
        local names={}
        for _,entry in ipairs(Startup.conflicts or {}) do names[#names+1]=safeText(entry.name) end
        message="Paused: "..(#names>0 and table.concat(names,", ") or Startup.failure or "reload or installation check required")..". Type /atrstartup to open the version chooser."
    else message=Startup.started and "Main module started." or "Startup has not completed." end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Auctionator Remastered:|r "..message)
end

function Startup.Resolve(useRemastered)
    if InCombatLockdown and InCombatLockdown() then return end
    if useRemastered then
        -- Refresh the inventory instead of acting on stale popup contents.
        for _, other in ipairs(conflicts()) do DisableAddOn(other.name) end
        EnableAddOn(addonName)
        EnableAddOn(ENGINE)
    else
        DisableAddOn(addonName)
        DisableAddOn(ENGINE)
    end
    ReloadUI()
end

function Startup.ShowWarning()
    if not Startup.blocked or not loggedIn then return end
    local dialog = Startup.dialog
    if not dialog then
        dialog = CreateFrame("Frame", "AuctionatorRemasteredConflictDialog", UIParent)
        dialog:SetSize(580, 350)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetFrameLevel(200)
        dialog:SetToplevel(false)
        dialog:EnableMouse(true)
        dialog:SetClampedToScreen(true)
        dialog:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
            tile=true, tileSize=32, edgeSize=24, insets={left=8,right=8,top=8,bottom=8}})
        dialog:SetBackdropColor(.85,.85,.85,1)
        dialog:SetBackdropBorderColor(1,1,1,1)
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 24, -22)
        title:SetText("Auctionator Remastered | Installation conflict")
        local intro = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        intro:SetPoint("TOPLEFT", 24, -56)
        intro:SetWidth(532)
        intro:SetJustifyH("LEFT")
        intro:SetText("Another Auctionator version is enabled. Remastered has not loaded, so the two versions cannot share auction windows or overwrite each other's functions.")
        -- Wrath's template OnLoad builds child names from self:GetName().
        local scroll = CreateFrame("ScrollFrame", "AuctionatorRemasteredConflictScroll", dialog, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 24, -112)
        scroll:SetPoint("BOTTOMRIGHT", -46, 112)
        local content = CreateFrame("Frame", "AuctionatorRemasteredConflictContent", scroll)
        content:SetWidth(500)
        local list = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        list:SetPoint("TOPLEFT")
        list:SetWidth(500)
        list:SetJustifyH("LEFT")
        scroll:SetScrollChild(content)
        dialog.list, dialog.content = list, content
        local help = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        help:SetPoint("BOTTOMLEFT", 24, 62)
        help:SetWidth(532)
        help:SetJustifyH("LEFT")
        help:SetText("Use Remastered disables the addons listed above for this character and reloads the UI. No addons or saved data are deleted. Close this window to keep your current version for this session.")
        dialog.useRemastered = button("AuctionatorRemasteredConflictUseNew", dialog, "Use Remastered", 180, 24, function() Startup.Resolve(true) end)
        dialog.useOther = button("AuctionatorRemasteredConflictUseOld", dialog, "Use other version", 180, 216, function() Startup.Resolve(false) end)
        dialog.later=button("AuctionatorRemasteredConflictLater", dialog, "Later", 130, 426, function() Startup.dismissed=true;dialog:Hide() end)
        table.insert(UISpecialFrames, "AuctionatorRemasteredConflictDialog")
        Startup.dialog=dialog
    end
    local lines = {}
    for _, other in ipairs(Startup.conflicts or {}) do
        lines[#lines + 1] = safeText(other.title).."\n  Folder: "..safeText(other.name)
    end
    if Startup.unidentified then
        lines[#lines + 1] = "An unrecognized addon has already created Auctionator's shared runtime. Disable that addon in the AddOns menu, then reload."
    end
    if Startup.needsReload then lines[#lines+1]="Remastered was enabled during an active session. Reload to initialize the main module safely." end
    if Startup.failure then lines[#lines + 1] = "Main module could not load: "..safeText(Startup.failure) end
    dialog.list:SetText(table.concat(lines, "\n\n"))
    dialog.content:SetHeight(math.max(80, dialog.list:GetStringHeight() + 8))
    if Startup.unidentified or Startup.failure then dialog.useRemastered:Disable() else dialog.useRemastered:Enable() end
    if InCombatLockdown and InCombatLockdown() then
        dialog.useRemastered:Disable(); dialog.useOther:Disable()
    else dialog.useOther:Enable() end
    dialog.later:Enable()
    style(dialog)
    layers(dialog,200)
    dialog:SetAlpha(1)
    dialog:Show()
end

local function queueWarning()
    if not Startup.blocked or Startup.dismissed then return end
    delay=1
    frame:SetScript("OnUpdate",function(self,elapsed)
        delay=delay-elapsed
        if delay>0 then return end
        self:SetScript("OnUpdate",nil)
        if not announced then Startup.Status();announced=true end
        Startup.ShowWarning()
    end)
end

function Startup.Start()
    if Startup.started or Startup.blocked then return end
    Startup.conflicts = conflicts()
    Startup.unidentified = #Startup.conflicts == 0 and (Atr_core ~= nil or AuctionatorLoaded ~= nil or gAtrZC ~= nil)
    if #Startup.conflicts > 0 or Startup.unidentified then
        Startup.blocked = true
        if loggedIn then queueWarning() end
        return
    end
    if loggedIn then
        Startup.needsReload=true;Startup.blocked=true;queueWarning();return
    end
    Startup.started = true
    -- Called from our ADDON_LOADED, before VARIABLES_LOADED and PLAYER_LOGIN.
    -- Preserve the engine's original default/SavedVariables/event ordering.
    local ok, reason = LoadAddOn(ENGINE)
    if not ok then
        Startup.started = false
        Startup.blocked = true
        Startup.failure = reason or "Unknown error; check that both Remastered folders are installed."
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then Startup.Start()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then loggedIn = true;queueWarning()
    elseif event == "PLAYER_REGEN_ENABLED" and Startup.dialog and Startup.dialog:IsShown() then Startup.ShowWarning() end
end)

-- Remains available while the main module is deliberately blocked, including
-- after Escape/CloseSpecialWindows hides the initial warning.
SLASH_ATRREMASTEREDSTARTUP1="/atrstartup"
SlashCmdList.ATRREMASTEREDSTARTUP=function()
    loggedIn=true
    if not Startup.started and not Startup.blocked then Startup.Start() end
    Startup.Status()
    Startup.ShowWarning()
end
