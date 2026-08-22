-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:zat', function(jobName, jobType)
    if source ~= 65535 then return end
    exports['zat-bossmenu']:OpenBossMenu(jobType or jobName)
end)

return bossmenu
