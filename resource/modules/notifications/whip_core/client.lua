local notifications = {}

local KINDS = { inform = 'info', info = 'info', success = 'success', error = 'error', warning = 'warning' }

function notifications.notify(data)
    if type(data) ~= 'table' then return end

    -- Whip's toast has one line of text, so a title goes in front of the description.
    local text = data.description or data.message or data.title
    if type(text) ~= 'string' or text == '' then return end
    if data.title and data.description and data.title ~= data.description then
        text = ('%s: %s'):format(data.title, text)
    end

    exports.whip_core:Notify(text, KINDS[data.type] or 'info', data.duration)
end

return notifications
