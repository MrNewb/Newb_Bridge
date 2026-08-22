local progressbar = {}

local lation = exports.lation_ui

local function normalizeVector(vec)
    if not vec then return nil end

    if vec.x and vec.y and vec.z then
        return { x = vec.x, y = vec.y, z = vec.z }
    end

    if vec[1] then
        return { x = vec[1], y = vec[2], z = vec[3] }
    end

    return vec
end

local function normalizeAnim(anim)
    if not anim then return nil end

    if anim.scenario then
        return {
            scenario = anim.scenario,
            playEnter = anim.playEnter,
        }
    end

    if not anim.dict or not anim.clip then
        return nil
    end

    return {
        dict = anim.dict,
        clip = anim.clip,
        flag = anim.flag,
        blendIn = anim.blendIn,
        blendOut = anim.blendOut,
        duration = anim.duration,
        playbackRate = anim.playbackRate,
        lockX = anim.lockX,
        lockY = anim.lockY,
        lockZ = anim.lockZ,
    }
end

local function normalizeProp(prop)
    if not prop then return nil end

    local item = prop[1] or prop
    if not item.model then return nil end

    return {
        model = item.model,
        bone = item.bone,
        pos = normalizeVector(item.pos),
        rot = normalizeVector(item.rot),
        rotOrder = item.rotOrder,
    }
end

local function normalizeDisable(disable)
    if not disable then return nil end

    return {
        move = disable.move,
        sprint = disable.sprint,
        car = disable.car,
        combat = disable.combat,
        mouse = disable.mouse,
    }
end

local function convertToLation(data)
    local options = {
        label = data.label,
        description = data.description,
        duration = data.duration,
        icon = data.icon,
        iconColor = data.iconColor,
        iconAnimation = data.iconAnimation,
        color = data.color,
        steps = data.steps,
        canCancel = data.canCancel,
        useWhileDead = data.useWhileDead,
        allowRagdoll = data.allowRagdoll,
        allowCuffed = data.allowCuffed,
        allowFalling = data.allowFalling,
        allowSwimming = data.allowSwimming,
    }

    local anim = normalizeAnim(data.anim)
    if anim then
        options.anim = anim
    end

    local prop = normalizeProp(data.prop)
    if prop then
        options.prop = prop
    end

    local disable = normalizeDisable(data.disable)
    if disable then
        options.disable = disable
    end

    return options
end

function progressbar.openprogressbar(data)
    if not data then return false end

    return lation:progressBar(convertToLation(data))
end

function progressbar.progressActive()
    return lation:progressActive()
end

function progressbar.cancelProgress()
    lation:cancelProgress()
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
