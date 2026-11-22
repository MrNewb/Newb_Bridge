-- kora_inventory provider (server). Uses kora_inventory's native exports and
-- kora_core's shared item registry; it does not depend on the ox_inventory or
-- qb-inventory compatibility identities.
--
-- Native item shape: { name, amount, info, slot }. Everything leaving this
-- module is converted to the bridge's ox shape ({ name, count, metadata, slot }).

local inventory = {}

local kora = exports.kora_inventory
local core = exports.kora_core

-- Slot counts of stashes registered through this module, used when a script adds
-- items to a stash directly. kora_inventory validates the range on write, so an
-- unknown stash falls back to DEFAULT_STASH_SLOTS and fails cleanly if too small.
local DEFAULT_STASH_SLOTS = 50
local stashSlots = {} ---@type table<string, number>
local stashWeight = {} ---@type table<string, number>

-- A shop row without a count is infinite in ox; kora shelves are finite.
local INFINITE_STOCK = 99999

-- ox groups are { jobOrGang = minGrade } with zero-based grades; kora_inventory
-- compares against kora_core's one-based grades.
local function koraGroups(groups)
    if type(groups) ~= 'table' then return nil end

    local converted = {}
    for name, grade in pairs(groups) do
        if type(name) == 'number' then
            converted[grade] = 1
        else
            converted[name] = (tonumber(grade) or 0) + 1
        end
    end

    return converted
end

-- kora_core accounts a shop may charge; ox allows any item as currency.
local ACCOUNT_CURRENCIES = { money = true, cash = true, bank = true, crypto = true }

-- ox resolves `metadata.image` ('vehicle_key_karin') by name and adds the extension itself.
-- kora_inventory's UI only uses a metadata image that already carries its file extension
-- and otherwise falls back to the item's own picture, so resolve the extension here.
-- URLs and values that already have an extension are left alone, as is a name with no
-- matching file in kora_inventory/images.
local imageFileCache = {} ---@type table<string, string|false>

local function resolveMetadataImage(image)
    if type(image) ~= 'string' or image == '' then return image end
    if image:find('^https?://') or image:find('^nui://') then return image end
    if image:lower():find('%.png$') or image:lower():find('%.webp$') or image:lower():find('%.jpe?g$') or image:lower():find('%.gif$') then
        return image
    end

    local cached = imageFileCache[image]
    if cached == nil then
        local found = InventoryFindImageFile('kora_inventory', 'images', image)
        cached = found and found:match('([^/]+)$') or false
        imageFileCache[image] = cached
    end

    return cached or image
end

---Copy of ox-format metadata with `image` resolved for kora_inventory (the caller's table is never changed).
local function koraMetadata(metadata)
    if type(metadata) ~= 'table' or type(metadata.image) ~= 'string' then return metadata end

    local copy = table.clone(metadata)
    copy.image = resolveMetadataImage(metadata.image)
    return copy
end

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function itemDefinition(itemName)
    if type(itemName) ~= 'string' then return nil end

    local name = itemName:lower()
    local def = core:getShared('items', name) or core:getShared('weapons', name)
    if type(def) ~= 'table' then return nil end

    def = table.clone(def)
    def.name = def.name or name
    if def.type == 'weapon' or name:find('^weapon_') then def.weapon = true end
    if def.ammoItem and not def.ammoName then def.ammoName = def.ammoItem end
    if def.imageUrl and not def.image then def.image = def.imageUrl end

    return def
end

local function isUnique(def)
    return def ~= nil and (def.unique == true or def.weapon == true)
end

local function metadataEquals(a, b)
    a, b = a or {}, b or {}
    return lib.table.matches(a, b)
end

---Slot-keyed item table of an inventory (player source or stash id).
local function inventoryItems(inv)
    if isPlayer(inv) then
        return kora:GetInventory(inv) or {}
    end

    return kora:GetStashItems(inv) or {}
end

local function countItems(inv, item, metadata)
    if isPlayer(inv) and not metadata then
        return kora:getItemCount(inv, item) or 0
    end

    local total = 0
    for _, itemData in pairs(inventoryItems(inv)) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

---Matching slots of one item, lowest slot first.
local function matchingSlots(inv, item, metadata)
    local slots = {}
    for slot, itemData in pairs(inventoryItems(inv)) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            slots[#slots + 1] = { slot = tonumber(itemData.slot) or tonumber(slot), amount = InventoryItemAmount(itemData) }
        end
    end

    table.sort(slots, function(a, b) return a.slot < b.slot end)
    return slots
end

-- Stashes have no add/remove export: read the slot map, edit it, write it back.
-- kora_inventory re-validates every row, slot range and the weight cap on write.
local function stashAdd(id, item, count, metadata, slot)
    metadata = koraMetadata(metadata)
    local def = itemDefinition(item)
    if not def then return false, 'invalid_item' end

    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false, 'invalid_amount' end

    local items = kora:GetStashItems(id) or {}
    local limit = stashSlots[id] or DEFAULT_STASH_SLOTS
    local unique = isUnique(def)

    local function nextFreeSlot()
        for candidate = 1, limit do
            if not items[candidate] then return candidate end
        end
    end

    if slot and not unique then
        local existing = items[slot]
        if existing and (existing.name ~= item or not metadataEquals(InventoryItemMetadata(existing), metadata)) then
            return false, 'slot_occupied'
        end
    end

    local remaining = count

    if not unique then
        local target = slot
        if not target then
            for candidate, itemData in pairs(items) do
                if itemData.name == item and metadataEquals(InventoryItemMetadata(itemData), metadata) then
                    target = tonumber(candidate)
                    break
                end
            end
        end

        if target and items[target] then
            items[target].amount = InventoryItemAmount(items[target]) + remaining
            remaining = 0
        end
    end

    while remaining > 0 do
        local free = (slot and not items[slot] and slot) or nextFreeSlot()
        if not free then return false, 'no_free_slot' end

        local amount = unique and 1 or remaining
        items[free] = { name = item, amount = amount, info = metadata or {}, metadata = metadata or {} }
        remaining = remaining - amount
        slot = nil
    end

    local ok, reason = kora:SetStashItems(id, items)
    if not ok then return false, reason end
    return true
end

local function stashRemove(id, item, count, metadata, slot)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false, 'invalid_amount' end

    local items = kora:GetStashItems(id) or {}
    local remaining = count

    local function take(slotKey)
        local itemData = items[slotKey]
        if not itemData or itemData.name ~= item or remaining <= 0 then return end
        if not InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then return end

        local amount = InventoryItemAmount(itemData)
        local removed = math.min(amount, remaining)
        remaining = remaining - removed

        if removed >= amount then
            items[slotKey] = nil
        else
            itemData.amount = amount - removed
        end
    end

    if slot then
        take(slot)
    else
        for _, entry in ipairs(matchingSlots(id, item, metadata)) do
            take(entry.slot)
        end
    end

    if remaining > 0 then return false, 'not_enough_items' end

    local ok, reason = kora:SetStashItems(id, items)
    if not ok then return false, reason end
    return true
end

function inventory.Items(itemName)
    if itemName then
        return NormalizeItemDefinitions(itemDefinition(itemName), itemName)
    end

    local definitions = {}
    for _, registry in ipairs({ 'items', 'weapons' }) do
        for _, def in ipairs(core:allShared(registry) or {}) do
            if def.name and not definitions[def.name] then
                definitions[def.name] = itemDefinition(def.name)
            end
        end
    end

    return NormalizeItemDefinitions(definitions)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, itemDefinition(itemName), 'kora_inventory', 'images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, itemDefinition(itemName), 'kora_inventory', 'images')
end

function inventory.addItem(inv, item, count, metadata, slot)
    if isPlayer(inv) then
        return kora:addItem(inv, item, count or 1, slot, koraMetadata(metadata), 'Newb_Bridge')
    end

    return stashAdd(inv, item, count, metadata, slot)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    count = count or 1

    if not isPlayer(inv) then
        return stashRemove(inv, item, count, metadata, slot)
    end

    if slot or not metadata then
        return kora:removeItem(inv, item, count, slot, 'Newb_Bridge')
    end

    -- With a metadata filter, take from matching stacks only (lowest slot first).
    local remaining = count
    for _, entry in ipairs(matchingSlots(inv, item, metadata)) do
        if remaining <= 0 then break end

        local take = math.min(entry.amount, remaining)
        local ok, reason = kora:removeItem(inv, item, take, entry.slot, 'Newb_Bridge')
        if not ok then return false, reason end
        remaining = remaining - take
    end

    if remaining > 0 then return false, 'not_enough_items' end
    return true
end

function inventory.hasItem(inv, item, count, metadata)
    if isPlayer(inv) and not metadata then
        return kora:hasItem(inv, item, count or 1) == true
    end

    return countItems(inv, item, metadata) >= (count or 1)
end

function inventory.getItemCount(inv, item, metadata)
    return countItems(inv, item, metadata)
end

function inventory.getInventoryItems(inv)
    return NormalizeInventoryItems(inventoryItems(inv))
end

function inventory.getSlot(inv, slot)
    slot = tonumber(slot)
    if not slot then return nil end

    if isPlayer(inv) then
        return NormalizeInventoryItem(kora:getItemBySlot(inv, slot), slot)
    end

    return NormalizeInventoryItem(inventoryItems(inv)[slot], slot)
end

function inventory.setMetadata(inv, slot, metadata)
    slot = tonumber(slot)
    if not slot or type(metadata) ~= 'table' then return false end

    local items = inventoryItems(inv)
    local itemData = items[slot]
    if not itemData then return false end

    metadata = koraMetadata(metadata)
    itemData.info = metadata
    itemData.metadata = metadata

    if isPlayer(inv) then
        return kora:SetInventory(inv, items) == true
    end

    return kora:SetStashItems(inv, items) == true
end

function inventory.clearInventory(inv, keep)
    if isPlayer(inv) then
        return kora:ClearInventory(inv, keep) == true
    end

    if keep == nil then
        return kora:SetStashItems(inv, nil) == true
    end

    local keepSet = {}
    if type(keep) == 'string' then
        keepSet[keep] = true
    else
        for _, name in ipairs(keep) do keepSet[name] = true end
    end

    local items = inventoryItems(inv)
    for slot, itemData in pairs(items) do
        if not keepSet[itemData.name] then items[slot] = nil end
    end

    return kora:SetStashItems(inv, items) == true
end

function inventory.canCarryItem(inv, item, count, metadata)
    count = count or 1

    if isPlayer(inv) then
        return kora:canCarry(inv, item, count) == true
    end

    local def = itemDefinition(item)
    if not def then return false end

    local items = inventoryItems(inv)
    local limit = stashSlots[inv] or DEFAULT_STASH_SLOTS

    -- Weight is only known for stashes registered through this module.
    local maxWeight = stashWeight[inv]
    if maxWeight then
        local used = 0
        for _, itemData in pairs(items) do
            local itemDef = itemDefinition(itemData.name)
            used = used + (itemData.weight or (itemDef and itemDef.weight) or 0) * InventoryItemAmount(itemData)
        end
        if used + (def.weight or 0) * count > maxWeight then return false end
    end

    if not isUnique(def) then
        for _, itemData in pairs(items) do
            if itemData.name == item and metadataEquals(InventoryItemMetadata(itemData), metadata) then
                return true
            end
        end
    end

    local free = 0
    for slot = 1, limit do
        if not items[slot] then free = free + 1 end
    end

    return free >= (isUnique(def) and count or 1)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    if type(id) ~= 'string' or id == '' then return false end

    local key = kora:registerStash(id, label, slots, maxWeight, owner, koraGroups(groups), coords)
    if not key then return false end

    if slots then stashSlots[id] = slots end
    if maxWeight then stashWeight[id] = maxWeight end

    return true
end

-- Gate distance/restrictions before calling.
function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    return kora:stashOpen(src, id) ~= false
end

local function mapShopRows(rows)
    local mapped = {}
    if type(rows) ~= 'table' then return mapped end

    for i = 1, #rows do
        local entry = rows[i]
        if type(entry) == 'table' and entry.name then
            local count = tonumber(entry.count)
            mapped[#mapped + 1] = {
                name = entry.name,
                amount = (count and count > 0) and count or INFINITE_STOCK,
                price = entry.price or 0,
                info = koraMetadata(entry.metadata),
            }
        end
    end

    return mapped
end

-- Accepts ox-format `shopData`. Omits coords so script-gated opens are not
-- blocked by a distance check. Per-row item currencies are not supported by
-- kora_inventory: a shop charges one kora_core account (`shopData.currency`).
function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}
    local rows = mapShopRows(shopData.inventory)

    local data = {
        label = shopData.label or shopData.name or shopType,
        slots = math.max(#rows, 1),
        weightLimit = false,
        inventory = rows,
        groups = koraGroups(shopData.groups),
    }

    if ACCOUNT_CURRENCIES[shopData.currency] then data.currency = shopData.currency end

    local key = kora:RegisterShop(shopType, data)
    return key ~= nil
end

-- Gate distance/restrictions before calling.
function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    return kora:OpenInventory(src, shopType, { type = 'shop', id = shopType }) ~= false
end

-- Hooks are registered under the bridge resource (a non-kora owner), so kora_inventory
-- delivers ox-style payloads. This keeps every payload in the bridge's ox shape:
-- slot tables use count/metadata (never amount/info) and keep extras such as
-- price/currency, and createItem's `item` stays an ox item definition (the shared
-- NormalizeHookPayload would turn it into a slot and drop stack/close/client).
local function toOxSlot(slot)
    if type(slot) ~= 'table' then return slot end

    local out = table.clone(slot)
    out.count = out.count or out.amount
    out.amount = nil

    local metadata = out.metadata
    if type(metadata) ~= 'table' then metadata = out.info end
    out.metadata = type(metadata) == 'table' and metadata or {}
    out.info = nil

    return out
end

local function normalizeHookPayload(eventName, payload)
    if type(payload) ~= 'table' then return payload end

    local out = table.clone(payload)

    if eventName == 'swapItems' then
        out.fromSlot = toOxSlot(payload.fromSlot)
        out.toSlot = toOxSlot(payload.toSlot)
    elseif eventName == 'buyItem' then
        out.fromSlot = toOxSlot(payload.fromSlot)
        out.metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    elseif eventName == 'usingItem' then
        out.item = toOxSlot(payload.item)
    elseif eventName == 'openShop' then
        if type(payload.items) == 'table' then
            out.items = {}
            for slot, row in pairs(payload.items) do out.items[slot] = toOxSlot(row) end
        end
    elseif eventName == 'createItem' then
        out.metadata = type(payload.metadata) == 'table' and payload.metadata or {}
        if type(payload.item) == 'table' then
            local item = table.clone(payload.item)
            for key, value in pairs(NormalizeItemDefinitions(payload.item, payload.itemName) or {}) do
                item[key] = value
            end
            out.item = item
        end
    end

    return out
end

function inventory.registerHook(eventName, callback, options)
    if type(callback) == 'function' then
        local handler = callback
        callback = function(payload, source)
            return handler(normalizeHookPayload(eventName, payload), source)
        end
    end

    return kora:RegisterHook(eventName, callback, options)
end

function inventory.removeHooks(hookId)
    return kora:RemoveHooks(hookId)
end

return inventory
