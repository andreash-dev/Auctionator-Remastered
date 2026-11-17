-- Exercise seller attribution and reusable-row/merchant integration without queries.
dofile('AuctionatorRemastered/Remastered/Core/Bootstrap.lua')
dofile('AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua')
dofile('AuctionatorRemastered/Remastered/Models/Sellers.lua')
local hooks = {}
function hooksecurefunc(target, method, callback)
 if callback then hooks[target] = hooks[target] or {}; hooks[target][method] = callback
 else hooks[target] = method end
end
function QueryAuctionItems() error('Details must not request auction data') end
function UnitName() return 'Me' end
AtrScan = {}
GameTooltip = {SetMerchantItem = function() end}
AUCTION_CREATOR, UNKNOWN = 'Seller', 'Unknown'
local function widget(parent)
 local w = {parent=parent, shown=true}
 function w:GetParent() return self.parent end
 function w:CreateFontString() return widget(self) end
 function w:SetPoint(...) self.point={...} end
 function w:SetWidth(width) self.width=width end
 function w:SetJustifyH() end
 function w:GetFont() return 'test-font', 12, '' end
 function w:SetFont(...) self.font={...} end
 function w:GetTextColor() return .6,.6,.6 end
 function w:SetTextColor(...) self.color={...} end
 function w:SetText(text) self.text=text end
 function w:Hide() self.shown=false end
 function w:Show() self.shown=true end
 function w:IsShown() return self.shown end
 function w:GetID() return self.id end
 return w
end
local scan = {scanData={
 {stackSize=1,buyoutPrice=100,owner='Me'},
 {stackSize=1,buyoutPrice=100,owner='Ann'},
 {stackSize=1,buyoutPrice=100,owner='Anna'},
 {stackSize=2,buyoutPrice=200,owner='Solo'},
 {stackSize=2,buyoutPrice=200,owner='Solo'},
 {stackSize=3,buyoutPrice=0,owner=''},
},sortedData={
 {stackSize=1,buyoutPrice=100,yours=true,type='n'},
 {stackSize=1,buyoutPrice=100,yours=false,type='n'},
 {stackSize=2,buyoutPrice=200,yours=false,type='n'},
 {stackSize=3,buyoutPrice=0,yours=false,type='n'},
}}
function Atr_GetCurrentPane() return {activeScan=scan} end
function Atr_FindScan() return scan end
local labels={}
local parent=widget()
function parent:CreateFontString() local w=widget(self);labels[#labels+1]=w;return w end
Atr_Col3_Heading=widget(parent)
for i=1,12 do
 local row=widget();row.id=i;_G['AuctionatorEntry'..i]=row
 _G['AuctionatorEntry'..i..'_EntryText']=widget(parent)
end
local calls={}
function GetMerchantItemLink(slot) return slot==1 and 'item:123' or nil end
function GetMerchantItemInfo() return 'Item',nil,nil,5 end
function Atr_ShowTipWithPricing(...) calls[#calls+1]={...} end
dofile('AuctionatorRemastered/Remastered/Integration/AuctionDetails.lua')
hooks[AtrScan].CondenseAndSort(scan)
assert(scan.sortedData[1].sellerName=='Me' and not scan.sortedData[1].multipleSellers)
assert(scan.sortedData[2].multipleSellers, 'Exact names must distinguish Ann from Anna')
assert(scan.sortedData[3].sellerName=='Solo' and not scan.sortedData[3].multipleSellers)
assert(scan.sortedData[4].sellerName==nil)
hooks.Atr_ShowCurrentAuctions()
assert(labels[1].text=='Seller' and labels[2].text=='Me')
assert(labels[3].text=='Multiple Sellers' and labels[4].text=='Solo' and labels[5].text=='Unknown')
assert(labels[3].point[4]==192 and labels[3].font[2]==12 and labels[3].color[1]==.6)
for _,name in ipairs({'Atr_ShowHistory','Atr_ShowSearchSummary','Atr_ClearList'}) do
 hooks[name]();for _,label in ipairs(labels) do assert(not label.shown) end
 hooks.Atr_ShowCurrentAuctions();assert(#labels==5, 'Reuse labels on redraw')
end
-- Rebuild with a different owner; stale attribution must disappear.
scan.scanData[2].owner='Anna';hooks[AtrScan].CondenseAndSort(scan)
assert(scan.sortedData[2].sellerName=='Anna' and not scan.sortedData[2].multipleSellers)
scan.sortedData={};hooks.Atr_ShowCurrentAuctions()
for _,label in ipairs(labels) do assert(not label.shown) end
hooks[GameTooltip].SetMerchantItem(GameTooltip,1)
hooks[GameTooltip].SetMerchantItem(GameTooltip,2)
assert(#calls==1 and calls[1][1]==GameTooltip and calls[1][2]=='item:123' and calls[1][3]==5)
GetMerchantItemInfo=function() end
hooks[GameTooltip].SetMerchantItem(GameTooltip,1)
assert(calls[2][3]==1)
-- The former companion's useful input guard belongs at the actual cache boundary.
assert(loadfile('AuctionatorRemastered/Legacy/AuctionatorVendor.lua'))('Auctionator',{zc={}})
assert(Atr_GetBondType(nil)==ATR_BINDTYPE_UNKNOWN and Atr_GetBondType('123')==ATR_BINDTYPE_UNKNOWN)
local cacheCalls=0
AtrBindTypeToolTip={SetOwner=function() cacheCalls=cacheCalls+1 end,NumLines=function() return 0 end,Hide=function() end}
assert(Atr_GetBondType(123)==ATR_CAN_BE_AUCTIONED)
assert(Atr_GetBondType(123)==ATR_CAN_BE_AUCTIONED and cacheCalls==1)
print('PASS: seller groups, exact names, own auctions, redraw/view cleanup, native fonts, merchant stacks and binding cache guard; zero queries')
