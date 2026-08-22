local bossmenu = {}

function bossmenu.openBossMenu(src, jobName, jobType)
    TriggerClientEvent('Newb_Bridge:client:openBossMenu:m', src, jobName, jobType)
end

return bossmenu
