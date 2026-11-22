-- Shared inventory helpers loaded before every provider module.

local function InventoryItemMetadata(itemData)
    if type(itemData) ~= 'table' then return {} end

    return itemData.metadata or itemData.info or {}
end

local function InventoryItemAmount(itemData)
    if type(itemData) ~= 'table' then return 0 end

    return itemData.count or itemData.amount or 0
end

-- Uses `lib.table.contains` for partial matching (ox default) or `lib.table.matches` when strict.
local function InventoryMetadataMatches(itemMetadata, filterMetadata, strict)
    if not filterMetadata then return true end

    itemMetadata = itemMetadata or {}
    local tablematch = strict and lib.table.matches or lib.table.contains

    return tablematch(itemMetadata, filterMetadata)
end

local function NormalizeInventoryItem(itemData, slotFallback)
    if type(itemData) ~= 'table' or not itemData.name then return nil end

    local slot = itemData.slot or slotFallback
    if type(slot) == 'string' then
        -- jaksam_inventory keys its item list by "SLOT-<n>" strings instead of plain numbers.
        slot = tonumber(slot:match('^SLOT%-(%d+)$') or slot)
    end

    local metadata = itemData.metadata or itemData.info
    if type(metadata) ~= 'table' then
        metadata = {}
    end

    local normalized = {
        name = itemData.name,
        count = itemData.count or itemData.amount or 0,
        slot = slot,
        metadata = metadata,
    }

    if itemData.label then normalized.label = itemData.label end
    if itemData.weight then normalized.weight = itemData.weight end
    if itemData.durability ~= nil then normalized.durability = itemData.durability end

    return normalized
end

local function NormalizeInventoryItems(items)
    if type(items) ~= 'table' then return {} end

    local normalized = {}

    if items[1] then
        for i = 1, #items do
            local item = NormalizeInventoryItem(items[i])
            if item then
                normalized[#normalized + 1] = item
            end
        end
    else
        for slotKey, itemData in pairs(items) do
            local item = NormalizeInventoryItem(itemData, slotKey)
            if item then
                normalized[#normalized + 1] = item
            end
        end
    end

    table.sort(normalized, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)

    return normalized
end

local function NormalizeItemDefinition(itemName, itemData)
    if type(itemData) ~= 'table' then return nil end

    local name = itemData.name or itemName
    if not name then return nil end

    local stack = itemData.stack
    if stack == nil and itemData.unique ~= nil then
        stack = not itemData.unique
    end
    if stack == nil and itemData.stackable ~= nil then
        stack = itemData.stackable
    end

    local close = itemData.close
    if close == nil and itemData.shouldClose ~= nil then
        close = itemData.shouldClose
    end

    local normalized = {
        name = name,
        label = itemData.label or name,
        weight = itemData.weight or 0,
        stack = stack ~= false,
        close = close == true,
        description = itemData.description,
    }

    if itemData.client then normalized.client = itemData.client end
    if itemData.consume ~= nil then normalized.consume = itemData.consume end
    if itemData.degrade ~= nil then normalized.degrade = itemData.degrade end
    if itemData.durability ~= nil then normalized.durability = itemData.durability end
    if itemData.weapon ~= nil then normalized.weapon = itemData.weapon end
    if itemData.ammoName or itemData.ammo or itemData.ammoname then
        normalized.ammoName = itemData.ammoName or itemData.ammo or itemData.ammoname
    end
    if itemData.image and not (normalized.client and normalized.client.image) then
        normalized.client = normalized.client or {}
        normalized.client.image = itemData.image
    end

    return normalized
end

local function NormalizeItemDefinitions(items, itemName)
    if type(items) ~= 'table' then return nil end

    if itemName then
        -- Providers pass either the single item definition or the whole item
        -- list keyed by name. A single definition never has a field named after
        -- the item, so an itemName-keyed table means we were handed the list.
        local entry = items[itemName]
        if type(entry) == 'table' then
            return NormalizeItemDefinition(itemName, entry)
        end

        return NormalizeItemDefinition(itemName, items)
    end

    local normalized = {}

    for name, itemData in pairs(items) do
        if type(itemData) == 'table' then
            normalized[name] = NormalizeItemDefinition(name, itemData)
        end
    end

    return normalized
end

local function InventoryItemImage(itemData)
    if type(itemData) ~= 'table' then return nil end

    if itemData.client and itemData.client.image then
        return itemData.client.image
    end

    return itemData.image
end

local function InventoryStripImageExtension(value)
    if type(value) ~= 'string' or value == '' then return '' end

    return value
        :gsub('%.png$', '')
        :gsub('%.webp$', '')
        :gsub('%.jpg$', '')
        :gsub('%.jpeg$', '')
end

-- Every LoadResourceFile call costs about 0.8 ms, even when the file does not exist, and one item lookup makes several.
-- An image either exists or it does not for as long as its resource runs, so each answer is kept (false = not found)
-- and dropped when the resource that owns the images starts again.
local imageFileCache = {}

AddEventHandler('onResourceStart', function(startedResource)
    imageFileCache[startedResource] = nil
end)

local function InventoryFindImageFile(resource, imageDir, filename)
    if type(filename) ~= 'string' or filename == '' then return nil end

    if filename:find('^nui://', 1, false) or filename:find('^https?://', 1, false) then
        return filename
    end

    local resourceCache = imageFileCache[resource]
    if not resourceCache then
        resourceCache = {}
        imageFileCache[resource] = resourceCache
    end

    local cacheKey = imageDir .. '|' .. filename
    local cached = resourceCache[cacheKey]
    if cached ~= nil then return cached or nil end

    local base = InventoryStripImageExtension(filename)
    local checks = {}

    if filename:find('%.', 1, true) then
        checks[#checks + 1] = ('%s/%s'):format(imageDir, filename)
    end

    if base ~= '' then
        checks[#checks + 1] = ('%s/%s.png'):format(imageDir, base)
        checks[#checks + 1] = ('%s/%s.webp'):format(imageDir, base)
    end

    for i = 1, #checks do
        if LoadResourceFile(resource, checks[i]) then
            resourceCache[cacheKey] = checks[i]
            return checks[i]
        end
    end

    resourceCache[cacheKey] = false
    return nil
end

local function InventoryImageNuiUrl(resource, relativePath)
    return ('nui://%s/%s'):format(resource, relativePath)
end

local function InventoryBuildImageUrl(itemName, itemData, resource, imageDir)
    resource = resource or 'ox_inventory'
    imageDir = imageDir or 'web/images'

    if type(itemData) == 'table' then
        itemData = NormalizeItemDefinition(itemName, itemData) or itemData
    end

    local defImage = InventoryItemImage(itemData)
    if type(defImage) == 'string' and defImage ~= '' and not defImage:find('fa%-', 1, false) then
        local resolved = InventoryFindImageFile(resource, imageDir, defImage)
        if resolved then
            if resolved:find('^nui://', 1, false) or resolved:find('^https?://', 1, false) then
                return resolved
            end

            return InventoryImageNuiUrl(resource, resolved)
        end
    end

    local itemFallback = InventoryFindImageFile(resource, imageDir, itemName)
    if itemFallback then
        if itemFallback:find('^nui://', 1, false) or itemFallback:find('^https?://', 1, false) then
            return itemFallback
        end

        return InventoryImageNuiUrl(resource, itemFallback)
    end

    local filename = defImage or itemName
    if type(filename) ~= 'string' or filename == '' then
        filename = itemName
    end

    if filename:find('^nui://', 1, false) or filename:find('^https?://', 1, false) then
        return filename
    end

    if not filename:find('%.', 1, false) then
        filename = filename .. '.png'
    end

    return InventoryImageNuiUrl(resource, ('%s/%s'):format(imageDir, filename))
end

local function InventoryBuildItemInfo(itemName, itemData, resource, imageDir)
    if type(itemData) == 'table' then
        itemData = NormalizeItemDefinition(itemName, itemData) or itemData
    end

    itemData = itemData or {}

    return {
        name = itemData.name or itemName,
        label = itemData.label or itemName,
        stack = itemData.stack ~= false,
        weight = itemData.weight or 0,
        description = itemData.description,
        image = InventoryBuildImageUrl(itemName, itemData, resource, imageDir),
    }
end

local function NormalizeHookPayload(eventName, payload)
    if type(payload) ~= 'table' then return payload end

    local normalized = table.clone(payload)

    if eventName == 'swapItems' then
        if type(payload.fromSlot) == 'table' then
            normalized.fromSlot = NormalizeInventoryItem(payload.fromSlot)
        end

        if type(payload.toSlot) == 'table' then
            normalized.toSlot = NormalizeInventoryItem(payload.toSlot)
        end
    elseif eventName == 'createItem' then
        if type(payload.item) == 'table' then
            normalized.item = NormalizeInventoryItem(payload.item)
        end
    elseif eventName == 'usingItem' then
        if type(payload.item) == 'table' then
            normalized.item = NormalizeInventoryItem(payload.item)
        end
    end

    return normalized
end

local function WrapInventoryHookCallback(eventName, callback)
    if type(callback) ~= 'function' then return callback end

    return function(payload)
        return callback(NormalizeHookPayload(eventName, payload))
    end
end
