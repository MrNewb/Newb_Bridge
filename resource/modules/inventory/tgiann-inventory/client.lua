local inventory = {}

local tgi = exports['tgiann-inventory']

function inventory.Items(itemName)
    return NormalizeItemDefinitions(tgi:Items(itemName), itemName)
end

function inventory.hasItem(item, count, metadata)
    return tgi:GetItemCount(item, metadata, false) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'tgiann-inventory', 'inventory_images/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'tgiann-inventory', 'inventory_images/images')
end

function inventory.getItemCount(item, metadata)
    return tgi:GetItemCount(item, metadata, false)
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(tgi:GetPlayerItems())
end

return inventory
