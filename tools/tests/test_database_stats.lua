dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
-- lua5.1 tools/tests/test_database_stats.lua
local hooks={}
function hooksecurefunc(name,fn) hooks[name]=fn end
local realm='Realm'
function GetRealmName() return realm end
function UnitFactionGroup() return 'Alliance' end
local now=100
function time() return now end
function IsControlKeyDown() return false end
local info={SetPoint=function() end,SetWidth=function() end,SetJustifyH=function() end,SetSpacing=function() end,SetText=function() end}
Atr_ScanningOptionsFrame={CreateFontString=function() return info end,HookScript=function() end}
local redraws=0
function Atr_UpdateFullScanCounts() redraws=redraws+1 end
ATR_FS_NULL=0;gAtr_FullScanState=0
AUCTIONATOR_DATABASE_STATS={Realm_Alliance={since=1,scans=6,fast=4,slow=2}}
assert(loadfile('AuctionatorRemastered/Remastered/Data/DatabaseStats.lua'))()
local checks=0
local function check(ok,message) checks=checks+1;assert(ok,message) end
local fast,slow=Atr_GetFullScanCounts()
check(fast==4 and slow==2,'reuse existing saved counters')
hooks.Atr_FullScanStart();hooks.Atr_Broadcast_DBupdated(1,'search')
fast,slow=Atr_GetFullScanCounts()
check(fast==4 and slow==2 and redraws==0,'searches and rejected starts do not add completed scans')
gAtr_FullScanState=1;Atr_FullScanSlowMode=false
hooks.Atr_FullScanStart();now=120;hooks.Atr_Broadcast_DBupdated(100,'fullscan')
fast,slow=Atr_GetFullScanCounts()
check(fast==5 and slow==2 and redraws==1,'completed fast scan updates saved total and dialog')
Atr_FullScanSlowMode=true;hooks.Atr_FullScanStart();now=150
hooks.Atr_Broadcast_DBupdated(100,'page')
fast,slow=Atr_GetFullScanCounts()
check(fast==5 and slow==2,'individual slow pages are not completed scans')
hooks.Atr_Broadcast_DBupdated(150,'fullscan')
fast,slow=Atr_GetFullScanCounts()
check(fast==5 and slow==3 and redraws==2,'completed slow scan increments once')
check(AUCTIONATOR_DATABASE_STATS.Realm_Alliance.scans==8,'existing aggregate totals preserved')
assert(loadfile('AuctionatorRemastered/Remastered/Data/DatabaseStats.lua'))()
fast,slow=Atr_GetFullScanCounts()
check(fast==5 and slow==3,'counts survive module reload')
realm='Other';fast,slow=Atr_GetFullScanCounts()
check(fast==0 and slow==0,'realm/faction counters are isolated')
check(QueryAuctionItems==nil,'statistics require no auction queries')
print('PASS: '..checks..' persisted full-scan counter checks')
