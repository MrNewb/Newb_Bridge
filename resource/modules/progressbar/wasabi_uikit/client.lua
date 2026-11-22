local progressbar = {}

local function convertToWasabi(data)
    if not data then return data end
    local options = {
        duration = data.duration or 5000,
        label = data.label,
        useWhileDead = data.useWhileDead or false,
        allowRagdoll = data.allowRagdoll or false,
        allowCuffed = data.allowCuffed or false,
        allowFalling = data.allowFalling or false,
        canCancel = data.canCancel or false,
        disable = {}
    }

    if data.disable then
        options.disable.move = data.disable.move
        options.disable.car = data.disable.car
        options.disable.mouse = data.disable.mouse
        options.disable.combat = data.disable.combat
    end

    if data.anim and data.anim.dict and data.anim.clip then
        options.anim = {
            dict = data.anim.dict,
            clip = data.anim.clip,
            flag = data.anim.flag or 49
        }
    elseif data.anim and data.anim.scenario then
        options.anim = {
            scenario = data.anim.scenario
        }
    end

    if data.prop then
        options.prop = data.prop
    end

    return options
end

function progressbar.openprogressbar(data)
    if not data then return false end
    if not exports.wasabi_uikit then return false end

    local options = convertToWasabi(data)
    return exports.wasabi_uikit:ProgressBar(options, "circle")
end

function progressbar.progressActive()
    return false
end

function progressbar.cancelProgress()
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
