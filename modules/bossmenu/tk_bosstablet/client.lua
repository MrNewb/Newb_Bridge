-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

RegisterNetEvent('Newb_Bridge:client:openBossMenu:tk', function(jobName, jobType)
    if source ~= 65535 then return end
    exports.tk_bosstablet:openBossMenu()
end)

return bossmenu
