local notifications = {}

function notifications.notify(data)
    if not data then return end
    exports.solaire_notify:Notify({
        type = data.type or "info",
        title = data.title or bridge.locale('common.notification'),
        message = data.description or "",
        duration = data.duration or 3000,
        position = data.position or "top-right",
        sound = data.sound,
    })
end

return notifications
