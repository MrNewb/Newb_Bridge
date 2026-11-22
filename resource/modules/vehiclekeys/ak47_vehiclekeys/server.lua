local vehiclekeys = {}

local ak47 = exports['ak47_vehiclekeys']

function vehiclekeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    ak47:GiveKey(src, plate, false)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    ak47:RemoveKey(src, plate, false)
end

return vehiclekeys
