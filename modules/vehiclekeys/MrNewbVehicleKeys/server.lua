local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.MrNewbVehicleKeys:GiveKeysByPlate(src, plate)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.MrNewbVehicleKeys:RemoveKeysByPlate(src, plate)
end

return vehiclekeys
