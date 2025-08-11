-- buyer.lua (server) — PATCH

local ox = exports.ox_inventory
local BUYER_POS = vec4(1507.93, 6336.9, 23.87, 57.24)
local DURATION  = 5 * 60 * 1000  -- 5 minutes
local Sessions = {}  -- [src] = { active = true, started = GetGameTimer()}

local function hasBox(src)
    local count = ox:GetItemCount(src, 'box')
    if count == nil then
        local items = ox:GetInventoryItems(src)
        count = 0
        if items then
            for _, it in pairs(items) do
                if it and it.name == 'box' and (it.count or 1) > 0 then
                    count = count + (it.count or 1)
                end
            end
        end
    end
    return (count or 0) > 0
end

-- accept an explicit target src (from server) or fall back to net source
RegisterNetEvent('buyer:start', function(targetSrc)
    local src = targetSrc or source
    if not src or src == 0 then return end
    if Sessions[src] and Sessions[src].active then return end
    if not hasBox(src) then return end

    Sessions[src] = { active = true, started = GetGameTimer() }

    -- send only the duration; client builds its own deadline
    TriggerClientEvent('buyer:spawn', src, BUYER_POS, DURATION)

    SetTimeout(DURATION + 100, function()
        local ses = Sessions[src]
        if not ses or not ses.active then return end
        ses.active = false
        TriggerClientEvent('buyer:expire', src)
        Sessions[src] = nil
    end)
end)


RegisterNetEvent('buyer:cancel', function(targetSrc)
    local src = targetSrc or source
    if not src or src == 0 then return end
    local ses = Sessions[src]
    if ses and ses.active then
        ses.active = false
        TriggerClientEvent('buyer:expire', src)
    end
    Sessions[src] = nil
end)


RegisterNetEvent('buyer:sell', function()
    local src = source
    local ses = Sessions[src]
    if not ses or not ses.active then
        TriggerClientEvent('ox_lib:notify', src, { description = "Buyer isn't available anymore.", type = "error" })
        return
    end
    if not hasBox(src) then
        TriggerClientEvent('ox_lib:notify', src, { description = "You don't have the box.", type = "error" })
        return
    end

    local removed = ox:RemoveItem(src, 'box', 1)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, { description = "Couldn't sell the box.", type = "error" })
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.AddMoney('cash', math.random(2500, 3500), 'sold-box-buyer')
    end

    ses.active = false
    Sessions[src] = nil
    TriggerClientEvent('buyer:sold', src)
    TriggerClientEvent('ox_lib:notify', src, { description = "Box sold. Move out!", type = "success" })
end)

AddEventHandler('playerDropped', function()
    local src = source
    Sessions[src] = nil
end)
