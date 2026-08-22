local inventory = {}

local ox_inventory = exports.ox_inventory

function inventory.Items(itemName)
    return ox_inventory:Items(itemName)
end

function inventory.hasItem(item, count, metadata)
    return ox_inventory:GetItemCount(item, metadata, false) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'ox_inventory')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'ox_inventory')
end

function inventory.getItemCount(item, metadata)
    return ox_inventory:GetItemCount(item, metadata, false)
end

function inventory.getInventoryItems()
    return ox_inventory:GetPlayerItems()
end

return inventory
