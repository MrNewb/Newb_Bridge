local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    TriggerEvent("cd_garage:AddKeys", plate)
end

function vehiclekeys.remove(vehicle, plate)
    error("cd_garage does not support removing keys")
end

return vehiclekeys