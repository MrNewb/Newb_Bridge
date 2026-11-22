local notifications = {}

function notifications.notify(data)
    if not data then return end

    TriggerEvent(
        "codem-notification:Create",
        data.description or "",
        data.type or "inform",
        nil,
        data.duration or 5000
    )
end

return notifications
