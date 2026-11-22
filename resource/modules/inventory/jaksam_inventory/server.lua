local inventory = {}

local jaksam = exports['jaksam_inventory']

local function mapGroups(groups)
    if type(groups) ~= 'table' then return nil end

    local out = {}

    if groups[1] and type(groups[1]) == 'table' and groups[1].name then
        for _, group in ipairs(groups) do
            if group.name then out[group.name] = true end
        end
    else
        for key, value in pairs(groups) do
            if type(key) == 'string' and value then
                out[key] = true
            end
        end
    end

    return next(out) and out or nil
end

function inventory.Items(itemName)
    if itemName then
        return NormalizeItemDefinitions(jaksam:getStaticItem(itemName), itemName)
    end

    return NormalizeItemDefinitions(jaksam:getStaticItemsList())
end

function inventory.getImagePath(itemName)
    local item = NormalizeItemDefinition(itemName, jaksam:getStaticItem(itemName))
    return InventoryBuildImageUrl(itemName, item, 'jaksam_inventory')
end

function inventory.getItemInfo(itemName)
    local item = NormalizeItemDefinition(itemName, jaksam:getStaticItem(itemName))
    return InventoryBuildItemInfo(itemName, item, 'jaksam_inventory')
end

function inventory.addItem(inv, item, count, metadata, slot)
    return jaksam:addItem(inv, item, count or 1, metadata, slot)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    return jaksam:removeItem(inv, item, count or 1, metadata, slot)
end

function inventory.hasItem(inv, item, count, metadata)
    if metadata then
        return jaksam:getTotalItemAmount(inv, item, metadata) >= (count or 1)
    end

    return jaksam:hasItem(inv, item, count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return jaksam:getTotalItemAmount(inv, item, metadata) or 0
end

function inventory.getInventoryItems(inv)
    local data = jaksam:getInventory(inv)
    return NormalizeInventoryItems(data and data.items or {})
end

function inventory.setMetadata(inv, slot, metadata)
    return jaksam:setItemMetadataInSlot(inv, slot, metadata)
end

function inventory.getSlot(inv, slot)
    return NormalizeInventoryItem(jaksam:getItemFromSlot(inv, slot), slot)
end

function inventory.clearInventory(inv, keep)
    return jaksam:clearInventory(inv, keep)
end

function inventory.canCarryItem(inv, item, count, metadata)
    return jaksam:canCarryItem(inv, item, count or 1)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    local options = {
        id = id,
        label = label or id,
        maxSlots = slots,
        maxWeight = maxWeight,
        coords = coords,
        isPrivate = owner == true,
        allowedJobs = mapGroups(groups),
    }

    if type(owner) == 'string' and owner ~= '' then
        options.allowedIdentifiers = { [owner] = true }
        options.isPrivate = false
    end

    return jaksam:registerStash(options)
end

function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    jaksam:forceOpenInventory(src, id)
    return true
end

function inventory.registerShop(shopType, shopData)
    lib.print.debug(('[bridge-inventory] Warning: jaksam_inventory has no server-side shop registration, cannot register shop "%s".'):format(shopType))
    return false
end

function inventory.openShop(src, shopType)
    lib.print.debug(('[bridge-inventory] Warning: jaksam_inventory has no server-side shop open export, cannot open shop "%s" for player %s.'):format(shopType, src))
    return false
end

-- jaksam_inventory's own hook events (onItemAdded, onItemRemoved, onItemTransferred,
-- onPreUseItem, onPostUseItem, onInventoryCreated) are not ox-style event names, so callers
-- must pass jaksam's own event names here - there is no ox-name translation.
function inventory.registerHook(eventName, callback, options)
    return jaksam:registerHook(eventName, callback, options)
end

function inventory.removeHooks(hookId)
    if not hookId then return false end

    return jaksam:unregisterHook(hookId)
end

return inventory
