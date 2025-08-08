-- spawn and despawn npc guards with cleanup and safety

local spawnedGuards = {}

RegisterNetEvent('fjella_mission:client:spawnGuards', function(guards, ai)
    if not guards or #guards == 0 then return end

    -- preload models
    for _, g in ipairs(guards) do
        if IsModelValid(g.model) then
            RequestModel(g.model)
            while not HasModelLoaded(g.model) do Wait(10) end
        end
    end

    -- hostile relationship to player
    local rel = GetHashKey('MISSION_GUARDS')
    AddRelationshipGroup('MISSION_GUARDS')
    SetRelationshipBetweenGroups(5, rel, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), rel)

    for _, g in ipairs(guards) do
        if not IsModelValid(g.model) then goto continue end

        local p = g.pos
        local ped = CreatePed(4, g.model, p.x, p.y, p.z - 1.0, p.w or 0.0, true, true)

        -- be sure it syncs to everyone
        NetworkRegisterEntityAsNetworked(ped)
        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(ped), true)

        SetEntityAsMissionEntity(ped, true, true)
        SetPedRelationshipGroupHash(ped, rel)
        SetPedArmour(ped, ai.armour or 50)
        SetEntityMaxHealth(ped, ai.health or 200)
        SetEntityHealth(ped, ai.health or 200)

        SetPedAccuracy(ped, math.max(0, math.min(100, ai.accuracy or 55)))
        SetPedAlertness(ped, 3)
        SetPedHearingRange(ped, ai.alertRange or 60.0)
        SetPedSeeingRange(ped, ai.alertRange or 60.0)
        SetPedCombatAbility(ped, 2)
        SetPedCombatAttributes(ped, 46, true) -- npc can use cover
        SetPedCombatMovement(ped, 2)          -- npc can be smart and flank
        SetPedDropsWeaponsWhenDead(ped, false)
        SetPedFleeAttributes(ped, 0, false)

        GiveWeaponToPed(ped, g.weapon or `WEAPON_SMG`, 250, false, true)
        TaskGuardCurrentPosition(ped, 15.0, 10.0, true)

        table.insert(spawnedGuards, ped)

        ::continue::
    end

    -- unload models from memory
    for _, g in ipairs(guards) do
        if IsModelValid(g.model) then SetModelAsNoLongerNeeded(g.model) end
    end
end)

RegisterNetEvent('fjella_mission:client:despawnGuards', function()
    for _, ped in ipairs(spawnedGuards) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedGuards = {}
end)
