local vehiclekeys = {}

local orKeys = exports['0r-vehiclekeys']

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    orKeys:GiveKeys(plate)
end

function vehiclekeys.remove(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    orKeys:RemoveKeys(plate)
end

return vehiclekeys
