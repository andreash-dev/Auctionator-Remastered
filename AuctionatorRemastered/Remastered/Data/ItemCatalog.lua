-- Read-only, ID/suffix-keyed reserve. It never seeds the price database and
-- never invents tooltip links or infers identities from "of ..." name families.
local Identity=AuctionatorRemastered.Models.ItemIdentity
local base=AuctionatorItemBase or {version=2,baseItems={},variants={}}
local byName,resolved,baseCache={},{},{}
local fields={'class','subclass','texture','quality','equipLoc'}
local function alias(name,key)
    if type(name)~='string' or name=='' then return end
    if byName[name]==nil then byName[name]=key
    elseif byName[name]~=key then byName[name]=false end
end
for key,entry in pairs(base.variants) do
    alias(entry.name,key)
    for _,name in ipairs(entry.aliases or {}) do alias(name,key) end
end
local function variant(key)
    if resolved[key] then return resolved[key] end
    local entry=base.variants[key]
    if not entry then return nil end
    local _,id,suffix=Identity.Parse(key)
    if not id then return nil end
    local shared=base.baseItems[id] or {}
    local record={id=id,suffix=suffix,key=key,name=entry.name}
    for _,field in ipairs(fields) do
        record[field]=entry[field]
        if record[field]==nil then record[field]=shared[field] end
    end
    resolved[key]=record
    return record
end
function Atr_GetBaseItemInfo(name,itemID)
    if itemID~=nil then
        local key,id=Identity.Parse(itemID)
        if not key then return nil end
        local exact=variant(key)
        if exact then return exact end
        local shared=base.baseItems[id]
        if not shared then return nil end
        if not baseCache[id] then
            local record={id=id,baseOnly=true}
            for _,field in ipairs(fields) do record[field]=shared[field] end
            baseCache[id]=record
        end
        return baseCache[id]
    end
    local key=byName[name]
    return key and variant(key) or nil
end
function Atr_GetBaseItemLink()
    -- Observed client/scan links remain the source for tooltips. The static
    -- reserve contains no seeds, instance IDs or synthesized hyperlinks.
    return nil
end
