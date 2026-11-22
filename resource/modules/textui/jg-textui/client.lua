local textui = {}

function textui.showTextUI(text, options)
    if not text then return end
    exports['jg-textui']:DrawText(text)
end

function textui.hideTextUI()
    exports['jg-textui']:HideText()
end

function textui.isTextUIOpen()
    return false
end

return textui
