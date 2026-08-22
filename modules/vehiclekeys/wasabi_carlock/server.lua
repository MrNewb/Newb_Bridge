local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.wasabi_carlock:GiveKey(src, plate)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.wasabi_carlock:RemoveKey(src, plate)
end

return vehiclekeys