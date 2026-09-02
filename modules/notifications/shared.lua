-- Shared notifications glue loaded before every provider module.
-- The bridge host relays server-sent notifications to the active provider,
-- so provider client files only need to implement `notifications.notify`.

if bridge.context == 'client' and bridge.isHost then
    RegisterNetEvent('Newb_Bridge:client:notify', function(data)
        if source ~= 65535 then return end
        bridge.notifications.notify(data)
    end)

    local notifyProvider = (Config.Providers and Config.Providers.notifications) or Config.Notifications
    if notifyProvider ~= 'internal' then
        RegisterNUICallback('notify:ready', function(_, cb)
            cb({ ok = true })
        end)
    end
end
