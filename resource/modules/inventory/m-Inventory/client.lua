local inventory = {}

local m_inventory = exports['m-Inventory']

local function getPlayerItems()
    if m_inventory.GetPlayerItems then
        return m_inventory:GetPlayerItems() or {}
    end

    if m_inventory.GetInventoryItems then
        return m_inventory:GetInventoryItems() or {}
    end

    return {}
end

local function countItem(item, metadata)
    if m_inventory.Search then
        local count = m_inventory:Search('count', item, metadata)

        if count then
            return count
        end
    end

    if m_inventory.GetItemCount and not metadata then
        return m_inventory:GetItemCount(item) or 0
    end

    local total = 0

    for _, itemData in pairs(getPlayerItems()) do
        if itemData.name == item and InventoryMetadataMatches(InventoryItemMetadata(itemData), metadata) then
            total = total + InventoryItemAmount(itemData)
        end
    end

    return total
end

function inventory.Items(itemName)
    if itemName then
        if m_inventory.getItemData then
            return m_inventory:getItemData(itemName)
        end

        if m_inventory.Items then
            return m_inventory:Items(itemName)
        end

        return nil
    end

    if m_inventory.Items then
        return m_inventory:Items()
    end

    return nil
end

function inventory.hasItem(item, count, metadata)
    return countItem(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    return InventoryBuildImageUrl(itemName, inventory.Items(itemName), 'm-Inventory')
end

function inventory.getItemInfo(itemName)
    return InventoryBuildItemInfo(itemName, inventory.Items(itemName), 'm-Inventory')
end

function inventory.getItemCount(item, metadata)
    return countItem(item, metadata)
end

function inventory.getInventoryItems()
    return getPlayerItems()
end

return inventory
