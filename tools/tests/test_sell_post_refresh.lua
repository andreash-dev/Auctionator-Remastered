-- Run from repository root: lua5.1 tools/tests/test_sell_post_refresh.lua
local f=assert(io.open('AuctionatorRemastered/Legacy/Auctionator.lua'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local function definition(name)
 return assert(source:match('(function '..name..'%s*%b().-\nend)'),name)
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
local ownerRows,ownerTotal={},nil
function GetNumAuctionItems() return #ownerRows,ownerTotal or #ownerRows end
function GetAuctionItemInfo(_,index)
 local row=ownerRows[index]
 return row.name,nil,row.size,nil,nil,nil,nil,nil,row.price
end
function GetAuctionItemLink(_,index) return ownerRows[index].link end
local function owned(link,size,price) return {name='Cloth',link=link,size=size,price=price} end
local zc={ItemIDStrfromLink=function(link) return link end,md=function() end}
local postings={ItemName='Cloth',ItemLink='cloth',StackSize=20,BuyoutPrice=10000,NumStacks=1}
local names={'Atr_AddToScan','Atr_CountPostedOwnerAuctions','Atr_ResetPostingProgress',
 'Atr_ConfirmPostedAuctions','Atr_FinishPostingProgress','Atr_OnAuctionPostedMessage',
 'Atr_OnAuctionOwnedUpdate','Atr_OnAuctionMultiSellUpdate','Atr_OnAuctionMultiSellFailure'}
local definitions={}
for _,name in ipairs(names) do definitions[#definitions+1]=definition(name) end
local setup=assert(loadstring([[local zc,gSellPane,gShopPane,gMorePane,gJustPosted=...
local gCurrentPane=gSellPane
local gAtr_SellTriggeredByAuctionator=false
local gMS_stacksPrev=0
local gActiveAuctions={}
local gItemPostingInProgress=false
local gHlistNeedsUpdate=false
local gPostingOwnerListReady=false
]]..table.concat(definitions,'\n')..'\n'..[[
return function(batch,ready)
 gCurrentPane=gSellPane;gAtr_SellTriggeredByAuctionator=true;gMS_stacksPrev=0
 gJustPosted.ItemName='Cloth';gJustPosted.NumStacks=batch;gPostingOwnerListReady=ready
 Atr_ResetPostingProgress()
end
]]))(zc,sell,buy,other,postings)
local logs,history,loggedStacks=0,0,0
function Atr_LogMsg(_,_,_,count) logs=logs+1;loggedStacks=loggedStacks+count end
function Atr_AddHistoricalPrice() history=history+1 end
function Atr_IsModeActiveAuctions() return false end
function Atr_IsTabSelected() return true end
function Atr_ClearScanCache() end
ERR_AUCTION_STARTED='Auction created.'
ATR_FS_NULL=0;gAtr_FullScanState=0
-- Baseline includes an existing identical listing. Only the increase is new.
ownerRows={owned('cloth',20,10000)}
setup(1,true)
ownerRows[2]=owned('cloth',20,10000)
Atr_OnAuctionOwnedUpdate()
check(cached.quantity==20 and sell.activeScan.quantity==20,'owner confirmation updates cached and detached visible Sell scans')
check(cached.sorts==1,'shared Buy/cache object inserted once')
check(sell.UINeedsUpdate and buy.UINeedsUpdate,'matching panes scheduled for redraw')
check(other.activeScan.quantity==0 and not other.UINeedsUpdate,'unrelated item untouched')
Atr_OnAuctionOwnedUpdate();Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED);Atr_OnAuctionMultiSellUpdate(1,1)
check(cached.quantity==20 and logs==1,'repeated confirmations do not duplicate a completed posting')
-- No multi-sell events: system acknowledgements alone update a whole batch.
setup(3,false)
Atr_OnAuctionPostedMessage('Unrelated message')
check(cached.quantity==20,'unrelated chat ignored')
Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED)
check(cached.quantity==40,'first acknowledgement immediately updates Sell')
Atr_OnAuctionOwnedUpdate()
check(cached.quantity==40,'unprimed owner list cannot import old auctions as new postings')
Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED);Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED)
check(cached.quantity==80 and sell.activeScan.quantity==80,'batch succeeds without multi-sell progress')
check(logs==2 and history==2 and loggedStacks==4,'completed batch logged once with exact stack total')
-- Mixed sources and duplicate/out-of-order multi-sell progress.
setup(3,true)
Atr_OnAuctionMultiSellUpdate(1,3);Atr_OnAuctionMultiSellUpdate(1,3)
Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED)
check(cached.quantity==100,'chat and repeated multi-sell share cumulative confirmation')
ownerRows[3]=owned('cloth',20,10000);ownerRows[4]=owned('cloth',20,10000)
Atr_OnAuctionOwnedUpdate();Atr_OnAuctionMultiSellUpdate(1,3)
check(cached.quantity==120,'owner-list fallback confirms batch progress without recounting')
Atr_OnAuctionMultiSellUpdate(3,3);Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED)
check(cached.quantity==140 and logs==3 and loggedStacks==7,'mixed sources count each stack once')
-- Failure must neither fabricate an extra auction nor lose confirmed history.
setup(3,true)
Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED);Atr_OnAuctionMultiSellFailure()
check(cached.quantity==160 and loggedStacks==8,'failure logs only confirmed stacks, adds no phantom listing')
Atr_OnAuctionMultiSellFailure();Atr_OnAuctionPostedMessage(ERR_AUCTION_STARTED)
check(cached.quantity==160 and logs==4,'late callbacks ignored after failure')
setup(3,true);Atr_OnAuctionMultiSellFailure()
check(logs==4 and history==4,'zero-progress failure creates no history')
-- An incomplete owner buffer or uncached item must not count as confirmation.
setup(2,true);ownerTotal=#ownerRows+1
ownerRows[5]=owned('cloth',20,10000)
ownerTotal=#ownerRows+1;Atr_OnAuctionOwnedUpdate()
check(cached.quantity==160,'partial owner-list buffer ignored')
ownerTotal=nil;ownerRows[5].link=nil;Atr_OnAuctionOwnedUpdate()
check(cached.quantity==160,'missing owner item link ignored')
ownerRows[5]=owned('other',20,10000);Atr_OnAuctionOwnedUpdate()
check(cached.quantity==160,'same-name different identity ignored')
Atr_AddToScan('cloth','Cloth',0,100,1)
check(cached.quantity==160,'zero stack rejected')
check(source:find('self:RegisterEvent("CHAT_MSG_SYSTEM");',1,true),'system acknowledgement event registered')
check(source:find('then Atr_OnAuctionPostedMessage(...); end;',1,true),'acknowledgement routed independently of chat-frame hooks')
print('PASS: '..checks..' Sell acknowledgement, owner-list fallback, batch, redraw and deduplication checks')
