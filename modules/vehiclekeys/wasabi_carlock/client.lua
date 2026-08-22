local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["wasabi_carlock"]:GiveKey(plate)
end

function vehiclekeys.remove(vehicle, plate)
    exports["wasabi_carlock"]:RemoveKey(plate)
end

return vehiclekeys