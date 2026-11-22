-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

local function handleBossMenuOpened(jobName, jobType)
    if source ~= 65535 then return end
    exports.qbx_management:OpenBossMenu(jobType or jobName)
end

RegisterNetEvent('Newb_Bridge:client:bossMenuOpened', handleBossMenuOpened)
RegisterNetEvent('Newb_Bridge:client:openBossMenu:qbx', handleBossMenuOpened) -- deprecated 2026-12-17: use Newb_Bridge:client:bossMenuOpened

return bossmenu
