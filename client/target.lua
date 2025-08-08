-- all the ox_target bits live here. doors, peds, crate, buyer… keep it tidy.

-- local state for zones only handled here (so we can nuke em clean)
local phase2SearchZoneId   = nil
local phaseTwoCrateZoneId  = nil
local phaseThreeDropZoneId = nil
local lootZones            = {} -- if i want to add some more

--  helper so i dont forget to clean a zone
local function safeRemoveZone(id)
    if id then
        exports.ox_target:removeZone(id)
    end
    return nil
end

-- Phase 1 door targets
function beginPhaseOne()
    if not (Config and Config.Doors and Config.Doors.Big and Config.Doors.Small) then
        print('target - Config.Doors.* missing, cant spawn the phase1 targets')
        return
    end

    exports.ox_target:addBoxZone({
        coords   = Config.Doors.Big.target,
        size     = vector3(1.2, 1.2, 1.2),
        rotation = 0,
        debug    = false,
        options  = {{
            label = 'Place C4',
            icon  = 'fas fa-bomb',
            canInteract = function() return missionActive end,
            onSelect = function()
                TriggerServerEvent("fjella_mission:server:tryUseC4")
            end
        }}
    })

    exports.ox_target:addBoxZone({
        coords   = Config.Doors.Small.target,
        size     = vector3(1.2, 1.2, 1.2),
        rotation = 0,
        debug    = false,
        options  = {{
            label = 'Use Thermite',
            icon  = 'fas fa-burn',
            canInteract = function() return missionActive end,
            onSelect = function()
                TriggerServerEvent("fjella_mission:server:tryUseThermite")
            end
        }}
    })
end

-- Mission PED & snitch targets
RegisterNetEvent('fjella_mission:client:_targetifyMissionPed', function(ped)
    if not ped or not DoesEntityExist(ped) then return end
    exports.ox_target:addLocalEntity(ped, {{
        icon = 'fas fa-chicken',
        label = 'Start mission',
        onSelect = function()
            TriggerServerEvent('fjella_mission:server:start')
        end,
        canInteract = function() return not missionActive end
    }})
end)

-- pay-to-notify snitch
RegisterNetEvent('fjella_mission:client:_targetifySnitchPed', function(ped)
    if not ped or not DoesEntityExist(ped) then return end
    exports.ox_target:addLocalEntity(ped, {{
        icon  = 'fa-solid fa-eye',
        label = 'Get info $100',
        onSelect = function()
            TriggerServerEvent('fjella_mission:server:snitchBuy')
        end
    }})
end)

-- Phase 2 small search
RegisterNetEvent('fjella_mission:client:setupPhase2Search', function(data)
    phase2SearchZoneId = safeRemoveZone(phase2SearchZoneId)

    if not data or not data.coords then
        print('target - setupPhase2Search missing coords??')
        return
    end

    phase2SearchZoneId = exports.ox_target:addSphereZone({
        name   = 'chicken_phase2_search',
        coords = data.coords,
        radius = data.radius or 1.2,
        debug  = false,
        options = {{
            icon  = 'fas fa-search',
            label = 'Search crate',
            onSelect = function()
                lib.progressBar({
                    duration = 3000,
                    label = 'Searching...',
                    canCancel = false,
                    disable = { move = true, car = true, combat = true }
                })
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                TriggerServerEvent('fjella_mission:server:tryPhase2Search', vec3(pos.x, pos.y, pos.z))
            end
        }}
    })
end)

RegisterNetEvent('fjella_mission:client:removePhase2Search', function()
    phase2SearchZoneId = safeRemoveZone(phase2SearchZoneId)
end)

-- phase 2/3 objectives
RegisterNetEvent('fjella_mission:client:phaseTwo', function()
    QBCore.Functions.Notify('Secure the package inside!', 'primary')
    local coords = selectedPoints and selectedPoints.objective
    if not coords then
        print('target - phaseTwo coords missing (selectedPoints.objective)')
        return
    end

    phaseTwoCrateZoneId = safeRemoveZone(phaseTwoCrateZoneId)

    phaseTwoCrateZoneId = exports.ox_target:addBoxZone({
        coords   = coords,
        size     = vec3(1, 1, 1),
        rotation = 0,
        debug    = false,
        options  = {{
            label = 'Steal the crate',
            icon  = 'fas fa-box',
            onSelect = function()
                QBCore.Functions.Progressbar("steal_crate", "Collecting...", 5000, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function()
                    phaseTwoCrateZoneId = safeRemoveZone(phaseTwoCrateZoneId)
                    TriggerServerEvent('fjella_mission:server:rewardItem')
                    TriggerServerEvent('fjella_mission:server:advancePhase', 3)
                    currentPhase = 3
                end)
            end
        }}
    })
end)

RegisterNetEvent('fjella_mission:client:phaseThree', function()
    QBCore.Functions.Notify('Deliver the crate to the drop-off!', 'success')
    local coords = selectedPoints and selectedPoints.delivery
    if not coords then
        print('target - phaseThree coords missing (selectedPoints.delivery)')
        return
    end

    phaseThreeDropZoneId = safeRemoveZone(phaseThreeDropZoneId)

    phaseThreeDropZoneId = exports.ox_target:addBoxZone({
        coords   = coords,
        size     = vec3(1, 1, 1),
        rotation = 0,
        debug    = false,
        options  = {{
            label = 'Deliver loot',
            icon  = 'fas fa-truck-loading',
            onSelect = function()
                QBCore.Functions.Progressbar("deliver_loot", "Delivering...", 5000, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function()
                    phaseThreeDropZoneId = safeRemoveZone(phaseThreeDropZoneId)
                    TriggerServerEvent('fjella_mission:server:complete')
                    missionActive = false
                end)
            end
        }}
    })
end)

-- BUYER 
local buyer = {
    ped = nil,
    blip = nil,
    vehicle = nil,
    expires = 0,
    running = false,
}

local BUYER_MODEL = `cs_martinmadrazo`
local VEH_MODEL   = `baller` 
local BUYER_POS   = vec4(1507.93, 6336.9, 23.87, 57.24)
local VEH_POS     = vec4(1511.67, 6338.65, 23.97, 32.13) -- parked behind
local EXIT_POS    = vec4(1606.92, 6483.73, 21.44, 7.49)  -- where he dips out

local function clearBuyer()
    if buyer.blip then RemoveBlip(buyer.blip) buyer.blip = nil end

    if buyer.ped and DoesEntityExist(buyer.ped) then
        if exports.ox_target and exports.ox_target.removeLocalEntity then
            exports.ox_target:removeLocalEntity(buyer.ped)
        end
        DeleteEntity(buyer.ped)
    end
    buyer.ped = nil

    if buyer.vehicle and DoesEntityExist(buyer.vehicle) then
        DeleteEntity(buyer.vehicle)
    end
    buyer.vehicle = nil

    buyer.expires = 0
    buyer.running = false
end

local function drawCountdown(msLeft)
    local sec = math.max(0, math.floor(msLeft / 1000))
    local m = math.floor(sec / 60)
    local s = sec % 60
    local txt = string.format("Buyer leaves in %02d:%02d", m, s)

    SetTextFont(4)
    SetTextScale(0.0, 0.5)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(txt)
    EndTextCommandDisplayText(0.5, 0.05)
end

-- Spawn buyer + parked car and start countdown
RegisterNetEvent('buyer:spawn', function(pos4, durationMs)
    clearBuyer()
    local pos = pos4 or BUYER_POS
    buyer.expires = GetGameTimer() + (tonumber(durationMs) or 300000)
    buyer.running = true

    lib.notify({ title = 'Buyer', description = 'Go to buyer, quickly!', type = 'inform' })
    SetNewWaypoint(pos.x + 0.0, pos.y + 0.0)

    -- buyer ped
    lib.requestModel(BUYER_MODEL, 2000)
    local ped = CreatePed(4, BUYER_MODEL, pos.x, pos.y, pos.z - 1.0, pos.w or 0.0, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeDraggedOut(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    buyer.ped = ped

    -- parked baller
    lib.requestModel(VEH_MODEL, 2000)
    local veh = CreateVehicle(VEH_MODEL, VEH_POS.x, VEH_POS.y, VEH_POS.z, VEH_POS.w or 0.0, false, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 2)  -- locked
    SetVehicleEngineOn(veh, false, false, true)
    SetVehicleCanBreak(veh, false)
    SetEntityInvincible(veh, true) -- ungriefable during scene
    buyer.vehicle = veh

    -- blip/route
    buyer.blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(buyer.blip, 605)
    SetBlipColour(buyer.blip, 5)
    SetBlipScale(buyer.blip, 0.9)
    BeginTextCommandSetBlipName("STRING"); AddTextComponentString("Buyer"); EndTextCommandSetBlipName(buyer.blip)
    SetBlipRoute(buyer.blip, true)

    -- sell target
    exports.ox_target:addLocalEntity(ped, {{
        icon  = 'fas fa-dollar-sign',
        label = 'Sell the box',
        onSelect = function()
            TriggerServerEvent('buyer:sell')
        end
    }})

    -- countdown overlay
    CreateThread(function()
        while buyer.running do
            local left = buyer.expires - GetGameTimer()
            if left <= 0 then break end
            drawCountdown(left)
            Wait(0)
        end
    end)
end)

-- timeout
RegisterNetEvent('buyer:expire', function()
    if buyer.running then
        lib.notify({ title = 'Buyer', description = "Too late. He left.", type = 'error' })
    end
    clearBuyer()
end)

-- successful sale -> enter car, drive away to EXIT_POS, then poof
RegisterNetEvent('buyer:sold', function()
    if not buyer.ped or not DoesEntityExist(buyer.ped) then
        clearBuyer()
        return
    end

    -- remove interaction & route
    if exports.ox_target and exports.ox_target.removeLocalEntity then
        exports.ox_target:removeLocalEntity(buyer.ped)
    end
    if buyer.blip then
        RemoveBlip(buyer.blip)
        buyer.blip = nil
    end
    buyer.running = false  -- stop countdown

    -- let him move
    FreezeEntityPosition(buyer.ped, false)

    -- If the vehicle is gone: just despawn
    if not buyer.vehicle or not DoesEntityExist(buyer.vehicle) then
        clearBuyer()
        return
    end

    -- lock it down and gtfo
    SetVehicleDoorsLocked(buyer.vehicle, 4) -- driver only
    SetEntityInvincible(buyer.vehicle, true)
    SetPedCanBeDraggedOut(buyer.ped, false)

    -- walk into driver seat
    TaskEnterVehicle(buyer.ped, buyer.vehicle, -1, -1, 2.0, 1, 0)

    -- wait until seated or timeout
    local t = GetGameTimer()
    while (not IsPedInVehicle(buyer.ped, buyer.vehicle, false)) and GetGameTimer() - t < 8000 do
        Wait(100)
    end

    if not IsPedInVehicle(buyer.ped, buyer.vehicle, false) then
        clearBuyer()
        return
    end

    -- put foot down
    SetVehicleEngineOn(buyer.vehicle, true, true, false)
    local speed = 25.0
    local drivingStyle = 786603

    if TaskVehicleDriveToCoordLongrange then
        TaskVehicleDriveToCoordLongrange(buyer.ped, buyer.vehicle, EXIT_POS.x, EXIT_POS.y, EXIT_POS.z, speed, drivingStyle, 10.0)
    else
        TaskVehicleDriveToCoord(buyer.ped, buyer.vehicle, EXIT_POS.x, EXIT_POS.y, EXIT_POS.z, speed, 0, GetEntityModel(buyer.vehicle), drivingStyle, 1.0, true)
    end

    -- wait until near EXIT_POS or timeout
    local maxTime = 20000
    local start = GetGameTimer()
    while GetGameTimer() - start < maxTime do
        local p = GetEntityCoords(buyer.vehicle)
        if #(p - vec3(EXIT_POS.x, EXIT_POS.y, EXIT_POS.z)) < 10.0 then
            break
        end
        Wait(250)
    end

    -- teleport farther and vanish (cant be robbed or fucked with)
    SetEntityCoords(buyer.vehicle, EXIT_POS.x, EXIT_POS.y, EXIT_POS.z, false, false, false, false)
    Wait(300)
    clearBuyer()
end)
