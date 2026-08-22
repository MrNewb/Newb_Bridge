-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:esx', function(jobName, jobType)
    if source ~= 65535 then return end
    TriggerEvent('esx_society:openBossMenu', jobName)
end)

return bossmenu
