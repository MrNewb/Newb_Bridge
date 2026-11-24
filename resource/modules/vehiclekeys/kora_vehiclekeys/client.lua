local vehiclekeys = {}

-- kora_vehiclekeys has no client give or remove; the server module holds the real implementation, so these stay
-- no-ops rather than pretending to succeed.
function vehiclekeys.give()
    lib.print.warn('kora_vehiclekeys has no client key exports; use the server module instead.')
end

function vehiclekeys.remove()
    lib.print.warn('kora_vehiclekeys has no client key exports; use the server module instead.')
end

return vehiclekeys
