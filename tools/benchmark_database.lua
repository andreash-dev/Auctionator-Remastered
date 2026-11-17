-- Reproducible Lua 5.1 microbenchmark. Synthetic prices, no game/network APIs.
dofile('AuctionatorRemastered/Remastered/Core/Bootstrap.lua')
dofile('AuctionatorRemastered/Remastered/Models/ItemIdentity.lua')
dofile('AuctionatorRemastered/Remastered/Models/Database.lua')
local D=AuctionatorRemastered.Models.Database
function Atr_GetScanDay_Today() return 100 end
function time() return 100000 end
function Atr_MigtrateMaxHistAge() end
function Atr_GetAuctionatorMemString() return '' end
local function copy(target,source)
 for key,value in pairs(source) do
  if type(value)=='table' then target[key]={};copy(target[key],value)
  else target[key]=value end
 end
end
local peak=0
local zc={msg_badErr=error,ClearTable=function(t) for key in pairs(t) do t[key]=nil end end,
 CopyDeep=function(target,source) copy(target,source);peak=math.max(peak,collectgarbage('count')) end}
local f=assert(io.open('AuctionatorRemastered/Legacy/AuctionatorScan.lua'));local source=f:read('*a'):gsub('\r\n','\n');f:close()
local prune=assert(source:match('(function Atr_PruneScanDB%b().-\nend)'))
assert(loadstring('return function(zc) '..prune..' return Atr_PruneScanDB end'))()(zc)
local legacyPrune=Atr_PruneScanDB
AUCTIONATOR_DB_MAXHIST_DAYS=14;AUCTIONATOR_DB_MAXITEM_AGE=180
AUCTIONATOR_MARKET_HISTORY_DAYS=14
dofile('AuctionatorRemastered/Remastered/Models/MarketHistory.lua')
local function fixture(count)
 local root=D.New();local h=assert(D.Open(root,'Synthetic_Alliance','enUS'))
 for id=1,count do
  local key,name='item:'..id..':0','Synthetic Item '..id
  local r={mr=id+100,lastScan=100000,id=tostring(id),_name=name}
  for day=60,100 do r['H'..day]=id+day;r['L'..day]=id+day-1;if day>=70 then r['M'..day]=id+day-.5 end end
  h.market.items[key]=r;h.market.names.enUS[name]=key;h.view[name]=r
 end
 return h
end
local function medianWork(h,cached)
 local total=0
 if cached then
  for name in pairs(h.view) do
   local result=D.Memo(h,'ref:'..name,function() return {Atr_MarketReference(name,h.view)} end)
   total=total+(result[1] or 0)
  end
 else
  for name in pairs(h.view) do total=total+(Atr_MarketReference(name,h.view) or 0) end
 end
 return total
end
local function elapsed(fn)
 local start=os.clock();local result=fn();return os.clock()-start,result
end
print('items,reference_uncached_ms,reference_cached_ms,cache_speedup,legacy_prune_ms,inplace_prune_ms,legacy_extra_checkpoint_KiB,inplace_extra_checkpoint_KiB')
for _,count in ipairs({10000,50000}) do
 local h=fixture(count)
 local uncached,expected=elapsed(function() return medianWork(h,false) end)
 local _,first=elapsed(function() return medianWork(h,true) end)
 local cached,actual=elapsed(function() return medianWork(h,true) end)
 assert(first==expected and actual==expected)
 h=nil;collectgarbage('collect')
 local original=fixture(count)
 gAtr_ScanDB=original.view
 original=nil -- legacy baseline has only the original name table, no canonical mirror
 collectgarbage('collect');local before=collectgarbage('count');peak=before
 local oldTime=elapsed(function() legacyPrune();Atr_PruneMarketObservations(gAtr_ScanDB) end)
 local oldExtra=peak-before
 local expectedRow=gAtr_ScanDB['Synthetic Item 1']
 local signature={H60=expectedRow.H60,H86=expectedRow.H86,H100=expectedRow.H100,M70=expectedRow.M70}
 original=nil;gAtr_ScanDB=nil;collectgarbage('collect')
 local modern=fixture(count)
 collectgarbage('collect');before=collectgarbage('count')
 local newTime=elapsed(function() D.Prune(modern,100,14,180) end)
 local newExtra=math.max(0,collectgarbage('count')-before)
 local row=modern.view['Synthetic Item 1']
 assert(row.H60==signature.H60 and row.H86==signature.H86 and row.H100==signature.H100 and row.M70==signature.M70)
 print(string.format('%d,%.3f,%.3f,%.2f,%.3f,%.3f,%.1f,%.1f',count,uncached*1000,cached*1000,uncached/math.max(cached,.000001),oldTime*1000,newTime*1000,oldExtra,newExtra))
 modern=nil;collectgarbage('collect')
end
