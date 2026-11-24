local inventory = {}

local wasabi_inventory = exports.wasabi_inventory

local function mutationResult(success, response)
    if success == false or success == nil then return false end
    if type(success) == 'table' then return success end
    if type(response) == 'table' then return response end
    return success
end

function inventory.Items(itemName)
    return NormalizeItemDefinitions(wasabi_inventory:Items(itemName), itemName)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'wasabi_inventory', 'ui/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'wasabi_inventory', 'ui/images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    return mutationResult(wasabi_inventory:AddItem(inv, item, count or 1, metadata, slot))
end

function inventory.removeItem(inv, item, count, metadata, slot)
    return mutationResult(wasabi_inventory:RemoveItem(inv, item, count or 1, metadata, slot))
end

function inventory.hasItem(inv, item, count, metadata)
    return inventory.getItemCount(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return wasabi_inventory:GetItemCount(inv, item, metadata, false) or 0
end

function inventory.getInventoryItems(inv)
    return NormalizeInventoryItems(wasabi_inventory:GetInventoryItems(inv, false) or {})
end

function inventory.setMetadata(inv, slot, metadata)
    local updated = wasabi_inventory:SetMetadata(inv, slot, metadata)
    if updated == false then return false end
    return true
end

function inventory.getSlot(inv, slot)
    return NormalizeInventoryItem(wasabi_inventory:GetSlot(inv, slot), slot)
end

function inventory.clearInventory(inv, keep)
    return wasabi_inventory:ClearInventory(inv, keep)
end

function inventory.canCarryItem(inv, item, count, metadata)
    local canCarry = wasabi_inventory:CanCarryItem(inv, item, count or 1, metadata)
    if canCarry == false or canCarry == nil then return false end
    return true
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    local registered = wasabi_inventory:RegisterStash(id, label, slots, maxWeight, owner, groups, coords)
    if registered == false then return false end
    return true
end

function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    local opened = wasabi_inventory:OpenInventory(src, id)
    if opened == false then return false end
    return true
end

function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}

    local registered = wasabi_inventory:RegisterShop(shopType, {
        name = shopData.name or shopType,
        inventory = shopData.inventory or {},
        groups = shopData.groups,
    })
    if registered == false then return false end

    return true
end

function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    local opened = wasabi_inventory:forceOpenInventory(src, 'shop', { type = shopType })
    if opened == false then return false end
    return true
end

function inventory.registerHook(eventName, callback, options)
    return wasabi_inventory:registerHook(eventName, WrapInventoryHookCallback(eventName, callback), options)
end

function inventory.removeHooks(hookId)
    return wasabi_inventory:removeHooks(hookId)
end

return inventory
