local vehiclekeys = {}

local ak47 = exports['ak47_vehiclekeys']

function vehiclekeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    ak47:GiveKey(plate, false)
end

function vehiclekeys.remove(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    ak47:RemoveKey(plate, false)
end

return vehiclekeys
