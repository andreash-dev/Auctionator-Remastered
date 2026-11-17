dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
-- Exercise the original full-scan analyzer, including its 1000-row yield.
local function source(path)
    local file=assert(io.open(path,'rb'));local text=file:read('*a');file:close();return text:gsub('\r\n','\n')
end
local now,driver=0,nil
function GetTime() return now end
function CreateFrame()
    local frame={scripts={}}
    function frame:Hide() self.shown=false end
    function frame:Show() self.shown=true end
    function frame:SetScript(name,callback) self.scripts[name]=callback end
    driver=frame;return frame
end
local hooks={}
function hooksecurefunc(name,callback) hooks[name]=callback end
local queries,priceWrites,linkReads,cacheReads,refreshes=0,0,0,0,0
function QueryAuctionItems() queries=queries+1 end
function Atr_UpdateScanDBprice() priceWrites=priceWrites+1 end
function Atr_RefreshOfflineBrowser() refreshes=refreshes+1 end
function Atr_BrowserSetMetadataStatus(text) _G.status=text end
local listings={}
local linkError=false
function GetAuctionItemLink(_,index)
    linkReads=linkReads+1
    if linkError then error('missing link response') end
    return listings[index] and listings[index].link
end
local itemCache={}
function GetItemInfo(lookup)
    cacheReads=cacheReads+1
    local entry=itemCache[lookup]
    if not entry then return end
    if entry.error then error('cache unavailable') end
    return entry.name,entry.link,entry.quality,80,1,entry.class,entry.subclass,20,entry.equipLoc,entry.texture
end
local browser=source('AuctionatorRemastered/Remastered/Data/BrowserData.lua')
local first=assert(browser:find('local canonicalClasses =',1,true))
local last=assert(browser:find('local function itemLookup(',first,true))
assert(loadstring(browser:sub(first,last-1)))()
ATR_FS_NULL=0;ATR_FS_ANALYZING=4;ATR_FS_UPDATING_DB=5;ATR_FS_CLEANING_UP=6;ATR_FS_SLOW_QUERY_NEEDED=3
gAtr_FullScanState=0
local n=0
local function check(ok,message) n=n+1;assert(ok,message) end
local function tick(elapsed) now=now+elapsed;if driver.shown then driver.scripts.OnUpdate(driver,elapsed) end end
local function broadcast() hooks.Atr_Broadcast_DBupdated(1,'fullscan') end
local a='|cffffffff|Hitem:2589:0:0:0:0:0:0:0|h[Linen Cloth]|h|r'
local b='|cff1eff00|Hitem:100:0:0:0:0:0:5:0|h[Sword of Test]|h|r'
listings={{name='Linen Cloth',texture='LinenIcon',link=a,count=20,price=1000},{name='Sword of Test',texture='SwordIcon',link=b,count=1,price=10000}}
Atr_BrowserBeginFullScanMetadata()
Atr_BrowserRememberFullScanRow('Linen Cloth','LinenIcon',1,1)
check(AUCTIONATOR_BROWSER_ITEMS['Linen Cloth'].id=='2589' and AUCTIONATOR_BROWSER_ITEMS['Linen Cloth'].link==a,'auction link and ID captured while rows still available')
check(cacheReads==0 and queries==0 and priceWrites==0,'row capture does not query, resolve cache or write prices')
for i=1,100 do Atr_BrowserRememberFullScanRow('Linen Cloth','LinenIcon',1,1) end
check(linkReads==1,'repeated stacks reuse one captured link per item name')
Atr_BrowserRememberFullScanRow('Sword of Test','SwordIcon',2,2)
broadcast();gAtr_FullScanState=ATR_FS_CLEANING_UP;tick(1)
check(cacheReads==0,'deferred cache work waits for full scan cleanup')
listings={} -- native cleanup has discarded the auction buffer
itemCache[a]={name='Linen Cloth',link=a,quality=1,class='Trade Goods',subclass='Cloth',texture='LinenIcon'}
itemCache[b]={name='Sword of Test',link=b,quality=2,class='Weapon',subclass='Sword',texture='SwordIcon',equipLoc='INVTYPE_WEAPON'}
gAtr_FullScanState=ATR_FS_NULL;tick(0.1)
check(AUCTIONATOR_BROWSER_ITEMS['Linen Cloth'].class=='Trade Goods' and AUCTIONATOR_BROWSER_ITEMS['Linen Cloth'].subclass=='Cloth','category and subcategory resolved after cleanup')
check(AUCTIONATOR_BROWSER_ITEMS['Sword of Test'].link==b,'exact random-suffix auction link preserved')
check(AUCTIONATOR_BROWSER_ITEMS['Sword of Test'].equipLoc=='INVTYPE_WEAPON','equipment slot persisted by deferred cache pass')
check(refreshes==1 and not driver.shown,'browser refreshes once background completion finishes')
check(queries==0 and priceWrites==0 and linkReads==2,'postprocessing never re-reads discarded auction rows or writes market prices')
Atr_BrowserBeginFullScanMetadata()
linkError=true
Atr_BrowserRememberFullScanRow('Linen Cloth',nil,nil,1)
check(AUCTIONATOR_BROWSER_ITEMS['Linen Cloth'].texture=='LinenIcon' and AUCTIONATOR_BROWSER_ITEMS['Linen Cloth'].class=='Trade Goods','missing metadata preserves prior good data')
for i=1,20 do Atr_BrowserRememberFullScanRow('Uncached',nil,nil,1) end
check(linkReads==5,'failed link reads are bounded to three per item and never escape')
broadcast();gAtr_FullScanState=0;tick(0.1)
itemCache.Uncached={name='Uncached',link='|Hitem:300|h[Uncached]|h',quality=1,class='Glyph',subclass='Mage',texture='GlyphIcon'}
tick(1.1)
check(AUCTIONATOR_BROWSER_ITEMS.Uncached.class=='Glyph' and AUCTIONATOR_BROWSER_ITEMS.Uncached.id=='300','late cache information is retried without another AH scan')
linkError=false
Atr_BrowserBeginFullScanMetadata();listings={{link='|Hitem:999|h[Other Item]|h'}}
Atr_BrowserRememberFullScanRow('WrongLink',nil,nil,1)
check(not AUCTIONATOR_BROWSER_ITEMS.WrongLink.link,'mismatched auction link rejected')
listings={{link=nil},{link='|Hitem:400|h[Delayed Icon]|h'}}
Atr_BrowserRememberFullScanRow('Delayed Icon',nil,nil,1)
Atr_BrowserRememberFullScanRow('Delayed Icon','RealIcon',1,2)
check(AUCTIONATOR_BROWSER_ITEMS['Delayed Icon'].texture=='RealIcon','later rows fill a missing icon')
AUCTIONATOR_BROWSER_ITEMS['Delayed Icon'].class='Armor';AUCTIONATOR_BROWSER_ITEMS['Delayed Icon'].subclass='Cloth'
Atr_BrowserBeginFullScanMetadata();Atr_BrowserRememberFullScanRow('Delayed Icon','Interface\\Icons\\INV_Misc_QuestionMark',nil,1)
check(AUCTIONATOR_BROWSER_ITEMS['Delayed Icon'].texture=='RealIcon','placeholder icon cannot replace a real icon')
-- Stubborn missing cache entries stop retrying and remain harmlessly partial.
Atr_BrowserBeginFullScanMetadata();Atr_BrowserRememberFullScanRow('Never Cached','FallbackIcon',1,1);broadcast()
for i=1,10 do tick(1.1) end
check(not driver.shown and status:find('still need details',1,true),'unresolved cache entries finish with an honest partial status')
-- A scan now supplies the exact link it already read for prices.
Atr_BrowserBeginFullScanMetadata()
local before=linkReads
for i=1,1001 do Atr_BrowserRememberFullScanRow('Linen Cloth','LinenIcon',1,1,a) end
check(linkReads==before,'exact links supplied by the scanner are not read twice')
check(queries==0 and priceWrites==0,'metadata adds no auction queries or independent price writes')
print('PASS: '..n..' full-scan metadata, deferred cache and failure isolation checks')
