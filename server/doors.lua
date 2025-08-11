local ox_lib = exports.ox_lib

-- C4 big door
RegisterNetEvent("fjella_mission:server:tryUseC4", function()
    local src = source
    local have = (exports.ox_inventory:Search(src, 'count', 'c4') or 0)
    if have <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { description = "You need C4", type = "error" })
        return
    end

    exports.ox_inventory:RemoveItem(src, 'c4', 1)
    TriggerClientEvent("fjella_mission:client:c4Countdown", src)

    -- lil dispatch ping roughly when it goes kaboom
    SetTimeout(5000, function()
        TriggerEvent('ps-dispatch:server:explosion', {
            coords = vector3(-139.11, 6146.3, 32.44),
            description = "Explosion reported at the chicken factory!",
            radius = 50.0,
            job = "police"
        })
    end)
end)

RegisterNetEvent("fjella_mission:server:explosionComplete", function()
    exports.ox_doorlock:setDoorState(1230, false)
    print("doors - big door (1230) unlocked AFTER explosion^0")

    -- one more ping for the boys in blue
    TriggerEvent('ps-dispatch:server:explosion', {
        coords = vector3(-139.11, 6146.3, 32.44),
        description = "Explosion reported at the chicken factory!",
        radius = 50.0,
        job = "police"
    })

    StartPhaseTwo()
end)

RegisterNetEvent('fjella_mission:bigDoorExploded', function()
    local src = source
    ox_lib:logger('info', 'Big door explosion triggered', {player = src, coords = Config.Doors.Big.explosion})
end)

-- Thermite (small door)
RegisterNetEvent("fjella_mission:server:tryUseThermite", function()
    local src = source
    local have = (exports.ox_inventory:Search(src, 'count', 'thermite') or 0)
    if have <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { description = "You need thermite", type = "error" })
        return
    end

    exports.ox_inventory:RemoveItem(src, 'thermite', 1)
    TriggerClientEvent("fjella_mission:client:thermiteCountdown", src)
end)

RegisterNetEvent("fjella_mission:server:thermiteComplete", function()
    local burnPos = vec3(-69.24, 6267.9, 31.15)
    TriggerClientEvent("fjella_mission:client:playThermiteEffect", -1, burnPos)

    -- give it a sec so the fx actually plays before unlock
    SetTimeout(10000, function()
        exports.ox_doorlock:setDoorState(1231, false)
        print("doors - small door (1231) unlocked after thermite^0")

        if not doorBreached then
            StartPhaseTwo()
        end
    end)
end)

RegisterNetEvent('fjella_mission:smallDoorBurned', function()
    local src = source
    ox_lib:logger('info', 'Small door burn triggered', {player = src, coords = Config.Doors.Small.burnFx})
end)

-- on boot: pls lock the doors thx
CreateThread(function()
    Wait(1000)
    exports.ox_doorlock:setDoorState(1230, true)
    exports.ox_doorlock:setDoorState(1231, true)
    print("doors - doors reset & locked^0")
end)
