local notifications = {}

function notifications.notify(data)
    if not data then return end
    exports['brutal_notify']:SendAlert(data.title or bridge.locale('common.notification'), data.description or "", data.duration or 3000, data.type or "success", false)
end

return notifications
