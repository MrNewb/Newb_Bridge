local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports.wasabi_carlock:GiveKey(plate)
end

function vehiclekeys.remove(vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports.wasabi_carlock:RemoveKey(plate)
end

return vehiclekeys
