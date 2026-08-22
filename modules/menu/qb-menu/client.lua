local qb_menu = exports['qb-menu']

local function retreiveNumberIndexedData(playerTable, functionsOverride)
    local newMethods = {}

    local function modifyMethods(data, method, modification)
        for dataIndex, dataValue in ipairs(data) do
            local originalMethods = type(modification.originalMethod) == 'table' and modification.originalMethod or { modification.originalMethod }
            local originalMethodRef
            local originalMethod
            for _, method in ipairs(originalMethods) do
                originalMethod = method
                originalMethodRef = originalMethod and dataValue[method]
                if originalMethodRef then
                    break
                end
            end

            local hasKeys = modification.hasKeys
            if hasKeys then
                local modifier = modification.modifier
                if modifier and modifier.effect then
                    newMethods[dataIndex][method] = modifier.effect(dataValue)
                end
            end

            if originalMethodRef then
                local modifier = modification.modifier
                newMethods[dataIndex] = newMethods[dataIndex] or {}
                local effect
                if modifier then
                    if modifier.executeFunc then
                        effect = modifier.effect(originalMethodRef, originalMethod)
                    else
                        effect = function(...)
                            return modifier.effect(originalMethodRef, ...)
                        end
                    end
                else
                    effect = originalMethodRef
                end
                newMethods[dataIndex][method] = effect
            end
        end
    end

    local function processTable(tableToProcess, overrides)
        for _, value in ipairs(tableToProcess) do
            for method, modification in pairs(overrides) do
                if type(modification) == 'table' and not modification.originalMethod then
                    processTable(value[method], modification)
                else
                    modifyMethods(tableToProcess, method, modification)
                end
            end
        end
    end

    processTable(playerTable, functionsOverride)
    return newMethods
end

local overRideData = {
    header = {
        originalMethod = 'title',
    },
    txt = {
        originalMethod = 'description',
    },
    icon = {
        originalMethod = 'icon',
        modifier = {
            executeFunc = true,
            effect = function(value)
                local text = ('fas fa-%s'):format(value)
                return text
            end
        }
    },
    params = {
        originalMethod = 'none',
        hasKeys = true,
        modifier = {
            effect = function(data)
                local params = {}
                if data.onSelect then
                    params.event = data.onSelect
                    params.isAction = true
                elseif data.event then
                    params.event = data.event
                    params.args = data.args
                elseif data.serverEvent then
                    params.event = data.serverEvent
                    params.isServer = true
                    params.args = data.args
                end
                return params
            end
        },
    },
    disabled = {
        originalMethod = 'disabled',
    },
    isMenuHeader = {
        originalMethod = 'isHeader',
    },
}

local menu = {}

function menu.openMenu(data)
    qb_menu:openMenu(retreiveNumberIndexedData(data, overRideData))
end

function menu.closeMenu()
    qb_menu:closeMenu()
end

return menu
