-- Offline browser: reads saved prices only. Never loads or queries the auction UI.
local function settings()
    if type(AUCTIONATOR_BROWSER_SETTINGS) ~= "table" then AUCTIONATOR_BROWSER_SETTINGS = {} end
    return AUCTIONATOR_BROWSER_SETTINGS
end
local function favorites()
    local config = settings()
    if type(config.favorites) ~= "table" then config.favorites = {} end
    return config.favorites
end
function Atr_IsBrowserFavorite(name)
    return favorites()[name] == true
end
function Atr_ToggleBrowserFavorite(name)
    if type(name) ~= "string" or name == "" then return false end
    local saved = favorites()
    saved[name] = not saved[name] and true or nil
    return saved[name] == true
end
-- Use the original saved lists and item names, including uncached items.
function Atr_BrowserAddToShoppingList(list, name)
    local exists = false
    for _, saved in ipairs(AUCTIONATOR_SHOPPING_LISTS or {}) do
        if saved == list then exists = true; break end
    end
    if not exists or list.isRecents or type(name) ~= "string" or name == "" then
        return false, "Choose a saved shopping list."
    end
    if Atr_SList.FindItemIndex(list,name) > 0 then return false, "Item is already on this shopping list." end
    if #list.items >= ATR_MAXNUM_ITEMS_ON_SHOPPING_LIST then
        return false, "Shopping list is full ("..ATR_MAXNUM_ITEMS_ON_SHOPPING_LIST.." items)."
    end
    Atr_SList.AddItem(list,name)
    if Atr_NotifyShoppingListsChanged then Atr_NotifyShoppingListsChanged()
    elseif Atr_GetCurrentPane and Atr_GetCurrentPane() then Atr_SetUINeedsUpdate() end
    return true, "Added "..name.." to "..list.name.."."
end
function Atr_BrowserCreateShoppingList(listName, itemName)
    listName = type(listName) == "string" and listName:match("^%s*(.-)%s*$") or ""
    if listName == "" then return false, "Enter a shopping list name." end
    if #listName > 32 then return false, "Shopping list names may have up to 32 characters." end
    if itemName ~= nil and (type(itemName) ~= "string" or itemName == "") then return false, "Select an item first." end
    if Atr_SList.FindByName(listName,{skipTempList=true}) then return false, "A shopping list with this name already exists." end
    local list = Atr_SList.create(listName)
    if itemName then
        local ok,message = Atr_BrowserAddToShoppingList(list,itemName)
        return ok,message,list
    end
    if Atr_NotifyShoppingListsChanged then Atr_NotifyShoppingListsChanged() end
    return true,"Created "..list.name..".",list
end
local db=AuctionatorRemastered.Legacy.GetBrowserPriceDatabase
local canonicalClasses = {"Weapon", "Armor", "Container", "Consumable", "Glyph", "Trade Goods", "Projectile", "Quiver", "Recipe", "Gem", "Miscellaneous", "Quest"}
local function className(value)
    if tonumber(value) then return canonicalClasses[tonumber(value)] end
    if type(value) ~= "string" or value == "" then return nil end
    local aliases = {
        weapon="Weapon", weapons="Weapon", armor="Armor", armour="Armor",
        container="Container", containers="Container", bag="Container", bags="Container",
        consumable="Consumable", consumables="Consumable", glyph="Glyph", glyphs="Glyph",
        ["trade goods"]="Trade Goods", projectile="Projectile", projectiles="Projectile",
        quiver="Quiver", quivers="Quiver", recipe="Recipe", recipes="Recipe",
        gem="Gem", gems="Gem", miscellaneous="Miscellaneous", key="Miscellaneous", keys="Miscellaneous", quest="Quest",
    }
    local normalized = aliases[string.lower(value)]
    if normalized then return normalized end
    if GetAuctionItemClasses then
        for i, label in ipairs({GetAuctionItemClasses()}) do
            if value == label then return canonicalClasses[i] end
        end
    end
    return nil
end
local function metadata(name,identity)
    local service=AuctionatorRemastered.Database
    local model=AuctionatorRemastered.Models.ItemMetadata
    if service and service.active and model then
        local root=service.active.root
        if not root.catalog then root.catalog=model.New() end
        return model.Get(root.catalog,service.active.locale,name,identity)
    end
    -- Standalone/legacy consumers retain the historical transient cache shape.
    if type(AUCTIONATOR_BROWSER_ITEMS) ~= "table" then AUCTIONATOR_BROWSER_ITEMS = {} end
    if not AUCTIONATOR_BROWSER_ITEMS[name] then AUCTIONATOR_BROWSER_ITEMS[name]={} end
    return AUCTIONATOR_BROWSER_ITEMS[name]
end
local function validQuality(value)
    if type(value)=="number" and value>=0 and value<=7 and value==math.floor(value) then return value end
end
local function remember(name, link, quality, class, subclass, texture, equipLoc)
    if type(name)~="string" or name=="" then return end
    quality=validQuality(quality)
    local item = metadata(name,link)
    local oldLink,oldQuality,oldClass,oldSubclass,oldTexture,oldSlot=item.link,item.quality,item.class,item.subclass,item.texture,item.equipLoc
    item.link, item.quality = link or item.link, quality or item.quality
    item.class, item.subclass = className(class) or item.class, subclass or item.subclass
    item.texture = texture or item.texture
    if type(equipLoc)=="string" and equipLoc~="" then item.equipLoc=equipLoc end
    if Atr_DatabaseInvalidate and (oldLink~=item.link or oldQuality~=item.quality or oldClass~=item.class
        or oldSubclass~=item.subclass or oldTexture~=item.texture or oldSlot~=item.equipLoc) then Atr_DatabaseInvalidate() end
end
local function cachedInfo(lookup)
    if not lookup then return nil end
    local name, link, quality, _, _, class, subclass, _, equipLoc, texture = GetItemInfo(lookup)
    if name then remember(name, link, quality, class, subclass, texture, equipLoc) end
    return link, quality, className(class), subclass, texture, equipLoc
end

-- Capture static item metadata while Full Scan still owns the returned rows.
-- No auction queries, price writes or changes to scan scheduling are made here.
local fullScanItems,cacheQueue,cacheHead={},nil,1
local cacheUnresolved,cacheElapsed=0,0
local cacheDriver=CreateFrame("Frame")
cacheDriver:Hide()
local function validTexture(texture)
    if type(texture)=="number" then return texture>0 end
    return type(texture)=="string" and texture~="" and not texture:lower():find("inv_misc_questionmark",1,true)
end
local function validItemLink(link,name)
    if type(link)~="string" or not link:match("item:%d+") then return nil end
    local linkedName=link:match("|h%[(.-)%]|h")
    if linkedName and linkedName~=name then return nil end
    return link
end
local function needsDetails(item)
    return not (item and item.id and item.link and item.class and item.subclass and validTexture(item.texture) and item.quality~=nil and ((item.class~="Armor" and item.class~="Weapon") or item.equipLoc))
end
function Atr_BrowserBeginFullScanMetadata()
    fullScanItems,cacheQueue,cacheHead={},nil,1
    cacheUnresolved,cacheElapsed=0,0
    cacheDriver:Hide()
end
function Atr_BrowserCancelFullScanMetadata()
    Atr_BrowserBeginFullScanMetadata()
    if Atr_BrowserSetMetadataStatus then Atr_BrowserSetMetadataStatus("Full scan item info cancelled.",false) end
end
function Atr_BrowserRememberFullScanRow(name,texture,quality,index,observedLink)
    if type(name)~="string" or name=="" then return end
    quality=validQuality(quality)
    observedLink=validItemLink(observedLink,name)
    local identity=AuctionatorRemastered.Models.ItemIdentity
    local key=identity and identity.Parse(observedLink) or name
    local entry=fullScanItems[key]
    if not entry then
        entry={tries=0,name=name,identity=observedLink};fullScanItems[key]=entry
        -- Missing or placeholder values never erase previously learned fields.
        remember(name,observedLink,quality,nil,nil,validTexture(texture) and texture or nil)
    end
    local item=metadata(name,observedLink)
    if not validTexture(item.texture) and validTexture(texture) then item.texture=texture end
    if item.quality==nil then item.quality=quality end
    if item.link then item.id=item.link:match("item:(%d+)") or item.id end
    if entry.link or not needsDetails(item) or entry.tries>=3 then return end
    entry.tries=entry.tries+1
    local ok,link=true,observedLink
    if not link then ok,link=pcall(GetAuctionItemLink,"list",index) end
    link=ok and validItemLink(link,name)
    if link then
        item.link=link;item.id=link:match("item:(%d+)");entry.link=true
    end
end
local function cachedFullScanDetails(name,identity)
    local item=metadata(name,identity)
    if type(item)~="table" then return false end
    if not needsDetails(item) then return true end
    local ok,knownName,link,quality,_,_,class,subclass,_,equipLoc,texture=pcall(GetItemInfo,item.link or name)
    if not ok or knownName~=name then return false end
    -- Prefer the exact auction link (including random suffixes) over a cache
    -- link. Only use name lookup links when they describe this exact item name.
    link=validItemLink(link,name)
    remember(name,item.link or link,quality,class,subclass,validTexture(texture) and texture or nil,equipLoc)
    item.id=(item.link and item.link:match("item:(%d+)")) or item.id
    return not needsDetails(item)
end
local function cacheStatus(message)
    if Atr_BrowserSetMetadataStatus then
        Atr_BrowserSetMetadataStatus(message,false)
    end
end
cacheDriver:SetScript("OnUpdate",function(self,elapsed)
    -- Cache resolution runs after the scan engine has finished cleanup, even
    -- with the browser closed. It never reads auction rows after cleanup.
    if not cacheQueue or (gAtr_FullScanState and gAtr_FullScanState~=ATR_FS_NULL) then return end
    cacheElapsed=cacheElapsed+elapsed
    if cacheElapsed<0.05 then return end
    cacheElapsed=0
    local now,start=GetTime(),GetTime()
    for _=1,32 do
        local entry=cacheQueue[cacheHead]
        if not entry then
            cacheQueue=nil;self:Hide()
            cacheStatus(cacheUnresolved>0 and ("Full scan info saved; "..cacheUnresolved.." items still need details.") or "Full scan item info saved.")
            if Atr_RefreshOfflineBrowser then Atr_RefreshOfflineBrowser() end
            return
        end
        if entry.nextTry and now<entry.nextTry then return end
        cacheHead=cacheHead+1
        entry.tries=entry.tries+1
        if not cachedFullScanDetails(entry.name,entry.identity) then
            if entry.tries<3 then entry.nextTry=now+1;cacheQueue[#cacheQueue+1]=entry
            else cacheUnresolved=cacheUnresolved+1 end
        end
        if GetTime()-start>=0.003 then break end
    end
end)
AuctionatorRemastered.Legacy.Hook("Atr_Broadcast_DBupdated",function(_,kind)
    if kind~="fullscan" then return end
    cacheQueue,cacheHead,cacheUnresolved,cacheElapsed={},1,0,0
    for _,entry in pairs(fullScanItems) do
        if needsDetails(metadata(entry.name,entry.identity)) then cacheQueue[#cacheQueue+1]={name=entry.name,identity=entry.identity,tries=0} end
    end
    fullScanItems={}
    cacheStatus("Finishing full scan item info...")
    cacheDriver:Show()
end)
local function itemLookup(name, data)
    local cached = metadata(name,data.id)
    local identity=AuctionatorRemastered.Models.ItemIdentity
    if identity and data.id and cached.link and identity.Parse(data.id)~=identity.Parse(cached.link) then cached={} end
    local base = Atr_GetBaseItemInfo and Atr_GetBaseItemInfo(name, data.id) or {}
    base = base or {}
    local baseLink = Atr_GetBaseItemLink and Atr_GetBaseItemLink(name, base)
    local lookup = cached.link or baseLink
    local itemID = data.id or (type(data.fo) == "string" and data.fo:match("^([^_]+)"))
    if not itemID and AUCTIONATOR_PRICING_HISTORY and AUCTIONATOR_PRICING_HISTORY[name] then
        itemID = AUCTIONATOR_PRICING_HISTORY[name].is
    end
    if itemID then
        local id, suffix = tostring(itemID):match("^(%d+):?(-?%d*)")
        if id then lookup = "item:"..id..":0:0:0:0:0:"..(suffix ~= "" and suffix or "0")..":0" end
    end
    local link, quality, class, subclass, texture, equipLoc = cachedInfo(lookup or name)
    if not link and lookup then link, quality, class, subclass, texture, equipLoc = cachedInfo(name) end
    return link or cached.link or baseLink, quality or cached.quality or base.quality,
        class or className(data.cc) or className(cached.class) or base.class,
        subclass or cached.subclass or base.subclass, texture or cached.texture or base.texture, (equipLoc~="" and equipLoc) or cached.equipLoc or base.equipLoc
end
-- Share the browser's cached/base/live classification without rebuilding prices.
function Atr_GetBrowserItemMetadata(name,data)
    local link,quality,class,subclass,texture,equipLoc=itemLookup(name,data or {})
    return {link=link,quality=quality,class=class or "Unclassified",subclass=subclass,texture=texture,equipLoc=equipLoc}
end
local function savedPrice(data)
    if type(data.mr) == "number" and data.mr > 0 then return data.mr end
    local latest
    for key, price in pairs(data) do
        local day = type(key) == "string" and tonumber(key:match("^H(%d+)$"))
        if day and type(price) == "number" and price > 0 and (not latest or day > latest) then latest = day end
    end
    if latest then return data["L"..latest] or data["H"..latest] end
end
function Atr_BuildBrowserSnapshot()
    local result = {}
    local database=db()
    local iterate,state,seed=pairs(database)
    if Atr_DatabaseHandles and Atr_DatabaseHandles(database) then iterate,state,seed=Atr_DatabaseRows(database),nil,nil end
    for name, data, itemKey in iterate,state,seed do
        local price=type(data)=="table" and savedPrice(data)
        if type(name) == "string" and price then
            local link, quality, class, subclass, texture, equipLoc = itemLookup(name, data)
            local reference, _, historyDays = Atr_MarketReference(itemKey or name, database)
            result[#result + 1] = {
                name = name, itemKey=itemKey, identityPending=(Atr_DatabaseHandles and Atr_DatabaseHandles(database) and not itemKey) or false, price = price, partial=data._partial==true, seen = tonumber(data.lastScan),
                reference = reference, historyDays = historyDays or 0,
                percent = reference and price / reference * 100 or nil,
                link = link, quality = quality, class = class or "Unclassified",
                subclass = subclass, texture = texture, equipLoc = equipLoc,
            }
        end
    end
    return result
end
local buildSnapshot=Atr_BuildBrowserSnapshot
function Atr_BuildBrowserSnapshot()
    if not Atr_DatabaseHandles or not Atr_DatabaseHandles(db()) then return buildSnapshot() end
    local key="browser:"..Atr_GetScanDay_Today()..":"..Atr_GetMarketHistoryDays()
    local saved=Atr_DatabaseMemo(db(),key,buildSnapshot)
    local rows={}
    -- Callers own their rows and may sort/filter them without poisoning cache.
    for index,row in ipairs(saved) do
        local copy={};for field,value in pairs(row) do copy[field]=value end
        rows[index]=copy
    end
    return rows
end
-- Internal dependencies shared with the browser view and existing AH hooks.
local Browser=AuctionatorRemastered.Browser
Browser.Settings=settings
Browser.Database=db
Browser.ClassName=className
Browser.CachedInfo=cachedInfo
Browser.Remember=remember
