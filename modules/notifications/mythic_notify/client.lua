local notifications = {}

function notifications.notify(data)
    if not data then return end
    return exports['mythic_notify']:SendAlert(data.type or "inform", data.description or "", data.duration or 3000, data.title or bridge.locale('common.notification'))
end

return notifications
