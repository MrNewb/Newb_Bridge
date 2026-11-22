-- whip_core inventory provider (client). Reads whip_core's local inventory mirror and item definitions. Weights are
-- converted from whip's kilograms to the bridge's grams, and the picture is looked up by item name in whip_core's own
-- folder (whip keeps a picture in the resource that registered the item and does not say which).

local inventory = {}

local whip = exports.whip_core

local function itemDefinition(itemName)
    if type(itemName) ~= 'string' then return nil end

    local def = whip:GetItemDef(itemName)
    if type(def) ~= 'table' then return nil end

    return {
        name = itemName,
        label = def.name or itemName,
        weight = (def.weight or 0) * 1000,
        stack = def.stack ~= false,
        description = def.desc,
    }
end

---Every stack the player carries as bridge items; accessory items have no bridge slot.
local function playerStacks()
    local stacks = {}
    local pockets = whip:GetInventory() or {}

    for _, pocket in ipairs({ 'player', 'accessory' }) do
        for slot, slotData in pairs(pockets[pocket] or {}) do
            local item = NormalizeInventoryItem({
                name = slotData.item,
                count = slotData.amount,
                metadata = slotData.metadata,
                slot = pocket == 'player' and tonumber(slot) or nil,
            })
            if item then
                if pocket ~= 'player' then item.pocket = pocket end
                stacks[#stacks + 1] = item
            end
        end
    end

    return stacks
end

local function countItem(item, metadata)
    if not metadata then return whip:GetItemCount(item) or 0 end

    local total = 0
    for _, stack in ipairs(playerStacks()) do
        if stack.name == item and InventoryMetadataMatches(stack.metadata, metadata) then
            total = total + stack.count
        end
    end
    return total
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

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, itemDefinition(itemName), 'whip_core', 'html/img/items')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, itemDefinition(itemName), 'whip_core', 'html/img/items')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    local stacks = playerStacks()
    table.sort(stacks, function(a, b) return (a.slot or math.huge) < (b.slot or math.huge) end)
    return stacks
end

return inventory
