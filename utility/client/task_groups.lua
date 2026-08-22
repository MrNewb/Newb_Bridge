-- Client-side task group membership (reads replicated `Player.state.taskGroups`).

local TaskGroups = {}
local menuConfig = Config.TaskGroups

local function normalizeGroupId(groupId)
    if groupId == nil then return end
    groupId = tostring(groupId)
    if groupId == '' then return end
    return groupId
end

local function getLocalState()
    return LocalPlayer.state.taskGroups or {}
end

function TaskGroups.has(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return false end

    local member = getLocalState().member
    return member ~= nil and member[groupId] == true
end

function TaskGroups.isLeader(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return false end

    local leader = getLocalState().leader
    return leader ~= nil and leader[groupId] == true
end

function TaskGroups.getGroups()
    local list = {}
    local member = getLocalState().member

    if member then
        for groupId in pairs(member) do
            list[#list + 1] = groupId
        end
    end

    table.sort(list)
    return list
end

function TaskGroups.getMembers(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return {} end

    return lib.callback.await('Newb_Bridge:callback:taskGroupsGetMembers', false, groupId) or {}
end

function TaskGroups.getLeader(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return false end

    return lib.callback.await('Newb_Bridge:callback:taskGroupsGetLeader', false, groupId) or false
end

AddStateBagChangeHandler('taskGroups', ('player:%s'):format(cache.serverId), function(_, _, value)
    TriggerEvent('Newb_Bridge:client:taskGroupsChanged', value or {})
end)

exports('IsInTaskGroup', TaskGroups.has)
exports('IsTaskGroupLeader', TaskGroups.isLeader)
exports('GetLocalTaskGroups', TaskGroups.getGroups)
exports('GetTaskGroupMembers', TaskGroups.getMembers)
exports('GetTaskGroupLeader', TaskGroups.getLeader)
exports('TaskGroups', function()
    return TaskGroups
end)

bridge.taskGroups = TaskGroups

-- Task group menu

local menuOpen = false

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    TriggerServerEvent('Newb_Bridge:server:taskGroupMenu:setOpen', false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'taskGroupMenu:close' })
end

local function openMenu()
    if menuOpen then return end
    local data = lib.callback.await('Newb_Bridge:callback:taskGroupMenuGetData', false)
    if not data then return end
    menuOpen = true
    TriggerServerEvent('Newb_Bridge:server:taskGroupMenu:setOpen', true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'taskGroupMenu:open', data = data })
end

RegisterNetEvent('Newb_Bridge:client:openTaskGroupMenu', function()
    if source ~= 65535 then return end
    openMenu()
end)

RegisterNetEvent('Newb_Bridge:client:taskGroupMenuRefresh', function(data)
    if source ~= 65535 then return end
    if not menuOpen or not data then return end
    SendNUIMessage({ action = 'taskGroupMenu:refresh', data = data })
end)

AddEventHandler('Newb_Bridge:client:playerUnload', function()
    closeMenu()
end)

RegisterNUICallback('taskGroupMenu:close', function(_, cb)
    closeMenu()
    cb({ success = true })
end)

RegisterNUICallback('taskGroupMenu:createGroup', function(data, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuCreateGroup', false, data))
end)
RegisterNUICallback('taskGroupMenu:joinByCode', function(data, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuJoinByCode', false, data))
end)
RegisterNUICallback('taskGroupMenu:joinGroup', function(data, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuJoinGroup', false, data))
end)
RegisterNUICallback('taskGroupMenu:leaveGroup', function(_, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuLeaveGroup', false))
end)
RegisterNUICallback('taskGroupMenu:kickMember', function(data, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuKickMember', false, data))
end)
RegisterNUICallback('taskGroupMenu:disbandGroup', function(_, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuDisbandGroup', false))
end)
RegisterNUICallback('taskGroupMenu:inviteMember', function(data, cb)
    cb(lib.callback.await('Newb_Bridge:callback:taskGroupMenuInviteMember', false, data))
end)

RegisterNUICallback('taskGroupMenu:copyJoinCode', function(data, cb)
    local joinCode = type(data) == 'table' and tostring(data.joinCode or '') or ''
    if joinCode == '' then
        cb({ success = false })
        return
    end
    lib.setClipboard(joinCode)
    cb({ success = true, message = bridge.locale('task_group_ui.join_code_copied') })
end)

RegisterNUICallback('taskGroupMenu:getNearbyCandidates', function(_, cb)
    local groupId = bridge.taskGroups and bridge.taskGroups.getGroups()[1]
    if not groupId or not bridge.taskGroups.isLeader(groupId) then
        cb({ candidates = {} })
        return
    end

    local radius  = menuConfig.InviteRadius
    local nearby  = lib.getNearbyPlayers(GetEntityCoords(cache.ped), radius, true) or {}
    local serverIds = {}
    for i = 1, #nearby do
        serverIds[i] = GetPlayerServerId(nearby[i].id)
    end

    local allowed    = lib.callback.await('Newb_Bridge:callback:taskGroupMenuFilterInviteCandidates', false, serverIds) or {}
    local candidates = {}
    for i = 1, #allowed do
        local target = allowed[i]
        candidates[#candidates + 1] = {
            serverId = target,
            name     = GetPlayerName(GetPlayerFromServerId(target)) or ('Player %s'):format(target),
        }
    end

    cb({ candidates = candidates })
end)

exports('OpenTaskGroupMenu',    openMenu)
exports('CloseTaskGroupMenu',   closeMenu)
exports('IsTaskGroupMenuOpen',  function() return menuOpen end)

bridge.registerCommand('taskgroups', function()
    if menuOpen then closeMenu() else openMenu() end
end)

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then return end
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'taskGroupMenu:close' })
end)
