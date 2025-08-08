-- spins up the run, picks points (with fallback), pokes cops, pings snitch now with payment and handles cooldown stuff, note to self, pls keep it neat .

QBCore = exports['qb-core']:GetCoreObject()

-- shared state
SnitchSubscribers = SnitchSubscribers or {}
phaseTwoActive    = phaseTwoActive or false
doorBreached      = doorBreached or false
searchTaken       = searchTaken or false
searchZoneActive  = searchZoneActive or false
missionTimeout    = missionTimeout or false

-- vec utils becaus config can be vec3/vec4/tables
local function toVec3(v)
    local t = type(v)
    if t == "vector3" then return v end
    if t == "vector4" then return vec3(v.x, v.y, v.z) end
    if t == "table" and v.x and v.y and v.z then return vec3(v.x, v.y, v.z) end
    return nil
end

local function pickFromListOrFallback(list, fallbackChain, name)
    -- first try user-provided list if any
    if type(list) == "table" and #list > 0 then
        local pick = list[math.random(#list)]
        local v = toVec3(pick)
        if v then return v end
    end
    -- then walk our “best guess” chain
    for _, candidate in ipairs(fallbackChain or {}) do
        local v = toVec3(candidate)
        if v then return v end
    end
    -- still nothing, sad
    return nil
end

--  start mission 
RegisterNetEvent('fjella_mission:server:start', function()
    local src = source
    if missionTimeout then
        TriggerClientEvent('ox_lib:notify', src, { description = "Mission on cooldown", type = "error" })
        return
    end

    -- fallback chainnns (tries each in orderr)
    local infiltrationFallbacks = {
        Config.Doors and Config.Doors.Big and (Config.Doors.Big.target or (Config.Doors.Big.anim and Config.Doors.Big.anim.pos)),
        Config.Crate and Config.Crate.coords,
        Config.Buyer and Config.Buyer.coords,
    }

    local objectiveFallbacks = {
        Config.Crate and Config.Crate.coords,
        Config.Doors and Config.Doors.Small and (Config.Doors.Small.target or (Config.Doors.Small.anim and Config.Doors.Small.anim.pos)),
        Config.Buyer and Config.Buyer.coords,
    }

    local deliveryFallbacks = {
        Config.Buyer and Config.Buyer.coords,
        Config.Crate and Config.Crate.coords,
        Config.Doors and Config.Doors.Big and (Config.Doors.Big.target or (Config.Doors.Big.anim and Config.Doors.Big.anim.pos)),
    }

    local infiltration = pickFromListOrFallback(Config.InfiltrationPoints, infiltrationFallbacks, "infiltration")
    local objective    = pickFromListOrFallback(Config.ObjectivePoints,    objectiveFallbacks,    "objective")
    local delivery     = pickFromListOrFallback(Config.DeliveryPoints,     deliveryFallbacks,     "delivery")

    if not (infiltration and objective and delivery) then
        print(('main - start failed, points missing infil=%s obj=%s deliv=%s')
            :format(tostring(infiltration), tostring(objective), tostring(delivery)))
        TriggerClientEvent('ox_lib:notify', src, {
            description = "Mission points are not configured on the server.",
            type = "error"
        })
        return
    end

    local randomSet = {
        infiltration = infiltration,
        objective    = objective,
        delivery     = delivery,
    }

    -- spin them up
    TriggerClientEvent('fjella_mission:client:begin', src, randomSet)

    -- notify PD
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job and player.PlayerData.job.name == "police" then
            TriggerClientEvent('fjella_mission:client:defenderAlert', playerId, randomSet.infiltration)
        end
    end

    -- only the ppl who paid the snitch get the text
    if NotifySnitchSubscribers then
        NotifySnitchSubscribers(src)
    end

    -- cooldown (1h) also lock doors back + clear snitch list after.
    missionTimeout = true
    SetTimeout(60 * 60 * 1000, function()
        missionTimeout = false
        exports.ox_doorlock:setDoorState(1230, true)
        exports.ox_doorlock:setDoorState(1231, true)
        SnitchSubscribers = {} -- reset paid list for next round
        print('main - cooldown over, doors re-locked, snitch list wiped')
    end)
end)

--  phase hop (client asks for next stage) 
RegisterNetEvent('fjella_mission:server:advancePhase', function(phase)
    local src = source
    if phase == 2 then
        TriggerClientEvent('fjella_mission:client:phaseTwo', src)
    elseif phase == 3 then
        TriggerClientEvent('fjella_mission:client:phaseThree', src)
    end
end)

--  donezo 
RegisterNetEvent('fjella_mission:server:complete', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.AddMoney('cash', math.random(3000, 5000), 'mission-complete')
        TriggerClientEvent('ox_lib:notify', src, { description = "Mission complete! Cash received.", type = "success" })
    end
    if CleanupPhaseTwo then CleanupPhaseTwo() end
end)
