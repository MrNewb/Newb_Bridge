local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    TriggerEvent('okokGarage:GiveKeys', plate, src)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    TriggerEvent('okokGarage:RemoveKeys', plate, src)
end

return vehiclekeys
