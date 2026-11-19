local f=assert(io.open('AuctionatorRemastered/Legacy/Auctionator.lua'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local function definition(name)
 return assert(source:match('(function '..name..'%s*%b().-\nend)'),name)
end
local now=100
function time(value) return value and 0 or now end
local scans,copies=0,0
local mats,gear={},{}
local zc={CopyDeep=function(dest,src)
 assert(type(src)=='table','missing before-cast snapshot reached CopyDeep')
 copies=copies+1
 for k,v in pairs(src) do
  if type(v)=='table' then dest[k]={};for field,value in pairs(v) do dest[k][field]=value end
  else dest[k]=v end
 end
end}
function Atr_ScanBags(outMats,outGear)
 scans=scans+1;zc.CopyDeep(outMats,mats);zc.CopyDeep(outGear,gear)
end
function Atr_ItemType2AuctionClass() return 4 end
function Atr_SubType2AuctionSubclass() return 1 end
function Atr_IsWeaponType() return false end
local reset=assert(loadstring([[local zc=...
local preDEmats,preDEgear
local gDisenchantTime=0
]]..definition('Atr_OnSpellCastSent')..'\n'..definition('Atr_OnSpellCastSucess')..'\n'..definition('Atr_OnBagUpdate')..[[

return function(snapshotMissing)
 preDEmats=nil;preDEgear=nil;gDisenchantTime=snapshotMissing and 100 or 0
end
]]))(zc)
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
Atr_OnSpellCastSucess('party1','Disenchant');Atr_OnBagUpdate()
check(scans==0 and copies==0,'party success followed by loot bag update cannot start disenchant analysis')
Atr_OnSpellCastSent('party1','Disenchant')
check(scans==0,'other player cast does not capture our bags')
Atr_OnSpellCastSucess('player','Disenchant');Atr_OnBagUpdate()
check(scans==0,'own success without SENT snapshot is ignored')
reset(true);Atr_OnBagUpdate()
check(scans==0,'active timestamp with missing snapshot cannot reach CopyDeep')
reset();Atr_OnSpellCastSent('player','Fireball');Atr_OnSpellCastSucess('player','Fireball');Atr_OnBagUpdate()
check(scans==0,'unrelated own spell ignored')
gear={item={count=1,t='Armor',s='Cloth',q=2,lev=40}}
Atr_OnSpellCastSent('player','Disenchant')
check(scans==1,'own SENT captures a baseline')
Atr_OnSpellCastSent('party1','Disenchant');Atr_OnSpellCastSucess('party1','Disenchant');Atr_OnBagUpdate()
check(scans==1,'party cast cannot arm or replace own pending baseline')
Atr_OnSpellCastSucess('player','Disenchant')
gear={};mats={Dust={count=2}}
Atr_OnBagUpdate()
check(scans==2 and AUCTIONATOR_DE_DATA and #AUCTIONATOR_DE_DATA==1,'valid own disenchant still records the item and resulting material')
Atr_OnBagUpdate()
check(scans==2 and #AUCTIONATOR_DE_DATA==1,'completed result is not processed twice')
reset();mats={};gear={}
Atr_OnSpellCastSent('player','Disenchant');Atr_OnSpellCastSucess('player','Disenchant')
now=106;Atr_OnBagUpdate()
check(scans==3,'expired observation window does not process unrelated bag changes')
print('PASS: '..checks..' disenchant ownership, missing-snapshot, normal-recording and timeout checks')
