local inventory = {}

local jaksam = exports['jaksam_inventory']

function inventory.Items(itemName)
    if itemName then
        return NormalizeItemDefinitions(jaksam:getStaticItem(itemName), itemName)
    end

    return NormalizeItemDefinitions(jaksam:getStaticItemsList())
end

function inventory.hasItem(item, count, metadata)
    return jaksam:getTotalItemAmount(item, metadata) >= (count or 1)
end

function inventory.getImagePath(itemName)
    local item = NormalizeItemDefinition(itemName, jaksam:getStaticItem(itemName))
    local image = InventoryItemImage(item)

    if type(image) == 'string' and (image:find('^nui://', 1, false) or image:find('^https?://', 1, false)) then
        return image
    end

    return InventoryBuildImageUrl(itemName, item, 'jaksam_inventory')
end

function inventory.getItemInfo(itemName)
    local item = NormalizeItemDefinition(itemName, jaksam:getStaticItem(itemName))
    return InventoryBuildItemInfo(itemName, item, 'jaksam_inventory')
end

function inventory.getItemCount(item, metadata)
    return jaksam:getTotalItemAmount(item, metadata)
end

function inventory.getInventoryItems()
    local inv = jaksam:getInventory()
    return NormalizeInventoryItems(inv and inv.items or {})
end

return inventory
