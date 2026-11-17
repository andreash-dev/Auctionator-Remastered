-- Opportunities use saved prices only; explicit right-click opens a normal Buy search.
local defaults = {maxMarket=70, minProfit=1, maxAge=24, minDays=3, resale=95, cut=5}
local limits = {maxMarket={1,1000}, minProfit={0,1000000}, maxAge={0,720}, minDays={0,30}, resale={1,200}, cut={0,100}}
local function number(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = fallback end
    return math.max(low, math.min(high, value))
end
function Atr_DealsOptions(options)
    local clean = {}
    for key, default in pairs(defaults) do
        clean[key] = number(options and options[key], default, limits[key][1], limits[key][2])
    end
    clean.minDays = math.floor(clean.minDays)
    return clean
end
function Atr_BuildDeals(options, query, sortBy, database, now)
    local opts = Atr_DealsOptions(options)
    database, now = database or gAtr_ScanDB, now or time()
    local result, priced, eligible = {}, 0, 0
    query = string.lower(query or '')
    if type(database) ~= 'table' then return result, priced, eligible end
    local iterate,state,seed=pairs(database)
    if Atr_DatabaseHandles and Atr_DatabaseHandles(database) then iterate,state,seed=Atr_DatabaseRows(database),nil,nil end
    for name, data, itemKey in iterate,state,seed do
        if type(name) == 'string' and type(data) == 'table' and type(data.mr) == 'number'
            and data.mr > 0 and data.mr < math.huge
            and (not Atr_DatabaseHandles or not Atr_DatabaseHandles(database) or itemKey) then
            priced = priced + 1
            local stamp = data.lastScan
            -- No invented timestamps for legacy data; a future clock is unknown.
            local age = type(stamp) == 'number' and stamp > 0 and stamp <= now and (now - stamp) or nil
            local reference, source, days = Atr_MarketReference(itemKey or name, database)
            if type(reference) == 'number' and reference > 0 and reference < math.huge then
                days = days or 0
                local market = data.mr / reference * 100
                local resale = math.floor(reference * opts.resale / 100)
                local fee = math.ceil(resale * opts.cut / 100)
                local net = resale - fee
                local profit = net - data.mr
                if age and age <= opts.maxAge * 3600 and days >= opts.minDays then
                    eligible = eligible + 1
                    if market <= opts.maxMarket and profit >= opts.minProfit * 10000
                        and (query == '' or string.find(string.lower(name), query, 1, true)) then
                        result[#result+1] = {name=name, itemKey=itemKey, buy=data.mr, reference=reference, source=source,
                            days=days, market=market, resale=resale, fee=fee, net=net, profit=profit,
                            age=age, when=stamp, preliminary=days<3}
                    end
                end
            end
        end
    end
    table.sort(result, function(a,b)
        if sortBy == 'market' and a.market ~= b.market then return a.market < b.market end
        if a.profit ~= b.profit then return a.profit > b.profit end
        if a.name==b.name then return (a.itemKey or a.name)<(b.itemKey or b.name) end
        return a.name < b.name
    end)
    return result, priced, eligible
end

