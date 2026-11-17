-- Boundary to the inherited Auctionator engine. Resolve globals at call time:
-- Blizzard_AuctionUI and the original panes are initialized lazily at the AH.
local Legacy = AuctionatorRemastered.Legacy
function Legacy.Hook(name, callback)
    return hooksecurefunc(name, callback)
end
function Legacy.GetActivePriceDatabase()
    return gAtr_ScanDB
end
function Legacy.GetBrowserPriceDatabase()
    if AuctionatorRemastered.Database and AuctionatorRemastered.Database.failed then return {} end
    if type(gAtr_ScanDB) == "table" then return gAtr_ScanDB end
    local key = GetRealmName().."_"..UnitFactionGroup("player")
    return type(AUCTIONATOR_PRICE_DATABASE) == "table" and AUCTIONATOR_PRICE_DATABASE[key] or {}
end
function Legacy.SearchBuyExact(name)
    if gAtr_FullScanState and gAtr_FullScanState~=ATR_FS_NULL then
        if UIErrorsFrame then UIErrorsFrame:AddMessage('Wait for the full scan to finish before searching Buy.',1,.8,.2) end
        return
    end
    Atr_SelectPane(3) -- Buy pane, independent of its current tab index.
    Atr_SetSearchText('"'..name..'"')
    Atr_Search_Onclick()
end
