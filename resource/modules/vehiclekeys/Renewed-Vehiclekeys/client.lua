local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['Renewed-Vehiclekeys']:addKey(plate)
end

function vehiclekeys.remove(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['Renewed-Vehiclekeys']:removeKey(plate)
end

return vehiclekeys
