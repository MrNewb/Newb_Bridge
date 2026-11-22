local textui = {}

function textui.showTextUI(text, options)
    if not text then return end
    exports['lab-TextUI']:Show(text)
end

function textui.hideTextUI()
    exports['lab-TextUI']:Hide()
end

function textui.isTextUIOpen()
    return false
end

return textui
