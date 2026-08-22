local bossmenu = {}

function bossmenu.openBossMenu(src, jobName, jobType)
    TriggerClientEvent('Newb_Bridge:client:openBossMenu:qbx', src, jobName, jobType)
end

return bossmenu
