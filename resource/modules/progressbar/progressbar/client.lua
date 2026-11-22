local progressbar = {}

local function convertToQB(data)
    if not data then return data end
    local prop1 = data.prop and (data.prop[1] or data.prop) or {}
    local prop2 = data.prop and data.prop[2] or {}
    return {
        name = data.label,
        duration = data.duration,
        label = data.label,
        useWhileDead = data.useWhileDead,
        canCancel = data.canCancel,
        controlDisables = {
            disableMovement = data.disable and data.disable.move,
            disableCarMovement = data.disable and data.disable.car,
            disableMouse = data.disable and data.disable.mouse,
            disableCombat = data.disable and data.disable.combat
        },
        animation = {
            animDict = data.anim and data.anim.dict,
            anim = data.anim and data.anim.clip,
            flags = data.anim and data.anim.flag or 49
        },
        prop = {
            model = prop1.model,
            bone = prop1.bone,
            coords = prop1.pos,
            rotation = prop1.rot
        },
        propTwo = {
            model = prop2.model,
            bone = prop2.bone,
            coords = prop2.pos,
            rotation = prop2.rot
        }
    }
end

function progressbar.openprogressbar(data)
    if not exports['progressbar'] then return false end
    if not data then return false end

    local options = convertToQB(data)
    local prom = promise.new()

    exports['progressbar']:Progress(options, function(cancelled)
        prom:resolve(not cancelled)
    end)

    return Citizen.Await(prom)
end

function progressbar.progressActive()
    return false
end

function progressbar.cancelProgress()
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
