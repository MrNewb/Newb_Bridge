local bossmenu = {}

function bossmenu.openBossMenu(src, jobName, jobType)
    TriggerClientEvent('Newb_Bridge:client:bossMenuOpened', src, jobName, jobType)
end

return bossmenu
