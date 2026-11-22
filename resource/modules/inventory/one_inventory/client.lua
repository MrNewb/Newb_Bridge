local inventory = {}

local one_inventory = exports.one_inventory

function inventory.Items(itemName)
    if itemName then
        return one_inventory:GetItemDefinition(itemName)
    end

    return one_inventory:GetAllItemDefinitions()
end

function inventory.hasItem(item, count, metadata)
    return one_inventory:GetItemCount(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'one_inventory')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'one_inventory')
end

function inventory.getItemCount(item, metadata)
    return one_inventory:GetItemCount(item, metadata)
end

function inventory.getInventoryItems()
    return one_inventory:GetInventoryItems()
end

return inventory
