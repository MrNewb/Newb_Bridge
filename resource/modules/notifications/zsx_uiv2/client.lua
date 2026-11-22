local notifications = {}

function notifications.notify(data)
    if not data then return end
    exports['ZSX_UIV2']:Notification(data.title or bridge.locale('common.notification'), data.description or "", data.icon, data.duration or 3000)
end

return notifications
