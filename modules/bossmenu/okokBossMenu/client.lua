-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:okok', function(jobName, jobType)
    if source ~= 65535 then return end
    TriggerEvent('okokBossMenu:openBossMenu')
end)

return bossmenu
