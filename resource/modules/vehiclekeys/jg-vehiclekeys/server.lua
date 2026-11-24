local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports['jg-vehiclekeys']:giveKeys(src, plate, vehicle and GetEntityModel(vehicle))
end

function vehiclekeys.remove(src, vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports['jg-vehiclekeys']:removeKeys(src, plate, vehicle and GetEntityModel(vehicle))
end

return vehiclekeys
