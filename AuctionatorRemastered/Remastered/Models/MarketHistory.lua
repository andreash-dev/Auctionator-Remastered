-- Market comparisons and bounded historical observations. No auction queries.
local marketWindows = {3, 5, 7, 14, 30}
AuctionatorRemastered.Models.MarketWindows=marketWindows
local function median(values)
    local sorted = {}
    for i,value in ipairs(values) do sorted[i] = value end
    table.sort(sorted)
    local n = #sorted
    if n == 0 then return nil end
    local middle = math.floor((n + 1) / 2)
    return n % 2 == 1 and sorted[middle] or (sorted[middle] + sorted[middle + 1]) / 2
end
-- M<day> stores one daily median. ms stores only the current day's samples.
-- Keep the original H/L history and mr (latest low) completely independent.
function Atr_RecordMarketObservation(itemName,price,database)
    if type(itemName) ~= "string" or itemName == "" or type(price) ~= "number"
        or price <= 0 or price ~= price or price == math.huge then return false end
    database = database or gAtr_ScanDB
    local item = type(database) == "table" and database[itemName]
    if type(item) ~= "table" then return false end
    local today,now = Atr_GetScanDay_Today(),time()
    local samples = item.ms
    if type(samples) ~= "table" or samples.day ~= today then
        for key in pairs(item) do
            local day = type(key) == "string" and tonumber(key:match("^M(%d+)$"))
            if day and (day < today - 30 or day > today) then item[key] = nil end
        end
        samples = {day=today,values={}}
        item.ms = samples
    end
    if type(samples.values) ~= "table" then samples.values = {} end
    -- Reloading does not reset the interval: last and values are saved together.
    if (samples.last and now - samples.last < 3600) or #samples.values >= 24 then return false end
    samples.values[#samples.values + 1] = price
    samples.last = now
    item["M"..today] = median(samples.values)
    return true
end
function Atr_PruneMarketObservations(database)
    if type(database) ~= "table" then return end
    local today = Atr_GetScanDay_Today()
    for _,item in pairs(database) do
        if type(item) == "table" then
            for key in pairs(item) do
                local day = type(key) == "string" and tonumber(key:match("^M(%d+)$"))
                if day and (day < today - 30 or day > today) then item[key] = nil end
            end
            if type(item.ms) == "table" and item.ms.day ~= today then item.ms = nil end
        end
    end
end
function Atr_GetMarketHistoryDays()
    for _, days in ipairs(marketWindows) do
        if tonumber(AUCTIONATOR_MARKET_HISTORY_DAYS) == days then return days end
    end
    return 14
end
function Atr_MarketReference(itemName, database)
    local prices = database or gAtr_ScanDB
    local db = type(prices) == "table" and prices[itemName]
    if Atr_DatabaseHandles and Atr_DatabaseHandles(prices) then db=Atr_DatabaseRecord(itemName,prices) end
    if type(db) ~= "table" then return nil end
    local today, values = Atr_GetScanDay_Today(), {}
    for day = today - Atr_GetMarketHistoryDays(), today - 1 do
        -- Old daily lows remain usable until newly collected medians replace them.
        local price = db["M"..day] or db["L"..day] or db["H"..day]
        if type(price) == "number" and price > 0 then values[#values + 1] = price end
    end
    local n = #values
    if n > 0 then
        return median(values), "Historical daily-price median", n
    end
    if type(db.mr) == "number" and db.mr > 0 then return db.mr, "Latest saved lowest price", 0 end
end

-- Only registered database views are memoized. Standalone callers and test
-- tables retain direct evaluation semantics, including manual mutations.
local calculateReference=Atr_MarketReference
function Atr_MarketReference(itemName,database)
    local prices=database or gAtr_ScanDB
    if Atr_DatabaseHandles and Atr_DatabaseHandles(prices) then
        local _,identity=Atr_DatabaseRecord(itemName,prices)
        local normalizer=AuctionatorRemastered.Models.ItemIdentity
        identity=normalizer and normalizer.Parse(identity)
        local key="reference:"..(identity or tostring(itemName))..":"..Atr_GetScanDay_Today()..":"..Atr_GetMarketHistoryDays()
        local result=Atr_DatabaseMemo(prices,key,function() return {calculateReference(itemName,prices)} end)
        return unpack(result)
    end
    return calculateReference(itemName,database)
end

function Atr_MarketPercentValue(itemName, buyout, count, database)
    if type(buyout)~="number" or buyout<=0 or type(count)~="number" or count<=0 then return nil end
    local reference,_,days=Atr_MarketReference(itemName,database)
    if not reference then return nil end
    return buyout/count/reference*100,days
end
function Atr_MarketPercentText(itemName, buyout, count, database)
    local value,days=Atr_MarketPercentValue(itemName,buyout,count,database)
    if not value then return "|cff999999--|r" end
    local percent=math.floor(value+0.5)
    local color=percent<95 and "55dd55" or (percent<=105 and "ffdd55" or "ff5555")
    return "|cff"..color..percent.."%"..(days<3 and "*" or "").."|r"
end

-- Observe successful price writes without changing Full Scan or query timing.
