dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
local hooks,frame={},nil
local messages={}
DEFAULT_CHAT_FRAME={AddMessage=function(self,message) messages[#messages+1]=message end}
function hooksecurefunc(name,fn) hooks[name]=fn end
function CreateFrame()
 frame={scripts={}}
 function frame:RegisterEvent() end
 function frame:SetScript(name,fn) self.scripts[name]=fn end
 return frame
end
ATR_FS_NULL=0;gAtr_FullScanState=0;KM_NULL_STATE=0
local search=0
AuctionFrame={IsShown=function() return true end}
function Atr_GetCurrentPane() return {GetProcessingState=function() return search end} end
-- Exercise the real read-only getter with the same local mode as Full Scan.
local scanSource=assert(io.open('AuctionatorRemastered/Remastered/Integration/FullScan.lua')):read('*a')
local getter=assert(scanSource:match('(function Atr_IsSlowFullScanActive%b().-end)'))
local setSlow=assert(loadstring('local S={}; '..getter..'; return function(value) S.slow=value;S.running=value end'))()
assert(loadfile('AuctionatorRemastered/Remastered/Integration/AFKGuard.lua'))()
local function tick() frame.scripts.OnUpdate(frame,.3) end
tick() -- no ElvUI
assert(#messages==0)
local engine={db={general={afk=true}}}
local module={toggles=0}
function module:Toggle() self.toggles=self.toggles+1;self.enabled=engine.db.general.afk end
function engine:GetModule() return module end
ElvUI={engine}
-- Fast scans and ordinary Buy/list searches must be silent.
gAtr_FullScanState=1;hooks.Atr_FullScanStart();tick()
assert(engine.db.general.afk==true and module.toggles==0 and #messages==0)
gAtr_FullScanState=0;search=1;tick()
assert(engine.db.general.afk==true and #messages==0)
setSlow(true);gAtr_FullScanState=1;hooks.Atr_FullScanStart()
assert(engine.db.general.afk==false and module.toggles==1)
assert(#messages==1 and messages[1]:find("Auctionator Remastered",1,true) and messages[1]:find("prevent scan interruptions",1,true))
tick();assert(module.toggles==1 and #messages==1)
search=1;gAtr_FullScanState=0;tick();assert(engine.db.general.afk==true)
search=0;tick();assert(engine.db.general.afk==true and module.toggles==2)
assert(#messages==2 and messages[2]:find("restored",1,true))
engine.db.general.afk=false;gAtr_FullScanState=3;hooks.Atr_FullScanStart();gAtr_FullScanState=0;tick()
assert(engine.db.general.afk==false and module.toggles==2 and #messages==2)
engine.db.general.afk=true;gAtr_FullScanState=3;hooks.Atr_FullScanStart();frame.scripts.OnEvent(frame,'PLAYER_LOGOUT')
assert(engine.db.general.afk==true)
gAtr_FullScanState=0;search=1;tick();assert(engine.db.general.afk==true)
search=0;tick();assert(engine.db.general.afk==true)
gAtr_FullScanState=3;hooks.Atr_FullScanStart();gAtr_FullScanState=0;hooks.Atr_OnAuctionHouseClosed()
assert(engine.db.general.afk==true)
local before=#messages
-- Missing or incompatible AFK module does not break scans.
function engine:GetModule() return nil end
gAtr_FullScanState=3;hooks.Atr_FullScanStart();assert(engine.db.general.afk==true)
function engine:GetModule() return {Toggle=function() error('unsupported') end} end
hooks.Atr_FullScanStart();assert(engine.db.general.afk==true)
assert(#messages==before)
print('PASS: Auctionator chat notifications, no repeated or false notices, no ElvUI, suspend/restore, slow Full Scan only, fast scan excluded, disabled preference, logout, ordinary search excluded, AH close, unsupported module')
