local notifications = {}

function notifications.notify(data)
    if not data then return end
    return exports['pNotify']:SendNotification({
        title = data.title or bridge.locale('common.notification'),
        text = data.description or "",
        type = data.type or "success",
        timeout = data.duration or 3000,
        layout = data.position or 'centerRight'
    })
end

return notifications
