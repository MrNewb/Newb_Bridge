local notifications = {}

local defaultDuration = 3000
local nuiReady = false
local pending = {}

local positions = {
    top = true,
    ['top-right'] = true,
    ['top-left'] = true,
    bottom = true,
    ['bottom-right'] = true,
    ['bottom-left'] = true,
    ['center-right'] = true,
    ['center-left'] = true,
}

local types = {
    inform = true,
    info = true,
    success = true,
    error = true,
    warning = true,
}

local animations = {
    spin = true,
    spinPulse = true,
    spinReverse = true,
    pulse = true,
    beat = true,
    fade = true,
    beatFade = true,
    bounce = true,
    shake = true,
}

local function coerceNotifyText(value)
    if type(value) == 'string' then return value end
    if type(value) == 'number' then return tostring(value) end
    if type(value) ~= 'table' then return end

    local parts = {}
    for index = 1, #value do
        local line = value[index]
        if type(line) == 'string' then
            parts[#parts + 1] = line
        elseif type(line) == 'number' then
            parts[#parts + 1] = tostring(line)
        end
    end
    if #parts == 0 then return end
    return table.concat(parts, '\n')
end

local function playNotifySound(sound)
    if type(sound) ~= 'table' then return end
    local name = sound.name
    if type(name) ~= 'string' or name == '' then return end
    local set = type(sound.set) == 'string' and sound.set or 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    local bank = type(sound.bank) == 'string' and sound.bank ~= '' and sound.bank or nil

    CreateThread(function()
        if bank then
            lib.waitFor(function()
                if RequestScriptAudioBank(bank, false) then
                    return true
                end
            end, false, 1000)
        end

        local soundId = GetSoundId()
        PlaySoundFrontend(soundId, name, set, true)
        ReleaseSoundId(soundId)

        if bank then
            ReleaseNamedScriptAudioBank(bank)
        end
    end)
end

local function flushPending()
    for index = 1, #pending do
        SendNUIMessage(pending[index])
    end
    pending = {}
end

local function sendNotifyNui(payload)
    local message = {
        type = 'notify:show',
        data = payload,
    }
    if nuiReady then
        SendNUIMessage(message)
        return
    end
    if #pending >= 20 then
        table.remove(pending, 1)
    end
    pending[#pending + 1] = message
end

function notifications.notify(data, extra)
    if extra ~= nil and type(data) == 'table' and data.title == nil and data.description == nil and data.message == nil then
        data = extra
    end
    if not data then return end

    if not bridge.isHost then
        return exports[bridge.name]:Notify(data)
    end

    local payload
    if type(data) == 'string' or type(data) == 'number' then
        payload = { description = tostring(data) }
    elseif type(data) == 'table' then
        payload = table.clone(data)
    else
        return
    end

    payload.title = coerceNotifyText(payload.title)
    payload.description = coerceNotifyText(payload.description) or coerceNotifyText(payload.message)
    if (not payload.title or payload.title == '') and (not payload.description or payload.description == '') then
        return
    end

    local notifyType = payload.type or 'inform'
    if notifyType == 'info' then notifyType = 'inform' end
    if not types[notifyType] then notifyType = 'inform' end
    payload.type = notifyType
    payload.duration = tonumber(payload.duration) or defaultDuration
    if payload.position and not positions[payload.position] then
        payload.position = 'top-right'
    end
    if payload.alignIcon ~= 'top' then
        payload.alignIcon = 'center'
    end
    if payload.iconAnimation and not animations[payload.iconAnimation] then
        payload.iconAnimation = nil
    end
    if payload.id ~= nil then
        payload.id = tostring(payload.id)
        if payload.id == '' then payload.id = nil end
    end
    if type(payload.image) == 'string' then
        payload.image = payload.image:match('^%s*(.-)%s*$')
        if payload.image == '' then payload.image = nil end
    else
        payload.image = nil
    end
    if payload.showDuration == nil then
        payload.showDuration = true
    end

    playNotifySound(payload.sound)
    payload.sound = nil
    sendNotifyNui(payload)
end

if bridge.isHost then
    exports('Notify', notifications.notify)

    RegisterNUICallback('notify:ready', function(_, cb)
        nuiReady = true
        flushPending()
        cb({ ok = true })
    end)
end

return notifications
