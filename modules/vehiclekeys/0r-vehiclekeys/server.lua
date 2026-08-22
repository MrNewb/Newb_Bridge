local vehiclekeys = {}

local orKeys = exports['0r-vehiclekeys']

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    orKeys:GiveKeys(src, plate)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    orKeys:RemoveKeys(src, plate)
end

return vehiclekeys
