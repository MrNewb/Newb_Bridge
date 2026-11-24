local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports['jg-vehiclekeys']:giveKeys(plate, vehicle and GetEntityModel(vehicle))
end

function vehiclekeys.remove(vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports['jg-vehiclekeys']:removeKeys(plate, vehicle and GetEntityModel(vehicle))
end

return vehiclekeys
