-- Left/right objective card (ox_lib-themed). Scripts drive the data; players can
-- collapse it with a keybind without ending the task. When every tracked row hits
-- its max, the HUD flips to a 30s "task complete" bar, then clears itself.
--
-- `type` switches the NUI style on demand:
--   dense  — current-style plate for large / multi-row contracts (default)
--   weight — quiet long-lived step (scrim + weight hierarchy)
--   gather — one-line rest; H first settles detail rows, H again hides the HUD

---@class BridgeTaskItem
---@field id? string
---@field label string
---@field current? number
---@field max? number
---@field value? string Preformatted progress (e.g. `5/10`). Wins over current/max.

---@class BridgeTaskPayload
---@field title string
---@field description? string
---@field tasks? BridgeTaskItem[]
---@field position? 'left'|'right'
---@field type? 'dense'|'weight'|'gather'
---@field expanded? boolean Gather only: show detail rows (default true).

---@class BridgeTask
local Task = {}

local toggleCommand = 'newbs_toggle_task_hud'
local completeMs = 30000

local active ---@type BridgeTaskPayload|nil
local shown = false
local completing = false
local completeToken = 0

local function formatProgress(current, max)
    if current and max then
        return ('%s/%s'):format(current, max)
    end

    if current then
        return tostring(current)
    end
end

local function normalizeRow(entry)
    if type(entry) ~= 'table' or type(entry.label) ~= 'string' or entry.label == '' then
        return
    end

    local current = tonumber(entry.current)
    local max = tonumber(entry.max)
    if current then current = math.floor(current) end
    if max then max = math.floor(max) end

    local value = type(entry.value) == 'string' and entry.value ~= '' and entry.value or formatProgress(current, max)

    return {
        id = type(entry.id) == 'string' and entry.id or nil,
        label = entry.label,
        current = current,
        max = max,
        value = value,
    }
end

local function normalizeTasks(list)
    if type(list) ~= 'table' then return {} end

    local out = {}
    for i = 1, #list do
        local row = normalizeRow(list[i])
        if row then
            out[#out + 1] = row
        end
    end
    return out
end

local function normalizeHudType(value, fallbackType)
    local candidate = type(value) == 'string' and value:lower() or fallbackType
    if candidate == 'weight' or candidate == 'gather' or candidate == 'dense' then
        return candidate
    end
    return 'dense'
end

local function normalize(data, fallback)
    if type(data) ~= 'table' then return end

    local title = type(data.title) == 'string' and data.title ~= '' and data.title
        or (fallback and fallback.title)
    if not title then return end

    local hudType = normalizeHudType(data.type, fallback and fallback.type)
    local expanded = data.expanded
    if expanded == nil and fallback then
        expanded = fallback.expanded
    end
    if expanded == nil then
        expanded = true
    end

    return {
        title = title,
        description = type(data.description) == 'string' and data.description
            or (fallback and fallback.description)
            or '',
        position = (data.position or (fallback and fallback.position)) == 'right' and 'right' or 'left',
        type = hudType,
        expanded = expanded == true,
        tasks = data.tasks ~= nil and normalizeTasks(data.tasks) or (fallback and fallback.tasks) or {},
    }
end

-- true when at least one row has a max and every such row is filled
local function allTasksMaxed(payload)
    if not payload or type(payload.tasks) ~= 'table' then return false end

    local tracked = 0
    for i = 1, #payload.tasks do
        local row = payload.tasks[i]
        if row.max then
            tracked = tracked + 1
            if not row.current or row.current < row.max then
                return false
            end
        end
    end

    return tracked > 0
end

local function toggleKey()
    return exports[cache.resource]:GetBoundKey(toggleCommand) or 'H'
end

local function push(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function decorate(payload)
    local key = toggleKey()

    return {
        title = payload.title,
        description = payload.description,
        position = payload.position,
        type = payload.type or 'dense',
        expanded = payload.expanded ~= false,
        tasks = payload.tasks,
        hideKey = key,
        hideLabel = bridge.locale('task_hud.hide') or 'Hide',
        complete = false,
    }
end

local function bumpCompleteToken()
    completeToken = completeToken + 1
    return completeToken
end

local function clearCompleteState()
    bumpCompleteToken()
    completing = false
end

local function unpaint()
    push('taskHud:hide')
    shown = false
end

local function paint()
    if not active then return end
    push('taskHud:show', decorate(active))
    shown = true
end

local function beginComplete()
    if completing or not active then return end

    completing = true
    local token = bumpCompleteToken()
    local key = toggleKey()

    push('taskHud:complete', {
        title = bridge.locale('task_hud.complete') or 'Task complete',
        description = active.description or '',
        position = active.position or 'left',
        type = active.type or 'dense',
        expanded = true,
        durationMs = completeMs,
        hideKey = key,
        hideLabel = bridge.locale('task_hud.hide') or 'Hide',
        complete = true,
    })
    shown = true

    SetTimeout(completeMs, function()
        if token ~= completeToken then return end
        Task.complete()
    end)
end

local function maybeComplete()
    if completing or not active then return end
    if allTasksMaxed(active) then
        beginComplete()
    end
end

---@param data BridgeTaskPayload
function Task.show(data)
    local payload = normalize(data)
    if not payload then return end

    clearCompleteState()
    active = payload
    paint()
    maybeComplete()
end

-- patches the current task, opening a new one if nothing is active yet
---@param data BridgeTaskPayload|table
function Task.update(data)
    if completing then return end

    if not active then
        Task.show(data)
        return
    end

    local payload = normalize(data, active)
    if not payload then return end

    active = payload
    if shown then
        push('taskHud:update', decorate(active))
    end
    maybeComplete()
end

function Task.hide()
    clearCompleteState()
    active = nil
    unpaint()
end

-- finishes and closes immediately, skipping the 30s complete bar
function Task.complete()
    Task.hide()
end

-- collapse or restore; while completing it dismisses the task entirely.
-- on gather, the first press settles detail rows and the second hides the HUD
function Task.toggle()
    if completing then
        Task.complete()
        return
    end

    if not active then return end

    if shown and active.type == 'gather' and active.expanded then
        active.expanded = false
        push('taskHud:update', decorate(active))
        return
    end

    if shown then
        push('taskHud:collapse')
        shown = false
    else
        if active.type == 'gather' then
            active.expanded = true
        end
        paint()
    end
end

function Task.isOpen()
    return shown
end

function Task.hasTask()
    return active ~= nil
end

function Task.isCompleting()
    return completing
end

function Task.get()
    return active
end

RegisterCommand(toggleCommand, function()
    Task.toggle()
end, false)

RegisterKeyMapping(
    toggleCommand,
    bridge.locale('task_hud.toggle') or 'Toggle task HUD',
    'keyboard',
    'H'
)

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then return end
    clearCompleteState()
    if shown then unpaint() end
    active = nil
    shown = false
end)

exports('Task', function()
    return Task
end)

exports('CompleteTask', function()
    Task.complete()
end)

bridge.task = Task
