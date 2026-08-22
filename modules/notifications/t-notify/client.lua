local notifications = {}

function notifications.notify(data)
    if not data then return end
    exports['t-notify']:Alert({
        title = data.title or bridge.locale('common.notification'),
        style = data.type or "inform",
        message = data.description or "",
        duration = data.duration or 3000
    })
end

return notifications
