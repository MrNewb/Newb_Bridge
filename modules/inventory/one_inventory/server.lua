local inventory = {}

local one_inventory = exports.one_inventory

---@type table<string, { label: string, slots?: number, maxWeight?: number, owner?: string|boolean, groups?: table }>
local registeredStashes = {}

-- Plain stash ids from ox-style callers become one_inventory identifiers.
local function resolveInv(inv)
    if type(inv) == 'number' then return inv end
    if type(inv) ~= 'string' then return inv end
    if inv:find(':', 1, true) then return inv end

    return ('stash:%s'):format(inv)
end

function inventory.Items(itemName)
    if itemName then
        return one_inventory:GetItemDefinition(itemName)
    end

    return one_inventory:GetAllItemDefinitions()
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'one_inventory')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'one_inventory')
end

function inventory.addItem(inv, item, count, metadata, slot)
    return one_inventory:AddItem(resolveInv(inv), item, count, metadata, slot)
end

function inventory.removeItem(inv, item, count, metadata, slot)
    return one_inventory:RemoveItem(resolveInv(inv), item, count, metadata, slot)
end

function inventory.hasItem(inv, item, count, metadata)
    return one_inventory:HasItem(resolveInv(inv), item, count, metadata)
end

function inventory.getItemCount(inv, item, metadata)
    return one_inventory:GetItemCount(resolveInv(inv), item, metadata)
end

function inventory.getInventoryItems(inv)
    return one_inventory:GetInventoryItems(resolveInv(inv))
end

function inventory.setMetadata(inv, slot, metadata)
    return one_inventory:SetItemMetadata(resolveInv(inv), slot, metadata)
end

function inventory.getSlot(inv, slot)
    return one_inventory:GetSlot(resolveInv(inv), slot)
end

function inventory.clearInventory(inv, keep)
    return one_inventory:ClearInventory(resolveInv(inv), keep)
end

function inventory.canCarryItem(inv, item, count, metadata)
    return one_inventory:CanCarryItem(resolveInv(inv), item, count)
end

function inventory.registerStash(id, label, slots, maxWeight, owner, groups, coords)
    if type(id) ~= 'string' or id == '' then return false end

    registeredStashes[id] = {
        label = label or id,
        slots = slots,
        maxWeight = maxWeight,
        owner = owner,
        groups = groups,
    }

    return true
end

function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    local stash = registeredStashes[id]

    return one_inventory:OpenInventory(src, 'stash', {
        id = id,
        label = stash and stash.label,
        slots = stash and stash.slots,
        maxWeight = stash and stash.maxWeight,
        owner = stash and stash.owner,
        groups = stash and stash.groups,
    })
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
                count = entry.count or 0,
                metadata = entry.metadata,
            }
        end
    end

    return mapped
end

local function mapShopData(shopType, shopData)
    shopData = shopData or {}

    local payload = {
        name = shopType,
        label = shopData.label or shopData.name or shopType,
        inventory = mapShopItems(shopData.inventory),
    }

    if shopData.currency then
        payload.currency = shopData.currency
    end

    if shopData.jobs then
        payload.jobs = shopData.jobs
    elseif shopData.groups then
        payload.jobs = shopData.groups
    end

    if shopData.gangs then
        payload.gangs = shopData.gangs
    end

    if shopData.licenses then
        payload.licenses = shopData.licenses
    elseif shopData.license then
        payload.licenses = shopData.license
    end

    if shopData.coords then
        payload.coords = shopData.coords
    end

    if shopData.locations then
        payload.locations = shopData.locations
        if not payload.coords and shopData.locations[1] then
            payload.coords = shopData.locations[1]
        end
    end

    return payload
end

-- Accepts ox-format `shopData`; maps `groups` to `jobs`. Item `count` defaults to `0` (infinite stock).
function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    local registered = one_inventory:RegisterShop(mapShopData(shopType, shopData))
    if registered == false then return false end

    return true
end

-- Server-side open bypasses proximity/restrictions; gate access yourself before calling.
function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    return one_inventory:OpenInventory(src, 'shop', shopType)
end

function inventory.registerHook(eventName, callback, options)
    if one_inventory.registerHook then
        return one_inventory:registerHook(eventName, callback, options)
    end

    return false
end

function inventory.removeHooks(hookId)
    if one_inventory.removeHooks then
        return one_inventory:removeHooks(hookId)
    end
end

return inventory
