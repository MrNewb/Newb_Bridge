local vehiclekeys = {}

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    return exports.MrNewbVehicleKeys:GiveKeysByPlate(plate)

end

function vehiclekeys.remove(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end
    exports.MrNewbVehicleKeys:RemoveKeysByPlate(plate)
end

return vehiclekeys