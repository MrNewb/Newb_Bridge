-- Shared notifications glue loaded before every provider module.
-- The bridge host relays server-sent notifications to the active provider,
-- so provider client files only need to implement `notifications.notify`.

if bridge.context == 'client' and bridge.isHost then
    RegisterNetEvent('Newb_Bridge:client:notify', function(data)
        if source ~= 65535 then return end
        bridge.notifications.notify(data)
    end)
end
