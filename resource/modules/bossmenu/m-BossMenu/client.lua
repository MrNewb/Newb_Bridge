-- Client-side handler invoked via net events from the server module.
local bossmenu = {}

local function handleBossMenuOpened(jobName, jobType)
    if source ~= 65535 then return end
    if not jobName then
        lib.print.error('[bossmenu] No job found for the player')
        return
    end

    exports['m-BossMenu']:OpenBossMenu(jobName, jobType)
end

RegisterNetEvent('Newb_Bridge:client:bossMenuOpened', handleBossMenuOpened)
RegisterNetEvent('Newb_Bridge:client:openBossMenu:m', handleBossMenuOpened) -- deprecated 2026-12-17: use Newb_Bridge:client:bossMenuOpened

return bossmenu
