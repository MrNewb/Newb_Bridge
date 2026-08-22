local textui = {}

function textui.showTextUI(text, options)
    if not text then return end
    lib.showTextUI(text, options)
end

function textui.hideTextUI()
    lib.hideTextUI()
end

function textui.isTextUIOpen()
    return lib.isTextUIOpen()
end

return textui
