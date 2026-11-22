local inventory = {}

local wasabi_inventory = exports.wasabi_inventory

function inventory.Items(itemName)
    return NormalizeItemDefinitions(wasabi_inventory:Items(itemName), itemName)
end

function inventory.hasItem(item, count, metadata)
    return inventory.getItemCount(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'wasabi_inventory', 'ui/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'wasabi_inventory', 'ui/images')
end

function inventory.getItemCount(item, metadata)
    return wasabi_inventory:GetItemCount(item, metadata, false) or 0
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(wasabi_inventory:GetPlayerItems() or {})
end

return inventory
