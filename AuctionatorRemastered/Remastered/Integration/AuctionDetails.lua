-- Remastered-owned seller column and merchant pricing integration.
local R = AuctionatorRemastered
local labels, heading = {}

local function hideSellers()
    if heading then heading:Hide() end
    for _, label in pairs(labels) do label:Hide() end
end

local function columnLabel(source)
    local label = source:GetParent():CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", source, "LEFT", 192, 0)
    label:SetWidth(100)
    label:SetJustifyH("LEFT")
    return label
end

local function matchFont(label, source)
    label:SetFont(source:GetFont())
    label:SetTextColor(source:GetTextColor())
end

R.Legacy.Hook("Atr_ShowCurrentAuctions", function()
    hideSellers()
    local pane = Atr_GetCurrentPane()
    local scan = pane and pane.activeScan or Atr_FindScan(nil)
    if not scan or not scan.sortedData or #scan.sortedData == 0 then return end
    heading = heading or columnLabel(Atr_Col3_Heading)
    matchFont(heading, Atr_Col3_Heading)
    heading:SetText(AUCTION_CREATOR)
    heading:Show()
    for index = 1, 12 do
        local row = _G["AuctionatorEntry"..index]
        local data = row and scan.sortedData[row:GetID()]
        if data and data.type == "n" and row:IsShown() then
            local source = _G["AuctionatorEntry"..index.."_EntryText"]
            local label = labels[index] or columnLabel(source)
            labels[index] = label
            matchFont(label, source)
            label:SetText(data.multipleSellers and "Multiple Sellers" or data.sellerName or UNKNOWN)
            label:Show()
        end
    end
end)

-- These views reuse the same rows and headings.
R.Legacy.Hook("Atr_ShowHistory", hideSellers)
R.Legacy.Hook("Atr_ShowSearchSummary", hideSellers)
R.Legacy.Hook("Atr_ClearList", hideSellers)

if AtrScan then
    hooksecurefunc(AtrScan, "CondenseAndSort", function(scan)
        R.Models.Sellers.Attach(scan, UnitName("player"))
    end)
end

if GameTooltip and GameTooltip.SetMerchantItem then
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, slot)
        local link = GetMerchantItemLink(slot)
        if not link then return end
        local _, _, _, quantity = GetMerchantItemInfo(slot)
        Atr_ShowTipWithPricing(tooltip, link, tonumber(quantity) or 1)
    end)
end
