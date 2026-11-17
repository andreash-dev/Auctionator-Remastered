dofile('AuctionatorRemastered/Remastered/Core/Bootstrap.lua')
dofile('AuctionatorRemastered/Remastered/Models/ItemIdentity.lua')
AuctionatorItemBase={version=2,baseItems={[100]={class='Weapon',texture='SwordIcon',quality=2},[200]={class='Armor',texture='ArmorIcon'}},variants={
 ['item:100:-5']={name='Shared',equipLoc='INVTYPE_WEAPON',subclass='Sword'},
 ['item:100:5']={name='Shared',equipLoc='INVTYPE_2HWEAPON',subclass='Two-Handed Sword'},
 ['item:200:0']={name='Armor',aliases={'Translated Armor'},subclass='Plate',equipLoc='INVTYPE_CHEST'},
}}
dofile('AuctionatorRemastered/Remastered/Data/ItemCatalog.lua')
assert(not Atr_GetBaseItemInfo('Shared'),'Ambiguous names cannot select a variant')
assert(Atr_GetBaseItemInfo('Wrong name','100:-5').equipLoc=='INVTYPE_WEAPON','Explicit identity wins over display name')
assert(Atr_GetBaseItemInfo('Shared','100:5').equipLoc=='INVTYPE_2HWEAPON')
assert(Atr_GetBaseItemInfo('Armor','100:999').texture=='SwordIcon','Unseen suffix uses only verified base-ID consensus fields')
assert(not Atr_GetBaseItemInfo('Armor','100:999').equipLoc,'No arbitrary suffix slot copied')
assert(not Atr_GetBaseItemInfo('Armor',999),'Unknown explicit ID never falls back to a name')
assert(not Atr_GetBaseItemInfo('Armor','bad'))
assert(not Atr_GetBaseItemInfo('Sword of Something'),'No suffix-family guessing')
assert(Atr_GetBaseItemInfo('Translated Armor').id==200)
assert(not Atr_GetBaseItemLink('Armor',Atr_GetBaseItemInfo('Armor')),'No synthetic tooltip link')
-- Validate the real merged catalog independently of the generator.
dofile('AuctionatorRemastered/Remastered/Data/ItemBase.lua')
assert(AuctionatorItemBase.version==2 and AuctionatorItemBase.items==nil and AuctionatorItemBase.families==nil)
local allowed={class=true,subclass=true,texture=true,quality=true,equipLoc=true}
local keys,names={},{}
local count=0
for id,row in pairs(AuctionatorItemBase.baseItems) do
 assert(type(id)=='number' and id>0)
 for field in pairs(row) do assert(allowed[field],'Non-metadata base field: '..field) end
end
for key,row in pairs(AuctionatorItemBase.variants) do
 assert(AuctionatorRemastered.Models.ItemIdentity.Parse(key)==key)
 assert(row.name==nil or (type(row.name)=='string' and row.name~=''))
 for field in pairs(row) do assert(allowed[field] or field=='name' or field=='aliases','Non-metadata variant field: '..field) end
 keys[key]=true;count=count+1
 local function remember(name) if names[name]==nil then names[name]=key elseif names[name]~=key then names[name]=false end end
 if row.name then remember(row.name) end;for _,name in ipairs(row.aliases or {}) do remember(name) end
end
dofile('AuctionatorRemastered/Remastered/Data/ItemCatalog.lua')
for key in pairs(keys) do local row=Atr_GetBaseItemInfo(nil,key);assert(row and row.key==key and not row.itemString) end
for name,key in pairs(names) do if key==false then assert(not Atr_GetBaseItemInfo(name)) end end
assert(AUCTIONATOR_REMASTERED_DATABASE==nil,'Loading the reserve never creates any price database')
print('PASS: '..count..' merged catalog variants, metadata-only field audit, exact IDs, ambiguous names, safe consensus and zero price seeding')
