dofile("AuctionatorRemastered/Remastered/Core/Bootstrap.lua")
dofile("AuctionatorRemastered/Remastered/Integration/LegacyBridge.lua")
-- Run from the repository root: lua5.1 tools/tests/test_buy_shopping_selection.lua
local file=assert(io.open('AuctionatorRemastered/Legacy/AuctionatorShop.lua'));local source=file:read('*a'):gsub('\r\n','\n');file:close()
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local query,summary,nilScan='Flask of',false,false
local pane={activeScan={itemName='Flask of the Frost Wyrm'},activeSearch={NumScans=function() return 2 end}}
function pane:IsScanNil() return nilScan end
function Atr_GetCurrentPane() return pane end
function Atr_ShowingSearchSummary() return summary end
Atr_Search_Box={GetText=function() return query end}
local updates=0
function Atr_SetUINeedsUpdate() updates=updates+1 end
function ZT(text) return text end
local function button()
 return {enabled=false,Enable=function(self) self.enabled=true end,Disable=function(self) self.enabled=false end,Hide=function() end,Show=function() end}
end
Atr_AddToSListButton=button();Atr_RemFromSListButton=button();Atr_SrchSListButton=button()
Atr_SaveThisList_Button=button();Atr_Back_Button=button()
local errors=0
Atr_Error_Text={SetText=function() errors=errors+1 end};Atr_Error_Frame={Show=function() end}
Atr_SList={};Atr_SList.__index=Atr_SList;ATR_MAXNUM_ITEMS_ON_SHOPPING_LIST=50
local definitions={}
for _,name in ipairs({'Atr_SList:AddItem','Atr_SList:RemoveItem','Atr_SList:FindItemIndex','Atr_SList:IsItemOnList','Atr_GetShoppingListItemName','Atr_AddToSListOnClick','Atr_RemFromSListOnClick','Atr_Shop_UpdateUI'}) do
 local escaped=name:gsub('%.','%%.')
 definitions[#definitions+1]=assert(source:match('(function '..escaped..'%s*%b().-\nend)'))
end
local setList=assert(loadstring('local zc=...;local gCurrentSList;local gTempShoppingList;\n'..table.concat(definitions,'\n')..'\nreturn function(list) gCurrentSList=list end'))({StringSame=function(a,b) return a and b and a:lower()==b:lower() end})
function Atr_SList:DisplayX() end
local recent=setmetatable({name='Recent Searches',isRecents=true,items={}},Atr_SList)
local list=setmetatable({name='Flasks',items={'Flask of'}},Atr_SList)
AUCTIONATOR_SHOPPING_LISTS={recent,list};setList(list)
check(Atr_GetShoppingListItemName()=='Flask of the Frost Wyrm','opened exact item overrides broad query')
Atr_Shop_UpdateUI()
check(Atr_AddToSListButton.enabled and not Atr_RemFromSListButton.enabled,'broad query already present does not disable adding opened item')
Atr_AddToSListOnClick()
check(#list.items==2 and list.items[2]=='Flask of the Frost Wyrm','Add Item saves selected flask')
check(query=='Flask of','adding does not rewrite query')
Atr_Shop_UpdateUI()
check(not Atr_AddToSListButton.enabled and Atr_RemFromSListButton.enabled,'button states now reflect exact item')
Atr_AddToSListOnClick();check(#list.items==2,'direct duplicate clicks rejected')
list.remasteredTargets={['Flask of the Frost Wyrm']=20,['Flask of']=10}
Atr_RemFromSListOnClick()
check(#list.items==1 and list.items[1]=='Flask of','Remove Item removes opened flask, not broad query')
check(list.remasteredTargets['Flask of the Frost Wyrm']==nil and list.remasteredTargets['Flask of']==10,'removal clears only selected target quantity')
summary=true
check(Atr_GetShoppingListItemName()=='Flask of','summary retains original query-list behavior')
Atr_Shop_UpdateUI();check(Atr_RemFromSListButton.enabled and not Atr_AddToSListButton.enabled,'summary checks query membership')
query='Potion';Atr_Shop_UpdateUI();check(Atr_AddToSListButton.enabled,'new broad search can still be saved')
Atr_AddToSListOnClick();check(list.items[2]=='Potion','summary adds search term')
summary=false;nilScan=true;check(Atr_GetShoppingListItemName()=='Potion','empty active scan uses query')
nilScan=false;pane.activeScan.itemName='nil';check(Atr_GetShoppingListItemName()=='Potion','placeholder name does not become an item')
pane.activeScan.itemName='Flask of the Frost Wyrm'
list.items={};for i=1,50 do list.items[i]='Item '..i end
Atr_AddToSListOnClick();check(#list.items==50 and errors==1,'existing 50-item limit preserved')
setList(recent);Atr_Shop_UpdateUI()
check(not Atr_AddToSListButton.enabled,'recent searches cannot receive manual additions')
Atr_AddToSListOnClick();check(#recent.items==0,'direct handler protects recent searches too')
check(updates>=3,'successful changes refresh UI')
check(QueryAuctionItems==nil and PlaceAuctionBid==nil,'shopping selection issues no auction actions')
print('PASS: '..checks..' Buy Add/Remove Item selection checks')
