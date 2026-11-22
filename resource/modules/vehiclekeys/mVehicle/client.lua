local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["mVehicle"]:AddTemporalVehicleClient(vehicle)
end

function vehiclekeys.remove(vehicle, plate)
    error("mVehicle does not support removing keys")
end

return vehiclekeys