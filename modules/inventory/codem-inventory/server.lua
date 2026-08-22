local inventory = {}

local codem = exports['codem-inventory']

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function getStashItems(stashId)
    return codem:GetStashItems(stashId) or {}
end

local function countItems(inv, item, metadata)
    if isPlayer(inv) and not metadata then
        return codem:GetItemsTotalAmount(inv, item) or 0
    end

    local items

    if isPlayer(inv) then
        items = codem:GetItemsByName(inv, item) or {}
    else
        items = getStashItems(inv)
    end

    local total = 0

    for _, itemData in pairs(items) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + (itemData.amount or itemData.count or 0)
        end
    end

    return total
end

local function findStashSlot(items)
    local used = {}
    local maxSlot = 0

    for slot in pairs(items) do
        local slotNum = tonumber(slot) or slot
        used[slotNum] = true

        if slotNum > maxSlot then
            maxSlot = slotNum
        end
    end

    for i = 1, maxSlot do
        if not used[i] then return i end
    end

    return maxSlot + 1
end

local function resolveRemoveSlot(inv, item, metadata, slot)
    if slot or not metadata then return slot end

    local items

    if isPlayer(inv) then
        items = codem:GetItemsByName(inv, item) or {}
    else
        items = getStashItems(inv)
    end

    for _, itemData in pairs(items) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            return itemData.slot
        end
    end

    return nil
end

function inventory.Items(itemName)
    local list = codem:GetItemList()
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'codem-inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'codem-inventory', 'html/images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    count = count or 1

    if isPlayer(inv) then
        if slot or metadata then
            return codem:AddItem(inv, item, count, slot, metadata)
        end

        return codem:AddItem(inv, item, count)
    end

    local items = getStashItems(inv)

    if slot then
        items[slot] = {
            name = item,
            amount = count,
            info = metadata or {},
            slot = slot,
        }
    else
        local stacked = false

        for _, itemData in pairs(items) do
            if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
                itemData.amount = (itemData.amount or 0) + count
                stacked = true
                break
            end
        end

        if not stacked then
            local newSlot = findStashSlot(items)

            items[newSlot] = {
                name = item,
                amount = count,
                info = metadata or {},
                slot = newSlot,
            }
        end
    end

    codem:UpdateStash(inv, items)
    return true
end

function inventory.removeItem(inv, item, count, metadata, slot)
    count = count or 1

    if isPlayer(inv) then
        slot = resolveRemoveSlot(inv, item, metadata, slot)

        if slot then
            return codem:RemoveItem(inv, item, count, slot)
        end

        return codem:RemoveItem(inv, item, count)
    end

    local items = getStashItems(inv)
    local remaining = count

    for key, itemData in pairs(items) do
        if remaining <= 0 then break end

        local matchesSlot = not slot or itemData.slot == slot or key == slot or tonumber(key) == slot

        if itemData.name == item and matchesSlot and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            local amount = itemData.amount or 0

            if amount <= remaining then
                remaining = remaining - amount
                items[key] = nil
            else
                itemData.amount = amount - remaining
                remaining = 0
            end
        end
    end

    codem:UpdateStash(inv, items)
end

function inventory.hasItem(inv, item, count, metadata)
    if isPlayer(inv) and not metadata then
        return codem:CheckItemValid(inv, item, count or 1)
    end

    return countItems(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return countItems(inv, item, metadata)
end

function inventory.getInventoryItems(inv)
    if isPlayer(inv) then
        local data = codem:GetInventory(nil, inv)

        if type(data) == 'table' then
            return NormalizeInventoryItems(data.items or data)
        end

        return {}
    end

    return NormalizeInventoryItems(getStashItems(inv))
end

function inventory.setMetadata(inv, slot, metadata)
    if not isPlayer(inv) then return false end

    local slotItem = codem:GetItemBySlot(inv, slot)
    if not slotItem or not slotItem.name then return false end

    codem:SetItemMetadata(inv, slot, metadata)
    return true
end

function inventory.getSlot(inv, slot)
    if isPlayer(inv) then
        return NormalizeInventoryItem(codem:GetItemBySlot(inv, slot), slot)
    end

    local items = getStashItems(inv)

    return NormalizeInventoryItem(items[slot] or items[tostring(slot)], slot)
end

function inventory.clearInventory(inv, keep)
    local keepSet

    if type(keep) == 'string' then
        keepSet = { [keep] = true }
    elseif type(keep) == 'table' then
        keepSet = {}
        for i = 1, #keep do
            keepSet[keep[i]] = true
        end
    end

    if isPlayer(inv) then
        if not keepSet then
            return codem:ClearInventory(inv)
        end

        local items = codem:GetInventory(inv) or {}
        for _, itemData in pairs(items) do
            if itemData.name and not keepSet[itemData.name] then
                local slot = itemData.slot
                local amount = itemData.amount or itemData.count or 1
                if slot then
                    codem:RemoveItem(inv, itemData.name, amount, slot)
                else
                    codem:RemoveItem(inv, itemData.name, amount)
                end
            end
        end
        return true
    end

    if not keepSet then
        codem:UpdateStash(inv, {})
        return true
    end

    local items = getStashItems(inv)
    local kept = {}
    for slotId, itemData in pairs(items) do
        if itemData.name and keepSet[itemData.name] then
            kept[slotId] = itemData
        end
    end
    codem:UpdateStash(inv, kept)
    return true
end

function inventory.canCarryItem(inv, item, count, metadata)
    return true
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    lib.print.debug(('[bridge-inventory] Warning: codem-inventory has no server-side stash registration, cannot register stash "%s".'):format(id))
    return true
end

-- codem-inventory has no server export to force a stash UI open, only
-- client-triggered access, so this always returns false.
function inventory.openStash(src, id)
    lib.print.debug(('[bridge-inventory] Warning: codem-inventory has no server-side stash open export, cannot open stash "%s" for player %s.'):format(id, src))
    return false
end

function inventory.registerShop(shopType, shopData)
    lib.print.debug(('[bridge-inventory] Warning: codem-inventory has no server-side shop registration, cannot register shop "%s".'):format(shopType))
    return false
end

function inventory.openShop(src, shopType)
    lib.print.debug(('[bridge-inventory] Warning: codem-inventory has no server-side shop open export, cannot open shop "%s" for player %s.'):format(shopType, src))
    return false
end

function inventory.registerHook(eventName, callback, options)
    lib.print.debug(('[bridge-inventory] Warning: codem-inventory has no hook API, cannot register hook for event "%s".'):format(eventName))
    return false
end

function inventory.removeHooks(hookId)
    lib.print.debug(('[bridge-inventory] Warning: codem-inventory has no hook API, cannot remove hook with id "%s".'):format(hookId))
    return nil
end

return inventory
