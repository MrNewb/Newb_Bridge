-- Adapted from object_gizmo <https://github.com/DemiAutomatic/object_gizmo>
-- Copyright (C) DemiAutomatic -- GPL-3.0
--
-- Also incorporates:
--   ox_lib PR #453 by Andyyy7666 <https://github.com/overextended/ox_lib/pull/453>
--   Copyright (C) 2021 Linden <https://github.com/thelindat> -- LGPL-3.0-or-later
--   DrawGizmo research by AvarianKnight
--   <https://forum.cfx.re/t/allow-drawgizmo-to-be-used-outside-of-fxdk/5091845/8>
--
-- Modified for Newb_Bridge. Changes: exported as useGizmo, bridge model requests,
-- shared camera_ray helper.
-- GPL-3.0-only <https://www.gnu.org/licenses/gpl-3.0.html>
-- See LICENSE and ATTRIBUTIONS.md in the Newb_Bridge repository.

local dataview = require '@Newb_Bridge/utility/client/dataview'
local controls = require '@Newb_Bridge/utility/client/placement_controls'

local isCursorActive = false
local gizmoEnabled = false
local gizmoConfirmed = false
local currentMode = 'Translate'
local isRelative = false
local currentEntity
local spawnedEntity -- preview we spawned for the spawn-and-edit form; ours to delete

-- combat/vehicle/cover always blocked; movement only while the cursor is active
-- so G can free the player to walk. E confirm and backspace cancel (194) below.
local alwaysBlockedControls = {
    19, 22, 23, 44, 45, 75,
    140, 141, 142, 143, 257, 263, 264,
}

local cursorBlockedControls = {
    21, 30, 31, 32, 33, 34, 35, 36,
}

local function justPressed(control)
    return IsDisabledControlJustPressed(0, control) or IsControlJustPressed(0, control)
end

local localeKeys = {
    'title', 'subtitle', 'mode', 'space', 'position', 'rotation',
    'controls_heading', 'cursor_toggle', 'translate', 'rotate_mode',
    'toggle_space', 'snap_ground', 'confirm', 'cancel',
    'drag_axis', 'cursor_on', 'cursor_off', 'space_world', 'space_relative',
}

local function gizmoLocales()
    local strings = {}
    for i = 1, #localeKeys do
        strings[localeKeys[i]] = bridge.locale('gizmo.' .. localeKeys[i])
    end

    strings.mode_translate = bridge.locale('gizmo.modes.translate')
    strings.mode_rotate = bridge.locale('gizmo.modes.rotate')
    return strings
end

local function openGizmoUI(entityLabel)
    SendNUIMessage({
        type = 'gizmo:open',
        entityLabel = entityLabel,
        mode = currentMode,
        space = isRelative and 'relative' or 'world',
        cursorActive = isCursorActive,
        locales = gizmoLocales(),
    })
end

local function closeGizmoUI()
    SendNUIMessage({ type = 'gizmo:close' })
end

local function pushGizmoUpdate()
    if not gizmoEnabled or not currentEntity or not DoesEntityExist(currentEntity) then return end

    local coords = GetEntityCoords(currentEntity)
    local rot = GetEntityRotation(currentEntity)

    SendNUIMessage({
        type = 'gizmo:update',
        mode = currentMode,
        space = isRelative and 'relative' or 'world',
        cursorActive = isCursorActive,
        position = { x = coords.x, y = coords.y, z = coords.z },
        rotation = { x = rot.x, y = rot.y, z = rot.z },
    })
end

local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then
        return 0, 0, 0
    end
    return x / length, y / length, z / length
end

local function makeEntityMatrix(entity)
    local f, r, u, a = GetEntityMatrix(entity)
    local view = dataview.ArrayBuffer(60)

    view:SetFloat32(0, r[1])
        :SetFloat32(4, r[2])
        :SetFloat32(8, r[3])
        :SetFloat32(12, 0)
        :SetFloat32(16, f[1])
        :SetFloat32(20, f[2])
        :SetFloat32(24, f[3])
        :SetFloat32(28, 0)
        :SetFloat32(32, u[1])
        :SetFloat32(36, u[2])
        :SetFloat32(40, u[3])
        :SetFloat32(44, 0)
        :SetFloat32(48, a[1])
        :SetFloat32(52, a[2])
        :SetFloat32(56, a[3])
        :SetFloat32(60, 1)

    return view
end

local function applyEntityMatrix(entity, view)
    local x1, y1, z1 = view:GetFloat32(16), view:GetFloat32(20), view:GetFloat32(24)
    local x2, y2, z2 = view:GetFloat32(0), view:GetFloat32(4), view:GetFloat32(8)
    local x3, y3, z3 = view:GetFloat32(32), view:GetFloat32(36), view:GetFloat32(40)
    local tx, ty, tz = view:GetFloat32(48), view:GetFloat32(52), view:GetFloat32(56)

    -- normalized so a stray +gizmoScale state can never scale the entity matrix
    x1, y1, z1 = normalize(x1, y1, z1)
    x2, y2, z2 = normalize(x2, y2, z2)
    x3, y3, z3 = normalize(x3, y3, z3)

    SetEntityMatrix(entity,
        x1, y1, z1,
        x2, y2, z2,
        x3, y3, z3,
        tx, ty, tz
    )
end

-- Same green as PropPlacer's ready outline.
local outlineColor = { 84, 227, 129, 255 }

local function gizmoLoop(entity, drawOutline)
    if not gizmoEnabled then
        return LeaveCursorMode()
    end

    EnterCursorMode()
    isCursorActive = true

    if drawOutline then
        SetEntityDrawOutlineColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
        SetEntityDrawOutline(entity, true)
    elseif IsEntityAPed(entity) then
        SetEntityAlpha(entity, 200)
    end

    -- swallowed so the input that opened the gizmo can't instantly cancel it
    local openedAt = GetGameTimer()
    controls.blockCancelWhile(function() return gizmoEnabled end)

    while gizmoEnabled and DoesEntityExist(entity) do
        Wait(0)

        if justPressed(controls.gizmoSnap) then
            PlaceObjectOnGroundProperly_2(entity)
            pushGizmoUpdate()
        end

        if justPressed(controls.cancel) and (GetGameTimer() - openedAt) >= controls.cancelGraceMs then
            gizmoConfirmed = false
            gizmoEnabled = false
        end

        if justPressed(controls.place) then
            gizmoConfirmed = true
            gizmoEnabled = false
        end

        for i = 1, #alwaysBlockedControls do
            DisableControlAction(0, alwaysBlockedControls[i], true)
        end

        if isCursorActive then
            for i = 1, #cursorBlockedControls do
                DisableControlAction(0, cursorBlockedControls[i], true)
            end
        end

        DisableControlAction(0, 24, true) -- lmb
        DisableControlAction(0, 25, true) -- rmb
        DisablePlayerFiring(cache.playerId, true)

        local matrixBuffer = makeEntityMatrix(entity)
        local changed = Citizen.InvokeNative(0xEB2EDCA2, matrixBuffer:Buffer(), 'Editor1',
            Citizen.ReturnResultAnyway())

        if changed then
            applyEntityMatrix(entity, matrixBuffer)
            pushGizmoUpdate()
        end
    end

    if isCursorActive then
        LeaveCursorMode()
    end
    isCursorActive = false

    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then SetEntityAlpha(entity, 255) end
        if drawOutline then SetEntityDrawOutline(entity, false) end
    end

    gizmoEnabled = false
    currentEntity = nil
end

local function roundCoord(value, places)
    places = places or 3
    local mult = 10 ^ places
    return math.floor(value * mult + 0.5) / mult
end

local function serializeAxis(axis)
    if not axis then return end

    local x = axis.x or axis[1]
    local y = axis.y or axis[2]
    local z = axis.z or axis[3]
    if x == nil or y == nil or z == nil then return end

    return { x = roundCoord(x + 0.0), y = roundCoord(y + 0.0), z = roundCoord(z + 0.0) }
end

local function serializeEntityMatrix(entity)
    if not entity or not DoesEntityExist(entity) then return end

    local forward, right, up, at = GetEntityMatrix(entity)
    local matrix = {
        forward = serializeAxis(forward),
        right = serializeAxis(right),
        up = serializeAxis(up),
        at = serializeAxis(at),
    }

    if not matrix.forward or not matrix.right or not matrix.up or not matrix.at then
        return
    end

    return matrix
end

local warnedUnbound = false

-- keybind defaults only apply on first registration, so an edited profile can
-- leave the mode keys unbound and W/R/Q silently do nothing
local function warnIfModeKeysUnbound()
    if warnedUnbound then return end

    local button = GetControlInstructionalButton(2, joaat('+_gizmoTranslation') | 0x80000000, true)
    if button and button ~= '' and button ~= 'NULL' then return end

    warnedUnbound = true
    bridge.notifications.notify({ description = bridge.locale('gizmo.keys_unbound'), type = 'error' })
end

local function getEntityLabel(entity)
    if not entity or not DoesEntityExist(entity) then
        return bridge.locale('gizmo.no_entity')
    end

    local archetype = GetEntityArchetypeName(entity)
    if archetype and archetype ~= '' then
        return archetype
    end

    return ('Model %s'):format(GetEntityModel(entity))
end

-- translucent frozen preview for the spawn-and-edit call form; ped/vehicle
-- models get the matching entity type automatically
local function spawnGizmoPreview(call)
    local model = call.model
    local modelHash = type(model) == 'number' and model or joaat(model)

    if not IsModelValid(modelHash) or not lib.requestModel(modelHash, 5000) then
        return
    end

    local coords = call.coords
    local x, y, z, heading

    if coords then
        x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
        local ctype = type(coords)
        local w = (ctype == 'vector4' or ctype == 'table') and coords.w or nil
        heading = tonumber(call.heading) or tonumber(w) or 0.0
    else
        local probe = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 2.5
        x, y, z = probe.x, probe.y, probe.z
        heading = tonumber(call.heading) or GetEntityHeading(cache.ped)
    end

    RequestCollisionAtCoord(x, y, z)

    local entity
    if call.ped == true or IsModelAPed(modelHash) then
        entity = CreatePed(4, modelHash, x, y, z, heading, false, false)
        if entity and entity ~= 0 then
            SetBlockingOfNonTemporaryEvents(entity, true)
            SetEntityInvincible(entity, true)
            SetPedCanRagdoll(entity, false)
        end
    elseif IsModelAVehicle(modelHash) then
        entity = CreateVehicle(modelHash, x, y, z, heading, false, false)
    else
        entity = CreateObjectNoOffset(modelHash, x, y, z, false, false, false)
        if entity and entity ~= 0 then
            SetEntityHeading(entity, heading)
        end
    end

    SetModelAsNoLongerNeeded(modelHash)
    if not entity or entity == 0 then return end

    local rot = call.rotation
    if rot and rot.x then
        SetEntityRotation(entity, rot.x + 0.0, (rot.y or 0.0) + 0.0, (rot.z or 0.0) + 0.0, 2, true)
    end

    SetEntityAlpha(entity, 200, false)
    SetEntityCollision(entity, false, false)
    SetEntityAsMissionEntity(entity, true, true)
    FreezeEntityPosition(entity, true)

    return entity
end

---@param entity number|GizmoCallOptions Entity to edit, or a table with a `model` key to spawn a preview entity first
---@param options GizmoOptions? Ignored when the first argument is a table (options ride in it instead)
---@return table|nil transform result; nil when cancelled
local function useGizmo(entity, options)
    -- spawn-and-edit form: useGizmo({ model = 'prop_x', coords = vec4(...) })
    local spawned = false
    if type(entity) == 'table' then
        options = entity
        entity = spawnGizmoPreview(options)
        spawned = true
        spawnedEntity = entity
    end

    if not entity or not DoesEntityExist(entity) then return end

    options = type(options) == 'table' and options or {}
    local deleteOnConfirm = options.deleteOnConfirm
    if deleteOnConfirm == nil then deleteOnConfirm = true end
    local labelOverride = type(options.label) == 'string' and options.label or nil
    -- true always, false never, nil keeps the legacy non-peds-only default
    local drawOutline = options.outline
    if drawOutline == nil then
        drawOutline = not IsEntityAPed(entity)
    end

    gizmoEnabled = true
    gizmoConfirmed = false
    currentEntity = entity
    -- currentMode/isRelative persist between sessions because the native remembers
    -- them and scripts can't reset it, so the labels track the native instead
    warnIfModeKeysUnbound()

    openGizmoUI(labelOverride or getEntityLabel(entity))
    pushGizmoUpdate()

    -- keeps the panel readout fresh while the loop runs
    CreateThread(function()
        while gizmoEnabled do
            pushGizmoUpdate()
            Wait(150)
        end
    end)

    gizmoLoop(entity, drawOutline)

    closeGizmoUI()

    if not gizmoConfirmed or not DoesEntityExist(entity) then
        -- a spawned preview is ours to clean up on cancel
        if spawned and DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
        spawnedEntity = nil
        return nil
    end

    local matrix = serializeEntityMatrix(entity)
    local finalCoords = GetEntityCoords(entity)
    local finalHeading = GetEntityHeading(entity)
    local finalRotation = GetEntityRotation(entity)

    if matrix and matrix.at then
        finalCoords = vector3(matrix.at.x, matrix.at.y, matrix.at.z)
    else
        finalCoords = vector3(
            roundCoord(finalCoords.x),
            roundCoord(finalCoords.y),
            roundCoord(finalCoords.z)
        )
    end

    if deleteOnConfirm then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    elseif spawned then
        -- Kept spawned entities become the placed object: restore visuals/collision.
        ResetEntityAlpha(entity)
        SetEntityCollision(entity, true, true)
    end
    spawnedEntity = nil

    return {
        handle = entity,
        position = finalCoords,
        rotation = finalRotation,
        heading = finalHeading,
        x = finalCoords.x,
        y = finalCoords.y,
        z = finalCoords.z,
        pitch = roundCoord(finalRotation.x),
        roll = roundCoord(finalRotation.y),
        yaw = roundCoord(finalRotation.z),
        matrix = matrix,
    }
end

exports('useGizmo', useGizmo)

-- Keybinds match object_gizmo: https://github.com/DemiAutomatic/object_gizmo
--
-- Only these handlers may run the +gizmo*/-gizmo* commands. Keybinds dispatch
-- under the console principal so the nested ExecuteCommand is allowed; the same
-- call from a script thread gets "Access denied for command" and does nothing.

lib.addKeybind({
    name = '_gizmoCursor',
    description = bridge.locale('gizmo.keybinds.toggle_cursor'),
    defaultKey = 'G',
    onPressed = function()
        if not gizmoEnabled then return end
        if isCursorActive then
            LeaveCursorMode()
            isCursorActive = false
        else
            EnterCursorMode()
            isCursorActive = true
        end
        pushGizmoUpdate()
    end,
})

lib.addKeybind({
    name = '_gizmoSelect',
    description = bridge.locale('gizmo.keybinds.select_object'),
    defaultMapper = 'MOUSE_BUTTON',
    defaultKey = 'MOUSE_LEFT',
    onPressed = function()
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoSelect')
    end,
    onReleased = function()
        ExecuteCommand('-gizmoSelect')
    end,
})

lib.addKeybind({
    name = '_gizmoTranslation',
    description = bridge.locale('gizmo.keybinds.translation_mode'),
    defaultKey = 'W',
    onPressed = function()
        if not gizmoEnabled then return end
        currentMode = 'Translate'
        pushGizmoUpdate()
        -- release the siblings first, or a +state stranded by a restart
        -- mid-press eats that mode's future edges
        ExecuteCommand('-gizmoRotation')
        ExecuteCommand('-gizmoScale')
        ExecuteCommand('+gizmoTranslation')
    end,
    onReleased = function()
        ExecuteCommand('-gizmoTranslation')
    end,
})

lib.addKeybind({
    name = '_gizmoRotation',
    description = bridge.locale('gizmo.keybinds.rotation_mode'),
    defaultKey = 'R',
    onPressed = function()
        if not gizmoEnabled then return end
        currentMode = 'Rotate'
        pushGizmoUpdate()
        ExecuteCommand('-gizmoTranslation')
        ExecuteCommand('-gizmoScale')
        ExecuteCommand('+gizmoRotation')
    end,
    onReleased = function()
        ExecuteCommand('-gizmoRotation')
    end,
})

lib.addKeybind({
    name = '_gizmoLocal',
    description = bridge.locale('gizmo.keybinds.toggle_space'),
    defaultKey = 'Q',
    onPressed = function()
        if not gizmoEnabled then return end
        isRelative = not isRelative
        pushGizmoUpdate()
        ExecuteCommand('+gizmoLocal')
    end,
    onReleased = function()
        ExecuteCommand('-gizmoLocal')
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then return end

    -- the session coroutine may never resume while stopping, so the preview
    -- gets deleted here instead of leaking into the world
    if spawnedEntity and DoesEntityExist(spawnedEntity) then
        SetEntityAsMissionEntity(spawnedEntity, true, true)
        DeleteEntity(spawnedEntity)
    end
    spawnedEntity = nil

    if isCursorActive then
        LeaveCursorMode()
        isCursorActive = false
    end

    if not gizmoEnabled then return end
    gizmoEnabled = false
    closeGizmoUI()
end)
