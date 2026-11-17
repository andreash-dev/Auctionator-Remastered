-- Temporarily suspend only ElvUI's visual AFK mode while scanning.
-- This does not reset player inactivity, send input, or prevent server logout.
local saved
local function notice(source, message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. source .. ":|r " .. message)
    end
end
local function elvAFK()
    local engine = type(ElvUI) == "table" and ElvUI[1]
    if not engine or not engine.db or not engine.db.general or not engine.GetModule then return end
    local ok, module = pcall(engine.GetModule, engine, "AFK", true)
    if ok and module and type(module.Toggle) == "function" then return engine, module end
end
local function suspend()
    if saved then return end
    local engine, module = elvAFK()
    if not engine or engine.db.general.afk ~= true then return end
    local source = "Auctionator Remastered"
    saved = {engine=engine, module=module, enabled=engine.db.general.afk, source=source}
    engine.db.general.afk = false
    local ok = pcall(module.Toggle, module)
    if not ok then
        engine.db.general.afk = saved.enabled
        saved = nil
        return
    end
    if module.isAFK and type(module.SetAFK) == "function" then pcall(module.SetAFK, module, false) end
    notice(saved.source, "ElvUI AFK screen paused to prevent scan interruptions.")
end
local function restore()
    if not saved then return end
    local previous = saved
    saved = nil
    previous.engine.db.general.afk = previous.enabled
    local ok = pcall(previous.module.Toggle, previous.module)
    if ok then notice(previous.source, "Scanning ended. ElvUI AFK screen restored.") end
end
local function scanActive()
    return type(Atr_IsSlowFullScanActive) == "function" and Atr_IsSlowFullScanActive()
end
local function update()
    if scanActive() then suspend() else restore() end
end
AuctionatorRemastered.Legacy.Hook("Atr_FullScanStart", update)
AuctionatorRemastered.Legacy.Hook("Atr_OnAuctionHouseClosed", restore)
local guard = CreateFrame("Frame")
guard:RegisterEvent("PLAYER_LOGOUT")
guard:SetScript("OnEvent", restore)
local elapsedTotal = 0
guard:SetScript("OnUpdate", function(self,elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.25 then return end
    elapsedTotal = 0
    update()
end)
