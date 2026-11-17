-- Real inherited event/UI functions, including the load-on-demand path where
-- VARIABLES_LOADED has already happened or Blizzard_AuctionUI loaded first.
local f=assert(io.open('AuctionatorRemastered/Legacy/Auctionator.lua','rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local function loadFunction(name,prefix)
 local code=assert(source:match('(function '..name..' %b().-\nend)') or source:match('(function '..name..'%b().-\nend)'),name)
 assert(loadstring('local zc={StringSame=function(a,b) return a:lower()==b:lower() end};'..(prefix or '')..code))()
end
for _,name in ipairs({'Atr_OnAddonLoaded','Atr_Init','Atr_ResetDuration','Atr_OnAuctionHouseShow','Atr_OnAuctionHouseClosed','Atr_CheckingActive_Finish'}) do
 loadFunction(name,'local recommendElements={};local gJustPosted={};local gPrevTime=0;')
end
local checks=0
local function check(ok,message) checks=checks+1;assert(ok,message) end
local noop=function() end
function time() return 100 end
function ZT(value) return value end
function Atr_Check_For_Conflicts() end
function Atr_ModTradeSkillFrame() end
local loads,tabs,clears,dropdowns=0,0,0,0
local blizzard=false
function IsAddOnLoaded(name) return name=='Blizzard_AuctionUI' and blizzard end
local initialized=false
function Atr_OnLoad()
 if initialized then return end
 loads=loads+1;initialized=true;AuctionatorLoaded=true
 AUCTIONATOR_SAVEDVARS={}
 if IsAddOnLoaded('Blizzard_AuctionUI') then Atr_Init() end
end
SELL_TAB,BUY_TAB,MORE_TAB=1,2,3;ITEM_HIST_NUM_LINES=0
AUCTIONATOR_OPEN_ALL_BAGS=0;AUCTIONATOR_DEFTAB=1;AUCTIONATOR_DEF_DURATION='L'
function Atr_ResetSavedVars() AUCTIONATOR_SAVEDVARS={} end
function Atr_AddSellTab()
 assert(AuctionatorLoaded and AuctionFrame,'UI must wait for core settings and Blizzard frame')
 tabs=tabs+1
 return {ClearSearch=function() clears=clears+1 end}
end
function Atr_AddMainPanel()
 Atr_Duration={};Atr_CheckActiveButton={SetText=noop};Atr_Main_Panel={}
end
Atr_SetupHookFunctions=noop;Atr_ShowHide_StartingPrice=noop;Atr_LocalizeFrames=noop
function UIDropDownMenu_Initialize(frame) assert(frame,'Duration menu missing');dropdowns=dropdowns+1 end
function UIDropDownMenu_SetSelectedValue(frame) assert(frame) end
function Atr_SelectPane() assert(gSellPane,'Panes must exist before selecting') end
Atr_HideAllDialogs=noop;Atr_ClearScanCache=noop;OpenAllBags=noop
local function reset()
 AuctionatorLoaded=false;AuctionatorInited=false;initialized=false
 gSellPane=nil;gShopPane=nil;gMorePane=nil;gCurrentPane=nil
 Atr_Duration=nil;Atr_CheckActiveButton=nil;Atr_Main_Panel=nil
 loads,tabs,clears,dropdowns=0,0,0,0
 AuctionFrame={};blizzard=false;AUCTIONATOR_SAVEDVARS=nil
end
-- Exact regression: own ADDON_LOADED must initialize even with no later
-- VARIABLES_LOADED event, and catch up when Blizzard UI was already loaded.
reset();blizzard=true
Atr_OnAddonLoaded('AuctionatorRemastered')
check(loads==1 and AuctionatorInited and tabs==3,'Own load initializes core and catches already-loaded Blizzard UI')
Atr_OnAuctionHouseShow();Atr_OnAuctionHouseClosed()
check(dropdowns==1 and clears==4,'Open/close use real initialized duration and pane controls')
Atr_OnAddonLoaded('AuctionatorRemastered')
check(loads==1 and tabs==3,'Repeated notifications never duplicate initialization or tabs')
reset()
Atr_OnAddonLoaded('AuctionatorRemastered')
check(loads==1 and not AuctionatorInited,'Core can load without auction UI')
Atr_OnAuctionHouseClosed()
check(clears==0,'Close before UI initialization is harmless')
blizzard=true;Atr_OnAddonLoaded('Blizzard_AuctionUI')
check(AuctionatorInited and tabs==3,'Later Blizzard load creates the live UI exactly once')
reset();blizzard=true
Atr_OnAddonLoaded('Blizzard_AuctionUI')
check(tabs==0,'Blizzard notification before saved initialization must wait')
Atr_OnAddonLoaded('AuctionatorRemastered');Atr_OnAuctionHouseShow()
check(loads==1 and tabs==3 and dropdowns==1,'Own load catches the earlier Blizzard notification')
reset();blizzard=true
Atr_OnAuctionHouseShow()
check(loads==1 and tabs==3 and dropdowns==1,'First AH open can catch up a missed initialization event')
reset()
Atr_Init()
check(not AuctionatorInited and tabs==0,'Uninitialized core cannot be marked GUI-ready')
print('PASS: '..checks..' own-addon, missed VARIABLES_LOADED, Blizzard-before/after, open/close and initialization idempotence lifecycle checks')
