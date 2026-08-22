local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['Renewed-Vehiclekeys']:addKey(src, plate)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['Renewed-Vehiclekeys']:removeKey(src, plate)
end

return vehiclekeys
