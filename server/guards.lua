-- phase 2: spawn the dudes, open the search spot, clean up the mess later.
-- try not to spaghetti this pls 

-- lil sanity helper
local function okCrate()
    return Config and Config.Crate and Config.Crate.coords
end

function StartPhaseTwo()
    if phaseTwoActive then
        return
    end

    -- flip the switches
    phaseTwoActive   = true
    doorBreached     = true
    searchTaken      = false
    searchZoneActive = true

    -- spawn goons (clients handle actual peds)
    if not (Config and Config.Guards) then
        print('guards - Config.Guards missing, spawning nothing')
    else
        TriggerClientEvent('fjella_mission:client:spawnGuards', -1, Config.Guards, Config.GuardAI or {})
    end

    -- open search spot (aka where the box is hiding)
    if not okCrate() then
        print('guards - Config.Crate.coords missing, no search zone')
    else
        TriggerClientEvent('fjella_mission:client:setupPhase2Search', -1, {
            coords = Config.Crate.coords,
            radius = Config.Crate.radius or 1.2
        })
    end

    -- hard timeout so mission doesnt hang forever (20m)
    SetTimeout(20 * 60 * 1000, function()
        if not phaseTwoActive then return end
        TriggerClientEvent('fjella_mission:client:despawnGuards', -1)

        if searchZoneActive then
            TriggerClientEvent('fjella_mission:client:removePhase2Search', -1)
            searchZoneActive = false
        end

        phaseTwoActive = false
        print('guards - phase 2 auto-cleaned after timeout')
    end)
end

function CleanupPhaseTwo()
    -- nuke guards + loot targets from orbit
    TriggerClientEvent('fjella_mission:client:despawnGuards', -1)
    TriggerClientEvent('fjella_mission:client:clearLootTargets', -1)

    if searchZoneActive then
        TriggerClientEvent('fjella_mission:client:removePhase2Search', -1)
        searchZoneActive = false
    end

    searchTaken    = false
    phaseTwoActive = false

    print('guards - phase 2 cleaned up')
end

local ox_lib = exports.ox_lib

exports('StartPhaseTwo', function()
    ox_lib:logger('info', 'Phase Two started - Guards spawning', {guardCount = #Config.Guards})
    StartPhaseTwo()
end)

exports('CleanupPhaseTwo', function()
    ox_lib:logger('info', 'Phase Two cleanup initiated', {despawnedGuards = #SpawnedGuards})
    CleanupPhaseTwo()
end)

local function spawnGuard(guardData, index)
    ox_lib:logger('debug', 'Spawning guard', {index = index, model = guardData.model, weapon = guardData.weapon})
end
