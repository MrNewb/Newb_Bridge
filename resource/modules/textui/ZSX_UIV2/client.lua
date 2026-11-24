local textui = {}

local isOpen = false

local function ignore() end

-- The persistent export is the documented choice for a TextUI that is shown again on every tick: it keeps one entry
-- instead of stacking a new one per call.
function textui.showTextUI(text, options)
    if not text then return end

    options = options or {}
    exports.ZSX_UIV2:TextUI_Persistent(options.keybind or 'E', text, options.duration, ignore, ignore)
    isOpen = true
end

function textui.hideTextUI()
    if not isOpen then return end

    exports.ZSX_UIV2:TextUI_RemovePersistent(true)
    isOpen = false
end

function textui.isTextUIOpen()
    return isOpen
end

return textui
