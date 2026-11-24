local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports.wasabi_carlock:GiveKey(src, plate, vehicle and GetEntityModel(vehicle))
end

function vehiclekeys.remove(src, vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports.wasabi_carlock:RemoveKey(src, plate)
end

return vehiclekeys
