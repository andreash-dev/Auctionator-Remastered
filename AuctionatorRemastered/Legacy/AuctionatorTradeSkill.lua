-- Anchor to recipe content, not the larger invisible TradeSkillFrame bounds.
-- Skillet owns its own toolbar placement through the public button API.
local skilletButton
local fonts={}
local function compact(button)
    if not fonts.normal then
        local face,_,flags=GameFontNormalSmall:GetFont()
        for _,spec in ipairs({{"normal",1,0.82,0},{"highlight",1,1,1},{"disabled",0.5,0.5,0.5}}) do
            local font=CreateFont("AuctionatorRecipeButton_"..spec[1])
            font:CopyFontObject(GameFontNormalSmall);font:SetFont(face,10,flags)
            font:SetTextColor(spec[2],spec[3],spec[4]);fonts[spec[1]]=font
        end
    end
    button:SetSize(70,18);button:SetText("Scan AH")
    button:SetNormalFontObject(fonts.normal)
    button:SetHighlightFontObject(fonts.highlight)
    button:SetDisabledFontObject(fonts.disabled)
end
local function tip(button)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine("Scan AH",1,0.82,0)
        GameTooltip:AddLine("Search the AH for the selected recipe's item and materials. Requires an open auction house.",1,1,1,true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function Atr_UpdateTradeSkillTools()
    if Auctionator_Search and TradeSkillDetailScrollChildFrame then
        compact(Auctionator_Search)
        Auctionator_Search:SetParent(TradeSkillDetailScrollChildFrame)
        Auctionator_Search:ClearAllPoints()
        Auctionator_Search:SetPoint("TOPRIGHT",TradeSkillDetailScrollChildFrame,"TOPRIGHT",-4,-4)
        if SkilletFrame and SkilletFrame:IsShown() then Auctionator_Search:Hide() else Auctionator_Search:Show() end
    end
    if Skillet and SkilletFrame and Skillet.AddButtonToTradeskillWindow and not skilletButton then
        skilletButton=CreateFrame("Button","AuctionatorSkilletRecipe",SkilletFrame,"UIPanelButtonTemplate")
        skilletButton:SetSize(70,18);skilletButton:SetText("Scan AH")
        compact(skilletButton)
        skilletButton:SetScript("OnClick",Atr_ScanTradeSkillRecipe);tip(skilletButton)
        Skillet:AddButtonToTradeskillWindow(skilletButton)
    end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"TRADE_SKILL_SHOW","TRADE_SKILL_UPDATE","ADDON_LOADED"}) do events:RegisterEvent(event) end
local pending
events:SetScript("OnEvent",function() pending=0.1 end)
events:SetScript("OnUpdate",function(self,elapsed)
    if pending then pending=pending-elapsed;if pending<=0 then pending=nil;Atr_UpdateTradeSkillTools() end end
end)
