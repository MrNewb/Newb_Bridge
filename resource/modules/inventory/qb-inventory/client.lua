local inventory = {}

local qbi = exports['qb-inventory']
local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local function countItem(item, metadata)
    local items = QBCore.Functions.GetPlayerData().items
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
    if itemName then
        return NormalizeItemDefinitions(QBCore.Shared.Items[itemName], itemName)
    end

    return NormalizeItemDefinitions(QBCore.Shared.Items)
end

function inventory.hasItem(item, count, metadata)
    if metadata then
        return countItem(item, metadata) >= (count or 1)
    end

    return qbi:HasItem(item, count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'qb-inventory', 'html/images')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'qb-inventory', 'html/images')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return NormalizeInventoryItems(QBCore.Functions.GetPlayerData().items or {})
end

return inventory
