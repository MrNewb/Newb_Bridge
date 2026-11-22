local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['vehicles_keys']:giveVehicleKeysToPlayerId(src, plate, 'temporary')
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['vehicles_keys']:removeKeysFromPlayerId(src, plate)
end

return vehiclekeys
