local textui = {}

local currentSerial = nil

function textui.showTextUI(text, options)
    if not text then return end
    options = options or {}

    local key = options.keybind or "E"
    local duration = options.duration

    -- ZSX_UIV2 TextUI API
    currentSerial = exports['ZSX_UIV2']:TextUI(
        key,
        text,
        duration,
        function()
            -- onComplete callback
        end,
        function()
            -- onFailure callback
        end
    )
end

function textui.hideTextUI()
    if currentSerial then
        exports['ZSX_UIV2']:TextUI_Remove(currentSerial, true)
        currentSerial = nil
    end
end

function textui.isTextUIOpen()
    return currentSerial ~= nil
end

return textui
