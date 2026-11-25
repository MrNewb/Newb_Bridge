local TaskGroups = {}
local menuConfig = Config.TaskGroups

---@class TaskGroupRecord
---@field members table<number, true>
---@field order number[]
---@field leader number|nil
---@field name string
---@field maxPlayers number
---@field joinCode string|nil
---@field public boolean
---@field banned table<number, true>

local groups = {} ---@type table<string, TaskGroupRecord>
local playerGroups = {} ---@type table<number, table<string, true>>
local joinCodeIndex = {} ---@type table<string, string>

local function normalizeGroupId(groupId)
    if groupId == nil then return end
    groupId = tostring(groupId)
    if groupId == '' then return end
    return groupId
end

local function normalizeSource(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    return src
end


local function appendOrder(order, src)
    for i = 1, #order do
        if order[i] == src then return end
    end

    order[#order + 1] = src
end

local function removeFromOrder(order, src)
    for i = #order, 1, -1 do
        if order[i] == src then
            table.remove(order, i)
            return
        end
    end
end

local function pickNextLeader(data, excludingSrc)
    for i = 1, #data.order do
        local candidate = data.order[i]
        if candidate ~= excludingSrc and data.members[candidate] then
            return candidate
        end
    end
end

local function getPlayerDisplayName(src)
    if bridge.framework and bridge.framework.getIdentifier then
        local identifier = bridge.framework.getIdentifier(src)
        if identifier and bridge.framework.getCharacterName then
            local fullName = select(1, bridge.framework.getCharacterName(identifier))
            if fullName and fullName ~= '' then
                return fullName
            end
        end
    end

    return GetPlayerName(src) or ('Player %s'):format(src)
end

local function normalizeJoinCode(code)
    code = tostring(code or ''):gsub('%D', '')
    local length = menuConfig.JoinCodeLength
    if #code ~= length then return end
    return code
end

local function generateJoinCode()
    local length = menuConfig.JoinCodeLength

    for _ = 1, 50 do
        local digits = {}
        for i = 1, length do
            digits[i] = math.random(0, 9)
        end

        local code = table.concat(digits)
        if not joinCodeIndex[code] then
            return code
        end
    end
end

local function registerJoinCode(groupId, code)
    if not code then return end
    joinCodeIndex[code] = groupId
end

local function unregisterJoinCode(data)
    if data and data.joinCode then
        joinCodeIndex[data.joinCode] = nil
    end
end

local function defaultGroupMeta()
    return {
        name = 'Task Group',
        maxPlayers = menuConfig.DefaultMaxPlayers,
        joinCode = nil,
        public = false,
        banned = {},
    }
end

local function newGroupRecord(meta)
    meta = meta or defaultGroupMeta()

    return {
        members = {},
        order = {},
        leader = nil,
        name = meta.name or 'Task Group',
        maxPlayers = meta.maxPlayers or defaultGroupMeta().maxPlayers,
        joinCode = meta.joinCode,
        public = meta.public == true,
        banned = meta.banned or {},
    }
end

local function syncPlayerState(src)
    local member = {}
    local leader = {}
    local memberships = playerGroups[src]

    if memberships then
        for groupId in pairs(memberships) do
            member[groupId] = true

            local data = groups[groupId]
            if data and data.leader == src then
                leader[groupId] = true
            end
        end
    end

    Player(src).state:set('taskGroups', {
        member = member,
        leader = leader,
    }, true)
end

local function migrateLeaderOrDelete(groupId, previousLeader)
    local data = groups[groupId]
    if not data then return end

    local nextLeader = pickNextLeader(data, previousLeader)
    if not nextLeader then
        TaskGroups.delete(groupId)
        return 'deleted'
    end

    data.leader = nextLeader
    syncPlayerState(nextLeader)
    TriggerEvent('Newb_Bridge:server:taskGroupLeaderChanged', groupId, nextLeader, previousLeader)
    return 'promoted'
end

local function removeMember(groupId, src)
    local data = groups[groupId]
    if not data or not data.members[src] then return false end

    local wasLeader = data.leader == src

    data.members[src] = nil
    removeFromOrder(data.order, src)

    if playerGroups[src] then
        playerGroups[src][groupId] = nil
        if not next(playerGroups[src]) then
            playerGroups[src] = nil
        end
    end

    syncPlayerState(src)
    TriggerEvent('Newb_Bridge:server:taskGroupMemberRemoved', groupId, src)

    if wasLeader then
        local result = migrateLeaderOrDelete(groupId, src)
        if result == 'deleted' then
            return 'deleted'
        end
        return true
    end

    if not next(data.members) then
        TaskGroups.delete(groupId)
        return 'deleted'
    end

    return true
end

function TaskGroups.create(groupId, leaderSrc)
    groupId = normalizeGroupId(groupId)
    if not groupId or groups[groupId] then return false end

    groups[groupId] = newGroupRecord()

    leaderSrc = normalizeSource(leaderSrc)
    if leaderSrc then
        TaskGroups.add(groupId, leaderSrc)
        groups[groupId].leader = leaderSrc
        syncPlayerState(leaderSrc)
    end

    TriggerEvent('Newb_Bridge:server:taskGroupCreated', groupId, leaderSrc)
    return true
end

function TaskGroups.add(groupId, src)
    groupId = normalizeGroupId(groupId)
    src = normalizeSource(src)
    if not groupId or not src then return false end

    local data = groups[groupId] or newGroupRecord()
    groups[groupId] = data

    if data.banned[src] then return false end

    local memberCount = 0
    for _ in pairs(data.members) do
        memberCount = memberCount + 1
    end

    if memberCount >= (data.maxPlayers or 4) then return false end

    if data.members[src] then return true end

    data.members[src] = true
    appendOrder(data.order, src)

    if not data.leader then
        data.leader = src
    end

    playerGroups[src] = playerGroups[src] or {}
    playerGroups[src][groupId] = true
    syncPlayerState(src)

    TriggerEvent('Newb_Bridge:server:taskGroupMemberAdded', groupId, src)
    return true
end

function TaskGroups.remove(groupId, src)
    groupId = normalizeGroupId(groupId)
    src = normalizeSource(src)
    if not groupId or not src then return false end

    local result = removeMember(groupId, src)
    return result ~= false
end

function TaskGroups.clear(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return false end

    local data = groups[groupId]
    if not data then return false end

    for src in pairs(data.members) do
        if playerGroups[src] then
            playerGroups[src][groupId] = nil
            if not next(playerGroups[src]) then
                playerGroups[src] = nil
            end
        end

        syncPlayerState(src)
    end

    data.members = {}
    data.order = {}
    data.leader = nil

    TriggerEvent('Newb_Bridge:server:taskGroupCleared', groupId)
    return true
end

function TaskGroups.delete(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return false end

    local data = groups[groupId]
    if not data then return false end

    unregisterJoinCode(data)

    for src in pairs(data.members) do
        if playerGroups[src] then
            playerGroups[src][groupId] = nil
            if not next(playerGroups[src]) then
                playerGroups[src] = nil
            end
        end

        syncPlayerState(src)
    end

    groups[groupId] = nil
    TriggerEvent('Newb_Bridge:server:taskGroupDeleted', groupId)
    return true
end

function TaskGroups.has(groupId, src)
    groupId = normalizeGroupId(groupId)
    src = normalizeSource(src)
    if not groupId or not src then return false end

    local data = groups[groupId]
    return data ~= nil and data.members[src] == true
end

function TaskGroups.isLeader(groupId, src)
    groupId = normalizeGroupId(groupId)
    src = normalizeSource(src)
    if not groupId or not src then return false end

    local data = groups[groupId]
    return data ~= nil and data.leader == src
end

function TaskGroups.getLeader(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return false end

    local data = groups[groupId]
    return data and data.leader or false
end

function TaskGroups.setLeader(groupId, src)
    groupId = normalizeGroupId(groupId)
    src = normalizeSource(src)
    if not groupId or not src then return false end

    local data = groups[groupId]
    if not data or not data.members[src] then return false end

    local previousLeader = data.leader
    if previousLeader == src then return true end

    data.leader = src

    if previousLeader then
        syncPlayerState(previousLeader)
    end

    syncPlayerState(src)
    TriggerEvent('Newb_Bridge:server:taskGroupLeaderChanged', groupId, src, previousLeader)
    return true
end

function TaskGroups.getMembers(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return {} end

    local data = groups[groupId]
    if not data then return {} end

    local list = {}
    for src in pairs(data.members) do
        list[#list + 1] = src
    end

    table.sort(list)
    return list
end

function TaskGroups.getPlayerGroups(src)
    src = normalizeSource(src)
    if not src then return {} end

    local memberships = playerGroups[src]
    if not memberships then return {} end

    local list = {}
    for groupId in pairs(memberships) do
        list[#list + 1] = groupId
    end

    table.sort(list)
    return list
end

function TaskGroups.getMemberCount(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return 0 end

    local data = groups[groupId]
    if not data then return 0 end

    local count = 0
    for _ in pairs(data.members) do
        count = count + 1
    end

    return count
end

function TaskGroups.getPrimaryGroupId(src)
    local list = TaskGroups.getPlayerGroups(src)
    return list[1]
end

function TaskGroups.buildClientGroup(groupId)
    groupId = normalizeGroupId(groupId)
    if not groupId then return end

    local data = groups[groupId]
    if not data then return end

    local players = {}

    for i = 1, #data.order do
        local memberSrc = data.order[i]
        if data.members[memberSrc] then
            players[#players + 1] = {
                serverId = memberSrc,
                name = getPlayerDisplayName(memberSrc),
                leader = data.leader == memberSrc,
            }
        end
    end

    return {
        id = groupId,
        name = data.name or groupId,
        maxPlayers = data.maxPlayers or 4,
        leader = data.leader,
        joinCode = data.joinCode,
        public = data.public == true,
        players = players,
    }
end

function TaskGroups.getBrowsableGroups()
    local list = {}

    for groupId, data in pairs(groups) do
        if data.public and next(data.members) then
            local entry = TaskGroups.buildClientGroup(groupId)
            if entry then
                list[#list + 1] = entry
            end
        end
    end

    table.sort(list, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    return list
end

function TaskGroups.createWithOptions(src, options)
    src = normalizeSource(src)
    if not src or type(options) ~= 'table' then return end

    local groupId = options.id or ('tg_%s_%s'):format(os.time(), src)
    groupId = normalizeGroupId(groupId)
    if not groupId or groups[groupId] then return end

    local maxPlayers = tonumber(options.maxPlayers) or defaultGroupMeta().maxPlayers
    local minPlayers = menuConfig.MinMaxPlayers
    local maxCap = menuConfig.MaxMaxPlayers
    maxPlayers = math.max(minPlayers, math.min(maxCap, maxPlayers))

    local joinCode = generateJoinCode()
    if not joinCode then return end

    TaskGroups.leaveAllGroups(src)

    local data = newGroupRecord({
        name = tostring(options.name or 'Task Group'):sub(1, menuConfig.MaxNameLength),
        maxPlayers = maxPlayers,
        joinCode = joinCode,
        public = options.public == true,
    })

    groups[groupId] = data
    registerJoinCode(groupId, joinCode)

    TaskGroups.add(groupId, src)
    data.leader = src
    syncPlayerState(src)

    TriggerEvent('Newb_Bridge:server:taskGroupCreated', groupId, src)
    return groupId
end

---Whether src could be added to the group right now (exists, not banned, has room, or already a member).
---Checked before leaving the current group so a failed join never strands the player.
local function canJoinGroup(groupId, src)
    local data = groups[groupId]
    if not data then return false, 'group_not_found' end
    if data.banned[src] then return false, 'banned_from_group' end
    if data.members[src] then return true end

    local memberCount = 0
    for _ in pairs(data.members) do
        memberCount = memberCount + 1
    end

    if memberCount >= (data.maxPlayers or 4) then return false, 'group_full' end
    return true
end

function TaskGroups.leaveAllGroups(src)
    src = normalizeSource(src)
    if not src then return end

    local groupIds = TaskGroups.getPlayerGroups(src)
    for i = 1, #groupIds do
        removeMember(groupIds[i], src)
    end
end

function TaskGroups.joinByCode(src, code)
    src = normalizeSource(src)
    code = normalizeJoinCode(code)
    if not src or not code then return false, nil, 'invalid_join_code' end

    local groupId = joinCodeIndex[code]
    if not groupId then return false, nil, 'group_not_found' end

    local data = groups[groupId]
    if not data then return false, nil, 'group_not_found' end

    local canJoin, reason = canJoinGroup(groupId, src)
    if not canJoin then return false, nil, reason end

    if not data.members[src] then
        TaskGroups.leaveAllGroups(src)
        if not TaskGroups.add(groupId, src) then
            return false, nil, 'group_full'
        end
    end

    return true, groupId
end

function TaskGroups.kickMember(groupId, actor, target)
    groupId = normalizeGroupId(groupId)
    actor = normalizeSource(actor)
    target = normalizeSource(target)
    if not groupId or not actor or not target then return false end

    if not TaskGroups.isLeader(groupId, actor) then return false end
    if actor == target then return false end

    return removeMember(groupId, target) ~= false
end

function TaskGroups.disband(groupId, actor)
    groupId = normalizeGroupId(groupId)
    actor = normalizeSource(actor)
    if not groupId or not actor then return false end
    if not TaskGroups.isLeader(groupId, actor) then return false end

    return TaskGroups.delete(groupId)
end

local function leaveAllGroups(src)
    local memberships = playerGroups[src]
    if not memberships then return end

    local groupIds = {}
    for groupId in pairs(memberships) do
        groupIds[#groupIds + 1] = groupId
    end

    for i = 1, #groupIds do
        removeMember(groupIds[i], src)
    end
end

AddEventHandler('playerDropped', function()
    leaveAllGroups(source)
end)

-- a character switch keeps the same server id, so the old character's groups must not carry over to the next one
AddEventHandler('Newb_Bridge:server:playerUnloaded', function(src)
    if type(src) == 'number' then leaveAllGroups(src) end
end)

local function callerExists(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and DoesEntityExist(ped)
end

lib.callback.register('Newb_Bridge:callback:taskGroupsGetMembers', function(src, groupId)
    if not callerExists(src) then return {} end
    groupId = normalizeGroupId(groupId)
    if not groupId or not TaskGroups.has(groupId, src) then return {} end
    return TaskGroups.getMembers(groupId)
end)

lib.callback.register('Newb_Bridge:callback:taskGroupsGetLeader', function(src, groupId)
    if not callerExists(src) then return false end
    groupId = normalizeGroupId(groupId)
    if not groupId or not TaskGroups.has(groupId, src) then return false end
    return TaskGroups.getLeader(groupId) or false
end)

exports('CreateTaskGroup', TaskGroups.create)
exports('AddToTaskGroup', TaskGroups.add)
exports('RemoveFromTaskGroup', TaskGroups.remove)
exports('ClearTaskGroup', TaskGroups.clear)
exports('DeleteTaskGroup', TaskGroups.delete)
exports('IsInTaskGroup', TaskGroups.has)
exports('IsTaskGroupLeader', TaskGroups.isLeader)
exports('GetTaskGroupLeader', TaskGroups.getLeader)
exports('SetTaskGroupLeader', TaskGroups.setLeader)
exports('GetTaskGroupMembers', TaskGroups.getMembers)
exports('GetPlayerTaskGroups', TaskGroups.getPlayerGroups)
exports('GetTaskGroupMemberCount', TaskGroups.getMemberCount)
exports('TaskGroups', function()
    return TaskGroups
end)

bridge.taskGroups = TaskGroups

local menuOpen = {} ---@type table<number, true>
local joinCodeAttempts = {} ---@type table<number, { count: number, resetAt: number }>

local function consumeJoinCodeAttempt(src)
    local now = GetGameTimer()
    local entry = joinCodeAttempts[src]
    if not entry or now >= entry.resetAt then
        joinCodeAttempts[src] = { count = 1, resetAt = now + 60000 }
        return true
    end
    if entry.count >= 5 then return false end
    entry.count = entry.count + 1
    return true
end

local function menuLocales()
    return {
        menuBrand = bridge.locale('task_group_ui.menu_brand'),
        menuTitle = bridge.locale('task_group_ui.menu_title'),
        close = bridge.locale('task_group_ui.close'),
        tabBrowse = bridge.locale('task_group_ui.tab_browse'),
        tabCreate = bridge.locale('task_group_ui.tab_create'),
        tabManage = bridge.locale('task_group_ui.tab_manage'),
        joinWithCode = bridge.locale('task_group_ui.join_with_code'),
        joinCodeHint = bridge.locale('task_group_ui.join_code_hint'),
        noPublicGroups = bridge.locale('task_group_ui.no_public_groups'),
        join = bridge.locale('task_group_ui.join'),
        createTitle = bridge.locale('task_group_ui.create_title'),
        createHint = bridge.locale('task_group_ui.create_hint'),
        groupName = bridge.locale('task_group_ui.group_name'),
        groupNamePlaceholder = bridge.locale('task_group_ui.group_name_placeholder'),
        maxPlayers = bridge.locale('task_group_ui.max_players'),
        publicGroup = bridge.locale('task_group_ui.public_group'),
        createGroup = bridge.locale('task_group_ui.create_group'),
        copyJoinCode = bridge.locale('task_group_ui.copy_join_code'),
        kick = bridge.locale('task_group_ui.kick'),
        disbandGroup = bridge.locale('task_group_ui.disband_group'),
        leaveGroup = bridge.locale('task_group_ui.leave_group'),
        inviteNearby = bridge.locale('task_group_ui.invite_nearby'),
        leader = bridge.locale('task_group_ui.leader'),
        you = bridge.locale('task_group_ui.you'),
        memberCount = bridge.locale('task_group_ui.member_count'),
        joinCodeCopyFailed = bridge.locale('task_group_ui.join_code_copy_failed'),
    }
end

local function messageKey(key)
    return bridge.locale(('task_group_ui.errors.%s'):format(key))
end

local function successPayload(groupId)
    local group = groupId and TaskGroups.buildClientGroup(groupId) or nil
    return {
        success = true,
        myGroup = group,
        groups = TaskGroups.getBrowsableGroups(),
    }
end

local function getMenuPayload(src)
    local groupId = TaskGroups.getPrimaryGroupId(src)

    return {
        groups = TaskGroups.getBrowsableGroups(),
        myGroup = groupId and TaskGroups.buildClientGroup(groupId) or nil,
        config = {
            defaultMaxPlayers = menuConfig.DefaultMaxPlayers,
            maxMaxPlayers = menuConfig.MaxMaxPlayers,
            minMaxPlayers = menuConfig.MinMaxPlayers,
            joinCodeLength = menuConfig.JoinCodeLength,
            maxNameLength = menuConfig.MaxNameLength,
            inviteRadius = menuConfig.InviteRadius,
        },
        locales = menuLocales(),
        myServerId = src,
    }
end

local function pushMenuRefresh(src)
    if not menuOpen[src] then return end

    local groupId = TaskGroups.getPrimaryGroupId(src)

    TriggerClientEvent('Newb_Bridge:client:taskGroupMenuRefreshed', src, {
        groups = TaskGroups.getBrowsableGroups(),
        myGroup = groupId and TaskGroups.buildClientGroup(groupId) or nil,
    })
end

AddEventHandler('Newb_Bridge:server:taskGroupMemberAdded', function(_, memberSrc)
    pushMenuRefresh(memberSrc)
end)

AddEventHandler('Newb_Bridge:server:taskGroupMemberRemoved', function(_, memberSrc)
    pushMenuRefresh(memberSrc)
end)

AddEventHandler('Newb_Bridge:server:taskGroupLeaderChanged', function(_, newLeader, previousLeader)
    pushMenuRefresh(newLeader)
    if previousLeader then pushMenuRefresh(previousLeader) end
end)

AddEventHandler('Newb_Bridge:server:taskGroupDeleted', function()
    for src in pairs(menuOpen) do
        pushMenuRefresh(src)
    end
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuGetData', function(src)
    if not callerExists(src) then return false end
    return getMenuPayload(src)
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuFilterInviteCandidates', function(src, serverIds)
    if not callerExists(src) then return {} end
    if type(serverIds) ~= 'table' then return {} end

    local groupId = TaskGroups.getPrimaryGroupId(src)
    if not groupId or not TaskGroups.isLeader(groupId, src) then return {} end

    local allowed = {}
    for i = 1, math.min(#serverIds, 64) do
        local target = tonumber(serverIds[i])
        if target and target ~= src and not TaskGroups.getPrimaryGroupId(target) then
            allowed[#allowed + 1] = target
        end
    end

    return allowed
end)

local function handleTaskGroupMenuOpenChanged(open)
    local src = source
    if not callerExists(src) then return end
    menuOpen[src] = (open == true) or nil
end

RegisterNetEvent('Newb_Bridge:server:taskGroupMenuOpenChanged', handleTaskGroupMenuOpenChanged)
RegisterNetEvent('Newb_Bridge:server:taskGroupMenu:setOpen', handleTaskGroupMenuOpenChanged) -- deprecated 2026-12-17: use Newb_Bridge:server:taskGroupMenuOpenChanged

AddEventHandler('playerDropped', function()
    menuOpen[source] = nil
    joinCodeAttempts[source] = nil
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuCreateGroup', function(src, data)
    if not callerExists(src) then return { success = false } end
    if type(data) ~= 'table' then
        return { success = false, message = messageKey('invalid_name') }
    end

    local name = tostring(data.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then
        return { success = false, message = messageKey('invalid_name') }
    end

    local groupId = TaskGroups.createWithOptions(src, {
        name = name,
        maxPlayers = data.maxplayers or data.maxPlayers,
        public = data.public == true,
    })

    if not groupId then
        return { success = false, message = messageKey('create_failed') }
    end

    local payload = successPayload(groupId)
    payload.message = bridge.locale('task_group_ui.created')
    return payload
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuJoinByCode', function(src, data)
    if not callerExists(src) then return { success = false } end
    if not consumeJoinCodeAttempt(src) then
        return { success = false, message = messageKey('invalid_join_code') }
    end
    if type(data) ~= 'table' then
        return { success = false, message = messageKey('invalid_join_code') }
    end

    local ok, groupId, errKey = TaskGroups.joinByCode(src, data.joinCode)
    if not ok then
        return { success = false, message = messageKey(errKey or 'group_not_found') }
    end

    local payload = successPayload(groupId)
    payload.message = bridge.locale('task_group_ui.joined')
    return payload
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuJoinGroup', function(src, data)
    if not callerExists(src) then return { success = false } end
    if type(data) ~= 'table' then
        return { success = false, message = messageKey('group_not_found') }
    end

    local groupId = tostring(data.groupId or ''):sub(1, 128)
    local group = groupId ~= '' and TaskGroups.buildClientGroup(groupId) or nil
    if not group or not group.public then
        return { success = false, message = messageKey('group_not_found') }
    end

    local canJoin, reason = canJoinGroup(groupId, src)
    if not canJoin then
        return { success = false, message = messageKey(reason == 'group_full' and 'group_full' or 'group_not_found') }
    end

    if not TaskGroups.has(groupId, src) then
        TaskGroups.leaveAllGroups(src)

        if not TaskGroups.add(groupId, src) then
            return { success = false, message = messageKey('group_full') }
        end
    end

    local payload = successPayload(groupId)
    payload.message = bridge.locale('task_group_ui.joined')
    return payload
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuLeaveGroup', function(src)
    if not callerExists(src) then return { success = false } end
    local groupId = TaskGroups.getPrimaryGroupId(src)
    if not groupId then
        return { success = false, message = messageKey('not_in_group') }
    end

    TaskGroups.remove(groupId, src)

    return {
        success = true,
        message = bridge.locale('task_group_ui.left'),
        myGroup = nil,
        groups = TaskGroups.getBrowsableGroups(),
    }
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuKickMember', function(src, data)
    if not callerExists(src) then return { success = false } end
    local groupId = TaskGroups.getPrimaryGroupId(src)
    local target = type(data) == 'table' and tonumber(data.targetId) or nil

    if not groupId or not target then
        return { success = false, message = messageKey('invalid_target') }
    end

    if not TaskGroups.kickMember(groupId, src, target) then
        return { success = false, message = messageKey('kick_failed') }
    end

    local payload = successPayload(groupId)
    payload.message = bridge.locale('task_group_ui.kicked')
    return payload
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuDisbandGroup', function(src)
    if not callerExists(src) then return { success = false } end
    local groupId = TaskGroups.getPrimaryGroupId(src)
    if not groupId then
        return { success = false, message = messageKey('not_in_group') }
    end

    if not TaskGroups.disband(groupId, src) then
        return { success = false, message = messageKey('disband_failed') }
    end

    return {
        success = true,
        message = bridge.locale('task_group_ui.disbanded'),
        myGroup = nil,
        groups = TaskGroups.getBrowsableGroups(),
    }
end)

lib.callback.register('Newb_Bridge:callback:taskGroupMenuInviteMember', function(src, data)
    if not callerExists(src) then return { success = false } end
    local groupId = TaskGroups.getPrimaryGroupId(src)
    local target = type(data) == 'table' and tonumber(data.targetId) or nil

    if not groupId or not target then
        return { success = false, message = messageKey('invalid_target') }
    end

    if not TaskGroups.isLeader(groupId, src) then
        return { success = false, message = messageKey('not_leader') }
    end

    local targetPed = GetPlayerPed(target)
    if targetPed == 0 or not DoesEntityExist(targetPed) then
        return { success = false, message = messageKey('invalid_target') }
    end

    local radius = menuConfig.InviteRadius
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(targetPed)) > radius then
        return { success = false, message = messageKey('invalid_target') }
    end

    if TaskGroups.getPrimaryGroupId(target) then
        return { success = false, message = messageKey('target_in_group') }
    end

    if not TaskGroups.add(groupId, target) then
        return { success = false, message = messageKey('group_full') }
    end

    local payload = successPayload(groupId)
    payload.message = bridge.locale('task_group_ui.invited')
    return payload
end)

exports('OpenTaskGroupMenu', function(target)
    target = tonumber(target)
    if not target then return end

    TriggerClientEvent('Newb_Bridge:client:taskGroupMenuOpened', target)
end)
