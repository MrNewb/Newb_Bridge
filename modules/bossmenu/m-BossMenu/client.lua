-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:m', function(jobName, jobType)
    if source ~= 65535 then return end
    if not jobName then
        lib.print.error('[bossmenu] No job found for the player')
        return
    end

    exports['m-BossMenu']:OpenBossMenu(jobName, jobType)
end)

return bossmenu
