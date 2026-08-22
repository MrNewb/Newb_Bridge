-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:vms', function(jobName, jobType)
    if source ~= 65535 then return end
    if not jobName then
        lib.print.error('[bossmenu] No job found for the player')
        return
    end

    exports['vms_bossmenu']:openBossMenu(jobName, jobType or 'job')
end)

return bossmenu
