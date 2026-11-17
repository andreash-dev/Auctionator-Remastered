-- Learn metadata from already returned auction pages and legacy tooltip hooks.
local Browser=AuctionatorRemastered.Browser
local className,cachedInfo,remember=Browser.ClassName,Browser.CachedInfo,Browser.Remember
-- Remember metadata while the normal UI already has a real item link. Price
-- scans stay untouched; this only reads the client's item cache.
AuctionatorRemastered.Legacy.Hook("Atr_UpdateScanDBitemID",function(name, link)
    if link then cachedInfo(link) end
end)
AuctionatorRemastered.Legacy.Hook("Atr_ShowTipWithPricing",function(tip,link)
    if link then cachedInfo(link) end
end)

-- Capture metadata from ordinary, already-returned AH pages. Full scans use
-- their own deduplicated row capture above; never loop over their bulk buffer here.
function Atr_BrowserRememberAuctionPage(explicitClass)
    if not AuctionFrame or not AuctionFrame:IsShown() then return 0 end
    if gAtr_FullScanState and gAtr_FullScanState ~= ATR_FS_NULL then return 0 end
    local count = GetNumAuctionItems("list")
    if not count or count > 50 then return 0 end
    local filteredClass = className(explicitClass)
    if not filteredClass and AuctionFrameBrowse and AuctionFrameBrowse:IsShown() then
        filteredClass = className(AuctionFrameBrowse.selectedClassIndex)
    end
    local captured = 0
    for index = 1, count do
        local name, texture, _, quality = GetAuctionItemInfo("list", index)
        if name then
            local link = GetAuctionItemLink("list", index)
            local knownLink, knownQuality, class, subclass, knownTexture, equipLoc = cachedInfo(link or name)
            remember(name, knownLink or link, knownQuality or quality, class or filteredClass, subclass, knownTexture or texture, equipLoc)
            captured = captured + 1
        end
    end
    return captured
end
local metadataEvents = CreateFrame("Frame")
metadataEvents:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
metadataEvents:SetScript("OnEvent",function()
    -- Postpone briefly so the normal result handlers can finish first.
    local wait = 0.2
    metadataEvents:SetScript("OnUpdate",function(self,elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        self:SetScript("OnUpdate",nil)
        if Atr_BrowserRememberAuctionPage() > 0 then Atr_RefreshOfflineBrowser() end
    end)
end)

