dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
-- Run from repository root: lua5.1 tools/tests/test_sell_post_refresh.lua
local f=assert(io.open('AuctionatorRemastered/Legacy/Auctionator.lua'))
local source=f:read('*a'):gsub('\r\n','\n'); f:close()
local function definition(name)
 return assert(source:match('(function '..name..'%s*%b().-\nend)'))
end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function scan(id)
 return {IDstring=id,quantity=0,sorts=0,
 AddScanItem=function(self,size,price,owner,count) self.quantity=self.quantity+size*count;self.owner=owner end,
 CondenseAndSort=function(self) self.sorts=self.sorts+1 end}
end
local cached,sell=scan('cloth'),{activeScan=scan('cloth')}
local buy={activeScan=cached};local other={activeScan=scan('other')}
function Atr_FindScan() return cached end
function UnitName() return 'Nisho' end
local zc={ItemIDStrfromLink=function(link) return link end,md=function() end}
local postings={ItemName='Cloth',ItemLink='cloth',StackSize=20,BuyoutPrice=10000,NumStacks=1}
local setup=assert(loadstring([[local zc,gSellPane,gShopPane,gMorePane,gJustPosted=...
local gCurrentPane=gSellPane
local gAtr_SellTriggeredByAuctionator=true
local gMS_stacksPrev=0
local gActiveAuctions={}
local gItemPostingInProgress=false
local gHlistNeedsUpdate=false
]]..definition('Atr_AddToScan')..'\n'..definition('Atr_OnAuctionOwnedUpdate')..'\n'..definition('Atr_OnAuctionMultiSellUpdate')..'\n'..[[
return function(pane,batch)
 gCurrentPane=pane;gAtr_SellTriggeredByAuctionator=true;gMS_stacksPrev=0;gJustPosted.NumStacks=batch
end
]]))(zc,sell,buy,other,postings)
local logs,history=0,0
function Atr_LogMsg() logs=logs+1 end
function Atr_AddHistoricalPrice() history=history+1 end
function Atr_IsModeActiveAuctions() return false end
function Atr_IsTabSelected() return true end
Atr_OnAuctionOwnedUpdate()
check(cached.quantity==20 and sell.activeScan.quantity==20,'confirmation updates replaced cache and visible Sell scan')
check(cached.sorts==1,'shared Buy/cache object inserted only once')
check(sell.UINeedsUpdate and buy.UINeedsUpdate,'matching panes scheduled for redraw')
check(other.activeScan.quantity==0 and not other.UINeedsUpdate,'unrelated item untouched')
check(logs==1 and history==1,'posting logged once')
Atr_OnAuctionOwnedUpdate()
check(sell.activeScan.quantity==20 and logs==1,'repeated owner update does not duplicate posting')
setup(buy,3)
Atr_OnAuctionMultiSellUpdate(1,3)
Atr_OnAuctionMultiSellUpdate(1,3)
check(cached.quantity==40 and cached.sorts==2,'duplicate progress does not insert or sort again')
Atr_OnAuctionMultiSellUpdate(3,3)
Atr_OnAuctionOwnedUpdate()
check(cached.quantity==80 and sell.activeScan.quantity==80,'batch confirmed deltas added across all matching scans')
check(logs==2 and history==2,'batch logging not duplicated by owned event')
Atr_AddToScan('cloth','Cloth',0,100,1)
check(cached.quantity==80,'zero stack rejected')
print('PASS: '..checks..' Sell post-confirmation, replaced cache, shared view, batch and redraw checks')
