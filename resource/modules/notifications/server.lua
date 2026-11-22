-- Default server module for every notification provider.
-- Notifications render client-side, so the server just relays to the player.

local notifications = {}

function notifications.notify(src, data)
    if not data then return end
    TriggerClientEvent('Newb_Bridge:client:notificationSent', src, data)
end

return notifications
