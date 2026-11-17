-- Saved-item category trees, filters and daily-low history.
local settings=AuctionatorRemastered.Browser.Settings
local db=AuctionatorRemastered.Browser.Database
local function subclassName(entry)
    return type(entry.subclass) == "string" and entry.subclass ~= "" and entry.subclass or "Unknown"
end
function Atr_GetBrowserSubcategories(snapshot, class)
    local counts, names = {}, {}
    for _, entry in ipairs(snapshot) do
        if entry.class == class then
            local name = subclassName(entry)
            if not counts[name] then names[#names + 1] = name; counts[name] = 0 end
            counts[name] = counts[name] + 1
        end
    end
    table.sort(names, function(a,b)
        if a == "Unknown" then return false end
        if b == "Unknown" then return true end
        return a < b
    end)
    return names, counts
end
local equipSlots={INVTYPE_HEAD="Head",INVTYPE_NECK="Neck",INVTYPE_SHOULDER="Shoulder",INVTYPE_CLOAK="Back",
    INVTYPE_CHEST="Chest",INVTYPE_ROBE="Chest",INVTYPE_BODY="Shirt",INVTYPE_TABARD="Tabard",INVTYPE_WRIST="Wrist",
    INVTYPE_HAND="Hands",INVTYPE_WAIST="Waist",INVTYPE_LEGS="Legs",INVTYPE_FEET="Feet",INVTYPE_FINGER="Finger",
    INVTYPE_TRINKET="Trinket",INVTYPE_WEAPON="One-Hand",INVTYPE_2HWEAPON="Two-Hand",INVTYPE_WEAPONMAINHAND="Main Hand",
    INVTYPE_WEAPONOFFHAND="Off Hand",INVTYPE_SHIELD="Off Hand",INVTYPE_HOLDABLE="Off Hand",INVTYPE_RANGED="Ranged",
    INVTYPE_RANGEDRIGHT="Ranged",INVTYPE_THROWN="Thrown",INVTYPE_RELIC="Relic"}
local slotOrder={"Head","Neck","Shoulder","Back","Chest","Shirt","Tabard","Wrist","Hands","Waist","Legs","Feet",
    "Finger","Trinket","One-Hand","Two-Hand","Main Hand","Off Hand","Ranged","Thrown","Relic","Unknown slot"}
function Atr_GetBrowserEquipSlot(entry)
    return equipSlots[entry.equipLoc] or "Unknown slot"
end
function Atr_FilterIncompleteBrowserItems(items)
    if settings().showIncompleteItems then return items end
    local visible={}
    for _,entry in ipairs(items) do
        local equipment=entry.class=="Armor" or entry.class=="Weapon"
        if not entry.identityPending and entry.class and entry.class~="Unclassified" and
            type(entry.subclass)=="string" and entry.subclass~="" and
            (not equipment or Atr_GetBrowserEquipSlot(entry)~="Unknown slot") then
            visible[#visible+1]=entry
        end
    end
    return visible
end
function Atr_GetBrowserSlots(snapshot,class,subclass)
    local counts,names={},{}
    for _,entry in ipairs(snapshot) do
        if entry.class==class and subclassName(entry)==subclass then
            local slot=Atr_GetBrowserEquipSlot(entry);counts[slot]=(counts[slot] or 0)+1
        end
    end
    for _,slot in ipairs(slotOrder) do if counts[slot] then names[#names+1]=slot end end
    return names,counts
end

-- Flatten only the open branch for a virtual, scrollable category tree.
function Atr_BuildBrowserCategoryTree(snapshot, expandedClass, expandedSubclass)
    local classes={"Favorites","All items","Weapon","Armor","Container","Consumable","Glyph","Trade Goods","Projectile","Quiver","Recipe","Gem","Miscellaneous","Quest"}
    if settings().showIncompleteItems then classes[#classes+1]="Unclassified" end
    local counts, result={Favorites=0},{}
    for _,entry in ipairs(snapshot) do
        counts[entry.class]=(counts[entry.class] or 0)+1
        if Atr_IsBrowserFavorite(entry.itemKey or entry.name) then counts.Favorites=counts.Favorites+1 end
    end
    for _,label in ipairs(classes) do
        local class=label~="All items" and label or nil
        local expandable=class and class~="Favorites" and class~="Unclassified" and (counts[class] or 0)>0
        local open=expandable and expandedClass==class
        result[#result+1]={label=label,class=class,count=class and (counts[class] or 0) or #snapshot,depth=0,expandable=expandable,open=open}
        if open then
            local names, amounts=Atr_GetBrowserSubcategories(snapshot,class)
            for _,name in ipairs(names) do
                local equipment=class=="Armor" or class=="Weapon"
                local childOpen=equipment and expandedSubclass==name
                result[#result+1]={label=name,class=class,subclass=name,count=amounts[name],depth=1,expandable=equipment,open=childOpen}
                if childOpen then
                    local slots,slotCounts=Atr_GetBrowserSlots(snapshot,class,name)
                    for _,slot in ipairs(slots) do
                        result[#result+1]={label=slot,class=class,subclass=name,slot=slot,count=slotCounts[slot],depth=2}
                    end
                end
            end
        end
    end
    return result
end

function Atr_FilterBrowserSnapshot(snapshot, query, class, sortKey, descending, subclass, slot)
    local result = {}
    query = string.lower(query or "")
    for _, entry in ipairs(snapshot) do
        if (not class or entry.class == class or (class == "Favorites" and Atr_IsBrowserFavorite(entry.itemKey or entry.name))) and (not subclass or subclassName(entry) == subclass) and (not slot or Atr_GetBrowserEquipSlot(entry)==slot) and (query == "" or string.find(string.lower(entry.name), query, 1, true)) then
            result[#result + 1] = entry
        end
    end
    sortKey = sortKey or "name"
    table.sort(result, function(a,b)
        local av, bv = a[sortKey], b[sortKey]
        if sortKey == "name" then av, bv = string.lower(a.name), string.lower(b.name) end
        if av == bv then
            if a.name==b.name then return (a.itemKey or a.name)<(b.itemKey or b.name) end
            return a.name < b.name
        end
        if av == nil then return false end
        if bv == nil then return true end
        if descending then return av > bv end
        return av < bv
    end)
    return result
end
function Atr_GetBrowserHistory(name)
    local result, data = {}, db()[name]
    if Atr_DatabaseHandles and Atr_DatabaseHandles(db()) then data=Atr_DatabaseRecord(name,db()) end
    if type(data) ~= "table" then return result end
    for key, high in pairs(data) do
        local day = type(key) == "string" and tonumber(key:match("^H(%d+)$"))
        if day and type(high) == "number" and high > 0 then
            result[#result + 1] = {day = day, low = data["L"..day] or high}
        end
    end
    table.sort(result, function(a,b) return a.day > b.day end)
    return result
end

