local bossmenu = {}

function bossmenu.openBossMenu(src, jobName, jobType)
    TriggerClientEvent('Newb_Bridge:client:openBossMenu:codem', src, jobName, jobType)
end

return bossmenu
