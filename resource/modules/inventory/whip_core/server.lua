-- whip_core inventory provider (server). Uses whip_core's inventory, store and container exports.
--
-- Everything leaving this module is converted to the bridge's ox shape ({ name, count, metadata, slot }).
-- Whip's pockets are 'player' (the slots the bridge numbers) and 'accessory'; accessory items are listed after them with
-- a `pocket` field and no slot, and are matched by every count and removal.
--
-- Stashes are whip containers kept at a hidden spot (the bridge never gives a stash a world presence); a stash's
-- coordinates and owner are ignored. Shops are whip shops with the 'infinite' mode: they need a real location to open
-- (whip checks the player is near the shop), so a shop registered without coords cannot be opened.
-- Whip has no inventory hooks, so registerHook returns nil.

local inventory = {}

local whip = exports.whip_core

local HIDDEN_COORDS = { x = 0.0, y = 0.0, z = -200.0 }
local KEY_PREFIX = 'bridge:'
local REASON = 'Newb_Bridge'

local containerIds = {} ---@type table<string, number> stash id -> whip containerId
local shopLocations = {} ---@type table<string, vector3|nil>

local function isPlayer(inv)
    return type(inv) == 'number'
end

local function stashKey(id)
    return (KEY_PREFIX .. id:gsub('[^%w_%-%.:]', '_')):sub(1, 100)
end

local function playerAddress(src, slot)
    return { kind = 'player', id = src, sub = 'player', slot = slot }
end

local function stashAddress(id, slot)
    local containerId = containerIds[id]
    if not containerId then return nil end
    return { kind = 'container', id = containerId, slot = slot }
end

local function address(inv, slot)
    if isPlayer(inv) then return playerAddress(inv, slot) end
    return stashAddress(inv, slot)
end

local function toBridgeItem(slotData, slot, pocket)
    if type(slotData) ~= 'table' then return nil end

    local item = NormalizeInventoryItem({
        name = slotData.item,
        count = slotData.amount,
        metadata = slotData.metadata,
        slot = slot,
    })
    if item and pocket and pocket ~= 'player' then item.pocket = pocket end
    return item
end

---Every stack of the inventory as bridge items. A stash is one pocket.
local function readStacks(inv)
    local stacks = {}

    if isPlayer(inv) then
        local pockets = whip:GetInventory(inv) or {}
        for _, pocket in ipairs({ 'player', 'accessory' }) do
            for slot, slotData in pairs(pockets[pocket] or {}) do
                local item = toBridgeItem(slotData, pocket == 'player' and tonumber(slot) or nil, pocket)
                if item then stacks[#stacks + 1] = item end
            end
        end
        return stacks
    end

    local addr = stashAddress(inv)
    if not addr then return stacks end

    for slot, slotData in pairs(whip:StoreRead(addr) or {}) do
        local item = toBridgeItem(slotData, tonumber(slot))
        if item then stacks[#stacks + 1] = item end
    end
    return stacks
end

local function matchingStacks(inv, item, metadata)
    local matches = {}
    for _, stack in ipairs(readStacks(inv)) do
        if stack.name == item and InventoryMetadataMatches(stack.metadata, metadata) then
            matches[#matches + 1] = stack
        end
    end
    return matches
end

local function sumStacks(stacks)
    local total = 0
    for _, stack in ipairs(stacks) do total = total + stack.count end
    return total
end

local function itemDefinition(itemName)
    if type(itemName) ~= 'string' then return nil end

    local def = whip:GetItemDef(itemName)
    if type(def) ~= 'table' then return nil end

    -- Whip weighs in kilograms, the bridge (like ox) in grams. `image` is left out on purpose: whip keeps an item's
    -- picture in the resource that registered the item (default html/img/items/<key>.png) and the definition does not say
    -- which one, so the picture is looked up by item name in whip_core's own folder, which holds the built-in items.
    return {
        name = itemName,
        label = def.name or itemName,
        weight = (def.weight or 0) * 1000,
        stack = def.stack ~= false,
        description = def.desc,
    }
end

local function imageUrl(itemName)
    return InventoryBuildImageUrl(itemName, itemDefinition(itemName), 'whip_core', 'html/img/items')
end

function inventory.Items(itemName)
    if itemName then
        return NormalizeItemDefinitions(itemDefinition(itemName), itemName)
    end

    local definitions = {}
    for name in pairs(whip:GetItemDefs() or {}) do
        definitions[name] = itemDefinition(name)
    end
    return NormalizeItemDefinitions(definitions)
end

function inventory.getImagePath(itemName)
    return imageUrl(itemName)
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, itemDefinition(itemName), 'whip_core', 'html/img/items')
end

function inventory.addItem(inv, item, count, metadata, slot)
    count = math.floor(tonumber(count) or 1)

    if isPlayer(inv) then
        return whip:AddItem(inv, item, count, metadata, { reason = REASON, noDrop = true }) ~= false
    end

    local addr = stashAddress(inv, slot)
    if not addr then return false end

    return whip:StoreGive(addr, item, count, metadata, REASON) ~= false
end

function inventory.removeItem(inv, item, count, metadata, slot)
    count = math.floor(tonumber(count) or 1)

    if slot then
        local addr = address(inv, slot)
        if not addr then return false end
        return whip:StoreTake(addr, count, { item = item, metadata = metadata, reason = REASON }) ~= false
    end

    if isPlayer(inv) then
        return whip:RemoveItem(inv, item, count, metadata, { reason = REASON }) == true
    end

    local addr = stashAddress(inv)
    if not addr then return false end

    return whip:StoreTake(addr, count, { item = item, metadata = metadata, reason = REASON }) ~= false
end

function inventory.hasItem(inv, item, count, metadata)
    count = count or 1

    if isPlayer(inv) and not metadata then
        return whip:HasItem(inv, item, count) == true
    end

    return sumStacks(matchingStacks(inv, item, metadata)) >= count
end

function inventory.getItemCount(inv, item, metadata)
    if isPlayer(inv) and not metadata then
        return whip:GetItemCount(inv, item) or 0
    end

    return sumStacks(matchingStacks(inv, item, metadata))
end

function inventory.getInventoryItems(inv)
    local stacks = readStacks(inv)
    table.sort(stacks, function(a, b) return (a.slot or math.huge) < (b.slot or math.huge) end)
    return stacks
end

function inventory.getSlot(inv, slot)
    slot = tonumber(slot)
    local addr = slot and address(inv, slot)
    if not addr then return nil end

    return toBridgeItem(whip:GetItemAt(addr), slot)
end

function inventory.setMetadata(inv, slot, metadata)
    slot = tonumber(slot)
    local addr = slot and address(inv, slot)
    if not addr or type(metadata) ~= 'table' then return false end

    return whip:SetItemMetadata(addr, metadata, { reason = REASON }) == true
end

function inventory.clearInventory(inv, keep)
    local keepSet = {}
    if type(keep) == 'string' then
        keepSet[keep] = true
    elseif type(keep) == 'table' then
        for _, name in ipairs(keep) do keepSet[name] = true end
    end

    local cleared = true
    for _, stack in ipairs(readStacks(inv)) do
        if not keepSet[stack.name] then
            local addr = stack.slot and address(inv, stack.slot)

            if addr then
                cleared = whip:StoreTake(addr, stack.count, { reason = REASON }) ~= false and cleared
            else
                -- an accessory item has no bridge slot
                cleared = whip:RemoveItem(inv, stack.name, stack.count, stack.metadata, { reason = REASON }) == true and cleared
            end
        end
    end

    return cleared
end

function inventory.canCarryItem(inv, item, count, metadata)
    count = math.floor(tonumber(count) or 1)

    if isPlayer(inv) then
        return whip:CanFitItem(inv, item, count, metadata) == true
    end

    local containerId = containerIds[inv]
    local def = whip:GetItemDef(item)
    if not containerId or not def then return false end

    local container = whip:GetContainer(containerId)
    if not container then return false end

    local used, stacked, filled = 0, false, 0
    for _, stack in ipairs(readStacks(inv)) do
        local stackDef = whip:GetItemDef(stack.name)
        used = used + ((stackDef and stackDef.weight) or 0) * stack.count
        filled = filled + 1
        if stack.name == item and def.stack ~= false then stacked = true end
    end

    if container.maxWeight and used + (def.weight or 0) * count > container.maxWeight then return false end
    if stacked then return true end

    return filled < (container.slots or 0)
end

local function groupJobs(groups)
    if type(groups) == 'string' then return { groups } end
    if type(groups) ~= 'table' then return nil end

    local jobs = {}
    for name, grade in pairs(groups) do
        jobs[#jobs + 1] = type(name) == 'number' and grade or name
    end
    return #jobs > 0 and jobs or nil
end

function inventory.registerStash(id, label, slots, maxWeight, _, groups)
    if type(id) ~= 'string' or id == '' then return false end

    local requirements
    local jobs = groupJobs(groups)
    if jobs then requirements = { jobs = jobs } end

    local container = whip:EnsureContainer(stashKey(id), {
        x = HIDDEN_COORDS.x,
        y = HIDDEN_COORDS.y,
        z = HIDDEN_COORDS.z,
        name = label or id,
        slots = slots,
        maxWeight = maxWeight and maxWeight / 1000 or nil, -- grams in, kilograms in whip
        requirements = requirements,
    })
    if not container then return false end

    containerIds[id] = container.containerId
    return true
end

-- Gate distance/restrictions before calling.
function inventory.openStash(src, id)
    if type(src) ~= 'number' or type(id) ~= 'string' or id == '' then return false end

    local addr = stashAddress(id)
    if not addr then return false end

    return whip:OpenStore(src, addr, { skipDistance = true, skipAccess = true }) == true
end

function inventory.registerShop(shopType, shopData)
    if type(shopType) ~= 'string' or shopType == '' then return false end

    shopData = shopData or {}

    local catalog = {}
    for _, row in ipairs(shopData.inventory or {}) do
        if type(row) == 'table' and row.name then catalog[row.name] = math.floor(tonumber(row.price) or 0) end
    end

    local location = shopData.coords or (shopData.locations and shopData.locations[1])
    shopLocations[shopType] = location

    local shop = whip:EnsureShop(('%s%s'):format(KEY_PREFIX, shopType), {
        name = shopData.label or shopData.name or shopType,
        mode = 'infinite',
        x = location and location.x or HIDDEN_COORDS.x,
        y = location and location.y or HIDDEN_COORDS.y,
        z = location and location.z or HIDDEN_COORDS.z,
        catalog = catalog,
    })

    return shop ~= false
end

-- Gate distance/restrictions before calling. Whip lets a player open a shop only within `range` of it.
function inventory.openShop(src, shopType)
    if type(src) ~= 'number' or type(shopType) ~= 'string' or shopType == '' then return false end

    if not shopLocations[shopType] then
        lib.print.warn(('Whip shop "%s" was registered without coordinates, so a player cannot be near it. Give registerShop a `coords` or `locations`.'):format(shopType))
        return false
    end

    return whip:OpenShop(src, { key = ('%s%s'):format(KEY_PREFIX, shopType) }, { range = 20.0 }) == true
end

function inventory.registerHook()
    return nil
end

function inventory.removeHooks() end

return inventory
