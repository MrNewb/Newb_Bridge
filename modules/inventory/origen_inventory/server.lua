local inventory = {}

local origin = exports.origen_inventory

-- origen_inventory's removeItem takes a slot, not a metadata filter — resolve the slot
-- ourselves via getItem when a metadata filter is given.
local function resolveSlot(inv, item, metadata, slot)
    if slot or not metadata then return slot end

    local match = origin:getItem(inv, item, metadata)
    return match and match.slot
end

-- STUB: origen_inventory has no documented export for the shared item list or a full item
-- definition — only `getItemLabel(item)` for a display label. Returns a label-only table
-- for a single item, or `nil` for the full list (unsupported).
function inventory.Items(itemName)
    if not itemName then return nil end

    local label = origin:getItemLabel(itemName)
    if not label then return nil end

    return NormalizeItemDefinition(itemName, { name = itemName, label = label })
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'origen_inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'origen_inventory', 'html/images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    return origin:addItem(inv, item, count or 1, slot, metadata)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    slot = resolveSlot(inv, item, metadata, slot)
    return origin:removeItem(inv, item, count or 1, slot)
end

-- origen_inventory's getItemCount has no metadata filter — one is applied manually via
-- getItems when needed.
function inventory.getItemCount(inv, item, metadata)
    if not metadata then
        return origin:getItemCount(inv, item) or 0
    end

    local total = 0

    for _, itemData in pairs(origin:getItems(inv) or {}) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

function inventory.hasItem(inv, item, count, metadata)
    if metadata then
        return inventory.getItemCount(inv, item, metadata) >= (count or 1)
    end

    return origin:HasItem(inv, item, count or 1)
end

function inventory.getInventoryItems(inv)
    return NormalizeInventoryItems(origin:getItems(inv) or {})
end

function inventory.setMetadata(inv, slot, metadata)
    return origin:setMetadata(inv, slot, metadata)
end

function inventory.getSlot(inv, slot)
    return NormalizeInventoryItem(origin:GetItemBySlot(inv, slot), slot)
end

function inventory.clearInventory(inv, keep)
    if not keep then
        origin:clearInventory(inv)
        return
    end

    local keepSet = {}

    if type(keep) == 'string' then
        keepSet[keep] = true
    else
        for i = 1, #keep do
            keepSet[keep[i]] = true
        end
    end

    for _, itemData in pairs(origin:getItems(inv) or {}) do
        if itemData.name and not keepSet[itemData.name] then
            origin:removeItem(inv, itemData.name, itemData.count or itemData.amount or 1, itemData.slot)
        end
    end
end

function inventory.canCarryItem(inv, item, count, metadata)
    return origin:canCarryItem(inv, item, count or 1)
end

-- registerStash takes a single `data` table rather than positional args; only `label`,
-- `slots`, and `maxweight` are documented fields.
function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    if type(id) ~= 'string' or id == '' then return false end

    origin:registerStash(id, {
        label = label,
        slots = slots,
        maxweight = maxWeight,
    })

    return true
end

-- Uses `OpenInventoryById`, documented as "useful for evidence lockers, faction stashes,
-- etc." — the closer match to opening a specific pre-registered stash by id, as opposed
-- to `OpenInventory` which opens the player's own inventory when no identifier is given.
function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    origin:OpenInventoryById(src, id)
    return true
end

local function mapShopItems(items)
    if type(items) ~= 'table' then return {} end

    local mapped = {}

    for i = 1, #items do
        local entry = items[i]
        if type(entry) == 'table' and entry.name then
            mapped[#mapped + 1] = {
                name = entry.name,
                price = entry.price,
                amount = entry.count or 0,
                metadata = entry.metadata or {},
            }
        end
    end

    return mapped
end

-- Accepts ox-format `shopData`; maps `inventory` items to origen's `amount` field
-- (createShop, aliased RegisterShop) and `coords`/`locations` to origen's `locations` array.
function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}

    local locations = shopData.locations
    if not locations and shopData.coords then
        locations = { shopData.coords }
    end

    origin:createShop(shopType, {
        label = shopData.label or shopData.name or shopType,
        slots = shopData.slots,
        items = mapShopItems(shopData.inventory),
        locations = locations,
    })

    return true
end

-- origen_inventory's shops are accessed via registered world point locations, not a
-- server-forced open export — `OpenInventory`/`OpenInventoryById` are only documented for
-- stash/trunk/glovebox.
function inventory.openShop(src, shopType)
    return false
end

function inventory.registerHook(eventName, callback, options)
    return origin:registerHook(eventName, callback, options)
end

function inventory.removeHooks(hookId)
    return origin:removeHooks(hookId)
end

return inventory
