local vehiclefuel = {}

-- whip_fuel keeps fuel as a vehicle stat (0 to 100) that only the server writes, so the server sets it directly and no
-- client needs to be asked. A car whip has not seen is adopted first.
local function setWhipFuel(vehicle, amount)
    amount = tonumber(amount)
    if not amount then return false end

    local id = exports.whip_core:AdoptVehicle({ entity = vehicle })
    if not id then return false end

    return exports.whip_core:SetVehicleStat(id, 'fuel', math.min(math.max(amount, 0.0), 100.0), 'Newb_Bridge') == true
end

function vehiclefuel.set(source, vehicle, amount)
    source = tonumber(source)
    if not source then return false end
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    if Config.Providers and Config.Providers.vehiclefuel == 'whip_fuel' then
        return setWhipFuel(vehicle, amount)
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId <= 0 then return false end

    TriggerClientEvent('Newb_Bridge:client:fuelSet', source, netId, amount)
    return true
end

-- bridge.vehiclefuel.set on a client, with whip_fuel: only the server can write the stat, so the host answers for a car
-- within reach of the player asking, once a second at most.
if bridge.isHost and Config.Providers and Config.Providers.vehiclefuel == 'whip_fuel' then
    local REACH = 15.0
    local MIN_INTERVAL = 1000
    local lastRequest = {} ---@type table<number, number>

    AddEventHandler('playerDropped', function()
        lastRequest[source] = nil
    end)

    RegisterNetEvent('Newb_Bridge:server:whipFuelRequested', function(netId, amount)
        local src = source
        if type(netId) ~= 'number' or netId <= 0 or type(amount) ~= 'number' then return end

        local now = GetGameTimer()
        if lastRequest[src] and now - lastRequest[src] < MIN_INTERVAL then return end
        lastRequest[src] = now

        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity == 0 or not DoesEntityExist(entity) then return end
        if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity)) > REACH then return end

        setWhipFuel(entity, amount)
    end)
end

return vehiclefuel
