local vehiclekeys = {}

-- Client give/remove are intentionally no-ops (same policy as qb / qbx).
function vehiclekeys.give(vehicle, plate)
end

function vehiclekeys.remove(vehicle, plate)
end

return vehiclekeys
