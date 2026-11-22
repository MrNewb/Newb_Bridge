-- Manual Config.Inventory only - not included in auto-detect.

local inventory = {}

local ESX = exports.es_extended:getSharedObject()

local esxWarnings = {}

local function warnEsxLimit(message)
    if esxWarnings[message] then return end

    esxWarnings[message] = true
    lib.print.debug(('esx-framework: %s Install a dedicated inventory resource.'):format(message))
end

local function getInventory()
    local data = ESX.GetPlayerData()
    return data and data.inventory or {}
end

local function getEsxItems()
    if ESX.GetItems then
        return ESX.GetItems()
    end

    if type(ESX.Items) == 'function' then
        return ESX.Items()
    end

    return ESX.Items
end

local function normalizeEsxInventoryItems(items)
    if type(items) ~= 'table' then return {} end

    local normalized = {}

    local function addItem(itemData, slotKey)
        local item = NormalizeInventoryItem(itemData, slotKey)
        if item and item.count > 0 then
            normalized[#normalized + 1] = item
        end
    end

    if items[1] then
        for i = 1, #items do
            addItem(items[i], i)
        end
    else
        for slotKey, itemData in pairs(items) do
            addItem(itemData, slotKey)
        end
    end

    table.sort(normalized, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)

    return normalized
end

local function countItem(item, metadata)
    if metadata then
        warnEsxLimit('item metadata filters are ignored on getItemCount.')
    end

    local total = 0

    for _, itemData in ipairs(getInventory()) do
        if itemData.name == item then
            total = total + (itemData.count or 0)
        end
    end

    return total
end

function inventory.Items(itemName)
    return NormalizeItemDefinitions(getEsxItems(), itemName)
end

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    local item = inventory.Items(itemName)
    local image = InventoryItemImage(item)

    if image then
        if image:find('^nui://', 1, false) or image:find('^https?://', 1, false) then
            return image
        end

        if not image:find('%.', 1, false) then
            image = image .. '.png'
        end

        return image
    end

    return itemName
end

function inventory.getItemInfo(itemName)
    local item = inventory.Items(itemName) or {}

    return {
        name = item.name or itemName,
        label = item.label or itemName,
        stack = item.stack ~= false,
        weight = item.weight or 0,
        description = item.description,
        image = inventory.getImagePath(itemName),
    }
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return normalizeEsxInventoryItems(getInventory())
end

return inventory
