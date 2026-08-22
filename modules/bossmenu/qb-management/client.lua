-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:qb', function(jobName, jobType)
    if source ~= 65535 then return end
    TriggerEvent('qb-bossmenu:client:OpenMenu')
end)

return bossmenu
