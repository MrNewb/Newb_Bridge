local inventory = {}

local qsi = exports['qs-inventory']

local function getPlayerItems()
    return qsi:getUserInventory() or {}
end

local function countItem(item, metadata)
    if not metadata then
        return tonumber(qsi:Search(item)) or 0
    end

    local total = 0

    for _, itemData in pairs(getPlayerItems()) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

function inventory.Items(itemName)
    local list = qsi:GetItemList()
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'qs-inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'qs-inventory', 'html/images')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(getPlayerItems())
end

return inventory
