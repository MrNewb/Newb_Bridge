local notifications = {}

function notifications.notify(data)
    if not data then return end
    -- FL-Notify themes: 1=Error, 2=Success, 3=Info, 4=Person, 5=Police, 6=Money, 8=Custom
    local typeMap = {
        ["error"] = 1,
        ["success"] = 2,
        ["inform"] = 3,
        ["info"] = 3,
        ["warning"] = 3,
    }
    local notifyType = typeMap[data.type or "inform"] or 3
    return exports['FL-Notify']:Notify(data.title or bridge.locale('common.notification'), "", data.description or "", data.duration or 3000, notifyType, 0)
end

return notifications
