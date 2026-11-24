local progressbar = {}

local progressRunning = false

local function getDisableControls(disable)
    disable = disable or {}

    return {
        disable_mouse = disable.mouse == true,
        disable_walk = disable.move == true,
        disable_driving = disable.car == true,
        disable_combat = disable.combat == true,
    }
end

-- ZSX_UIV2 plays clips only; a scenario-only animation has no dict and clip to hand over.
local function getAnim(anim)
    if not anim or not anim.dict or not anim.clip then return end

    return {
        dict = anim.dict,
        clip = anim.clip,
        blendIn = anim.blendIn,
        blendOut = anim.blendOut,
        duration = anim.duration,
        flag = anim.flag,
        playbackRate = anim.playbackRate,
        lockX = anim.lockX,
        lockY = anim.lockY,
        lockZ = anim.lockZ,
    }
end

function progressbar.openprogressbar(data)
    if not data then return false end

    local props = data.prop or {}
    local prop1 = props[1] or data.prop
    local prop2 = props[2]
    local prom = promise.new()
    progressRunning = true

    exports.ZSX_UIV2:ProgressBar(
        data.icon,
        data.label or data.description or '',
        data.duration,
        function()
            progressRunning = false
            prom:resolve(true)
        end,
        function()
            progressRunning = false
            prom:resolve(false)
        end,
        data.canCancel == true,
        getDisableControls(data.disable),
        getAnim(data.anim),
        prop1,
        prop2
    )

    return Citizen.Await(prom)
end

function progressbar.progressActive()
    return progressRunning
end

-- ZSX_UIV2 has no cancel export.
function progressbar.cancelProgress()
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
