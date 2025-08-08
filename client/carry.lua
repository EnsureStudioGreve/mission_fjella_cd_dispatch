
-- we only handle the box hei_prop_heist_box. 
-- walk-only while carrying.

-- CFG 
local BOX_MODEL = `hei_prop_heist_box`
local BOX_BONE  = 60309 -- right hand-ish
local BOX_PLACE = {
    pos = vector3(0.025, 0.080, 0.255),
    rot = vector3(-145.0, 290.0, 0.0),
}

local ANIM_DICT = 'anim@heists@box_carry@'
local ANIM_CLIP = 'idle'
local ANIM_FLAG = 51 -- upperbody, stay looping etc

--  state 
local carryingProp  = nil
local carryingLoop  = false

-- tiny helpers just bcs
local function reqModel(hash, timeout)
    lib.requestModel(hash, timeout or 1200)
    if not IsModelValid(hash) then
        print('[carry] uhh model not valid??', hash)
    end
end

local function reqAnim(dict, timeout)
    lib.requestAnimDict(dict, timeout or 1200)
end

local function ensureCarryAnim(ped)
    if not IsEntityPlayingAnim(ped, ANIM_DICT, ANIM_CLIP, 3) then
        TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 2.0, 2.0, -1, ANIM_FLAG, 0.0, false, false, false)
    end
end

-- actually start carrying (attach prop & lock behavior)
local function startCarrying()
    if carryingLoop then
        -- already carrying, chill
        return
    end

    local ped = cache.ped
    if not ped or ped == 0 then
        print('carry - no ped?? how')
        return
    end

    carryingLoop = true
    reqModel(BOX_MODEL, 1500)

    -- spawn n glue the box
    local p = GetEntityCoords(ped)
    carryingProp = CreateObject(BOX_MODEL, p.x, p.y, p.z + 0.2, true, true, true)
    if not carryingProp or carryingProp == 0 then
        print('carry -  box didnt spawn lol')
        carryingLoop = false
        return
    end

    SetEntityCollision(carryingProp, false, false)
    AttachEntityToEntity(
        carryingProp, ped, GetPedBoneIndex(ped, BOX_BONE),
        BOX_PLACE.pos.x, BOX_PLACE.pos.y, BOX_PLACE.pos.z,
        BOX_PLACE.rot.x, BOX_PLACE.rot.y, BOX_PLACE.rot.z,
        true, true, false, true, 1, true
    )

    -- play the goofy “im carrying smth” anim
    reqAnim(ANIM_DICT, 1500)
    ensureCarryAnim(ped)

    -- control loop — walk only, no vehicles, keep anim alive
    CreateThread(function()
        local me = cache.playerId
        print('carry - ok walking only now')

        while carryingLoop do
            -- block sprint / sneakysneaky toggles
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 36, true)  -- duck
            SetPlayerSprint(me, false)

            -- dont let ppl yeet into cars while holding a full fuckin IKEA
            if DoesEntityExist(GetVehiclePedIsTryingToEnter(ped)) then
                ClearPedTasks(ped)
                ensureCarryAnim(ped)
            end
            if IsPedInAnyVehicle(ped, false) then
                ClearPedTasksImmediately(ped)
                ensureCarryAnim(ped)
            end

            -- sometimes anim dies for no reason (so we ensure the carry animation)
            ensureCarryAnim(ped)

            Wait(0) -- i should probably reconsider this, but here we go, tips are more then welcome
        end

        -- cleanup controls when we stop
        SetPlayerSprint(me, true)
        print('carry - k ur free to run again')
    end)
end

-- stop carrying (del prop + anim)
local function stopCarrying()
    if not carryingLoop and not carryingProp then
        return -- already clean dont spam
    end

    carryingLoop = false

    if carryingProp and DoesEntityExist(carryingProp) then
        DeleteEntity(carryingProp)
    end
    carryingProp = nil

    if cache.ped and cache.ped ~= 0 then
        ClearPedTasks(cache.ped)
    end
end

-- network/state sync, lets centralize ONE statebag key so both sides agree: 'carryBox'
AddStateBagChangeHandler('carryBox', nil, function(bagName, _key, value, _rep, replicated)
    if replicated then return end

    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end
    if GetPlayerPed(ply) ~= cache.ped then return end

    if value then
        print('carry - start STATEBAG')
        startCarrying()
    else
        print('carry - stop STATEBAG')
        stopCarrying()
    end
end)

-- when we load in, ask server to check our inv and set statebag right
local function onLoaded()
    print('carry - sync ')
    TriggerServerEvent('carry:sync')
end

-- lil spread across common frameworks cuz… i dunno what you will be starting this with
AddEventHandler('Characters:Client:Spawn', onLoaded)
RegisterNetEvent('esx:playerLoaded', onLoaded)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onLoaded)
RegisterNetEvent('ox:playerLoaded', onLoaded)

-- cleanup if resource dies mid-carry (pls no)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopCarrying()
end)

-- ox_inventory pings us w/ counts; we only care about "box"
-- tell server true/false so it flips the statebag for everyone to see
AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount)
    if itemName ~= 'box' then return end
    local has = (totalCount or 0) > 0
    print(('carry - inv says box=%s'):format(tostring(has)))
    TriggerServerEvent('carry:update', has)
end)
