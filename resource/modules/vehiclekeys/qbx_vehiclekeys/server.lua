local vehiclekeys = {}

function vehiclekeys.give(src, vehicle, plate)
    exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
end

function vehiclekeys.remove(src, vehicle, plate)
    exports.qbx_vehiclekeys:RemoveKeys(src, vehicle)
end

return vehiclekeys
