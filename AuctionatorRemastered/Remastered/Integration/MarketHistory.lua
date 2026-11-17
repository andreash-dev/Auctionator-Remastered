-- Observe original price writes and pruning without changing the engine.
AuctionatorRemastered.Legacy.Hook("Atr_UpdateScanDBprice",function(name,price,database)
    if not Atr_DatabaseHandles or not Atr_DatabaseHandles(database) then
        Atr_RecordMarketObservation(name,price,database)
    end
end)
AuctionatorRemastered.Legacy.Hook("Atr_PruneScanDB",function() Atr_PruneMarketObservations(gAtr_ScanDB) end)

