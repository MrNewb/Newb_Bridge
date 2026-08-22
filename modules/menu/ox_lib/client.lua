local menu = {}

function menu.openMenu(data)
    lib.registerContext(data)

    local openId = data[1] and data[1].id or data.id

    lib.showContext(openId)

    return openId
end

function menu.closeMenu()
    lib.hideContext()
end

return menu
