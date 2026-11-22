local notifications = {}

function notifications.notify(data)
    if not data then return end
    return exports.lation_ui:notify({
        title = data.title or bridge.locale('common.notification'),
        message = data.description or "",
        type = data.type or "success",
        duration = data.duration or 3000,
        position = data.position or 'top-right'
    })
end

return notifications
