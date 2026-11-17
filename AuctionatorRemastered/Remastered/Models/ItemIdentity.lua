-- Market identity deliberately excludes enchantments, gems, unique instance ID
-- and link level. Random suffix/property IDs remain signed and significant.
local Identity = {}
AuctionatorRemastered.Models.ItemIdentity = Identity

local function integer(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= math.floor(number) or number < minimum or number > maximum then return nil end
    return number
end

function Identity.Parse(value)
    if type(value) == "number" then
        local id = integer(value, 1, 2147483647)
        if id then return "item:"..id..":0", id, 0 end
        return nil
    end
    if type(value) ~= "string" then return nil end
    -- An exact stable key is unambiguous; a compact legacy ID is ID[:suffix].
    local id, suffix = value:match("^item:(%d+):(-?%d+)$")
    if not id then id, suffix = value:match("^(%d+):(-?%d+)$") end
    if not id then id = value:match("^(%d+)$") end
    if not id then
        local payload = value:match("|Hitem:([%d:%-]+)|h") or value:match("^item:([%d:%-]+)$")
        if not payload then return nil end
        local fields = {}
        for part in (payload..":"):gmatch("(.-):") do fields[#fields + 1] = part end
        -- A bare item ID denotes its base variant; truncated multi-field links
        -- cannot prove which suffix was present and must remain unresolved.
        if #fields ~= 1 and #fields < 7 then return nil end
        id, suffix = fields[1], #fields >= 7 and fields[7] or "0"
    end
    id, suffix = integer(id, 1, 2147483647), integer(suffix or "0", -2147483647, 2147483647)
    if not id or not suffix then return nil end
    return "item:"..id..":"..suffix, id, suffix
end

function Identity.Legacy(value)
    local _, id, suffix = Identity.Parse(value)
    if not id then return nil end
    return suffix == 0 and tostring(id) or id..":"..suffix
end

function Identity.LinkMatchesName(link, name)
    if type(link) ~= "string" then return false end
    local label = link:match("|h%[(.-)%]|h")
    return not label or label == name
end
