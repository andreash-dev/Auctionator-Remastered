-- Attribute condensed engine rows without changing their order or prices.
local Sellers = {}
AuctionatorRemastered.Models.Sellers = Sellers

local function key(row, player)
    return tostring(row.stackSize)..":"..tostring(row.buyoutPrice)..":"
        ..tostring(row.owner == player)
end

function Sellers.Attach(scan, player)
    local groups = {}
    for _, auction in ipairs(scan.scanData or {}) do
        local owner = auction.owner
        if type(owner) == "string" and owner ~= "" then
            local id = key(auction, player)
            local group = groups[id]
            if not group then
                groups[id] = {name = owner, multiple = false}
            elseif group.name ~= owner then
                group.multiple = true
            end
        end
    end
    for _, row in ipairs(scan.sortedData or {}) do
        local id = tostring(row.stackSize)..":"..tostring(row.buyoutPrice)..":"..tostring(row.yours == true)
        local group = row.type == "n" and groups[id]
        row.sellerName = group and group.name or nil
        row.multipleSellers = group and group.multiple or false
    end
end
