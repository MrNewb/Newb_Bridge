local textui = {}

local function convertToLation(text, options)
    if not text then return {} end
    options = options or {}
    return {
        title = options.title,
        description = text,
        keybind = options.keybind,
        icon = options.icon,
        iconColor = options.iconColor,
        iconAnimation = options.iconAnimation,
        alignIcon = options.alignIcon,
        position = options.position or 'right-center',
        options = options.options,
        bgColor = options.bgColor,
        txtColor = options.txtColor,
    }
end

function textui.showTextUI(text, options)
    if not text then return end
    local converted = convertToLation(text, options)
    exports.lation_ui:showText(converted)
end

function textui.hideTextUI()
    exports.lation_ui:hideText()
end

function textui.isTextUIOpen()
    return exports.lation_ui:isOpen()
end

return textui