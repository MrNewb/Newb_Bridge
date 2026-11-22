-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

local function handleBossMenuOpened(jobName, jobType)
    if source ~= 65535 then return end
    ExecuteCommand('bossmenu')
end

RegisterNetEvent('Newb_Bridge:client:bossMenuOpened', handleBossMenuOpened)
RegisterNetEvent('Newb_Bridge:client:openBossMenu:codem', handleBossMenuOpened) -- deprecated 2026-12-17: use Newb_Bridge:client:bossMenuOpened

return bossmenu
