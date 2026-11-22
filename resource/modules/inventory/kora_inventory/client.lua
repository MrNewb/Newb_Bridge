-- kora_inventory provider (client). Reads the local PlayerData mirror kora_core
-- replicates and kora_core's shared item registry; it does not depend on the
-- ox_inventory or qb-inventory compatibility identities.

local inventory = {}

local core = exports.kora_core

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

local function playerItems()
    return core:getInventory() or {}
end

local function countItem(item, metadata)
    local total = 0

    for _, itemData in pairs(playerItems()) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
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

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, itemDefinition(itemName), 'kora_inventory', 'images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, itemDefinition(itemName), 'kora_inventory', 'images')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(playerItems())
end

return inventory
