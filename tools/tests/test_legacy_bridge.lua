dofile('AuctionatorRemastered/Remastered/Core/Bootstrap.lua')
dofile('AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua')
local bridge=AuctionatorRemastered.Legacy
local count=0
local function check(ok,message) count=count+1;assert(ok,message) end
local hookName,hookCallback
function hooksecurefunc(name,fn) hookName,hookCallback=name,fn;return 'hooked' end
local fn=function() end
check(bridge.Hook('Atr_Init',fn)=='hooked' and hookName=='Atr_Init' and hookCallback==fn,'hooks preserve target, callback and return value')
function GetRealmName() return 'Realm' end
function UnitFactionGroup(unit) assert(unit=='player');return 'Alliance' end
AUCTIONATOR_PRICE_DATABASE={Realm_Alliance={Saved={mr=100}}}
gAtr_ScanDB=nil
check(bridge.GetBrowserPriceDatabase()==AUCTIONATOR_PRICE_DATABASE.Realm_Alliance,'offline fallback resolves original realm/faction database')
check(bridge.GetActivePriceDatabase()==nil,'active database remains nil before original initialization')
gAtr_ScanDB={Other={mr=200}}
check(bridge.GetActivePriceDatabase()==gAtr_ScanDB and bridge.GetBrowserPriceDatabase()==gAtr_ScanDB,'live database takes priority without copying data')
gAtr_ScanDB=nil;AUCTIONATOR_PRICE_DATABASE=nil
check(next(bridge.GetBrowserPriceDatabase())==nil,'missing database remains an empty read-only view')
local pane,text,searches,notices=nil,nil,0,0
function Atr_SelectPane(value) pane=value end
function Atr_SetSearchText(value) text=value end
function Atr_Search_Onclick() searches=searches+1 end
UIErrorsFrame={AddMessage=function() notices=notices+1 end}
ATR_FS_NULL=0;gAtr_FullScanState=0
bridge.SearchBuyExact('Frost Lotus')
check(pane==3 and text=='"Frost Lotus"' and searches==1,'Buy handoff preserves exact-name search and original pane')
gAtr_FullScanState=4;pane=nil;text=nil
bridge.SearchBuyExact('Blocked')
check(searches==1 and pane==nil and text==nil and notices==1,'full scan still blocks handoff before any pane or search action')
print('PASS: '..count..' legacy boundary, lazy database and exact Buy handoff checks')
