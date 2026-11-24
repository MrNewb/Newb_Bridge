local vehiclekeys = {}

-- The third argument stores the key as a hotwired one, which counts even when the server has temporary keys turned off.
function vehiclekeys.give(src, vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports.kora_vehiclekeys:giveKeys(src, plate, true)
end

function vehiclekeys.remove(src, vehicle, plate)
    plate = plate or GetVehicleNumberPlateText(vehicle)

    exports.kora_vehiclekeys:removeKeys(src, plate)
end

return vehiclekeys
