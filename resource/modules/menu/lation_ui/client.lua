local menu = {}

local lation = exports.lation_ui

local function copyOption(option, title)
    local item = {}

    for key, value in pairs(option) do
        item[key] = value
    end

    if title and not item.title then
        item.title = title
    end

    return item
end

local function normalizeOptions(options)
    if not options then return {} end

    if options[1] ~= nil then
        local list = {}

        for index, option in ipairs(options) do
            if type(option) == 'table' then
                list[index] = copyOption(option)
            else
                list[index] = { title = tostring(option) }
            end
        end

        return list
    end

    local list = {}

    for key, option in pairs(options) do
        if type(option) == 'table' then
            list[#list + 1] = copyOption(option, type(key) == 'string' and key or nil)
        else
            list[#list + 1] = { title = type(key) == 'string' and key or tostring(key) }
        end
    end

    return list
end

local function toLationContext(context)
    return {
        id = context.id,
        title = context.title,
        subtitle = context.subtitle,
        headerIcon = context.headerIcon or context.icon,
        headerIconColor = context.headerIconColor or context.iconColor,
        headerIconAnimation = context.headerIconAnimation or context.iconAnimation,
        menu = context.menu,
        canClose = context.canClose,
        position = context.position,
        onExit = context.onExit,
        onBack = context.onBack,
        options = normalizeOptions(context.options),
    }
end

function menu.openMenu(data)
    local contexts = data[1] and data or { data }
    local openId

    for _, context in ipairs(contexts) do
        local menuData = toLationContext(context)

        lation:registerMenu(menuData)
        openId = openId or menuData.id
    end

    if openId then
        lation:showMenu(openId)
    end

    return openId
end

function menu.closeMenu()
    lation:hideMenu()
end

return menu
