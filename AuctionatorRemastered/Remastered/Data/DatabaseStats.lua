-- Persist scan summaries separately from prices. Observe existing completion
-- notifications; never modify scan queries, timing, processing, or cooldowns.
local function stats()
    if type(AUCTIONATOR_DATABASE_STATS) ~= "table" then AUCTIONATOR_DATABASE_STATS = {} end
    local key = GetRealmName().."_"..UnitFactionGroup("player")
    local root = AUCTIONATOR_DATABASE_STATS
    if type(root[key]) ~= "table" then root[key] = {since = time(), scans = 0, fast = 0, slow = 0} end
    return root[key]
end

function Atr_GetFullScanCounts()
    local record=stats()
    return tonumber(record.fast) or 0,tonumber(record.slow) or 0
end

function Atr_GetDatabaseCoverage()
    local uniqueDays, oldest, newest, samples = {}, nil, nil, 0
    if type(gAtr_ScanDB) == "table" then
        for _, item in pairs(gAtr_ScanDB) do
            if type(item) == "table" then
                -- One H entry per item/day. L is an optional second price,
                -- not another observation or another scan.
                for key, value in pairs(item) do
                    local day = type(key) == "string" and tonumber(key:match("^H(%d+)$"))
                    if day and type(value) == "number" and value > 0 then
                        uniqueDays[day] = true
                        samples = samples + 1
                        oldest = not oldest and day or math.min(oldest, day)
                        newest = not newest and day or math.max(newest, day)
                    end
                end
            end
        end
    end
    local days = 0
    for _ in pairs(uniqueDays) do days = days + 1 end
    return days, oldest, newest, samples
end

local scanStart, scanMode
AuctionatorRemastered.Legacy.Hook("Atr_FullScanStart", function()
    if gAtr_FullScanState ~= ATR_FS_NULL then
        scanStart = time()
        scanMode = (Atr_FullScanSlowMode or IsControlKeyDown()) and "slow" or "fast"
    end
end)
AuctionatorRemastered.Legacy.Hook("Atr_Broadcast_DBupdated", function(num, kind)
    if kind ~= "fullscan" then return end
    local health=Atr_GetDatabaseHealth and Atr_GetDatabaseHealth()
    if health and health.lastScan and not health.lastScan.complete then scanStart,scanMode=nil,nil;return end
    local record = stats()
    record.scans = (record.scans or 0) + 1
    if scanMode then record[scanMode] = (record[scanMode] or 0) + 1 end
    record.last = time()
    record.duration = scanStart and math.max(0, time() - scanStart) or nil
    record.items = num
    record.auctions = Atr_FSR_scanned_count and tonumber(Atr_FSR_scanned_count:GetText()) or nil
    scanStart, scanMode = nil, nil
    if Atr_UpdateFullScanCounts then Atr_UpdateFullScanCounts() end
end)

AuctionatorRemastered.Legacy.Hook("Atr_Init", function()
    stats()
    -- Adopt the requested new default once, preserving explicit non-7-day choices.
    if not AUCTIONATOR_DATABASE_STATS.default14Applied then
        if AUCTIONATOR_MARKET_HISTORY_DAYS == nil or tonumber(AUCTIONATOR_MARKET_HISTORY_DAYS) == 7 then
            AUCTIONATOR_MARKET_HISTORY_DAYS = 14
        end
        AUCTIONATOR_DATABASE_STATS.default14Applied = true
    end
end)

local panel = Atr_ScanningOptionsFrame
local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
info:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -350)
info:SetWidth(440); info:SetJustifyH("LEFT")
info:SetSpacing(4)
local function dayDate(day)
    return day and date("%Y-%m-%d", gScanHistDayZero + day * 86400) or "No history"
end
local function stamp(value)
    return value and date("%Y-%m-%d %H:%M", value) or "None recorded"
end
local function update()
    local record = stats()
    local days, oldest, newest, samples = Atr_GetDatabaseCoverage()
    local lines = {
        "Price history: "..dayDate(oldest).." to "..dayDate(newest),
        "Days with data: "..days.."   |   Item/day records: "..samples,
        "Scan tracking started: "..stamp(record.since),
        "Full scans recorded: "..(record.scans or 0).."   (Fast: "..(record.fast or 0)..", Slow: "..(record.slow or 0)..")",
        "Last recorded full scan: "..stamp(record.last),
    }
    local health=Atr_GetDatabaseHealth and Atr_GetDatabaseHealth()
    if health then
        table.insert(lines,1,"Database: Remastered v"..health.schemaVersion.." | Identified variants: "..health.identified.." | Unresolved names: "..health.unresolved)
        lines[#lines+1]="Last complete scan: "..stamp(health.lastCompleteScan).." | Ambiguous names: "..health.ambiguous
    end
    if record.last then
        lines[#lines + 1] = "Last scan: "..(record.auctions or "?").." auctions, "..(record.items or "?").." items"..(record.duration and ", "..record.duration.." sec" or "")
    end
    info:SetText(table.concat(lines, "\n"))
end
panel:HookScript("OnShow", update)
AuctionatorRemastered.Legacy.Hook("Atr_ScanningConfigFrame_Update", update)
