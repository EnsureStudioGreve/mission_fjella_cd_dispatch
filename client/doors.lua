--doors - plant the thing, do the boom, open sesame

-- helpers bc i dont want to repeat myself
local function reqModel(hash, timeout)
    lib.requestModel(hash, timeout or 1500)
    if not IsModelValid(hash) then
        print('doors - model busted??', hash)
    end
end

local function reqAnim(dict, timeout)
    lib.requestAnimDict(dict, timeout or 1500)
end

local function ensureAnim(ped, dict, clip, flag)
    if not IsEntityPlayingAnim(ped, dict, clip, 3) then
        TaskPlayAnim(ped, dict, clip, 2.0, 2.0, -1, flag or 49, 0.0, false, false, false)
    end
end

-- Big door (C4 go brrr)
RegisterNetEvent("fjella_mission:client:c4Countdown", function()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        print('doors - no ped??')
        return
    end

    local cfg = Config.Doors and Config.Doors.Big
    if not cfg or not cfg.anim or not cfg.explosion then
        print('doors - Big door cfg missing, check Config.Doors.Big pls')
        return
    end

    local coords  = cfg.anim.pos
    local heading = cfg.anim.heading

    reqAnim("anim@heists@ornate_bank@thermal_charge")
    reqModel("hei_p_m_bag_var22_arm_s")
    reqModel("hei_prop_heist_thermite")

    while not HasAnimDictLoaded("anim@heists@ornate_bank@thermal_charge")
       or not HasModelLoaded("hei_p_m_bag_var22_arm_s")
       or not HasModelLoaded("hei_prop_heist_thermite") do
        Wait(25)
    end

    SetEntityHeading(ped, heading)
    Wait(80)

    -- lil bag + “c4” (ye its the thermite prop, dont @ me)
    local bag   = CreateObject(`hei_p_m_bag_var22_arm_s`, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(bag, false, true)

    local c4    = CreateObject(`hei_prop_heist_thermite`, coords.x, coords.y, coords.z + 0.2, true, true, true)
    AttachEntityToEntity(c4, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

    -- sync scene bc fancy
    local rx, ry, rz = table.unpack(GetEntityRotation(ped))
    local scene = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, rx, ry, rz, 2, false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, scene, "anim@heists@ornate_bank@thermal_charge", "thermal_charge", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(bag, scene, "anim@heists@ornate_bank@thermal_charge", "bag_thermal_charge", 4.0, -8.0, 1)
    NetworkStartSynchronisedScene(scene)

    lib.progressBar({
        duration     = 5000,
        label        = 'Placing C4...',
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, car = true, combat = true }
    })

    Wait(5000) -- lemme “finish” the place

    -- tidy up
    DetachEntity(c4, true, true)
    FreezeEntityPosition(c4, true)
    DeleteObject(bag)
    NetworkStopSynchronisedScene(scene)

    -- kaboom (pls stand back)
    local boom = cfg.explosion
    AddExplosion(boom.x, boom.y, boom.z, 2, 1.0, true, false, 1.0)
    TriggerServerEvent("fjella_mission:server:explosionComplete")

    -- garbage collector but manual lol
    CreateThread(function()
        Wait(10000)
        if DoesEntityExist(c4) then DeleteEntity(c4) end
    end)
end)

-- small door thermite
RegisterNetEvent("fjella_mission:client:thermiteCountdown", function()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        print('doors - no ped??')
        return
    end

    local cfg = Config.Doors and Config.Doors.Small
    if not cfg or not cfg.anim then
        print('doors - Small door cfg missing, check Config.Doors.Small pls')
        return
    end

    local coords  = cfg.anim.pos
    local heading = cfg.anim.heading

    reqAnim("anim@heists@ornate_bank@thermal_charge")
    reqModel("hei_p_m_bag_var22_arm_s")
    reqModel("hei_prop_heist_thermite")

    while not HasAnimDictLoaded("anim@heists@ornate_bank@thermal_charge")
       or not HasModelLoaded("hei_p_m_bag_var22_arm_s")
       or not HasModelLoaded("hei_prop_heist_thermite") do
        Wait(25)
    end

    SetEntityHeading(ped, heading)

    local bag = CreateObject(`hei_p_m_bag_var22_arm_s`, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(bag, false, true)

    local thermite = CreateObject(`hei_prop_heist_thermite`, coords.x, coords.y, coords.z + 0.2, true, true, true)
    AttachEntityToEntity(thermite, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

    local rx, ry, rz = table.unpack(GetEntityRotation(ped))
    local scene = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, rx, ry, rz, 2, false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, scene, "anim@heists@ornate_bank@thermal_charge", "thermal_charge", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(bag, scene, "anim@heists@ornate_bank@thermal_charge", "bag_thermal_charge", 4.0, -8.0, 1)
    NetworkStartSynchronisedScene(scene)

    lib.progressBar({
        duration     = 5000,
        label        = 'Placing thermite...',
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, combat = true, car = true }
    })

    Wait(5000)

    -- pack up
    DetachEntity(thermite, true, true)
    FreezeEntityPosition(thermite, true)
    DeleteObject(bag)
    NetworkStopSynchronisedScene(scene)
    Wait(1000)
    if DoesEntityExist(thermite) then DeleteEntity(thermite) end

    -- tell server to do the unlock after fx
    TriggerServerEvent("fjella_mission:server:thermiteComplete")
end)
