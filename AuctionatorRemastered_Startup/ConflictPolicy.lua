-- Only metadata is inspected here. Never load another addon to identify it.
AuctionatorRemasteredConflictPolicy = {}
local Policy = AuctionatorRemasteredConflictPolicy
local own = {AuctionatorRemastered = true, AuctionatorRemastered_Startup = true}
local diagnostic = {AuctionatorDiagnostics = true, AuctionatorBulkProbe = true}

local function normalized(value)
    return tostring(value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower():gsub("[^%w]", "")
end

function Policy.IsCandidate(name, title, component)
    if own[name] or diagnostic[name] then return false end
    local folder, display = normalized(name), normalized(title)
    return component == "Engine" or component == "Startup"
        or folder:find("auctionator", 1, true) ~= nil
        or display:find("auctionator", 1, true) ~= nil
end

function Policy.Find(api)
    local conflicts = {}
    for index = 1, api.GetNumAddOns() do
        local name, title, _, enabled = api.GetAddOnInfo(index)
        if name and Policy.IsCandidate(name, title, api.GetAddOnMetadata(name, "X-AuctionatorRemastered-Component")) then
            local loaded = api.IsAddOnLoaded(name)
            if loaded or enabled == true or (type(enabled) == "number" and enabled > 0) then
                conflicts[#conflicts + 1] = {name = name, title = title or name, loaded = not not loaded}
            end
        end
    end
    table.sort(conflicts, function(a, b) return a.name:lower() < b.name:lower() end)
    return conflicts
end
