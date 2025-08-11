-- spawns the npcs, handles snitch spam, mission start, misc fx.

QBCore         = exports['qb-core']:GetCoreObject()
missionActive  = false
currentPhase   = 0
selectedPoints = {}

local ox_lib = exports.ox_lib

--  helper so i dont softlock on missing cfg and cry later
local function need(tbl, key, who)
    if not tbl or not tbl[key] then
        print(('main missing %s.%s ?? check your Config'):format(who or 'Config', key))
        return nil
    end
    return tbl[key]
end

--  mission ped 
local function createMissionPed()
    local pedModel = need(Config.MissionPed, 'model', 'Config.MissionPed'); if not pedModel then return end
    local coords   = need(Config.MissionPed, 'coords', 'Config.MissionPed'); if not coords then return end
    local heading  = Config.MissionPed.heading or 0.0

    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(10) end

    local ped = CreatePed(0, pedModel, coords.x, coords.y, coords.z - 1.0, heading, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- ox_target hookup lives in target.lua so we dont mix concerns
    TriggerEvent('fjella_mission:client:_targetifyMissionPed', ped)
end
CreateThread(createMissionPed)

-- snitch boi 
local function createSnitchPed()
    local pedModel = need(Config.SnitchPed, 'model', 'Config.SnitchPed'); if not pedModel then return end
    local coords   = need(Config.SnitchPed, 'coords', 'Config.SnitchPed'); if not coords then return end
    local heading  = Config.SnitchPed.heading or 0.0

    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(10) end

    local ped = CreatePed(0, pedModel, coords.x, coords.y, coords.z - 1.0, heading, false, true)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- binoculars idle cuz hes nosey
    TaskStartScenarioAtPosition(ped, "WORLD_HUMAN_BINOCULARS", coords.x, coords.y, coords.z, heading, 0, true, false)

    -- ox_target hookup lives in target.lua too
    TriggerEvent('fjella_mission:client:_targetifySnitchPed', ped)
end
CreateThread(createSnitchPed)

--  snitch msgs 
RegisterNetEvent('fjella_mission:client:snitchStatus', function(enabled, message)
    lib.notify({
        title = (Config.SnitchPed and (Config.SnitchPed.smsFrom or 'Snitch')) or 'Snitch',
        description = message or (enabled and 'I will tell you if something happens.' or 'Snitch notifications disabled.'),
        type = 'inform'
    })
end)

RegisterNetEvent('fjella_mission:client:snitchNotify', function(message)
    lib.notify({
        title = (Config.SnitchPed and (Config.SnitchPed.smsFrom or 'Snitch')) or 'Snitch',
        description = message or 'Yo! There is some crazy movement over at the chicken factory right now!',
        type = 'warning',
        duration = 8000
    })
end)

--  mission start → phase 1 
RegisterNetEvent('fjella_mission:client:begin', function(randomizedPoints)
    selectedPoints = randomizedPoints or {}
    missionActive  = true
    currentPhase   = 1

    QBCore.Functions.Notify('Infiltrate the factory!', 'inform')
    if beginPhaseOne then
        beginPhaseOne()
    else
        print('main - beginPhaseOne missing? target.lua should define it')
    end
end)

--  defender ping (pd blip etc) 
RegisterNetEvent('fjella_mission:client:defenderAlert', function(coords)
    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.2)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Chicken factory")
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)

    -- not spamming qb notify here, just silent route. 30s then poof
    Wait(30000)
    RemoveBlip(blip)
end)

--  thermite fx (client-side pretty) 
RegisterNetEvent("fjella_mission:client:playThermiteEffect", function(pos)
    if not pos then return end
    RequestNamedPtfxAsset("scr_ornate_heist")
    while not HasNamedPtfxAssetLoaded("scr_ornate_heist") do Wait(25) end

    UseParticleFxAssetNextCall("scr_ornate_heist")
    local fx = StartParticleFxLoopedAtCoord(
        "scr_heist_ornate_thermal_burn",
        pos.x, pos.y, pos.z,
        0.0, 0.0, 0.0,
        1.0, false, false, false
    )
    SetParticleFxLoopedAlpha(fx, 0.7)

    Wait(10000)
    StopParticleFxLooped(fx, 0)
end)

local function startMission()
    ox_lib:logger('info', 'Starting mission sequence')
end

local function abortMission()
    ox_lib:logger('warn', 'Mission aborted by player')
end

local function completeMission()
    ox_lib:logger('info', 'Mission completed successfully')
end
