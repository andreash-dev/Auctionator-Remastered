dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
-- Local Browse presentation sorting must never change native auction identity.
local f=assert(io.open('AuctionatorRemastered/Remastered/Integration/MarketPercent.lua'));local source=f:read('*a');f:close()
local identityPart=assert(source:match('(local function marketIdentity%b().-\nend)'))
local function widget(name)
    local w={scripts={},shown=true,id=0,width=180}
    function w:SetScript(k,v) self.scripts[k]=v end
    function w:IsShown() return self.shown end
    function w:Show() self.shown=true end
    function w:Hide() self.shown=false end
    function w:SetText(v) self.text=v end
    function w:SetWidth(v) self.width=v end
    function w:GetWidth() return self.width end
    function w:GetStringWidth() return 46 end
    function w:GetName() return name end
    function w:GetTextColor() return .95,.95,.95,1 end
    function w:SetTextColor(...) self.textColor={...} end
    function w:SetTexCoord(...) self.coords={...} end
    function w:GetHeight() return self.height or 8 end
    function w:GetTexture() return self.texture or 'native-hover' end
    function w:GetVertexColor() return .3,.3,.3,.6 end
    function w:SetVertexColor(...) self.vertex={...} end
    function w:GetAlpha() return .7 end
    function w:GetBlendMode() return 'BLEND' end
    function w:SetTexture(...) self.texture=...;self.textureArgs={...} end
    function w:GetNormalFontObject() return 'native-normal' end
    function w:GetHighlightFontObject() return 'native-highlight' end
    function w:SetNormalFontObject(value) self.normalFont=value end
    function w:SetHighlightFontObject(value) self.highlightFont=value end
    function w:GetFontString() self.font=self.font or widget();return self.font end
    function w:SetNormalTexture(value) self.arrow=self.arrow or widget();self.arrow.width=8;self.arrow.height=8;self.arrow.texture=value end
    function w:SetHighlightTexture(value)
        if type(value)=='table' then self.highlightTexture=value
        else self.highlightTexture=self.highlightTexture or widget();self.highlightTexture.texture=value end
    end
    function w:GetHighlightTexture() return self.highlightTexture end
    function w:GetPushedTexture() return self.pushed end
    function w:SetPushedTexture(value) self.pushed=value end
    function w:GetCheckedTexture() return self.checked end
    function w:GetHitRectInsets() return unpack(self.hitInsets or {0,0,0,0}) end
    function w:SetHitRectInsets(...) self.hitInsets={...} end
    function w:SetAllPoints(relative) self.allPoints=relative end
    function w:SetSize(v) self.width=v end
    function w:SetPoint(...) self.anchor={...} end
    function w:SetID(v) self.id=v end
    function w:GetID() return self.id end
    function w:GetFrameLevel() return 1 end
    function w:GetNormalTexture() return self.arrow end
    function w:CreateFontString() return widget() end
    function w:CreateTexture() return widget() end
    function w:SetChecked(v) self.checked=v end
    function w:GetChecked() return self.checked end
    function w:Enable() self.enabled=true end
    function w:Disable() self.enabled=false end
    setmetatable(w,{__index=function(_,key) if key:find('^Set') or key=='ClearAllPoints' then return function() end end end})
    if name then _G[name]=w end
    return w
end
function CreateFrame(_,name) return widget(name) end
local hooks={}
function hooksecurefunc(name,callback) hooks[name]=callback end
function Atr_GetScanDay_Today() return 100 end
gAtr_ScanDB={A={mr=100},B={mr=100},C={mr=100}}
local mf=assert(io.open('AuctionatorRemastered/Remastered/Models/MarketHistory.lua'));local mathPart=mf:read('*a');mf:close()
assert(loadstring(identityPart.."\n"..mathPart))()
NUM_BROWSE_TO_DISPLAY=3;ATR_FS_NULL=0;gAtr_FullScanState=0
BrowseScrollFrame=widget();AuctionFrameBrowse=widget();AuctionFrameBrowse.page=0
BrowseLevelSort=widget('BrowseLevelSort');BrowseResetButton=widget('BrowseResetButton')
BrowseQualitySort=widget('BrowseQualitySort');BrowseQualitySort.highlightTexture=widget();BrowseQualitySort:SetNormalTexture('Interface\\Buttons\\UI-SortArrow')
BrowseQualitySortArrow=widget('BrowseQualitySortArrow');BrowseQualitySortArrow.width=9;BrowseQualitySortArrow.height=8
BrowseQualitySortRight=widget('BrowseQualitySortRight')
Atr_BrowseMarketSortMiddle=widget('Atr_BrowseMarketSortMiddle');Atr_BrowseMarketSortMiddle:SetTexture('vanilla-tab-art')
Atr_BasicOptionsFrame=widget()
local offset,selected=0,1
function FauxScrollFrame_GetOffset() return offset end
function FauxScrollFrame_SetOffset(_,n) offset=n end
for i=1,3 do widget('BrowseButton'..i);widget('BrowseButton'..i..'Name');widget('BrowseButton'..i..'Level') end
local listings={{'A',1,100},{'B',2,100},{'C',1,300},{'A',1,0},{'NoData',1,20},{'A',2,120},{'B',1,1000},{'A',2,200},{'A',1,99},{'A',1,105}}
local count=#listings
function GetNumAuctionItems() return count,count end
function GetAuctionItemInfo(kind,index)
    local row=listings[index];if not row then return end
    return row[1],'icon'..index,row[2],1,true,80,1,1,row[3]
end
function GetAuctionItemTimeLeft(_,index) return index end
function GetAuctionItemLink(_,index) return 'item:'..index end
function GetSelectedAuctionItem() return selected end
function AuctionFrame_OnClickSortColumn() end
function SortButton_UpdateArrow(button)
 local arrow=_G[button:GetName()..'Arrow'];if arrow then arrow:Show();arrow:SetTexCoord(0,.5625,0,1) end
end
local renders,fail,buyout=0,false,nil
function AuctionFrameBrowse_Update()
    renders=renders+1
    for i=1,3 do
        local row=_G['BrowseButton'..i];local index=offset+i
        row.displayName=GetAuctionItemInfo('list',index)
        row.displayLink=GetAuctionItemLink('list',index)
        row.displayTime=GetAuctionItemTimeLeft('list',index)
        row.highlight=index==GetSelectedAuctionItem('list')
        if row.highlight then buyout=select(9,GetAuctionItemInfo('list',index)) end
        row.bidIndex=GetSelectedAuctionItem('list') -- native selection appears at its visual position during render
    end
    if fail then error('render failed') end
end
local function badge(row)
    row.atrMarketPercent=row.atrMarketPercent or widget();row.atrMarketPercent:Show();return row.atrMarketPercent
end
local updatePart=source:sub(assert(source:find('local function updateBrowse()',1,true)),assert(source:find('\nlocal function explain',1,true))-1)
local sortStart=assert(source:find('-- Browse-only presentation sort.',1,true))
local sortPart=source:sub(sortStart)
assert(loadstring('return function(badge)\n'..identityPart..'\n'..updatePart..'\n'..sortPart..'\nreturn updateBrowse end'))()(badge)()
local n=0
local function check(ok,msg) n=n+1;assert(ok,msg) end
check(Atr_BrowseMarketColumnEnabled() and Atr_BrowseMarketSort:IsShown(),'column enabled by default')
check(BrowseQualitySortRight.anchor[4]==-80,'vanilla Rarity background ends with its trimmed hit and highlight area')
check(Atr_BrowseMarketSortMiddle.texture=='vanilla-tab-art','vanilla Market tab preserves the same background art as native headers')
check(Atr_BrowseMarketSort.normalFont=='native-normal' and Atr_BrowseMarketSort.highlightFont=='native-highlight','Market % uses native header text and hover fonts')
check(Atr_BrowseMarketSort.highlightTexture.texture=='Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight','standard UI uses the native sort-header highlight asset')
check(not Atr_BrowseMarketSort.arrow:IsShown() and Atr_BrowseMarketSort.text=='Market %','inactive Market header has no extra direction marker')
check(BrowseButton1Name.width==106 and BrowseButton1.atrMarketPercent:IsShown(),'dedicated column reserves name width')
local order=Atr_BuildBrowseMarketOrder(count,GetAuctionItemInfo,false)
check(table.concat(order,',')=='2,6,9,1,8,10,3,7,4,5','unit-price ascending, stable ties, unknown/no-buyout last')
Atr_BrowseMarketSort.scripts.OnClick()
check(BrowseButton1.displayLink=='item:2' and BrowseButton2.displayLink=='item:6' and BrowseButton3.displayLink=='item:9','native renderer receives sorted rows')
check(Atr_BrowseMarketSort.arrow:IsShown() and not BrowseQualitySort.arrow:IsShown() and Atr_BrowseMarketSort.arrow.texture=='Interface\\Buttons\\UI-SortArrow','only Market % displays the native arrow while its sort is active')
check(BrowseButton1:GetID()+offset==2 and BrowseButton2:GetID()+offset==6,'row IDs point to native auction indexes')
check(GetAuctionItemLink('list',1)=='item:1' and GetAuctionItemTimeLeft('list',1)==1,'raw APIs unchanged outside renderer')
check(GetSelectedAuctionItem('list')==1,'native selected auction is never remapped outside redraw')
offset=3;AuctionFrameBrowse_Update()
check(BrowseButton1.displayLink=='item:1' and BrowseButton1.highlight,'selection highlights correct row after scrolling')
check(BrowseButton2:GetID()+offset==8,'scrolled row keeps native purchase/tooltip identity')
-- Blizzard BrowseButton_OnClick selects ID + scroll offset, then redraws.
selected=BrowseButton2:GetID()+offset;AuctionFrameBrowse_Update()
check(selected==8 and BrowseButton2.highlight,'selecting sorted/scrolled row selects and retains correct native auction')
check(selected==8 and buyout==200,'native buyout selection and displayed price belong to the same auction')
check(BrowseButton2.displayTime==8 and BrowseButton2.displayLink=='item:8','time and link agree with selected row')
Atr_BrowseMarketSort.scripts.OnClick()
check(offset==0 and BrowseButton1.displayLink=='item:7','second click reverses to descending and resets scroll')
check(Atr_GetBrowseMarketIndex(9)==4 and Atr_GetBrowseMarketIndex(10)==5,'missing prices last in descending too')
hooks.AuctionFrame_OnClickSortColumn('list','quality')
check(BrowseButton1.displayLink=='item:1' and BrowseButton1:GetID()==1,'native sort exits percent sorting')
check(not Atr_BrowseMarketSort.arrow:IsShown() and Atr_BrowseMarketSort.text=='Market %','native list/field sort clears the Market direction indicator')
Atr_BrowseMarketSort.scripts.OnClick();Atr_SetBrowseMarketColumnEnabled(false)
check(not Atr_BrowseMarketSort:IsShown() and not BrowseButton1.atrMarketPercent:IsShown(),'toggle hides both header and percentages')
check(BrowseButton1Name.width==180 and BrowseButton1:GetID()==1,'toggle restores full name width and native IDs')
check(AUCTIONATOR_SAVEDVARS.browseMarketPercent==false,'toggle is saved in existing SavedVariables')
check(BrowseQualitySort.hitInsets[2]==0 and BrowseQualitySort.highlightTexture.allPoints==BrowseQualitySort,'disabling Market % restores the full native Rarity hover area')
check(BrowseQualitySortRight.anchor[4]==0,'disabling Market % restores full vanilla Rarity background')
Atr_SetBrowseMarketColumnEnabled(true);Atr_BrowseMarketSort.scripts.OnClick()
gAtr_FullScanState=1;AuctionFrameBrowse_Update()
check(BrowseButton1.displayLink=='item:1' and not Atr_BrowseMarketSort.enabled,'full scan never uses local sort')
gAtr_FullScanState=0;count=100;AuctionFrameBrowse_Update()
check(BrowseButton1.displayLink=='item:1','bulk result sets are not sorted')
count=10;fail=true
check(not pcall(AuctionFrameBrowse_Update),'renderer errors propagate')
check(GetAuctionItemLink('list',1)=='item:1' and GetSelectedAuctionItem('list')==selected,'render context always cleared after error')
fail=false;AuctionFrameBrowse_Update()
check(BrowseButton1.displayLink=='item:2','render recovers after error')
local opened
function InterfaceOptionsFrame_OpenToCategory(panel) opened=panel end
check(Atr_BrowseMarketSettings==nil,'Browse has no redundant Settings shortcut')
check(BrowseQualitySort.width==180 and BrowseQualitySort.hitInsets[2]==80,'Rarity mouse area reserves Market % without shifting native columns')
check(BrowseQualitySort.highlightTexture.anchor[1]=='BOTTOMRIGHT' and BrowseQualitySort.highlightTexture.anchor[4]==-80,'Rarity highlight stops before Market %')
check(Atr_BrowseMarketSort.font.textColor[1]==.95,'Market label matches actual native text color, not just its font object')
check(Atr_BrowseMarketSort.arrow.width==9 and Atr_BrowseMarketSort.arrow.coords[2]==.5625,'Market arrow uses native named-arrow size and cropped texture')
check(Atr_BrowseMarketSort.arrow.anchor[1]=='LEFT' and Atr_BrowseMarketSort.arrow.anchor[2]==Atr_BrowseMarketSort.font and Atr_BrowseMarketSort.font.width==46,'sort arrow follows the actual Market percent text width')
SortButton_UpdateArrow(BrowseQualitySort,'list','quality')
hooks.SortButton_UpdateArrow(BrowseQualitySort,'list','quality')
check(not BrowseQualitySortArrow:IsShown() and Atr_BrowseMarketSort.arrow:IsShown(),'late native arrow updates cannot show a second active sort indicator')
hooks.AuctionFrame_OnClickSortColumn('list','quality')
SortButton_UpdateArrow(BrowseQualitySort,'list','quality')
hooks.SortButton_UpdateArrow(BrowseQualitySort,'list','quality')
check(BrowseQualitySortArrow:IsShown() and not Atr_BrowseMarketSort.arrow:IsShown(),'switching to native sort restores its arrow and hides Market direction')
Atr_BrowseMarketSort.scripts.OnClick()
check(not BrowseQualitySortArrow:IsShown() and Atr_BrowseMarketSort.arrow:IsShown(),'switching back to Market hides both named and skinned native arrows')
Atr_UpdateBrowseMarketControls();Atr_UpdateBrowseMarketControls()
check(BrowseQualitySort.hitInsets[2]==80,'repeated redraws do not cumulatively shrink the Rarity hit area')
-- Reproduce the user's older/partially loaded ElvUI skin: no StyleButton
-- or hover property on the reference header. Styling must still run.
ElvUI={};BrowseQualitySort.StyleButton=nil;BrowseQualitySort.hover=nil
for _,suffix in ipairs({'Left','Middle','Right'}) do
 local region=widget('Atr_BrowseMarketSort'..suffix);region:SetTexture('vanilla-tab-art')
end
local whiteHighlight=Atr_BrowseMarketSort.highlightTexture
Atr_UpdateBrowseMarketControls()
local realHover=Atr_BrowseMarketSort.atrHover
check(realHover and Atr_BrowseMarketSort.highlightTexture==realHover and realHover.textureArgs[4]==.3,'ElvUI uses its actual 30 percent color-texture recipe even when native helper fields are absent')
check(Atr_BrowseMarketSort.pushed==Atr_BrowseMarketSort.atrPushed and Atr_BrowseMarketSort.pushed.textureArgs[1]==.9 and Atr_BrowseMarketSort.pushed.textureArgs[4]==.3,'Market header uses the exact native ElvUI yellow pressed overlay alongside its independent hover')
check(whiteHighlight.texture==nil,'old opaque highlight is cleared rather than left beneath the new texture')
check(Atr_BrowseMarketSortLeft.texture==nil and Atr_BrowseMarketSortMiddle.texture==nil and Atr_BrowseMarketSortRight.texture==nil,'ElvUI removes all three vanilla tab pieces while retaining the custom hover and sort arrow')
Atr_UpdateBrowseMarketControls()
check(Atr_BrowseMarketSort.atrHover==realHover and Atr_BrowseMarketSort.highlightTexture==realHover,'redraw retains the single native-style highlight')
BrowseQualitySort.GetRight=function() return 400 end
BrowseQualitySort.GetEffectiveScale=function() return 1 end
Atr_BrowseMarketSort.GetLeft=function() return 322 end
Atr_BrowseMarketSort.GetEffectiveScale=function() return 1 end
Atr_UpdateBrowseMarketControls()
check(BrowseQualitySort.hitInsets[2]==79 and BrowseQualitySort.highlightTexture.anchor[4]==-79,'Rarity highlight and hit area stop one pixel before the actual Market left edge')
BrowseQualitySort.pushed=widget();BrowseQualitySort.checked=widget()
Atr_UpdateBrowseMarketControls()
check(BrowseQualitySort.pushed.anchor[4]==-79 and BrowseQualitySort.checked.anchor[4]==-79,'late-created yellow pressed and checked overlays stop at the same Rarity boundary')
Atr_SetBrowseMarketColumnEnabled(false)
check(BrowseQualitySort.pushed.allPoints==BrowseQualitySort and BrowseQualitySort.checked.allPoints==BrowseQualitySort,'disabling Market restores full-width native pressed/checked overlays')

local originalValue=Atr_MarketPercentValue
local originalHandles=Atr_DatabaseHandles
Atr_DatabaseHandles=function() return true end
Atr_MarketPercentValue=function(value) return value=='item:1:0' and 20 or 80 end
local exactOrder=Atr_BuildBrowseMarketOrder(2,function() return 'Shared',nil,1,nil,nil,nil,nil,nil,100 end,false,
    function(_,index) return index==1 and 'item:2:0' or 'item:1:0' end)
check(exactOrder[1]==2 and exactOrder[2]==1,'Browse sorting reads exact row identities when a managed database is active')
Atr_MarketPercentValue=originalValue;Atr_DatabaseHandles=originalHandles
print('PASS: '..n..' Browse market sorting, identity, settings and render-isolation checks')
