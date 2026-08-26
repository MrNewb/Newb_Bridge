local inventory = {}

local core = exports['core_inventory']

-- getInventory() returns a wrapper table with an `items` field, not a flat item list.
local function getItems()
    local data = core:getInventory()

    if type(data) == 'table' then
        return data.content or data.items or data
    end

    return {}
end

-- core_inventory's client `getItemCount`/`hasItem` take no metadata filter, so one is
-- applied manually against the full inventory when a caller asks for it.
local function countItem(item, metadata)
    if not metadata then
        return core:getItemCount(item) or 0
    end

    local total = 0

    for _, itemData in pairs(getItems()) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

function inventory.Items(itemName)
    local list = core:getItemsList()
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.hasItem(item, count, metadata)
    if metadata then
        return countItem(item, metadata) >= (count or 1)
    end

    return core:hasItem(item, count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'core_inventory', 'html/img')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'core_inventory', 'html/img')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(getItems())
end

return inventory
