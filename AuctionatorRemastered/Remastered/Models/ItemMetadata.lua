-- Static learned item information is shared across markets, but exact suffix
-- variants retain their own links. No prices or availability belong here.
local Metadata={}
AuctionatorRemastered.Models.ItemMetadata=Metadata
local Identity=AuctionatorRemastered.Models.ItemIdentity

function Metadata.New()
    return {items={},names={},unresolved={}}
end

function Metadata.Get(catalog,locale,name,identity)
    if type(name)~="string" or name=="" or #name>512 then return {} end
    catalog.names[locale]=catalog.names[locale] or {}
    catalog.unresolved[locale]=catalog.unresolved[locale] or {}
    local aliases,unknown=catalog.names[locale],catalog.unresolved[locale]
    local key=Identity.Parse(identity)
    if key then
        local record=catalog.items[key]
        if not record then
            record={}
            catalog.items[key]=record
            -- Static unresolved hints may fill blanks, never price histories.
            if aliases[name]==nil and unknown[name] then
                for field,value in pairs(unknown[name]) do
                    if field~="link" and field~="id" then record[field]=value end
                end
                unknown[name]=nil
            end
        end
        if aliases[name]==false or (aliases[name] and aliases[name]~=key) then aliases[name]=false
        else aliases[name]=key end
        return record,key
    end
    if aliases[name] then return catalog.items[aliases[name]],aliases[name] end
    if not unknown[name] then unknown[name]={} end
    return unknown[name]
end

function Metadata.Validate(catalog)
    if type(catalog)~="table" or type(catalog.items)~="table" or type(catalog.names)~="table"
        or type(catalog.unresolved)~="table" then return false end
    local function valid(record,key)
        if type(record)~="table" then return false end
        for _,field in ipairs({"link","class","subclass","equipLoc"}) do
            if record[field]~=nil and type(record[field])~="string" then return false end
        end
        if record.link and key and Identity.Parse(record.link)~=key then return false end
        if record.quality~=nil and (type(record.quality)~="number" or record.quality<0 or record.quality>7
            or record.quality~=math.floor(record.quality)) then return false end
        if record.texture~=nil and type(record.texture)~="string" and type(record.texture)~="number" then return false end
        return true
    end
    for key,record in pairs(catalog.items) do if Identity.Parse(key)~=key or not valid(record,key) then return false end end
    for locale,aliases in pairs(catalog.names) do
        if type(locale)~="string" or type(aliases)~="table" then return false end
        for name,key in pairs(aliases) do
            if type(name)~="string" or (key~=false and not catalog.items[key]) then return false end
        end
    end
    for locale,rows in pairs(catalog.unresolved) do
        if type(locale)~="string" or type(rows)~="table" then return false end
        for name,record in pairs(rows) do if type(name)~="string" or not valid(record) then return false end end
    end
    return true
end
