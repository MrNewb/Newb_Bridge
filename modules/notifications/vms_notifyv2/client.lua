local notifications = {}

function notifications.notify(data)
    if not data then return end

    exports.vms_notifyv2:Notification({
        title = data.title or bridge.locale('common.notification'),
        description = data.description or "",
        type = data.type or "inform",
        time = data.duration or 3000,
    })
end

return notifications
