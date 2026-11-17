dofile('AuctionatorRemastered/Remastered/Core/Bootstrap.lua')
dofile('AuctionatorRemastered/Remastered/Models/ItemIdentity.lua')
dofile('AuctionatorRemastered/Remastered/Models/Database.lua')
local I,D=AuctionatorRemastered.Models.ItemIdentity,AuctionatorRemastered.Models.Database
local checks=0
local function check(ok,message) checks=checks+1;assert(ok,message) end
local function link(id,suffix,enchant,unique,level)
 return '|cff00ff00|Hitem:'..id..':'..(enchant or 0)..':0:0:0:0:'..(suffix or 0)..':'..(unique or 0)..':'..(level or 80)..'|h[Test]|h|r'
end
check(I.Parse(100)=='item:100:0')
check(I.Parse('100:-5')=='item:100:-5')
check(I.Parse(link(100,-5,99,123,80))=='item:100:-5')
check(I.Parse(link(100,-5,11,999,1))==I.Parse(link(100,-5,99,123,80)),'No price fragmentation by enchant/instance/link level')
check(I.Parse(link(100,5))~=I.Parse(link(100,-5)),'Signed suffix matters')
check(I.Legacy(link(100,-5))=='100:-5' and I.Legacy('item:100:0')=='100')
for _,bad in ipairs({'','Sword of the Bear','item:0:0','item:1:0:0','item:1:0:0:0','item:1:0:0:0:0:0:','item:1.5:0','item:1:abc','battlepet:1','2147483648','1:2147483648',0,-1,1.5,math.huge,0/0,false,{}}) do
 check(not I.Parse(bad),'Reject invalid or insufficient identity '..tostring(bad))
end
check(I.LinkMatchesName(link(100,5),'Test') and not I.LinkMatchesName(link(100,5),'Other'))
local root=D.New()
local h=assert(D.Open(root,'Realm_Alliance','enUS'))
check(D.Validate(root) and next(h.view)==nil)
local row,key=D.Write(h,'Sword of the Bear',10,100000,100,'100:-5')
check(key=='item:100:-5' and h.view['Sword of the Bear']==root.markets.Realm_Alliance.items[key])
check(row.mr==10 and row.H100==10 and row.L100==nil)
D.Write(h,'Sword of the Bear',20,100100,100)
check(row.H100==20 and row.L100==10,'A rising price preserves the first daily low')
D.Write(h,'Sword of the Bear',5,100200,100)
check(row.H100==20 and row.L100==5)
D.Write(h,'Sword of the Tiger',99,100300,100,'100:5')
check(D.Find(h,'100:-5').mr==5 and D.Find(h,'100:5').mr==99,'Suffix prices isolated')
for _,price in ipairs({-1,0,math.huge,-math.huge,0/0,'100',true,{}}) do
 check(not D.Write(h,'Invalid',price,100000,100,100),'Reject malformed price')
end
check(not D.Write(h,'',10,100000,100,100))
check(not D.Write(h,'Test',10,0,100,100))
check(not D.Write(h,'Test',10,100000,0/0,100))
check(not D.Write(h,'Test',10,100000,100.5,100))
check(not D.Write(h,'Test',10,100000,100,'bad'))
check(not root.markets.Realm_Alliance.items['item:999:0'],'Rejected writes do not create junk records')
D.Write(h,'Unresolved',1,100000,100,false)
check(h.view.Unresolved and not I.Parse('Unresolved'))
D.Bind(h,'Unresolved','200')
check(not D.Find(h,'200').mr,'An unverified name never imports price history into an ID')
D.Write(h,'Unresolved',50,100500,100,'200')
check(D.Find(h,'200').mr==50 and not h.market.unresolved.enUS.Unresolved)
D.Write(h,'Shared name',30,100000,100,'300')
D.Write(h,'Shared name',40,100000,100,'301')
local value,reason=D.Find(h,'Shared name')
check(not value and reason=='ambiguous' and not h.view['Shared name'])
check(D.Find(h,300).mr==30 and D.Find(h,301).mr==40,'No same-name ID collision')
check(not D.Write(h,'Shared name',1,100600,100),'Name-only writes fail closed after ambiguity')
local found={}
for name,record,id in D.Rows(h) do if name=='Shared name' then found[id]=record.mr end end
check(found['item:300:0']==30 and found['item:301:0']==40,'Canonical iterator exposes both ambiguous-name variants')
local de=assert(D.Open(root,'Realm_Alliance','deDE'))
D.Write(de,'Schwert',60,100800,100,'100:-5')
check(D.Find(h,'100:-5').mr==60 and D.Find(de,'Schwert')==row,'Localized names alias the same canonical item')
local enemy=assert(D.Open(root,'Realm_Horde','enUS'))
D.Write(enemy,'Sword of the Bear',999,100000,100,'100:-5')
check(D.Find(h,'100:-5').mr==60 and D.Find(enemy,'100:-5').mr==999,'Faction scope isolated')
local other=assert(D.Open(root,'OtherRealm_Alliance','enUS'))
check(not D.Find(other,'100:-5'),'Realm scope isolated')
local reloaded=assert(D.Open(root,'Realm_Alliance','enUS'))
check(D.Find(reloaded,'Sword of the Bear')==row and row.mr==60,'Rebuild transient name view from persisted ID records')
local builds=0
local function build() builds=builds+1;return {value=builds} end
check(D.Memo(h,'test',build)==D.Memo(h,'test',build) and builds==1)
D.Write(h,'Sword of the Bear',70,100900,101)
check(D.Memo(h,'test',build).value==2,'Price writes invalidate cached views')
h.market.lastCompleteScan=100900
local beforeClear=D.Clear(h)
check(next(h.market.items)==nil and next(h.view)==nil and next(h.market.unresolved.enUS)==nil)
check(D.Find(enemy,'100:-5').mr==999,'Realm clear does not touch other factions')
D.Write(h,'Sword of the Bear',80,101000,102,'100:-5')
D.Restore(h,beforeClear)
check(D.Find(h,'100:-5').mr==80,'Undo preserves observations made after clear')
check(D.Find(h,'100:5').mr==99 and D.Find(h,'300').mr==30,'Undo includes hidden ambiguous canonical entries')
check(h.market.lastCompleteScan==100900,'Undo restores scan provenance')
local current=D.Find(h,'100:-5')
current.H1,current.L1,current.M1,current.M500,current.H90=10,5,5,100,100
D.Prune(h,110,14,180)
check(current.H1==nil and current.L1==nil and current.M1==nil and current.M500==nil)
check(current.H90==nil and current.H102==80,'Bound histories, retaining newest day')
D.Write(h,'Old',10,100000,1,'999')
D.Prune(h,300,30,180)
check(not D.Find(h,'999') and not h.view.Old,'Expired item and aliases removed together')
check(D.Validate(root),'Pruning and Undo maintain schema invariants')
local invalid={schemaVersion=999,markets={untouched=true}}
check(not D.Open(invalid,'Realm_Alliance','enUS') and invalid.schemaVersion==999 and invalid.markets.untouched,'Future versions are rejected without reset')
local corrupt=D.New();corrupt.markets.X={items={['item:1:0']={mr=0/0}},names={},unresolved={}}
check(not D.Validate(corrupt),'Invalid serialized prices rejected')
-- Property check: varied ordering always preserves the exact daily min/max.
math.randomseed(12345)
local test=assert(D.Open(D.New(),'Test','enUS'))
for id=1,100 do
 local low,high=math.huge,0
 for n=1,20 do
  local price=math.random(1,100000);low=math.min(low,price);high=math.max(high,price)
  local record=D.Write(test,'Item '..id,price,100000+n,100,id)
  check(record.H100==high and (record.L100 or record.H100)==low,'Daily extrema independent of observation order')
 end
end
check(D.Validate(test.root))
-- Round-trip only the persistent root, using serialization of our own fixture.
local function serialize(value,seen)
    if type(value)=="number" then return string.format("%.17g",value) end
    if type(value)=="string" then return string.format("%q",value) end
    if type(value)=="boolean" then return tostring(value) end
    assert(type(value)=="table","No runtime objects/functions may enter SavedVariables")
    seen=seen or {};assert(not seen[value],"Persistent graph must not duplicate/cycle price tables");seen[value]=true
    local parts={"{"}
    for key,entry in pairs(value) do parts[#parts+1]="["..serialize(key,seen).."]="..serialize(entry,seen).."," end
    parts[#parts+1]="}";return table.concat(parts)
end
D.Find(test,1).ms={day=100,last=100000,values={1,2,3}}
local text=serialize(test.root)
local loaded=assert(loadstring("return "..text))()
local after=assert(D.Open(loaded,'Test','enUS'))
check(D.Find(after,1).mr==D.Find(test,1).mr and #D.Find(after,1).ms.values==3,'SavedVariables round-trip restores canonical prices and samples')
check(after.view['Item 1']==after.market.items['item:1:0'],'Alias views reconstruct after reload without a second saved price graph')
local toc=assert(io.open('AuctionatorRemastered/AuctionatorRemastered.toc'))
local declarations=toc:read('*a'):match('## SavedVariables:([^\n]+)');toc:close()
check(declarations:find('AUCTIONATOR_REMASTERED_DATABASE',1,true) and not declarations:find('AUCTIONATOR_PRICE_DATABASE',1,true) and not declarations:find('AUCTIONATOR_BROWSER_ITEMS',1,true),'Old price/cache views are not serialized')
print('PASS: '..checks..' database identity, schema, writes, collisions, scope, reload, cache, Clear/Undo, pruning and daily-extrema checks')
