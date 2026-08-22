local progressbar = {}
local progressRunning = false

local function convertToZSX(data)
    if not data then return {} end

    local disableControls = {
        disable_mouse = data.disable and data.disable.mouse or false,
        disable_walk = data.disable and data.disable.move or false,
        disable_driving = data.disable and data.disable.car or false,
        disable_combat = data.disable and data.disable.combat or false,
    }

    local anim = nil
    if data.anim then
        anim = {
            dict = data.anim.dict,
            clip = data.anim.clip,
            blendIn = data.anim.blendIn,
            blendOut = data.anim.blendOut,
            duration = data.anim.duration,
            flag = data.anim.flag,
            playbackRate = data.anim.playbackRate,
            lockX = data.anim.lockX,
            lockY = data.anim.lockY,
            lockZ = data.anim.lockZ,
        }
    end

    local prop1 = nil
    local prop2 = nil

    if data.prop then
        if type(data.prop) == "table" then
            if data.prop[1] then
                prop1 = data.prop[1]
            end
            if data.prop[2] then
                prop2 = data.prop[2]
            end
        else
            prop1 = data.prop
        end
    end

    return {
        icon = data.icon,
        text = data.description or data.label or "",
        duration = data.duration,
        canCancel = data.canCancel ~= false,
        disableControls = disableControls,
        anim = anim,
        prop1 = prop1,
        prop2 = prop2,
    }
end

function progressbar.openprogressbar(data)
    if not data then return false end

    local converted = convertToZSX(data)
    local prom = promise.new()
    progressRunning = true

    exports['ZSX_UIV2']:ProgressBar(
        converted.icon,
        converted.text,
        converted.duration,
        function()
            progressRunning = false
            prom:resolve(true)
        end,
        function()
            progressRunning = false
            prom:resolve(false)
        end,
        converted.canCancel,
        converted.disableControls,
        converted.anim,
        converted.prop1,
        converted.prop2
    )

    return Citizen.Await(prom)
end

function progressbar.progressActive()
    return progressRunning
end

function progressbar.cancelProgress()
    -- ZSX_UIV2 has no cancel export; progressActive tracks completion callbacks only.
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
