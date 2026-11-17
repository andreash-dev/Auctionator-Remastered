dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
-- Run from the addon project root: lua5.1 tools/tests/test_market_history.lua
local day,now=100,100000
function Atr_GetScanDay_Today() return day end
function time() return now end
local hooks={}
function hooksecurefunc(name,callback)
    hooks[name]=callback
    local original=_G[name]
    if original then _G[name]=function(...) original(...);callback(...) end end
end
function Atr_PruneScanDB() end
local f=assert(io.open('AuctionatorRemastered/Legacy/AuctionatorScan.lua'));local scan=f:read('*a'):gsub('\r\n','\n');f:close()
local priceFunction=assert(scan:match('(function Atr_UpdateScanDBprice %b().-\nend)'))
assert(loadstring('local zc={msg_badErr=function() end};'..priceFunction))()
f=assert(io.open('AuctionatorRemastered/Remastered/Models/MarketHistory.lua'));local market=f:read('*a');f:close()
local mathCode=market
assert(loadstring(mathCode))()
dofile("AuctionatorRemastered/Remastered/Integration/MarketHistory.lua")
local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg) end
AUCTIONATOR_MARKET_HISTORY_DAYS=14
gAtr_ScanDB={}
local values={10,9,12,8,11,10}
for i,v in ipairs(values) do now=100000+(i-1)*3600;Atr_UpdateScanDBprice('Item',v) end
local item=gAtr_ScanDB.Item
check(item.M100==10,'median of six scans')
check(item.mr==10 and item.H100==12 and item.L100==8,'latest price and legacy history kept')
check(#item.ms.values==6,'six hourly observations')
now=now+10;Atr_UpdateScanDBprice('Item',1)
check(item.mr==1 and item.L100==1 and item.M100==10,'rapid scans update latest/low but do not skew median')
check(#item.ms.values==6,'same hour ignored')
-- Sampler has no per-session state: saved table is sufficient after reload.
local last=item.ms.last
assert(loadstring(mathCode))()
dofile("AuctionatorRemastered/Remastered/Integration/MarketHistory.lua")
check(not Atr_RecordMarketObservation('Item',50),'reload preserves sampling interval')
check(item.ms.last==last and #item.ms.values==6,'reload does not change samples')
now=last+3600;check(Atr_RecordMarketObservation('Item',20),'next eligible hour accepted')
check(item.M100==10 and #item.ms.values==7,'odd median')
day=101;now=now+86400;Atr_UpdateScanDBprice('Item',30)
check(#item.ms.values==1 and item.ms.day==101 and item.M101==30 and item.M100==10,'rollover stores only new day samples')
day=102
local ref,_,count=Atr_MarketReference('Item')
check(ref==20 and count==2,'each day equal weight despite different observation counts')
item.M102=999;item.L99=2;item.H99=2
ref,_,count=Atr_MarketReference('Item')
check(ref==10 and count==3,'legacy fallback combined with new medians; today excluded')
check(Atr_MarketPercentText('Item',8,1)=='|cff55dd5580%|r','green 80 percent')
check(Atr_MarketPercentText('Item',12,1)=='|cffff5555120%|r','red 120 percent')
check(Atr_MarketPercentText('Item',100,10)=='|cffffdd55100%|r','per-item stack normalization')
gAtr_ScanDB.OnlyLatest={mr=50}
check(Atr_MarketPercentText('OnlyLatest',50,1)=='|cffffdd55100%*|r','no history marked preliminary')
gAtr_ScanDB.OneDay={mr=20,M101=10}
check(Atr_MarketPercentText('OneDay',20,1)=='|cffff5555200%*|r','one history day preliminary')
local external={Other={mr=40}}
now=now+7200
check(Atr_RecordMarketObservation('Other',40,external) and external.Other.M102==40 and not gAtr_ScanDB.Other,'explicit database isolated')
check(not Atr_RecordMarketObservation('Missing',20),'missing rows not created')
check(not Atr_RecordMarketObservation('Other',0,external),'zero rejected')
check(not Atr_RecordMarketObservation('Other',math.huge,external),'infinity rejected')
check(not Atr_RecordMarketObservation('Other',0/0,external),'NaN rejected')
item.M1=1;item.M71=1;item.M72=2;item.M103=3
Atr_PruneScanDB()
check(item.M1==nil and item.M71==nil and item.M72==2 and item.M103==nil,'bounded median history pruned via existing prune hook')
check(item.ms==nil and item.H99==2 and item.L99==2,'old samples cleared; legacy lows preserved')
-- Day transitions also prune, even if the client stays logged in for weeks.
item.M1=1;now=now+7200;Atr_RecordMarketObservation('Item',10)
check(item.M1==nil and item.ms.day==102,'rollover prunes without reload')
for i=2,24 do now=now+3600;Atr_RecordMarketObservation('Item',i) end
check(#item.ms.values==24,'current day bounded to 24 observations')
now=now+3600;check(not Atr_RecordMarketObservation('Item',1000),'daily cap')
check(#item.ms.values==24,'cap retained')
for _,window in ipairs({3,5,7,14,30}) do
    AUCTIONATOR_MARKET_HISTORY_DAYS=window
    local dataset={Test={mr=99}}
    dataset.Test['M'..(day-window)]=10
    dataset.Test['M'..(day-window-1)]=1000
    dataset.Test['M'..day]=1000
    local value,_,n=Atr_MarketReference('Test',dataset)
    check(value==10 and n==1,'window boundaries '..window)
end
print('PASS: '..checks..' median/history/throttle/migration/math checks against original price writer')
