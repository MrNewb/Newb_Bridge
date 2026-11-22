local inventory = {}

local ox_inventory = exports.ox_inventory

function inventory.Items(itemName)
    return ox_inventory:Items(itemName)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'ox_inventory')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'ox_inventory')
end

function inventory.addItem(inv, item, count, metadata, slot)
    return ox_inventory:AddItem(inv, item, count, metadata, slot)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    return ox_inventory:RemoveItem(inv, item, count, metadata, slot)
end

function inventory.hasItem(inv, item, count, metadata)
    return ox_inventory:GetItemCount(inv, item, metadata, false) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return ox_inventory:GetItemCount(inv, item, metadata, false)
end

function inventory.getInventoryItems(inv)
    return ox_inventory:GetInventoryItems(inv, false)
end

function inventory.setMetadata(inv, slot, metadata)
    return ox_inventory:SetMetadata(inv, slot, metadata)
end

function inventory.getSlot(inv, slot)
    return ox_inventory:GetSlot(inv, slot)
end

function inventory.clearInventory(inv, keep)
    return ox_inventory:ClearInventory(inv, keep)
end

function inventory.canCarryItem(inv, item, count, metadata)
    return ox_inventory:CanCarryItem(inv, item, count, metadata)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    return ox_inventory:RegisterStash(id, label, slots, maxWeight, owner, groups, coords)
end

function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    ox_inventory:forceOpenInventory(src, 'stash', id)
    return true
end

function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}

    ox_inventory:RegisterShop(shopType, {
        name = shopData.name or shopType,
        inventory = shopData.inventory or {},
        groups = shopData.groups,
    })

    return true
end

function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    TriggerClientEvent('ox_inventory:openInventory', src, 'shop', { type = shopType })
    return true
end

function inventory.registerHook(eventName, callback, options)
    return ox_inventory:registerHook(eventName, callback, options)
end

function inventory.removeHooks(hookId)
    return ox_inventory:removeHooks(hookId)
end

return inventory
