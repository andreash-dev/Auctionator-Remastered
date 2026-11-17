dofile('AuctionatorRemastered/Remastered/Core/Bootstrap.lua')
dofile('AuctionatorRemastered/Remastered/Models/ItemIdentity.lua')
dofile('AuctionatorRemastered/Remastered/Models/Database.lua')
dofile('AuctionatorRemastered/Remastered/Models/ItemMetadata.lua')
local M,D=AuctionatorRemastered.Models.ItemMetadata,AuctionatorRemastered.Models.Database
local checks=0
local function check(ok,message) checks=checks+1;assert(ok,message) end
local cat=M.New()
local unknown=M.Get(cat,'enUS','Shared')
unknown.quality=2;unknown.texture='UnknownIcon'
local first,key=M.Get(cat,'enUS','Shared','100:-5')
check(key=='item:100:-5' and first.texture=='UnknownIcon' and not cat.unresolved.enUS.Shared)
first.link='|Hitem:100:0:0:0:0:0:-5:0|h[Shared]|h';first.class='Weapon';first.subclass='Sword'
local other=M.Get(cat,'enUS','Shared','100:5');other.texture='OtherIcon';other.class='Armor'
check(other~=first and cat.names.enUS.Shared==false,'A shared display name cannot alias two metadata identities')
check(M.Get(cat,'enUS','Shared','100:-5')==first and M.Get(cat,'enUS','Shared','100:5')==other)
check(M.Get(cat,'enUS','Shared')~=first and M.Get(cat,'enUS','Shared')~=other,'Unidentified lookup never chooses an arbitrary catalog entry')
local translated=M.Get(cat,'deDE','Gemeinsam','100:-5')
check(translated==first and cat.names.deDE.Gemeinsam=='item:100:-5','Static metadata shared across locale aliases and markets')
check(M.Validate(cat))
local root=D.New();root.catalog=cat
check(D.Validate(root))
cat.items['item:100:-5'].link='|Hitem:999:0:0:0:0:0:0:0|h[Wrong]|h'
check(not M.Validate(cat) and not D.Validate(root),'Mismatched serialized metadata link rejected')
cat.items['item:100:-5'].link=nil
cat.items['item:100:-5'].equipLoc={}
check(not M.Validate(cat),'Malformed cached types do not reach tooltip or slot code')
cat.items['item:100:-5'].equipLoc='INVTYPE_WEAPON'
local before=next(cat.unresolved.enUS)
M.Get(cat,'enUS',nil,nil)
check(next(cat.unresolved.enUS)==before,'Invalid metadata names do not create saved junk')
check(next(root.markets)==nil,'Metadata catalog alone creates no price entries')
print('PASS: '..checks..' exact metadata identity, suffix/locale aliases, unresolved lookup, corrupt-field validation and price/catalog separation checks')
