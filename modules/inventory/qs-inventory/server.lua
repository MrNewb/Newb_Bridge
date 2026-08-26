local inventory = {}

local qsi = exports['qs-inventory']

---@type table<string, { label: string, slots: number, maxWeight: number, owner?: string|boolean, groups?: table }>
local registeredStashes = {}

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function getStashConfig(stashId)
    return registeredStashes[stashId]
end

local function getStashItems(stashId)
    return qsi:GetStashItems(stashId) or {}
end

local function countItems(inv, item, metadata)
    if isPlayer(inv) and not metadata then
        return qsi:GetItemTotalAmount(inv, item) or 0
    end

    local items

    if isPlayer(inv) then
        items = qsi:GetInventory(inv) or {}
    else
        items = getStashItems(inv)
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
        items = qsi:GetInventory(inv) or {}
    else
        items = getStashItems(inv)
    end

    for slotId, itemData in pairs(items) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            return itemData.slot or slotId
        end
    end

    return nil
end

local function getKeepSet(keep)
    if not keep then return nil end

    if type(keep) == 'string' then
        return { [keep] = true }
    end

    local set = {}

    for i = 1, #keep do
        set[keep[i]] = true
    end

    return set
end

function inventory.Items(itemName)
    local list = qsi:GetItemList()
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'qs-inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'qs-inventory', 'html/images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    count = count or 1

    if isPlayer(inv) then
        return qsi:AddItem(inv, item, count, slot, metadata)
    end

    local stash = getStashConfig(inv) or { slots = 50, maxWeight = 100000 }

    return qsi:AddItemIntoStash(inv, item, count, slot, metadata, stash.slots, stash.maxWeight)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    count = count or 1

    if isPlayer(inv) then
        slot = resolveRemoveSlot(inv, item, metadata, slot)
        return qsi:RemoveItem(inv, item, count, slot, metadata)
    end

    local stash = getStashConfig(inv) or { slots = 50, maxWeight = 100000 }
    slot = resolveRemoveSlot(inv, item, metadata, slot)

    return qsi:RemoveItemIntoStash(inv, item, count, slot, stash.slots, stash.maxWeight )
end

function inventory.hasItem(inv, item, count, metadata)
    return countItems(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return countItems(inv, item, metadata)
end

function inventory.getInventoryItems(inv)
    if isPlayer(inv) then
        return NormalizeInventoryItems(qsi:GetInventory(inv) or {})
    end

    return NormalizeInventoryItems(getStashItems(inv))
end

function inventory.setMetadata(inv, slot, metadata)
    if not isPlayer(inv) then return false end

    return qsi:SetItemMetadata(inv, slot, metadata) ~= false
end

function inventory.getSlot(inv, slot)
    if isPlayer(inv) then
        local items = qsi:GetInventory(inv) or {}
        return NormalizeInventoryItem(items[slot] or items[tostring(slot)], slot)
    end

    local items = getStashItems(inv)
    return NormalizeInventoryItem(items[slot] or items[tostring(slot)], slot)
end

function inventory.clearInventory(inv, keep)
    local keepSet = getKeepSet(keep)

    if not isPlayer(inv) then
        if keepSet then
            local items = getStashItems(inv)
            local stash = getStashConfig(inv) or { slots = 50, maxWeight = 100000 }

            for slotId, itemData in pairs(items) do
                if itemData.name and not keepSet[itemData.name] then
                    qsi:RemoveItemIntoStash(
                        inv,
                        itemData.name,
                        itemData.amount or 1,
                        itemData.slot or slotId,
                        stash.slots,
                        stash.maxWeight
                    )
                end
            end

            return
        end

        return qsi:ClearOtherInventory('stash', inv)
    end

    local items = qsi:GetInventory(inv) or {}

    for slotId, itemData in pairs(items) do
        if itemData.name and (not keepSet or not keepSet[itemData.name]) then
            qsi:RemoveItem(inv, itemData.name, itemData.amount or 1, itemData.slot or slotId, itemData.info)
        end
    end
end

function inventory.canCarryItem(inv, item, count, metadata)
    if not isPlayer(inv) then return true end

    return qsi:CanCarryItem(inv, item, count or 1) == true
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    if type(id) ~= 'string' or id == '' then return false end

    registeredStashes[id] = {
        label = label or id,
        slots = slots or 50,
        maxWeight = maxWeight or 100000,
        owner = owner,
        groups = groups,
        coords = coords,
    }

    return true
end

-- qs-inventory has no dedicated "force open for player" export — the documented server
-- `RegisterStash(playerSource, stashID, stashSlots, stashWeight)` both creates and opens a
-- stash for that specific player, so it doubles as openStash. Bridge-registered stash config
-- (slots/maxWeight from `inventory.registerStash`) is passed through here since qs-inventory
-- itself has no separate global stash-registration export.
function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    local stash = getStashConfig(id) or { slots = 50, maxWeight = 100000 }

    qsi:RegisterStash(src, id, stash.slots, stash.maxWeight)
    return true
end

function inventory.registerShop(shopType, shopData)
    lib.print.debug('qs-inventory does not support bridge.registerShop; configure shops in qs-inventory instead.', shopType)
    return false
end

function inventory.openShop(src, shopType)
    lib.print.debug('qs-inventory does not support bridge.openShop; configure shops in qs-inventory instead.', shopType)
    return false
end

function inventory.registerHook(eventName, callback, options)
    lib.print.debug(('[bridge-inventory] Warning: qs-inventory has no ox-style hook API, cannot register hook for event "%s".'):format(eventName))
    return false
end

function inventory.removeHooks(hookId)
    lib.print.debug(('[bridge-inventory] Warning: qs-inventory has no ox-style hook API, cannot remove hook with id "%s".'):format(hookId))
    return false
end

return inventory
