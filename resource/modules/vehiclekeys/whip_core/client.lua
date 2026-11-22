-- whip_core vehicle keys (client). Whip's keys are items the server cuts, so this asks the bridge host's server side to do
-- it for the local player; the server checks the car is within reach and not owned by someone else.
local vehiclekeys = {}

local function request(action, vehicle, plate)
    local netId = 0
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) then
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    end

    if netId == 0 and not (action == 'remove' and plate) then return end

    TriggerServerEvent('Newb_Bridge:server:whipKeyRequested', action, netId, plate)
end

function vehiclekeys.give(vehicle, plate)
    request('give', vehicle, plate)
end

function vehiclekeys.remove(vehicle, plate)
    request('remove', vehicle, plate)
end

return vehiclekeys
