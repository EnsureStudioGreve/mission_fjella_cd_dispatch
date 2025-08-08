function NotifySnitchSubscribers(starterSrc)
    local msg = (Config.SnitchPed and Config.SnitchPed.smsText) or
        'Yo! There is some crazy movement over at the chicken factory right now!'
    for src, _ in pairs(SnitchSubscribers) do
        TriggerClientEvent('fjella_mission:client:snitchNotify', src, msg)
    end
end

-- pay to receive alerts for the current mission window until server restart
RegisterNetEvent('fjella_mission:server:snitchBuy', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- already paid? just confirm
    if SnitchSubscribers[src] then
        TriggerClientEvent('fjella_mission:client:snitchStatus', src, true, 'You already paid the snitch for tips this mission.')
        return
    end

    local cash = Player.Functions.GetMoney and Player.Functions.GetMoney('cash') or (Player.PlayerData.money and Player.PlayerData.money.cash) or 0
    if (cash or 0) < 100 then
        TriggerClientEvent('ox_lib:notify', src, { description = "Not enough cash ($100).", type = "error" })
        return
    end

    -- charge and subscribe
    local ok = Player.Functions.RemoveMoney and Player.Functions.RemoveMoney('cash', 100, 'snitch-info') or false
    if not ok then
        ok = true
        if Player.Functions.RemoveMoney then
        end
    end

    if ok then
        SnitchSubscribers[src] = true
        TriggerClientEvent('fjella_mission:client:snitchStatus', src, true, 'You paid the snitch. He will text you if something happens.')
    else
        TriggerClientEvent('ox_lib:notify', src, { description = "Payment failed.", type = "error" })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    SnitchSubscribers[src] = nil
end)
