local vehiclekeys = {}

-- qb-vehiclekeys exposes no client give/remove; the server module holds the real
-- implementation, so these stay no-ops rather than pretending to succeed.
function vehiclekeys.give()
    lib.print.warn('qb-vehiclekeys has no client key exports; use the server module instead.')
end

function vehiclekeys.remove()
    lib.print.warn('qb-vehiclekeys has no client key exports; use the server module instead.')
end

return vehiclekeys
