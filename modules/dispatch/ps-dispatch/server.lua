local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    local sound = data.sound
    local alertSound = "Lose_1st"
    local soundRef = "GTAO_FM_Events_Soundset"

    if sound then
        if type(sound.alert) == "table" and sound.alert.sound then
            alertSound = sound.alert.sound
        elseif sound.alert then
            alertSound = sound.alert
        elseif sound.name then
            alertSound = sound.name
        end

        if sound.ref then
            soundRef = sound.ref
        end
    end

    TriggerEvent("ps-dispatch:server:notify", {
        jobs = jobs,
        coords = coords,
        code = data.code,
        message = data.title,
        length = data.length or blip.length,
        flash = alertFlash,
        alert = {
            sound = alertSound,
            sound2 = soundRef,
            sprite = blip.sprite,
            scale = blip.scale,
            color = blip.colour,
            flashes = blip.flash,
            text = blip.text,
            length = blip.length,
        },
    })
end

return dispatch
