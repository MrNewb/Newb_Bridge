-- Manual Config.Inventory only - not included in auto-detect.

local inventory = {}

-- GetCoreObject serializes the whole core every call, so cache the copy and
-- re-pull only when the framework reports a runtime Shared change.
local cachedCore

local function getCoreObject()
    if cachedCore then return cachedCore end

    if GetResourceState('qbx_core') == 'started' then
        cachedCore = exports.qbx_core:GetCoreObject()
    elseif GetResourceState('qb-core') == 'started' then
        cachedCore = exports['qb-core']:GetCoreObject()
    end

    return cachedCore
end

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    cachedCore = nil
end)

local function getPlayerData()
    local QBCore = getCoreObject()
    return QBCore and QBCore.Functions.GetPlayerData()
end

local function countItem(item, metadata)
    local data = getPlayerData()
    local items = data and data.items
    if not items then return 0 end

    local total = 0

    for _, itemData in pairs(items) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

function inventory.Items(itemName)
    local QBCore = getCoreObject()
    local list = QBCore and QBCore.Shared and QBCore.Shared.Items
    return NormalizeItemDefinitions(list, itemName)
end

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    if GetResourceState('qb-inventory') ~= 'missing' then
        return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'qb-inventory', 'html/images')
    end

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
    if GetResourceState('qb-inventory') ~= 'missing' then
        return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'qb-inventory', 'html/images')
    end

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

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    local data = getPlayerData()
    return NormalizeInventoryItems(data and data.items or {})
end

return inventory
