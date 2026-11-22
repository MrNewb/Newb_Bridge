local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["mVehicle"].AddTemporalVehicle(src, vehicle)
end

function vehiclekeys.remove(src, vehicle, plate)
    error("mVehicle does not support removing keys")
end

return vehiclekeys