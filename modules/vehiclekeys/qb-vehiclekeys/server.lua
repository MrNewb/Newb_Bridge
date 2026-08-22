local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['qb-vehiclekeys']:GiveKeys(src, plate)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports['qb-vehiclekeys']:RemoveKeys(src, plate)
end

return vehiclekeys
