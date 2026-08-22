local textui = {}

function textui.showTextUI(text, options)
    if not text then return end
    TriggerEvent('cd_drawtextui:ShowUI', 'show', text)
end

function textui.hideTextUI()
    TriggerEvent('cd_drawtextui:HideUI')
end

function textui.isTextUIOpen()
    return false
end

return textui
