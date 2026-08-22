local inventory = {}

local codem = exports['codem-inventory']

local function getPlayerItems()
    return codem:getUserInventory() or codem:GetClientPlayerInventory() or {}
end

local function countItem(item, metadata)
    local total = 0

    for _, itemData in pairs(getPlayerItems()) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

function inventory.Items(itemName)
    local list = codem:GetItemList()
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'codem-inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'codem-inventory', 'html/images')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(codem:getUserInventory() or codem:GetClientPlayerInventory() or {})
end

return inventory
