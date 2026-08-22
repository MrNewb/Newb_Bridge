local inventory = {}

local qbi = exports['qb-inventory']
local QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('QBCore:Server:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function countItems(inv, item, metadata)
    if isPlayer(inv) and not metadata then
        return qbi:GetItemCount(inv, item) or 0
    end

    if not isPlayer(inv) and not metadata then
        local stash = qbi:GetInventory(inv)
        if not stash or not stash.items then return 0 end

        local total = 0

        for _, itemData in pairs(stash.items) do
            if itemData.name == item then
                total = total + (itemData.amount or 0)
            end
        end

        return total
    end

    local items

    if isPlayer(inv) then
        items = qbi:GetItemsByName(inv, item) or {}
    else
        local stash = qbi:GetInventory(inv)
        items = stash and stash.items or {}
    end

    local total = 0

    for _, itemData in pairs(items) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

local function resolveRemoveSlot(inv, item, metadata, slot)
    if slot or not metadata then return slot end

    local items

    if isPlayer(inv) then
        items = qbi:GetItemsByName(inv, item) or {}
    else
        local stash = qbi:GetInventory(inv)
        items = stash and stash.items or {}
    end

    for _, itemData in pairs(items) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            return itemData.slot
        end
    end

    return nil
end

function inventory.Items(itemName)
    if itemName then
        return NormalizeItemDefinitions(QBCore.Shared.Items[itemName], itemName)
    end

    return NormalizeItemDefinitions(QBCore.Shared.Items)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'qb-inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'qb-inventory', 'html/images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    if tonumber(inv) then
        TriggerClientEvent('qb-inventory:client:ItemBox', inv, QBCore.Shared.Items[item], 'add')
    end
    return qbi:AddItem(inv, item, count or 1, slot or false, metadata or false, 'Newb_Bridge')
end

function inventory.removeItem(inv, item, count, metadata, slot)
    slot = resolveRemoveSlot(inv, item, metadata, slot)
    if tonumber(inv) then
        TriggerClientEvent('qb-inventory:client:ItemBox', inv, QBCore.Shared.Items[item], 'remove')
    end
    return qbi:RemoveItem(inv, item, count or 1, slot or false, 'Newb_Bridge')
end

function inventory.hasItem(inv, item, count, metadata)
    if isPlayer(inv) and not metadata then
        return qbi:HasItem(inv, item, count or 1)
    end

    return countItems(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return countItems(inv, item, metadata)
end

function inventory.getInventoryItems(inv)
    if isPlayer(inv) then
        local player = QBCore.Functions.GetPlayer(inv)
        return NormalizeInventoryItems(player and player.PlayerData.items or {})
    end

    local stash = qbi:GetInventory(inv)
    return NormalizeInventoryItems(stash and stash.items or {})
end

function inventory.setMetadata(inv, slot, metadata)
    if not isPlayer(inv) then return false end

    local slotItem = qbi:GetItemBySlot(inv, slot)
    if not slotItem or not slotItem.name then return false end

    return qbi:SetItemData(inv, slotItem.name, 'info', metadata, slot)
end

function inventory.getSlot(inv, slot)
    if isPlayer(inv) then
        return NormalizeInventoryItem(qbi:GetItemBySlot(inv, slot), slot)
    end

    local stash = qbi:GetInventory(inv)
    if not stash or not stash.items then return nil end

    return NormalizeInventoryItem(stash.items[tonumber(slot)], slot)
end

function inventory.clearInventory(inv, keep)
    if isPlayer(inv) then
        qbi:ClearInventory(inv, keep)
        return
    end

    qbi:ClearStash(inv)
end

function inventory.canCarryItem(inv, item, count, metadata)
    return qbi:CanAddItem(inv, item, count or 1)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    qbi:CreateInventory(id, {
        label = label,
        slots = slots,
        maxweight = maxWeight,
    })
    return true
end

-- Gate distance/restrictions before calling.
function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    qbi:OpenInventory(src, id)
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
            }
        end
    end

    return items
end

-- Omits `coords`/`locations` so script-gated opens are not blocked by qb's 5m check.
local function mapShopData(shopType, shopData)
    shopData = shopData or {}

    return {
        name = shopType,
        label = shopData.label or shopData.name or shopType,
        items = mapShopItems(shopData.inventory),
    }
end

-- Accepts ox-format `shopData`; maps `inventory` to qb `items` (`count` -> `amount`).
function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    qbi:CreateShop(mapShopData(shopType, shopData))
    return true
end

-- Gate distance/restrictions before calling.
function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    qbi:OpenShop(src, shopType)
    return true
end

function inventory.registerHook(eventName, callback, options)
    lib.print.debug(('[bridge-inventory] Warning: qb-inventory has no ox-style hook API, cannot register hook for event "%s".'):format(eventName))
    return false
end

function inventory.removeHooks(hookId)
    lib.print.debug(('[bridge-inventory] Warning: qb-inventory has no ox-style hook API, cannot remove hook with id "%s".'):format(hookId))
    return false
end

return inventory
