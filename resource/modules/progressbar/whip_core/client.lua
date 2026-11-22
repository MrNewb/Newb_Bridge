-- Client-only module; no server exports.
-- Whip's progress bar. The bridge's ox_lib table converts to whip's options: `anim`, `disable`, `canCancel`, `label` and
-- `duration` use the same keys; a prop's `pos` is whip's `offset`. Whip holds move and combat off unless told otherwise,
-- the bridge holds nothing off unless told, so a missing `disable` is sent as an empty one. Only one prop is held.
-- Whip's bar is the player's word only; anything handed out at the end of it should be paid by the server.
local progressbar = {}

local active = false

local function convertProp(prop)
    if type(prop) ~= 'table' then return nil end
    if prop[1] then prop = prop[1] end

    return {
        model = prop.model,
        bone = prop.bone,
        offset = prop.pos or prop.offset,
        rot = prop.rot,
    }
end

function progressbar.openprogressbar(data)
    if type(data) ~= 'table' then return false end

    active = true
    local completed = exports.whip_core:Progress({
        label = data.label,
        duration = data.duration,
        canCancel = data.canCancel,
        anim = data.anim,
        prop = convertProp(data.prop),
        disable = data.disable or {},
    })
    active = false

    return completed == true
end

function progressbar.progressActive()
    return active or exports.whip_core:IsProgressActive() == true
end

function progressbar.cancelProgress()
    exports.whip_core:CancelProgress()
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
