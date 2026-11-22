-- Derived from Renewed-Lib <https://github.com/Renewed-Scripts/Renewed-Lib>
-- Copyright (C) Renewed Scripts (FjamZoo et al.) -- GPL-3.0
--
-- Modified for Newb_Bridge. Changes: renamed variables for consistency, added
-- missing native parameters, replaced the deprecated ox_lib raycast camera export
-- with the shared camera_ray helper, reworked the showtext UI to serve multiple
-- systems, moved placement text into locales, and swapped ox_lib model request
-- exports for bridge functions.
-- GPL-3.0-only <https://www.gnu.org/licenses/gpl-3.0.html>
-- See LICENSE and ATTRIBUTIONS.md in the Newb_Bridge repository.

local controls = require '@Newb_Bridge/resource/utility/client/placement_controls'
local ray = require '@Newb_Bridge/resource/utility/client/camera_ray'

local placing = false
local preview ---@type number|nil current preview entity
local raycastInterval = 0

local groundEpsilon = 0.04
local footBones = { 14201, 52301, 57717, 24806 } -- feet + toes

local markerPresets = {
    bouncing_arrow = {
        type = 2,
        scale = vector3(0.4, 0.4, 0.4),
        color = { 46, 204, 113, 220 },
        offset = { x = 0.0, y = 0.0, z = 0.45 },
        rotation = { x = 180.0, y = 0.0, z = 0.0 },
        bob = true,
        faceCamera = true,
    },
}

-- movement/combat controls blocked while the placer is up
local blockedControls = {
    21, 22, 23, 24, 25, 36, 44, 45, 47, 55, 58, 75,
    140, 141, 142, 143, 257, 263, 264, 200, 201, 322,
}

local localeKeys = {
    'status_ready', 'status_invalid_material', 'status_too_far', 'status_aiming',
    'position', 'heading', 'distance', 'controls',
    'controls_position', 'controls_preview', 'controls_actions', 'animation',
    'cycle_animation', 'clear_animation', 'raise_lower', 'cycle_model',
    'toggle_preview_mode', 'preview_mode_position', 'preview_mode_model',
    'preview_mode_animation', 'toggle_gizmo',
    'exit', 'finish', 'undo', 'debug',
}

local function justPressed(control)
    return IsDisabledControlJustPressed(0, control) or IsControlJustPressed(0, control)
end

local function placerLocales(placementType)
    local strings = {}
    for i = 1, #localeKeys do
        strings[localeKeys[i]] = bridge.locale('placer.' .. localeKeys[i])
    end

    local suffix = (placementType == 'ped' or placementType == 'vehicle') and ('_' .. placementType) or ''
    strings.title = bridge.locale('placer.title' .. suffix)
    strings.subtitle = bridge.locale('placer.subtitle' .. suffix)
    strings.rotate = bridge.locale('placer.rotate' .. suffix)
    strings.place = bridge.locale('placer.place' .. suffix)

    return strings
end

local function openUI(ui)
    local strings = placerLocales(ui.placementType)
    if type(ui.localeOverrides) == 'table' then
        for key, value in pairs(ui.localeOverrides) do
            if type(value) == 'string' then strings[key] = value end
        end
    end

    SendNUIMessage({
        type = 'placer:open',
        modelLabel = ui.modelLabel,
        maxDistance = ui.maxDistance,
        placementType = ui.placementType,
        animationCycling = ui.animationCycling == true,
        modelCycling = ui.modelCycling == true,
        pedVerticalAdjust = ui.placementType == 'ped',
        adjustmentMode = ui.adjustmentMode,
        adjustmentModeToggleAvailable = ui.canToggleMode == true,
        gizmoToggleAvailable = ui.gizmoToggleAvailable == true,
        multiPlace = ui.multiPlace == true,
        maxPlacements = ui.maxPlacements,
        placedCount = ui.placedCount or 0,
        debug = Config.Debug == true,
        locales = strings,
    })
end

local function closeUI()
    SendNUIMessage({ type = 'placer:close' })
end

local rayFlagsFull = 511 -- intersect everything

-- Shared camera cast, re-ordered to the placer's (hit, entity, coords, material)
-- convention. The trailing normal is kept for surface-aware callers.
local function raycastFromCamera(maxDistance, ignoreEntity, rayFlags, skipObjectEntities)
    local hit, coords, entity, material, normal = ray.cast(maxDistance, ignoreEntity, rayFlags, skipObjectEntities)
    return hit, entity, coords, material, normal
end

local function startingCoords(maxDistance, ignoreEntity, rayFlags, skipObjectEntities)
    local hit, _, coords, material = raycastFromCamera(maxDistance, ignoreEntity, rayFlags, skipObjectEntities)
    if hit and coords then
        return coords, material, true
    end

    local pedCoords = GetEntityCoords(cache.ped, false)
    local probe = pedCoords + (GetEntityForwardVector(cache.ped) * 3.0)
    local found, groundZ = GetGroundZFor_3dCoord(probe.x, probe.y, probe.z + 2.0, false)

    if found then
        return vector3(probe.x, probe.y, groundZ + groundEpsilon), material, false
    end

    return vector3(probe.x, probe.y, pedCoords.z - 0.95), material, false
end

local function pedFeetZ(ped)
    local lowest

    for i = 1, #footBones do
        local foot = GetPedBoneCoords(ped, footBones[i], 0.0, 0.0, 0.0)
        if not lowest or foot.z < lowest then
            lowest = foot.z
        end
    end

    return lowest or select(3, GetEntityCoords(ped))
end

-- lifts a ped so its lowest foot bone clears the surface instead of clipping
local function alignFeet(ped, surfaceZ)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local delta = (surfaceZ + 0.03) - pedFeetZ(ped)
    if delta <= 0.0005 then return end

    local coords = GetEntityCoords(ped)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + delta, false, false, false)
end

local function groundOffset(modelHash, placementType, override)
    if override == false or override == 'measure' then return 0.0 end
    if type(override) == 'number' then return override end

    if placementType == 'ped' then return 0.0 end

    local minDim = GetModelDimensions(modelHash)
    return minDim and -minDim.z or 0.0
end

-- snaps to ground when asked, then lifts by the model's ground offset
local function resolveCoords(modelHash, coords, forceGround, placementType, offsetOverride)
    if forceGround then
        local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
        if found then
            coords = vector3(coords.x, coords.y, groundZ + groundEpsilon)
        end
    end

    local offset = groundOffset(modelHash, placementType, offsetOverride)
    if offset == 0.0 then return coords end

    return vector3(coords.x, coords.y, coords.z + offset)
end

-- markers are always tables: { preset = 'bouncing_arrow' } or a custom shape with
-- offset/rotation/color nested. explicit fields win over the preset, and a bare
-- number offset is the z offset
local function resolveMarker(marker)
    if type(marker) ~= 'table' then return end

    local base = type(marker.preset) == 'string' and markerPresets[marker.preset] or {}

    local offset = marker.offset
    if type(offset) == 'number' then
        offset = { x = 0.0, y = 0.0, z = offset }
    elseif type(offset) ~= 'table' then
        offset = base.offset
    end

    local bob = marker.bob
    if bob == nil then bob = base.bob end
    local face = marker.faceCamera
    if face == nil then face = base.faceCamera end

    return {
        type = marker.type or base.type or 2,
        scale = marker.scale or base.scale,
        color = marker.color or base.color,
        offset = offset,
        rotation = type(marker.rotation) == 'table' and marker.rotation or base.rotation,
        bob = bob,
        faceCamera = face,
    }
end

local modelTopCache = {}

local function markerCoords(entity, placementType, marker)
    local off = marker.offset
    local ox = off and off.x or 0.0
    local oy = off and off.y or 0.0
    local oz = off and off.z or 0.35

    if placementType == 'ped' then
        local head = GetPedBoneCoords(entity, 31086, 0.0, 0.0, 0.0) -- skel_head
        return vector3(head.x + ox, head.y + oy, head.z + oz)
    end

    local model = GetEntityModel(entity)
    local top = modelTopCache[model]
    if not top then
        local _, maxDim = GetModelDimensions(model)
        top = maxDim and maxDim.z or 0.5
        modelTopCache[model] = top
    end

    local coords = GetEntityCoords(entity)
    return vector3(coords.x + ox, coords.y + oy, coords.z + top + oz)
end

local function drawStatusMarker(entity, placementType, marker, outline)
    if not marker then return end

    local coords = markerCoords(entity, placementType, marker)
    local color = marker.color or { 46, 204, 113, 220 }

    if outline == 'invalid' then
        color = { 250, 82, 82, 220 }
    elseif outline == 'far' then
        color = { 250, 176, 5, 220 }
    elseif outline == 'idle' then
        color = { 144, 144, 144, 200 }
    end

    local scale = marker.scale or vector3(0.4, 0.4, 0.4)
    local rot = marker.rotation

    DrawMarker(
        marker.type or 2,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        rot and rot.x or 0.0, rot and rot.y or 0.0, rot and rot.z or 0.0,
        scale.x, scale.y, scale.z,
        color[1], color[2], color[3], color[4],
        marker.bob == true, marker.faceCamera ~= false, 2,
        false, nil, nil, false
    )
end

local function resolveType(modelHash, placementType)
    placementType = placementType or 'auto'

    if placementType == 'ped' then
        return IsModelAPed(modelHash) and 'ped' or nil
    end

    if placementType == 'vehicle' then
        return IsModelAVehicle(modelHash) and 'vehicle' or nil
    end

    if placementType == 'prop' or placementType == 'object' then
        return 'prop'
    end

    if IsModelAPed(modelHash) then return 'ped' end
    if IsModelAVehicle(modelHash) then return 'vehicle' end

    return 'prop'
end

local function vehicleLabel(modelHash)
    local name = GetDisplayNameFromVehicleModel(modelHash)
    if not name or name == '' or name == 'CARNOTFOUND' then return end

    local label = GetLabelText(name)
    if not label or label == '' or label == 'NULL' then return end

    return label
end

local function spawnPreview(modelHash, coords, heading, placementType)
    if placementType == 'ped' then
        local ped = CreatePed(5, modelHash, coords.x, coords.y, coords.z, heading, false, false)
        if not ped or ped == 0 then return end

        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityInvincible(ped, true)
        SetPedCanRagdoll(ped, false)
        SetPedDefaultComponentVariation(ped)
        return ped
    end

    if placementType == 'vehicle' or IsModelAVehicle(modelHash) then
        local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, false, false)
        if not vehicle or vehicle == 0 then return end

        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        return vehicle
    end

    return CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
end

local function setupPreview(entity, placementType, alpha)
    SetEntityCollision(entity, false, false)

    if placementType == 'prop' or placementType == 'vehicle' then
        SetEntityCompletelyDisableCollision(entity, false, false)
        if DoesEntityExist(entity) then SetEntityDrawOutline(entity, true) end
    elseif placementType == 'ped' then
        SetBlockingOfNonTemporaryEvents(entity, true)
        SetEntityHasGravity(entity, false)
        SetPedCanRagdoll(entity, false)
    end

    SetEntityAlpha(entity, alpha, false)
    FreezeEntityPosition(entity, true)
end

local function setStatusColor(entity, placementType, outline)
    if placementType == 'ped' then
        local alpha = outline == 'ready' and 255 or outline == 'invalid' and 170 or outline == 'far' and 200 or 220
        SetEntityAlpha(entity, alpha, false)
        return
    end

    if outline == 'ready' then
        SetEntityDrawOutlineColor(84, 227, 129, 255)
    elseif outline == 'invalid' then
        SetEntityDrawOutlineColor(250, 82, 82, 255)
    elseif outline == 'far' then
        SetEntityDrawOutlineColor(250, 176, 5, 255)
    else
        SetEntityDrawOutlineColor(144, 144, 144, 255)
    end
end

local function resetVisuals(entity, placementType)
    if (placementType == 'prop' or placementType == 'vehicle') and DoesEntityExist(entity) then
        SetEntityDrawOutline(entity, false)
    end

    ResetEntityAlpha(entity)
end

local function moveTo(entity, coords, heading, placementType)
    SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(entity, heading)

    if placementType == 'ped' then
        alignFeet(entity, coords.z)
    elseif GetEntityType(entity) == 2 then
        SetVehicleOnGroundProperly(entity)
    end
end

local function setPedPreview(entity, base, heightOffset, heading)
    moveTo(entity, vector3(base.x, base.y, base.z + heightOffset), heading, 'ped')
    return GetEntityCoords(entity)
end

---@return PlacerPreviewBehaviorCycle|nil cycle
---@return PlacerPreviewBehavior|nil behavior
---@return boolean cycling
local function parseBehavior(previewBehavior)
    if type(previewBehavior) ~= 'table' then
        return nil, previewBehavior, false
    end

    if type(previewBehavior.options) == 'table' and #previewBehavior.options > 0 then
        local index = lib.math.clamp(math.floor(tonumber(previewBehavior.index) or 1), 1, #previewBehavior.options)
        local entry = previewBehavior.options[index]
        return previewBehavior, entry and entry.behavior or nil, true
    end

    return nil, previewBehavior, false
end

local function behaviorLabel(cycle, index)
    if not cycle or type(cycle.options) ~= 'table' then return '' end

    local entry = cycle.options[index]
    return entry and type(entry.label) == 'string' and entry.label or ''
end

local function playBehavior(entity, behavior)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 1 then return end

    if not behavior then
        ClearPedTasks(entity)
        return
    end

    local anim = behavior.anim
    if type(anim) == 'table' and anim.animDict and anim.anim then
        if not DoesAnimDictExist(anim.animDict) then return end

        ClearPedTasksImmediately(entity)
        lib.requestAnimDict(anim.animDict, 5000)
        TaskPlayAnim(entity, anim.animDict, anim.anim, anim.blendIn or 8.0, anim.blendOut or 8.0, anim.duration or -1, anim.flag or 1, 0, false, false, false)
        return
    end

    if type(behavior.scenario) == 'string' and behavior.scenario ~= '' then
        ClearPedTasksImmediately(entity)
        TaskStartScenarioInPlace(entity, behavior.scenario, 0, false)
    end
end

local function applyBehavior(entity, behavior, surfaceZ)
    playBehavior(entity, behavior)
    if surfaceZ then
        alignFeet(entity, surfaceZ)
    end
end

local placedPreviewPeds = {}

local function clearPlacedPreviewPeds()
    for i = 1, #placedPreviewPeds do
        local entity = placedPreviewPeds[i]
        if entity and DoesEntityExist(entity) then
            if GetEntityType(entity) == 2 then
                SetEntityDrawOutline(entity, false)
            end
            SetEntityAsMissionEntity(entity, false, false)
            DeleteEntity(entity)
        end
    end
    placedPreviewPeds = {}
end

local function spawnPlacedPreviewPed(modelHash, coords, heading, behavior)
    if not modelHash then return end

    local x = coords.x + 0.0
    local y = coords.y + 0.0
    local z = coords.z + 0.0
    local w = (heading or 0.0) + 0.0
    RequestCollisionAtCoord(x, y, z)

    local ped = CreatePed(5, modelHash, x, y, z, w, false, false)
    if not ped or ped == 0 then return end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDefaultComponentVariation(ped)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, false, false)
    SetEntityCompletelyDisableCollision(ped, false, false)
    SetEntityHasGravity(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, w)

    if type(behavior) == 'table' and type(behavior.scenario) == 'string' and behavior.scenario ~= ''
        and not (type(behavior.anim) == 'table' and behavior.anim.animDict and behavior.anim.anim)
    then
        ClearPedTasksImmediately(ped)
        TaskStartScenarioAtPosition(ped, behavior.scenario, x, y, z, w, -1, false, true)
    else
        playBehavior(ped, behavior)
    end

    placedPreviewPeds[#placedPreviewPeds + 1] = ped
    return ped
end

local function spawnPlacedPreviewVehicle(modelHash, coords, heading)
    if not modelHash then return end

    local x = coords.x + 0.0
    local y = coords.y + 0.0
    local z = coords.z + 0.0
    local w = (heading or 0.0) + 0.0
    RequestCollisionAtCoord(x, y, z)

    local vehicle = CreateVehicle(modelHash, x, y, z, w, false, false)
    if not vehicle or vehicle == 0 then return end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityInvincible(vehicle, true)
    SetVehicleDoorsLocked(vehicle, 2)
    SetEntityCollision(vehicle, false, false)
    SetEntityCompletelyDisableCollision(vehicle, false, false)
    FreezeEntityPosition(vehicle, true)
    ResetEntityAlpha(vehicle)
    SetEntityVisible(vehicle, true, false)
    if DoesEntityExist(vehicle) then
        SetEntityDrawOutline(vehicle, true)
        SetEntityDrawOutlineColor(84, 227, 129, 255)
    end
    SetVehicleEngineOn(vehicle, false, true, true)

    placedPreviewPeds[#placedPreviewPeds + 1] = vehicle
    return vehicle
end

local function spawnPlacedPreviewEntity(modelHash, coords, heading, behavior, placeType)
    if placeType == 'vehicle' then
        return spawnPlacedPreviewVehicle(modelHash, coords, heading)
    end
    return spawnPlacedPreviewPed(modelHash, coords, heading, behavior)
end

-- normalises the model argument into a list of valid entries
local function parseModels(model)
    if type(model) ~= 'table' then
        if type(model) == 'string' or type(model) == 'number' then
            return { model }
        end
        return
    end

    local models = {}
    for i = 1, #model do
        if type(model[i]) == 'string' or type(model[i]) == 'number' then
            models[#models + 1] = model[i]
        end
    end

    if #models > 0 then return models end
end

local function labelFor(entry, modelHash, placementType, index, total)
    local label = placementType == 'vehicle' and vehicleLabel(modelHash) or nil

    if not label then
        label = type(entry) == 'string' and entry or tostring(entry)
    end

    if total > 1 then
        return ('%s (%d/%d)'):format(label, index, total)
    end

    return label
end

local function drawPlacedMarkers(results, marker)
    if type(marker) ~= 'table' or type(results) ~= 'table' or #results == 0 then return end

    local radius = tonumber(marker.radius) or 0.2
    local diameter = radius * 2.0
    local color = marker.color or { 34, 139, 230, 100 }

    for i = 1, #results do
        local entry = results[i]
        if type(entry) == 'table' and entry.x and entry.y and entry.z then
            DrawMarker(
                28,
                entry.x, entry.y, entry.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                diameter, diameter, diameter,
                color[1] or 34, color[2] or 139, color[3] or 230, color[4] or 100,
                false, false, 2, false, nil, nil, false
            )
        end
    end
end

---@param model string | number | string[] | number[] | PlacerCallOptions Model(s) to place, or a single table carrying every argument (`{ model = ..., maxDistance = ..., multi = ... }`)
---@param forceGround boolean?
---@param allowedMaterials table<number, boolean>?
---@param maxDistance number?
---@param placementType string? 'auto' | 'ped' | 'prop' | 'vehicle'
---@param marker PlacerMarker|nil Optional head marker table (`{ preset = 'bouncing_arrow' }` or custom); may also ride in `options.marker`
---@param previewBehavior PlacerPreviewBehavior|PlacerPreviewBehaviorCycle|nil Optional ped animation/scenario preview while placing
---@param options PlacerOptions|nil `{ multi = true }` keeps the placer open until Backspace finishes the session
---@return table | false | nil result `{ x, y, z, w, pitch, roll }` (pitch/roll are 0.0 unless a prop was tilted with the gizmo), a cycling-variant table with `modelIndex`/`previewIndex` added, `{ multi = true, results = {...} }`, or `false`/`nil` when cancelled
local function propPlacer(model, forceGround, allowedMaterials, maxDistance, placementType, marker, previewBehavior, options)
    if type(model) == 'table' and model.model ~= nil then
        local call = model
        model = call.model
        forceGround = call.forceGround
        if forceGround == nil then forceGround = call.snapToGround end
        allowedMaterials = call.allowedMaterials
        maxDistance = call.maxDistance
        placementType = call.placementType or call.type
        marker = call.marker
        previewBehavior = call.previewBehavior
        options = type(call.options) == 'table' and call.options or call
    end

    if placing then
        bridge.notifications.notify({
            title = bridge.locale('common.error'),
            description = bridge.locale('placer.errors.already_placing'),
            type = 'error',
        })
        return false
    end

    maxDistance = maxDistance or 10.0
    forceGround = forceGround == true
    local multiPlace = type(options) == 'table' and options.multi == true
    local maxPlacements = type(options) == 'table' and math.floor(tonumber(options.maxPlacements) or 0) or 0
    if maxPlacements < 1 then maxPlacements = nil end
    local placedMarker = type(options) == 'table' and options.placedMarker or nil
    local placedPreview = type(options) == 'table' and type(options.placedPreview) == 'table' and options.placedPreview or nil
    local gizmoToggleAvailable = type(options) == 'table' and options.collisionToggle == true
    local heightAdjust = not (type(options) == 'table' and options.heightAdjust == false)
    local returnCancel = type(options) == 'table' and options.returnCancel == true
    local isPositionValid = type(options) == 'table' and type(options.isPositionValid) == 'function'
        and options.isPositionValid or nil
    local localeOverrides = type(options) == 'table' and type(options.localeOverrides) == 'table'
        and options.localeOverrides or nil
    local invalidPositionText = localeOverrides and localeOverrides.status_invalid_material or nil
    local offsetOverride
    if type(options) == 'table' then
        local go = options.groundOffset
        if go == false or go == 'measure' or type(go) == 'number' then offsetOverride = go end
    end
    local rotateSteps = { fine = 1.0, normal = 5.0, coarse = 22.5 }
    local rotateOverride = type(options) == 'table' and options.rotateStep or nil
    if type(rotateOverride) == 'number' then
        rotateSteps.normal = rotateOverride
    elseif type(rotateOverride) == 'table' then
        rotateSteps.fine = tonumber(rotateOverride.fine) or rotateSteps.fine
        rotateSteps.normal = tonumber(rotateOverride.normal) or rotateSteps.normal
        rotateSteps.coarse = tonumber(rotateOverride.coarse) or rotateSteps.coarse
    end
    local gizmoActive = false
    local multiResults = {}

    local allowedMats
    if allowedMaterials then
        allowedMats = {}
        for hash, allowed in pairs(allowedMaterials) do
            if allowed then allowedMats[hash] = true end
        end
    end

    local models = parseModels(model)
    if not models then
        lib.print.debug(bridge.locale('placer.debug_log.invalid_model'), model)
        return false
    end

    local modelIndex = 1
    local cyclingModels = #models > 1
    local currentModel = models[modelIndex]
    local modelHash = type(currentModel) == 'number' and currentModel or joaat(currentModel)

    if not IsModelValid(modelHash) then
        lib.print.debug(bridge.locale('placer.debug_log.invalid_model'), currentModel, modelHash)
        return false
    end

    local placeType = resolveType(modelHash, placementType)
    if not placeType then
        lib.print.debug(bridge.locale('placer.debug_log.invalid_model'), currentModel, modelHash)
        return false
    end

    local groundPreview = offsetOverride == 'measure' and placeType == 'prop'

    if marker == nil and type(options) == 'table' and options.marker ~= nil then
        marker = options.marker
    end

    local marker = resolveMarker(marker)
    local animCycle, behavior, cyclingAnims = parseBehavior(previewBehavior)
    local animIndex = cyclingAnims and math.floor(tonumber(animCycle.index) or 1) or 1

    if not lib.requestModel(modelHash, 5000) then
        lib.print.debug(bridge.locale('placer.debug_log.model_load_failed'), currentModel, modelHash)
        return false
    end

    local label = labelFor(currentModel, modelHash, placeType, modelIndex, #models)
    local heading = type(options) == 'table' and tonumber(options.startHeading) or GetEntityHeading(cache.ped)
    local startCoords, material, aimed = startingCoords(maxDistance, cache.ped, rayFlagsFull, false)
    startCoords = resolveCoords(modelHash, startCoords, forceGround, placeType, offsetOverride)
    local lastSurface = startCoords
    RequestCollisionAtCoord(startCoords.x, startCoords.y, startCoords.z)

    preview = spawnPreview(modelHash, startCoords, heading, placeType)
    if not preview or preview == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        return false
    end

    setupPreview(preview, placeType, aimed and 255 or 200)
    setStatusColor(preview, placeType, aimed and 'ready' or 'idle')

    local coords = startCoords
    local baseCoords = startCoords
    local feetZ = startCoords.z
    local heightOffset = 0.0

    moveTo(preview, startCoords, heading, placeType)
    if placeType == 'ped' then
        applyBehavior(preview, behavior, startCoords.z)
        coords = GetEntityCoords(preview)
    end

    local placedPreviewModelHash
    local existingPreviewCount = 0
    local supportsPlacedPreview = placedPreview and (placeType == 'ped' or placeType == 'vehicle')
    if supportsPlacedPreview then
        clearPlacedPreviewPeds()

        local previewModel = placedPreview.model
        placedPreviewModelHash = type(previewModel) == 'number' and previewModel
            or (type(previewModel) == 'string' and joaat(previewModel))
            or modelHash
        if not IsModelValid(placedPreviewModelHash) then placedPreviewModelHash = modelHash end
        if placedPreviewModelHash ~= modelHash and not HasModelLoaded(placedPreviewModelHash) then
            lib.requestModel(placedPreviewModelHash, 5000)
        end

        local existing = type(placedPreview.existing) == 'table' and placedPreview.existing or {}
        for i = 1, #existing do
            local spot = existing[i]
            if type(spot) == 'table' and spot.x and spot.y and spot.z then
                spawnPlacedPreviewEntity(placedPreviewModelHash, spot, spot.w or 0.0, spot.behavior, placeType)
            end
        end
        existingPreviewCount = #placedPreviewPeds
    end

    placing = true
    local finalCoords, finalHeading, finalPitch, finalRoll

    -- Set only while the preview is holding a gizmo-set tilt (prop placement only).
    -- Cleared whenever anything else takes over the preview's rotation (rotate keys,
    -- a model swap, or moving on to the next multi-placement), so a stale tilt can
    -- never be reported for a pose the player didn't actually confirm with the gizmo.
    local manualPitch, manualRoll
    local gizmoLocked = false

    local function buildPlacementEntry(coordsVec, headingValue, pitchValue, rollValue)
        local entry = {
            x = coordsVec.x,
            y = coordsVec.y,
            z = coordsVec.z,
            w = headingValue,
            pitch = pitchValue or 0.0,
            roll = rollValue or 0.0,
        }

        if cyclingModels then
            entry.modelIndex = modelIndex
            entry.model = models[modelIndex]
        end

        if cyclingAnims then
            entry.previewIndex = animIndex
        end

        return entry
    end

    local function relocatePreviewAfterPlace()
        local hit, _, hitCoords, hitMaterial = raycastFromCamera(maxDistance, preview, rayFlagsFull, false)
        local nextCoords = lastSurface

        if hit and hitCoords then
            nextCoords = resolveCoords(modelHash, hitCoords, forceGround, placeType, offsetOverride)
            material = hitMaterial or material
        end

        lastSurface = nextCoords
        baseCoords = nextCoords
        feetZ = nextCoords.z + heightOffset
        heading = GetEntityHeading(cache.ped)
        manualPitch, manualRoll = nil, nil
        gizmoLocked = false

        moveTo(preview, nextCoords, heading, placeType)

        if placeType == 'ped' then
            FreezeEntityPosition(preview, true)
            coords = setPedPreview(preview, baseCoords, heightOffset, heading)
            applyBehavior(preview, behavior, baseCoords.z + heightOffset)
            alignFeet(preview, feetZ)
            coords = GetEntityCoords(preview)
        else
            coords = nextCoords
        end
    end

    local function withoutPropLift(vec)
        if placeType ~= 'prop' then return vec end

        local lift = groundOffset(modelHash, placeType, offsetOverride)
        if lift == 0.0 then return vec end

        return vector3(vec.x, vec.y, vec.z - lift)
    end

    local function commitMultiPlacement(opts)
        opts = type(opts) == 'table' and opts or {}

        if placeType == 'ped' and not opts.skipAlign then
            alignFeet(preview, feetZ)
        end

        finalCoords = withoutPropLift(opts.coords or GetEntityCoords(preview))
        finalHeading = opts.heading or heading
        finalPitch, finalRoll = manualPitch, manualRoll
        multiResults[#multiResults + 1] = buildPlacementEntry(finalCoords, finalHeading, finalPitch, finalRoll)
        if supportsPlacedPreview then
            spawnPlacedPreviewEntity(placedPreviewModelHash, finalCoords, finalHeading, behavior, placeType)
        end
        if maxPlacements and #multiResults >= maxPlacements then
            placing = false
            return
        end
        relocatePreviewAfterPlace()
        coords = GetEntityCoords(preview)
    end

    local function undoLastPlacement()
        if #multiResults == 0 then return end

        multiResults[#multiResults] = nil
        if supportsPlacedPreview and #placedPreviewPeds > existingPreviewCount then
            local entity = placedPreviewPeds[#placedPreviewPeds]
            if entity and DoesEntityExist(entity) then
                if GetEntityType(entity) == 2 then
                    SetEntityDrawOutline(entity, false)
                end
                SetEntityAsMissionEntity(entity, false, false)
                DeleteEntity(entity)
            end
            placedPreviewPeds[#placedPreviewPeds] = nil
        end
    end

    if placeType == 'ped' then
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        FreezeEntityPosition(preview, true)

        local hit, _, hitCoords, hitMaterial = raycastFromCamera(maxDistance, preview, rayFlagsFull, false)
        if hit and hitCoords then
            baseCoords = resolveCoords(modelHash, hitCoords, forceGround, placeType, offsetOverride)
            feetZ = baseCoords.z + heightOffset
            coords = setPedPreview(preview, baseCoords, heightOffset, heading)
            material = hitMaterial or material
        end

        alignFeet(preview, feetZ)
        coords = GetEntityCoords(preview)
    end

    local pedCoords = GetEntityCoords(cache.ped, false)
    local distance = #(coords - pedCoords)
    local materialOk = not allowedMats or (material and allowedMats[material] == true)
    local inRange = distance <= maxDistance
    local posOk = true
    local lastValidate = 0
    local canPlace = materialOk and inRange
    local outline = 'idle'

    local modes = {}
    if heightAdjust and (placeType == 'ped' or placeType == 'prop') then modes[#modes + 1] = 'position' end
    if cyclingModels then modes[#modes + 1] = 'model' end
    if cyclingAnims then modes[#modes + 1] = 'animation' end

    local modeIndex = 1
    local mode = modes[modeIndex]
    local canToggleMode = #modes > 1

    local startMode = type(options) == 'table' and type(options.startMode) == 'string' and options.startMode or nil
    if startMode then
        for i = 1, #modes do
            if modes[i] == startMode then
                modeIndex = i
                mode = modes[i]
                break
            end
        end
    end

    local function refreshPlacerUI()
        openUI({
            modelLabel = label,
            maxDistance = maxDistance,
            placementType = placeType,
            animationCycling = cyclingAnims,
            modelCycling = cyclingModels,
            adjustmentMode = mode,
            canToggleMode = canToggleMode,
            gizmoToggleAvailable = gizmoToggleAvailable,
            multiPlace = multiPlace,
            maxPlacements = maxPlacements,
            placedCount = #multiResults,
            localeOverrides = localeOverrides,
        })
    end

    refreshPlacerUI()
    lib.disableControls:Add(blockedControls)
    local openedAt = GetGameTimer()

    controls.blockCancelWhile(function() return placing end)

    local function nextMode()
        if not canToggleMode then return end

        modeIndex = modeIndex % #modes + 1
        mode = modes[modeIndex]
    end

    local function selectModel(index)
        if not cyclingModels then return end

        if index < 1 then index = #models end
        if index > #models then index = 1 end

        local nextModel = models[index]
        local nextHash = type(nextModel) == 'number' and nextModel or joaat(nextModel)
        if not IsModelValid(nextHash) then return end
        if not lib.requestModel(nextHash, 5000) then return end

        local nextType = resolveType(nextHash, placementType)
        if not nextType then return end

        local respawnCoords = resolveCoords(nextHash, lastSurface, forceGround, nextType, offsetOverride)
        local oldHash = modelHash

        resetVisuals(preview, placeType)
        DeleteEntity(preview)

        if oldHash ~= nextHash then
            SetModelAsNoLongerNeeded(oldHash)
        end

        modelIndex = index
        modelHash = nextHash
        placeType = nextType
        currentModel = nextModel
        label = labelFor(nextModel, modelHash, placeType, modelIndex, #models)

        preview = spawnPreview(modelHash, respawnCoords, heading, placeType)
        if not preview or preview == 0 then
            SetModelAsNoLongerNeeded(modelHash)
            placing = false
            return
        end

        setupPreview(preview, placeType, outline == 'ready' and 255 or 200)
        setStatusColor(preview, placeType, outline)
        moveTo(preview, respawnCoords, heading, placeType)
        manualPitch, manualRoll = nil, nil
        gizmoLocked = false

        if placeType == 'ped' then
            FreezeEntityPosition(preview, true)
            baseCoords = respawnCoords
            feetZ = respawnCoords.z + heightOffset
            coords = setPedPreview(preview, baseCoords, heightOffset, heading)
            applyBehavior(preview, behavior, baseCoords.z + heightOffset)
        else
            coords = respawnCoords
        end
    end

    local function selectAnim(index)
        if not cyclingAnims or not animCycle then return end

        local count = #animCycle.options
        if count == 0 then return end

        animIndex = lib.math.clamp(index, 1, count)
        animCycle.index = animIndex
        behavior = animCycle.options[animIndex] and animCycle.options[animIndex].behavior or nil

        applyBehavior(preview, behavior, baseCoords.z + heightOffset)
        coords = GetEntityCoords(preview)
    end

    CreateThread(function()
        local lastPush = 0

        while placing do
            if gizmoActive then
                Wait(100)
            else
            local now = GetGameTimer()
            if now - lastPush >= 150 then
                lastPush = now

                local status = 'aiming'
                if canPlace then
                    status = 'ready'
                elseif not materialOk or not posOk then
                    status = 'invalid_material'
                elseif not inRange then
                    status = 'too_far'
                end

                SendNUIMessage({
                    type = 'placer:update',
                    modelLabel = label,
                    adjustmentMode = mode,
                    adjustmentModeToggleAvailable = canToggleMode,
                    pedVerticalAdjust = placeType == 'ped',
                    gizmoToggleAvailable = gizmoToggleAvailable,
                    multiPlace = multiPlace,
                    maxPlacements = maxPlacements,
                    placedCount = #multiResults,
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    heading = heading,
                    distance = distance,
                    maxDistance = maxDistance,
                    status = status,
                    animationLabel = cyclingAnims and behaviorLabel(animCycle, animIndex) or nil,
                })
            end

            Wait(0)
            end
        end
    end)

    local lastRaycast = 0
    local lastHit = aimed

    while placing do
        local now = GetGameTimer()
        local placePressed = justPressed(controls.place)
        local hPressed = justPressed(controls.returnMenu)
        local cancelPressed = (justPressed(controls.cancel) or (returnCancel and hPressed)) and (now - openedAt) >= controls.cancelGraceMs
        local undoPressed = multiPlace and justPressed(controls.undo)
        local debugPressed = Config.Debug and hPressed and not returnCancel
        local togglePressed = canToggleMode and justPressed(controls.previewModeToggle)
        local gizmoTogglePressed = gizmoToggleAvailable and justPressed(controls.gizmoToggle)
        local cycleUp = justPressed(controls.pedRaise)
        local cycleDown = justPressed(controls.pedLower)
        local clearAnim = cyclingAnims and mode == 'animation' and justPressed(controls.animClear)
        local isPed = placeType == 'ped'
        local canLift = mode == 'position'
        local raise = canLift and (IsControlPressed(0, controls.pedRaise) or IsDisabledControlPressed(0, controls.pedRaise))
        local lower = canLift and (IsControlPressed(0, controls.pedLower) or IsDisabledControlPressed(0, controls.pedLower))
        local coarse = IsControlPressed(0, controls.modifierCoarse) or IsDisabledControlPressed(0, controls.modifierCoarse)
        local fine = IsControlPressed(0, controls.modifierFine) or IsDisabledControlPressed(0, controls.modifierFine)
        local rotateRight = justPressed(controls.scrollUp) or justPressed(controls.rotateRight)
        local rotateLeft = justPressed(controls.scrollDown) or justPressed(controls.rotateLeft)

        if raise then
            heightOffset = heightOffset + 1.5 * GetFrameTime()
        elseif lower then
            heightOffset = heightOffset - 1.5 * GetFrameTime()
        end

        local rotateStep = fine and rotateSteps.fine or coarse and rotateSteps.coarse or rotateSteps.normal

        if rotateRight then
            heading = (heading + rotateStep) % 360.0
        elseif rotateLeft then
            heading = (heading - rotateStep) % 360.0
        end

        if (rotateRight or rotateLeft) and preview and DoesEntityExist(preview) then
            SetEntityHeading(preview, heading)
            -- Plain yaw rotation supersedes a held gizmo tilt; resume normal aim-tracking.
            manualPitch, manualRoll = nil, nil
            gizmoLocked = false
        end

        if undoPressed then
            undoLastPlacement()
        end

        local openedGizmo = false

        if gizmoTogglePressed and preview and DoesEntityExist(preview) then
            openedGizmo = true
            gizmoActive = true
            closeUI()

            if isPed then
                applyBehavior(preview, behavior, baseCoords.z + heightOffset)
            end

            local gizmoResult = exports[cache.resource]:useGizmo(preview, { deleteOnConfirm = false })

            setupPreview(preview, placeType, outline == 'ready' and 255 or 200)
            setStatusColor(preview, placeType, outline)

            if gizmoResult then
                heading = gizmoResult.heading or GetEntityHeading(preview)

                local pos = gizmoResult.position
                if type(pos) == 'table' then
                    pos = vector3(pos.x, pos.y, pos.z)
                elseif gizmoResult.x and gizmoResult.y and gizmoResult.z then
                    pos = vector3(gizmoResult.x, gizmoResult.y, gizmoResult.z)
                else
                    pos = GetEntityCoords(preview)
                end

                SetEntityCoordsNoOffset(preview, pos.x, pos.y, pos.z, false, false, false)

                if placeType == 'prop' then
                    manualPitch = gizmoResult.pitch or 0.0
                    manualRoll = gizmoResult.roll or 0.0
                    SetEntityRotation(preview, manualPitch, manualRoll, heading, 2, true)
                    -- Hold this exact pose (position + tilt) instead of letting the next
                    -- frame's camera raycast immediately overwrite it - otherwise the tilt
                    -- the player just dialled in would never survive to the next frame.
                    gizmoLocked = true
                else
                    SetEntityHeading(preview, heading)
                end

                coords = pos
                baseCoords = vector3(pos.x, pos.y, pos.z - heightOffset)
                feetZ = pedFeetZ(preview) or pos.z
                lastSurface = baseCoords

                if isPed then
                    playBehavior(preview, behavior)
                end

                if multiPlace then
                    commitMultiPlacement({ coords = pos, heading = heading, skipAlign = true })
                end
            end

            gizmoActive = false
            refreshPlacerUI()
            openedAt = GetGameTimer()
        end

        if not openedGizmo and not gizmoLocked then
            if now - lastRaycast >= raycastInterval then
                lastRaycast = now
                local rHit, _, rCoords, rMaterial = raycastFromCamera(maxDistance, preview, rayFlagsFull, false)
                lastHit = rHit and rCoords ~= nil
                if rHit and rCoords then
                    lastSurface = resolveCoords(modelHash, rCoords, forceGround, placeType, offsetOverride)
                end
                if rMaterial then material = rMaterial end
            end

            feetZ = lastSurface.z + heightOffset

            if isPed then
                baseCoords = lastSurface
                coords = setPedPreview(preview, baseCoords, heightOffset, heading)
            elseif canLift and heightOffset ~= 0.0 then
                coords = vector3(lastSurface.x, lastSurface.y, lastSurface.z + heightOffset)
                moveTo(preview, coords, heading, placeType)
            elseif groundPreview and placeType == 'prop' then
                moveTo(preview, lastSurface, heading, placeType)
                PlaceObjectOnGroundProperly(preview)
                coords = GetEntityCoords(preview)
            else
                coords = lastSurface
                moveTo(preview, lastSurface, heading, placeType)
            end
        end

        if togglePressed then
            nextMode()
        end

        if mode == 'animation' and (cycleUp or cycleDown or clearAnim) then
            if clearAnim then
                selectAnim(1)
            else
                local count = animCycle and #animCycle.options or 0
                if count > 0 then
                    local nextIndex = animIndex + (cycleUp and -1 or 1)
                    if nextIndex < 1 then nextIndex = count end
                    if nextIndex > count then nextIndex = 1 end
                    selectAnim(nextIndex)
                end
            end
        elseif mode == 'model' and (cycleUp or cycleDown) then
            if #models > 1 then
                local nextIndex = modelIndex + (cycleUp and -1 or 1)
                if nextIndex < 1 then nextIndex = #models end
                if nextIndex > #models then nextIndex = 1 end
                selectModel(nextIndex)
            end
        end

        if placeType == 'ped' and not openedGizmo then
            alignFeet(preview, feetZ)
            coords = GetEntityCoords(preview)
        end

        pedCoords = GetEntityCoords(cache.ped, false)
        distance = #(coords - pedCoords)
        materialOk = not allowedMats or (material and allowedMats[material] == true)
        inRange = distance <= maxDistance

        if isPositionValid and now - lastValidate >= 150 then
            lastValidate = now
            posOk = isPositionValid(coords) ~= false
        end

        canPlace = materialOk and inRange and posOk

        local nextOutline = canPlace and 'ready'
            or ((lastHit and not materialOk) or not posOk) and 'invalid'
            or (not inRange) and 'far'
            or 'idle'

        if nextOutline ~= outline then
            outline = nextOutline
            setStatusColor(preview, placeType, outline)
        end

        drawStatusMarker(preview, placeType, marker, outline)
        if placedPreview then
            for i = 1, #placedPreviewPeds do
                local ped = placedPreviewPeds[i]
                if ped and DoesEntityExist(ped) then
                    drawStatusMarker(ped, placeType, marker, 'ready')
                end
            end
        else
            drawPlacedMarkers(multiResults, placedMarker)
        end

        lib.disableControls()
        DisablePlayerFiring(cache.playerId, true)
        EnableControlAction(0, controls.place, true)
        -- CANCEL stays disabled by blockCancelWhile; justPressed still reads the
        -- disabled press, so Backspace works without triggering frontend back.
        EnableControlAction(0, controls.scrollUp, true)
        EnableControlAction(0, controls.scrollDown, true)
        EnableControlAction(0, controls.rotateLeft, true)
        EnableControlAction(0, controls.rotateRight, true)

        if multiPlace then
            EnableControlAction(0, controls.undo, true)
        end

        if mode then
            EnableControlAction(0, controls.pedRaise, true)
            EnableControlAction(0, controls.pedLower, true)
        end

        if cyclingAnims and mode == 'animation' then
            EnableControlAction(0, controls.animClear, true)
        end

        if canToggleMode then
            EnableControlAction(0, controls.previewModeToggle, true)
        end

        if gizmoToggleAvailable then
            EnableControlAction(0, controls.gizmoToggle, true)
        end

        if cancelPressed then
            placing = false
        elseif debugPressed then
            if material then
                lib.setClipboard(tostring(material))
                lib.print.info(bridge.locale('placer.debug_log.material_copied', { hash = material }))
                bridge.notifications.notify({
                    title = bridge.locale('placer.title'),
                    description = bridge.locale('placer.debug_log.material_copied', { hash = material }),
                    type = 'inform',
                })
            end
        elseif placePressed then
            if canPlace then
                if placeType == 'ped' then
                    alignFeet(preview, feetZ)
                end

                finalCoords = withoutPropLift(GetEntityCoords(preview))
                finalHeading = heading
                finalPitch, finalRoll = manualPitch, manualRoll

                if multiPlace then
                    commitMultiPlacement()
                else
                    placing = false
                end
            elseif not posOk then
                bridge.notifications.notify({
                    title = bridge.locale('common.error'),
                    description = invalidPositionText or bridge.locale('placer.errors.invalid_material'),
                    type = 'error',
                })
            elseif not materialOk then
                bridge.notifications.notify({
                    title = bridge.locale('common.error'),
                    description = bridge.locale('placer.errors.invalid_material'),
                    type = 'error',
                })
            else
                bridge.notifications.notify({
                    title = bridge.locale('common.error'),
                    description = bridge.locale('placer.errors.too_far'),
                    type = 'error',
                })
            end
        end

        Wait(0)
    end

    lib.disableControls:Remove(blockedControls)
    closeUI()
    if preview and DoesEntityExist(preview) then
        resetVisuals(preview, placeType)
        DeleteEntity(preview)
    end
    preview = nil
    clearPlacedPreviewPeds()
    if placedPreviewModelHash and placedPreviewModelHash ~= modelHash then
        SetModelAsNoLongerNeeded(placedPreviewModelHash)
    end
    SetModelAsNoLongerNeeded(modelHash)

    if multiPlace and #multiResults > 0 then
        return { multi = true, results = multiResults }
    end

    if not finalCoords then return false end

    if cyclingModels or cyclingAnims then
        local result = {
            x = finalCoords.x, y = finalCoords.y, z = finalCoords.z, w = finalHeading,
            pitch = finalPitch or 0.0, roll = finalRoll or 0.0,
        }

        if cyclingModels then
            result.modelIndex = modelIndex
            result.model = models[modelIndex]
        end

        if cyclingAnims then
            result.previewIndex = animIndex
        end

        return result
    end

    -- A plain table rather than a vector4 so pitch/roll can ride alongside x/y/z/w;
    -- every existing caller only ever reads those named fields, never vector4-only
    -- behaviour (arithmetic, native calls expecting real vector4 userdata), so this
    -- is a drop-in replacement for callers that don't care about the new fields.
    return { x = finalCoords.x, y = finalCoords.y, z = finalCoords.z, w = finalHeading,
        pitch = finalPitch or 0.0, roll = finalRoll or 0.0 }
end

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource or not placing then return end
    if not preview or not DoesEntityExist(preview) then return end

    local entityType = GetEntityType(preview)
    local placeType = entityType == 1 and 'ped' or entityType == 2 and 'vehicle' or 'prop'

    resetVisuals(preview, placeType)
    SetEntityAsMissionEntity(preview, false, false)
    DeleteEntity(preview)
    preview = nil
    clearPlacedPreviewPeds()
    placing = false
    lib.disableControls:Remove(blockedControls)
    closeUI()
end)

lib.callback.register('Newb_Bridge:callback:PlaceProp', propPlacer)
exports('PropPlacer', propPlacer)
