-- Client-only module; no server exports.
-- Whip's hint capsule (ShowText). Whip answers HideText with false when the text on screen belongs to another resource,
-- so isTextUIOpen is tracked here for the text this resource put up.
local textui = {}

local open = false

function textui.showTextUI(text, options)
    if not text then return end

    local position = type(options) == 'table' and options.position
    open = true
    exports.whip_core:ShowText(text, (position == 'top' or position == 'top-center') and 'top' or 'bottom')
end

function textui.hideTextUI()
    open = false
    exports.whip_core:HideText()
end

function textui.isTextUIOpen()
    return open
end

return textui
