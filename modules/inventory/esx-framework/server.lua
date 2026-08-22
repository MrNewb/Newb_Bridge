-- Uses xPlayer inventory APIs from es_extended. No slots/metadata/stash support.
-- Manual Config.Inventory only — not included in auto-detect.

local inventory = {}

local ESX = exports.es_extended:getSharedObject()

local esxWarnings = {}

local function warnEsxLimit(message)
    if esxWarnings[message] then return end

    esxWarnings[message] = true
    lib.print.debug(('esx-framework: %s Install a dedicated inventory resource.'):format(message))
end

local function getPlayer(src)
    return ESX.GetPlayerFromId(tonumber(src))
end

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function getItemCount(xPlayer, item)
    local slot = xPlayer.getInventoryItem(item)
    return slot and slot.count or 0
end

local function getEsxItems()
    if ESX.GetItems then
        return ESX.GetItems()
    end

    if type(ESX.Items) == 'function' then
        return ESX.Items()
    end

    return ESX.Items
end

local function normalizeEsxInventoryItems(items)
    if type(items) ~= 'table' then return {} end

    local normalized = {}

    local function addItem(itemData, slotKey)
        local item = NormalizeInventoryItem(itemData, slotKey)
        if item and item.count > 0 then
            normalized[#normalized + 1] = item
        end
    end

    if items[1] then
        for i = 1, #items do
            addItem(items[i], i)
        end
    else
        for slotKey, itemData in pairs(items) do
            addItem(itemData, slotKey)
        end
    end

    table.sort(normalized, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)

    return normalized
end

function inventory.Items(itemName)
    return NormalizeItemDefinitions(getEsxItems(), itemName)
end

function inventory.getImagePath(itemName)
    local item = inventory.Items(itemName)
    local image = InventoryItemImage(item)

    if image then
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

-- Metadata and slots are ignored on default ESX.
function inventory.addItem(inv, item, count, metadata, slot)
    if not isPlayer(inv) then return false end

    if metadata then
        warnEsxLimit('item metadata is ignored on addItem.')
    end

    if slot then
        warnEsxLimit('item slots are ignored on addItem.')
    end

    local xPlayer = getPlayer(inv)
    if not xPlayer then return false end

    count = count or 1

    if xPlayer.canCarryItem and not xPlayer.canCarryItem(item, count) then
        return false
    end

    xPlayer.addInventoryItem(item, count)
    return true
end

function inventory.removeItem(inv, item, count, metadata, slot)
    if not isPlayer(inv) then return false end

    if metadata then
        warnEsxLimit('item metadata is ignored on removeItem.')
    end

    if slot then
        warnEsxLimit('item slots are ignored on removeItem.')
    end

    local xPlayer = getPlayer(inv)
    if not xPlayer then return false end

    count = count or 1

    if getItemCount(xPlayer, item) < count then
        return false
    end

    xPlayer.removeInventoryItem(item, count)
    return true
end

function inventory.hasItem(inv, item, count, metadata)
    return inventory.getItemCount(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    if not isPlayer(inv) then return 0 end

    if metadata then
        warnEsxLimit('item metadata filters are ignored on getItemCount.')
    end

    local xPlayer = getPlayer(inv)
    if not xPlayer then return 0 end

    return getItemCount(xPlayer, item)
end

function inventory.getInventoryItems(inv)
    if not isPlayer(inv) then return {} end

    warnEsxLimit('getInventoryItems uses synthetic slot indexes, not real ESX slots.')

    local xPlayer = getPlayer(inv)
    if not xPlayer then return {} end

    return normalizeEsxInventoryItems(xPlayer.getInventory())
end

function inventory.setMetadata(inv, slot, metadata)
    warnEsxLimit('setMetadata is not supported.')
    return false
end

function inventory.getSlot(inv, slot)
    if not isPlayer(inv) then return nil end

    warnEsxLimit('getSlot returns synthetic list indexes, not real ESX slots.')

    local xPlayer = getPlayer(inv)
    if not xPlayer then return nil end

    local items = xPlayer.getInventory() or {}
    return NormalizeInventoryItem(items[tonumber(slot)], slot)
end

function inventory.clearInventory(inv, keep)
    if not isPlayer(inv) then return false end

    local xPlayer = getPlayer(inv)
    if not xPlayer then return false end

    local keepSet

    if type(keep) == 'string' then
        keepSet = { [keep] = true }
    elseif type(keep) == 'table' then
        keepSet = {}

        for i = 1, #keep do
            keepSet[keep[i]] = true
        end
    end

    for _, item in ipairs(xPlayer.getInventory() or {}) do
        if item.count and item.count > 0 and not (keepSet and keepSet[item.name]) then
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    end

    return true
end

function inventory.canCarryItem(inv, item, count, metadata)
    if not isPlayer(inv) then return false end

    if metadata then
        warnEsxLimit('item metadata is ignored on canCarryItem.')
    end

    local xPlayer = getPlayer(inv)
    if not xPlayer or not xPlayer.canCarryItem then return false end

    return xPlayer.canCarryItem(item, count or 1)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    lib.print.debug('esx-framework does not support registerStash; install a dedicated inventory resource.')
    return false
end

function inventory.openStash(src, id)
    lib.print.debug('esx-framework does not support openStash; install a dedicated inventory resource.')
    return false
end

function inventory.registerShop(shopType, shopData)
    lib.print.debug('esx-framework does not support registerShop; install a dedicated inventory resource.')
    return false
end

function inventory.openShop(src, shopType)
    lib.print.debug('esx-framework does not support openShop; install a dedicated inventory resource.')
    return false
end

function inventory.registerHook(eventName, callback, options)
    lib.print.debug('esx-framework does not support registerHook; install a dedicated inventory resource.')
    return false
end

function inventory.removeHooks(hookId)
    lib.print.debug('esx-framework does not support removeHooks; install a dedicated inventory resource.')
    return
end

return inventory
