local inventory = {}

local m_inventory = exports['m-Inventory']

local function getItemCount(inv, item, metadata)
    if metadata then
        return m_inventory:Search(inv, 'count', item, metadata) or 0
    end

    return m_inventory:GetItemCount(inv, item) or 0
end

function inventory.Items(itemName)
    return m_inventory:Items(itemName)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'm-Inventory')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'm-Inventory')
end

function inventory.addItem(inv, item, count, metadata, slot)
    return m_inventory:AddItem(inv, item, count, metadata, slot)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    return m_inventory:RemoveItem(inv, item, count, metadata, slot)
end

function inventory.hasItem(inv, item, count, metadata)
    if metadata then
        return getItemCount(inv, item, metadata) >= (count or 1)
    end

    return m_inventory:HasItem(inv, item, count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return getItemCount(inv, item, metadata)
end

function inventory.getInventoryItems(inv)
    return m_inventory:GetInventoryItems(inv) or {}
end

function inventory.setMetadata(inv, slot, metadata)
    return m_inventory:SetMetadata(inv, slot, metadata)
end

function inventory.getSlot(inv, slot)
    return m_inventory:GetSlot(inv, slot)
end

function inventory.clearInventory(inv, keep)
    if not keep then
        return m_inventory:ClearInventory(inv)
    end

    local keepSet = {}

    if type(keep) == 'string' then
        keepSet[keep] = true
    else
        for i = 1, #keep do
            keepSet[keep[i]] = true
        end
    end

    for _, itemData in pairs(inventory.getInventoryItems(inv)) do
        if itemData.name and not keepSet[itemData.name] then
            m_inventory:RemoveItem(inv, itemData.name, itemData.count or 1, nil, itemData.slot)
        end
    end
end

function inventory.canCarryItem(inv, item, count, metadata)
    return m_inventory:CanCarryItem(inv, item, count, metadata)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    return m_inventory:RegisterStash(id, label, slots, maxWeight, owner, groups, coords)
end

function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    return m_inventory:openInventory(src, 'stash', id) ~= false
end

-- Script-opened shops omit `locations` so items are stored on the shop type directly (no location `id` on open).
-- `targets`, `blip`, and `model` are ignored at runtime.
function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}

    m_inventory:RegisterShop(shopType, {
        name = shopData.name or shopType,
        inventory = shopData.inventory or {},
        groups = shopData.groups,
    })

    return true
end

-- Gate distance/restrictions before calling.
function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    return m_inventory:openInventory(src, 'shop', { type = shopType }) ~= false
end

function inventory.registerHook(eventName, callback, options)
    return m_inventory:registerHook(eventName, callback, options)
end

function inventory.removeHooks(hookId)
    return m_inventory:removeHook(hookId)
end

return inventory
