-- whip_core vehicle keys (server). In whip a key is an item cut for one vehicle, so giving one needs whip's vehicle id.
-- The id comes from the entity (a car whip has not seen is adopted as a session car) or, when only a plate is given, from
-- a car whip already knows by that plate. Owned cars are always known.
local vehiclekeys = {}

local whip = exports.whip_core

local function vehicleIdFor(vehicle, plate)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local id = whip:AdoptVehicle({ entity = vehicle })
        if id then return id end
    end

    if type(plate) == 'string' and plate ~= '' then
        local known = whip:GetVehicle({ plate = plate })
        return known and known.vehicleId or nil
    end
end

function vehiclekeys.give(src, vehicle, plate)
    local id = vehicleIdFor(vehicle, plate)
    if not id then return false end

    return whip:GiveVehicleKey(tonumber(src), id) == true
end

function vehiclekeys.remove(src, vehicle, plate)
    local id = vehicleIdFor(vehicle, plate)
    if not id then return false end

    return whip:RemoveVehicleKey(tonumber(src), id) == true
end

-- A player's own game asks for a key through bridge.vehiclekeys on the client. Whip's keys are the server's to give, so
-- the host answers, for one player's own key only: the car must be within reach, and it must be a car nobody else owns.
if bridge.isHost then
    local REACH = 15.0
    local MIN_INTERVAL = 1000
    local lastRequest = {} ---@type table<number, number>

    AddEventHandler('playerDropped', function()
        lastRequest[source] = nil
    end)

    RegisterNetEvent('Newb_Bridge:server:whipKeyRequested', function(action, netId, plate)
        local src = source
        if action ~= 'give' and action ~= 'remove' then return end
        if not whip:GetCharId(src) then return end

        local now = GetGameTimer()
        if lastRequest[src] and now - lastRequest[src] < MIN_INTERVAL then return end
        lastRequest[src] = now

        local entity = type(netId) == 'number' and netId > 0 and NetworkGetEntityFromNetworkId(netId) or 0
        local found = entity ~= 0 and DoesEntityExist(entity)

        if found and #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity)) > REACH then return end

        if action == 'remove' then
            vehiclekeys.remove(src, found and entity or 0, plate)
            return
        end

        if not found then return end

        local id = vehicleIdFor(entity)
        if not id then return end

        local owner = whip:GetVehicle(id)
        local ownerCharId = owner and owner.owner and owner.owner.charId or 0
        if ownerCharId ~= 0 and ownerCharId ~= whip:GetCharId(src) then return end

        whip:GiveVehicleKey(src, id)
    end)
end

return vehiclekeys
