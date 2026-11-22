local inventory = {}

local tgi = exports['tgiann-inventory']

-- number = player source, string = secondary inventory id (stash)
local function isStash(inv)
    return type(inv) ~= 'number'
end

function inventory.Items(itemName)
    return NormalizeItemDefinitions(tgi:Items(itemName), itemName)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'tgiann-inventory', 'inventory_images/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'tgiann-inventory', 'inventory_images/images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    count = count or 1

    if isStash(inv) then
        return tgi:AddItemToSecondaryInventory('stash', inv, item, count, slot, metadata)
    end

    return tgi:AddItem(inv, item, count, slot, metadata)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    count = count or 1

    if isStash(inv) then
        return tgi:RemoveItemFromSecondaryInventory('stash', inv, item, count, slot, metadata)
    end

    return tgi:RemoveItem(inv, item, count, slot, metadata)
end

function inventory.getItemCount(inv, item, metadata)
    if isStash(inv) then
        local stashItem = tgi:GetItemByNameFromSecondaryInventory('stash', inv, item, metadata)
        if not stashItem then return 0 end

        return stashItem.amount or stashItem.count or 0
    end

    if metadata then
        return tgi:GetItem(inv, item, metadata, true) or 0
    end

    return tgi:GetItemCount(inv, item) or 0
end

function inventory.hasItem(inv, item, count, metadata)
    count = count or 1

    if isStash(inv) or metadata then
        return inventory.getItemCount(inv, item, metadata) >= count
    end

    return tgi:HasItem(inv, item, count)
end

function inventory.getInventoryItems(inv)
    if isStash(inv) then
        return NormalizeInventoryItems(tgi:GetSecondaryInventoryItems('stash', inv) or {})
    end

    return NormalizeInventoryItems(tgi:GetPlayerItems(inv) or {})
end

function inventory.setMetadata(inv, slot, metadata)
    if isStash(inv) then return false end

    local slotItem = tgi:GetItemBySlot(inv, slot)
    if not slotItem or not slotItem.name then return false end

    tgi:UpdateItemMetadata(inv, slotItem.name, slot, metadata)
    return true
end

function inventory.getSlot(inv, slot)
    if isStash(inv) then
        local items = tgi:GetSecondaryInventoryItems('stash', inv) or {}

        for _, value in pairs(items) do
            if value.slot == slot then
                return NormalizeInventoryItem(value, slot)
            end
        end

        return nil
    end

    return NormalizeInventoryItem(tgi:GetItemBySlot(inv, slot), slot)
end

function inventory.clearInventory(inv, keep)
    if isStash(inv) then
        if not keep then
            tgi:DeleteInventory('stash', inv)
            return true
        end

        local keepSet = {}

        if type(keep) == 'string' then
            keepSet[keep] = true
        elseif type(keep) == 'table' then
            for i = 1, #keep do
                keepSet[keep[i]] = true
            end
        end

        local items = tgi:GetSecondaryInventoryItems('stash', inv) or {}

        for _, itemData in pairs(items) do
            if itemData.name and not keepSet[itemData.name] then
                tgi:RemoveItemFromSecondaryInventory('stash', inv, itemData.name, itemData.amount or itemData.count or 0, itemData.slot)
            end
        end

        return true
    end

    return tgi:ClearInventory(inv, keep)
end

function inventory.canCarryItem(inv, item, count, metadata)
    if isStash(inv) then return true end

    return tgi:CanCarryItem(inv, item, count or 1)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    return tgi:RegisterStash(id, label, slots, maxWeight, owner, groups, coords)
end

function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    tgi:ForceOpenInventory(src, 'stash', id)
    return true
end

local function mapShopItems(inventory)
    if type(inventory) ~= 'table' then return {} end

    local items = {}

    for i = 1, #inventory do
        local entry = inventory[i]
        if type(entry) == 'table' and entry.name then
            items[#items + 1] = {
                name = entry.name,
                price = entry.price,
                amount = entry.count or 0,
                type = 'item',
            }
        end
    end

    return items
end

-- Accepts ox-format `shopData`; maps `inventory` to tgiann items (`count` -> `amount`).
function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}

    tgi:RegisterShop(shopType, mapShopItems(shopData.inventory))
    return true
end

-- Gate distance/restrictions before calling.
function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    tgi:OpenShop(src, shopType)
    return true
end

-- tgiann slots use qb-style `info`/`amount` internally - payloads are normalized to ox shape.
function inventory.registerHook(eventName, callback, options)
    local registerHook = tgi.RegisterHook or tgi.registerHook
    if not registerHook then return false end

    return registerHook(tgi, eventName, WrapInventoryHookCallback(eventName, callback), options)
end

function inventory.removeHooks(hookId)
    local removeHooks = tgi.RemoveHooks or tgi.removeHooks
    if removeHooks then
        return removeHooks(tgi, hookId)
    end
end

return inventory
