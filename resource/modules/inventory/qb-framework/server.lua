-- Uses `Player.Functions` item APIs on the active qb-core / qbx_core player object.
-- Manual Config.Inventory only - not included in auto-detect.

local inventory = {}

-- GetCoreObject serializes the whole core every call, so cache the copy and
-- re-pull only when the framework reports a runtime Shared change.
local qbCore, qbxItems

local function getQbCore()
    if not qbCore and GetResourceState('qb-core') == 'started' then
        qbCore = exports['qb-core']:GetCoreObject()
    end
    return qbCore
end

AddEventHandler('QBCore:Server:UpdateObject', function()
    qbxItems = nil
    if qbCore then
        qbCore = exports['qb-core']:GetCoreObject()
    end
end)

local function getSharedItems()
    if GetResourceState('qbx_core') == 'started' then
        if not qbxItems then
            local core = exports.qbx_core:GetCoreObject()
            qbxItems = core and core.Shared and core.Shared.Items
        end
        return qbxItems
    end

    local core = getQbCore()
    return core and core.Shared.Items
end

local function getPlayer(src)
    src = tonumber(src)
    if not src then return nil end

    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayer(src)
    end

    local core = getQbCore()
    return core and core.Functions.GetPlayer(src)
end

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function getPlayerItems(src)
    local player = getPlayer(src)
    return player and player.PlayerData and player.PlayerData.items or {}
end

local function countItems(inv, item, metadata)
    if not isPlayer(inv) then return 0 end

    local player = getPlayer(inv)
    if not player then return 0 end

    if not metadata then
        local total = 0

        for _, itemData in pairs(player.Functions.GetItemsByName(item) or {}) do
            total = total + InventoryItemAmount(itemData)
        end

        return total
    end

    local total = 0

    for _, itemData in pairs(getPlayerItems(inv)) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

local function resolveRemoveSlot(inv, item, metadata, slot)
    if slot or not metadata or not isPlayer(inv) then return slot end

    local player = getPlayer(inv)
    if not player then return nil end

    for _, itemData in pairs(player.Functions.GetItemsByName(item) or {}) do
        if InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            return itemData.slot
        end
    end

    return nil
end

function inventory.Items(itemName)
    local list = getSharedItems()
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.getImagePath(itemName)
    local item = inventory.Items(itemName)
    local image = InventoryItemImage(item)

    if type(image) == 'string' and image ~= '' then
        if image:find('^nui://', 1, false) or image:find('^https?://', 1, false) then
            return image
        end

        if not image:find('%.', 1, false) then
            image = image .. '.png'
        end

        return image
    end

    return itemName
end

function inventory.getItemInfo(itemName)
    local item = inventory.Items(itemName) or {}

    return {
        name = item.name or itemName,
        label = item.label or itemName,
        stack = item.stack ~= false,
        weight = item.weight or 0,
        description = item.description,
        image = inventory.getImagePath(itemName),
    }
end

-- Stashes are not supported.
function inventory.addItem(inv, item, count, metadata, slot)
    if not isPlayer(inv) then return false end

    local player = getPlayer(inv)
    if not player then return false end

    return player.Functions.AddItem(item, count or 1, slot, metadata or false)
end

-- Stashes are not supported.
function inventory.removeItem(inv, item, count, metadata, slot)
    if not isPlayer(inv) then return false end

    local player = getPlayer(inv)
    if not player then return false end

    slot = resolveRemoveSlot(inv, item, metadata, slot)

    if metadata and not slot then
        return false
    end

    return player.Functions.RemoveItem(item, count or 1, slot)
end

function inventory.hasItem(inv, item, count, metadata)
    return countItems(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return countItems(inv, item, metadata)
end

function inventory.getInventoryItems(inv)
    if not isPlayer(inv) then return {} end

    return NormalizeInventoryItems(getPlayerItems(inv))
end

function inventory.setMetadata(inv, slot, metadata)
    if not isPlayer(inv) then return false end

    local player = getPlayer(inv)
    if not player then return false end

    local slotItem = player.Functions.GetItemBySlot(slot)
    if not slotItem or not slotItem.name then return false end

    local name = slotItem.name
    local previousInfo = slotItem.info

    if not player.Functions.RemoveItem(name, 1, slot) then
        return false
    end

    if player.Functions.AddItem(name, 1, slot, metadata) then
        return true
    end

    player.Functions.AddItem(name, 1, slot, previousInfo or false)
    return false
end

function inventory.getSlot(inv, slot)
    if not isPlayer(inv) then return nil end

    local player = getPlayer(inv)
    if not player then return nil end

    return NormalizeInventoryItem(player.Functions.GetItemBySlot(slot), slot)
end

function inventory.clearInventory(inv, keep)
    if not isPlayer(inv) then return false end

    local player = getPlayer(inv)
    if not player then return false end

    player.Functions.ClearInventory(keep)
    return true
end

function inventory.canCarryItem(inv, item, count, metadata)
    if not isPlayer(inv) then return false end

    local player = getPlayer(inv)
    if not player or not player.Functions.CanCarryItem then return false end

    return player.Functions.CanCarryItem(item, count or 1)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    lib.print.debug('qb-framework does not support registerStash; install a dedicated inventory resource.')
    return false
end

function inventory.openStash(src, id)
    lib.print.debug('qb-framework does not support openStash; install a dedicated inventory resource.')
    return false
end

function inventory.registerShop(shopType, shopData)
    lib.print.debug('qb-framework does not support registerShop; install a dedicated inventory resource.')
    return false
end

function inventory.openShop(src, shopType)
    lib.print.debug('qb-framework does not support openShop; install a dedicated inventory resource.')
    return false
end

function inventory.registerHook(eventName, callback, options)
    lib.print.debug('qb-framework does not support registerHook; install a dedicated inventory resource.')
    return false
end

function inventory.removeHooks(hookId)
    lib.print.debug('qb-framework does not support removeHooks; install a dedicated inventory resource.')
    return
end

return inventory
