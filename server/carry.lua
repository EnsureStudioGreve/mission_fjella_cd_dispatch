-- does a few things:
-- 1) phase2 search → actually give the box
-- 2) mirror “do i have a box?” into a statebag so client can glue anim/prop
-- 3) poke the buyer flow when u pick/drop the box
-- try to keep this boring & reliable pls :>

local ox = exports.ox_inventory
local ox_lib = exports.ox_lib

-- do they actually have a 'box' item? (fast path then fallback scan, cuz ox versions be diff)
local function hasBox(src)
    local count = ox:GetItemCount(src, 'box')
    if count == nil then
        count = 0
        local items = ox:GetInventoryItems(src)
        if items then
            for _, it in pairs(items) do
                if it and it.name == 'box' then
                    count = count + (it.count or 1) -- some metas dont have .count lol
                end
            end
        end
    end
    return (count or 0) > 0
end

-- flip statebag so client knows to attach/detach
local function setCarryState(src, carrying)
    local ok, err = pcall(function()
        Player(src).state:set('carryBox', carrying and true or false, true)
    end)
    if not ok then
        print(('carry - couldnt set state for %s, err=%s'):format(tostring(src), tostring(err)))
    end
end

local function buyerStart(src) TriggerEvent('buyer:start', src) end
local function buyerCancel(src) TriggerEvent('buyer:cancel', src) end

-- phase 2  search spot → give the box 
RegisterNetEvent('fjella_mission:server:tryPhase2Search', function(playerPos)
    local src = source
    if not phaseTwoActive or searchTaken then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    if not (Config and Config.Crate and Config.Crate.coords) then
        print('carry - Config.Crate.coords missing, cant validate search pos^0')
        return
    end

    -- anti-spoof: must be close-ish to the crate coords
    local p = vector3(playerPos.x, playerPos.y, playerPos.z)
    if #(p - Config.Crate.coords) > 3.0 then return end

    -- ok u get the thing
    searchTaken = true
    ox:AddItem(src, 'box', 1)

    if searchZoneActive then
        TriggerClientEvent('fjella_mission:client:removePhase2Search', -1)
        searchZoneActive = false
    end

    TriggerClientEvent('ox_lib:notify', src, {
        description = "You found a box.",
        type = "success"
    })

    -- mirror state + start buyer timer
    setCarryState(src, true)
    buyerStart(src)
end)

-- Optional reward on the main crate (client can call this during phaseTwo)
RegisterNetEvent('fjella_mission:server:rewardItem', function()
    local src = source
    ox:AddItem(src, 'box', 1)
    -- make sure client flips into carry mode too
    setCarryState(src, true)
    buyerStart(src)
end)

--  CARRY STATE SYNC
-- client asks us to sync with whatever inventory says rn
RegisterNetEvent('carry:sync', function()
    local src = source
    local carrying = hasBox(src)
    setCarryState(src, carrying)
    if carrying then
        buyerStart(src) -- already holding? go to the dude
    end
end)

-- client says their box count changed (ox hook on client triggers this)
RegisterNetEvent('carry:update', function(hasAny)
    local src = source
    setCarryState(src, hasAny and true or false)
    if hasAny then
        buyerStart(src)
    else
        buyerCancel(src)
    end
end)

-- boot pass: catch ppl that loaded before us or were mid-run
CreateThread(function()
    Wait(1000) -- let ox/core breathe a sec
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id then
            local carrying = hasBox(id)
            setCarryState(id, carrying)
            if carrying then
                buyerStart(id)
            end
        end
    end
end)

-- cleanup if they poof
AddEventHandler('playerDropped', function()
    local src = source
    setCarryState(src, false)
    buyerCancel(src)
end)

RegisterNetEvent('fjella_mission:pickupCrate', function()
    local src = source
    ox_lib:logger('info', 'Player picked up crate', {player = src, coords = Config.Crate.coords})
end)

RegisterNetEvent('fjella_mission:deliverCrate', function()
    local src = source
    ox_lib:logger('info', 'Player delivered crate', {player = src, coords = Config.Buyer.coords})
end)
