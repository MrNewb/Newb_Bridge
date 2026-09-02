--[[
    Adapted from https://github.com/overextended/ox_lib/blob/main/resource/zoneCreator/client.lua

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>

    Modified for Newb_Bridge: reworked the placement flow into freecam/on-foot modes,
    added box and sphere zone types alongside poly, and integrated with Newb_Bridge's
    NUI, locales, and notification/keybind systems.
]]

local controls = require '@Newb_Bridge/utility/client/placement_controls'
local ray = require '@Newb_Bridge/utility/client/camera_ray'

local creatorActive = false
local creatorOwner ---@type string|nil
local controlsActive = false

-- what the player is building: shape, its label, and whether they place from
-- the freecam or on foot
local zoneType, zoneName, placementMode

-- the shape being edited. the cursor is where the laser lands; heading/height/
-- width/length describe the box or sphere around it
local xCoord, yCoord, zCoord
local heading, height, width, length
local points = {} -- confirmed poly points, in placement order
local boxCorners = {} -- the four rotated corners, rebuilt only when boxChanged
local boxChanged = false

-- scroll adjusts by one entry of these; step indexes into whichever list the
-- current control is using
local distanceSteps = { 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 25, 50, 100 }
local angleSteps = { 0.25, 0.5, 1, 2.5, 5, 15, 30, 45, 60, 90, 180 }
local step

-- placement is capped to maxDistance around anchor so zones stay near where
-- the session started
local anchor, maxDistance, camEase, createOptions

-- freecam scaffolding: the camera itself plus the ped clone holding the tablet
local cam, camPos, camRot, clone, tablet

-- last raycast result, redrawn every frame
local laserStart, laserEnd, laserHit

local allowMovement, movementToggle, movementLocked
local uiChanged = false
local lastPanelPush = 0
local movementKeybind ---@type CKeybind|nil
local modeKeybind ---@type CKeybind|nil

-- colours match the NUI design tokens (web/src/design-system/tokens.css), except
-- bounds, which runs hotter than red.6 so the limit stays obvious over grass,
-- asphalt and at night
local colors = {
    outline = { 15, 191, 62 },
    wall = { 95, 237, 131 },
    bounds = { 255, 60, 60 },
    laser = { 18, 184, 134 },
    laserMiss = { 92, 95, 102 },
    marker = { 32, 201, 151 },
}

local tabletModel = `prop_cs_tablet`
local tabletAnims = {
    male = 'amb@world_human_tourist_map@male@base',
    female = 'amb@world_human_tourist_map@female@base',
}

-- movement, combat and camera controls blocked while placing on foot with movement locked
local blockedControls = {
    21, 22, 23, 24, 25, 36, 37, 44, 45, 47, 55, 58, 75,
    140, 141, 142, 143, 257, 263, 264, 322,
}

local freecamControls = { 21, 32, 33, 34, 35, 36, 44 } -- shift + wasd + q(up)/lctrl(down)

local localeKeys = {
    'title', 'subtitle_poly', 'subtitle_box', 'subtitle_sphere', 'zone_name',
    'mode_edit', 'mode_camera', 'mode_onfoot', 'step', 'position', 'heading',
    'height', 'width', 'length', 'radius', 'points', 'bounds', 'distance',
    'controls_heading', 'toggle_mode', 'scroll_step', 'move_cursor',
    'move_vertical', 'move_faster', 'height_scroll', 'width_scroll',
    'length_scroll', 'radius_scroll', 'rotate', 'add_point', 'undo_point',
    'center_position', 'allow_movement', 'movement_free', 'movement_locked',
    'toggle_movement', 'swap_mode', 'confirm', 'cancel',
}

local function round(value)
    return math.floor(value * 100 + 0.5) / 100
end

local function showError(key)
    bridge.notifications.notify({
        title = bridge.locale('zone_creator.title'),
        description = bridge.locale('zone_creator.errors.' .. key),
        type = 'error',
    })
end

local function locales()
    local strings = {}
    for i = 1, #localeKeys do
        strings[localeKeys[i]] = bridge.locale('zone_creator.' .. localeKeys[i])
    end

    strings.lmb = bridge.locale('keys.lmb')
    strings.rmb = bridge.locale('keys.rmb')
    return strings
end

local function toggleKeyLabel()
    return movementKeybind and movementKeybind.currentKey or 'B'
end

local function modeKeyLabel()
    return modeKeybind and modeKeybind.currentKey or 'F'
end

local function openUI()
    SendNUIMessage({
        type = 'zoneCreator:open',
        zoneType = zoneType,
        zoneName = zoneName,
        placementMode = placementMode,
        maxDistance = maxDistance,
        allowMovement = allowMovement,
        movementToggle = movementToggle,
        movementToggleKey = toggleKeyLabel(),
        modeToggleKey = modeKeyLabel(),
        locales = locales(),
    })
end

local function updateText(force)
    if not creatorActive then return end
    if not force and not uiChanged then return end

    local now = GetGameTimer()
    if not force and now - lastPanelPush < 150 then return end

    lastPanelPush = now

    SendNUIMessage({
        type = 'zoneCreator:update',
        zoneType = zoneType,
        zoneName = zoneName,
        placementMode = placementMode,
        controlsActive = controlsActive,
        step = { distance = distanceSteps[step], rotation = angleSteps[step] },
        position = { x = xCoord, y = yCoord, z = zCoord },
        heading = heading,
        height = height,
        width = width,
        length = length,
        pointCount = #points,
        maxDistance = maxDistance,
        allowMovement = allowMovement,
        movementToggle = movementToggle,
        movementToggleKey = toggleKeyLabel(),
        modeToggleKey = modeKeyLabel(),
        distanceFromCenter = #(vec2(xCoord, yCoord) - vec2(anchor.x, anchor.y)),
    })

    uiChanged = false
end

local function updateKeybind()
    if not movementKeybind then return end

    local enable = creatorActive and placementMode == 'onfoot' and movementToggle
    movementKeybind:disable(not enable)
end

local function updateModeKeybind()
    if not modeKeybind then return end
    modeKeybind:disable(not creatorActive)
end

-- a wall panel between two edges of the zone. DrawPoly is single-sided, so each
-- triangle is drawn twice with its winding reversed to make the wall visible
-- from both inside and outside the zone.
local function drawRectangle(corners)
    local first, second, third, fourth = corners[1], corners[2], corners[3], corners[4]
    local r, g, b = colors.wall[1], colors.wall[2], colors.wall[3]

    DrawPoly(first.x, first.y, first.z, second.x, second.y, second.z, third.x, third.y, third.z, r, g, b, 55)
    DrawPoly(second.x, second.y, second.z, first.x, first.y, first.z, third.x, third.y, third.z, r, g, b, 55)
    DrawPoly(first.x, first.y, first.z, fourth.x, fourth.y, fourth.z, third.x, third.y, third.z, r, g, b, 55)
    DrawPoly(fourth.x, fourth.y, fourth.z, first.x, first.y, first.z, third.x, third.y, third.z, r, g, b, 55)
end

-- Draws the zone outline as a ring of wall panels. Every point becomes a
-- vertical edge from floor to ceiling, and consecutive points are joined by a
-- panel. For a poly the ring is still open, so the last point connects back to
-- the first by way of the cursor, showing where the next segment would land.
local function drawLines()
    local halfHeight = vec3(0.0, 0.0, height / 2)
    local cursor = vec3(xCoord, yCoord, zCoord)
    local cursorTop, cursorBottom = cursor + halfHeight, cursor - halfHeight
    local r, g, b = colors.outline[1], colors.outline[2], colors.outline[3]

    local function line(from, to)
        DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, r, g, b, 225)
    end

    if zoneType == 'poly' then
        line(cursorTop, cursorBottom)
    end

    local zonePoints = zoneType == 'box' and boxCorners or points

    for i = 1, #zonePoints do
        local current = zonePoints[i]
        local following = zonePoints[i + 1] or zonePoints[1]
        local currentTop, currentBottom = current + halfHeight, current - halfHeight
        local followingTop, followingBottom = following + halfHeight, following - halfHeight

        line(currentTop, currentBottom)

        local closingPolyRing = i == #zonePoints and zoneType == 'poly'

        if closingPolyRing then
            -- route the closing segment through the cursor instead of straight
            -- back to the first point
            line(cursorTop, followingTop)
            line(cursorBottom, followingBottom)
            line(currentTop, cursorTop)
            line(currentBottom, cursorBottom)
            line(cursor, following)
            line(current, cursor)
            drawRectangle({ currentTop, currentBottom, cursorBottom, cursorTop })
            drawRectangle({ cursorTop, cursorBottom, followingBottom, followingTop })
        else
            line(currentTop, followingTop)
            line(currentBottom, followingBottom)
            line(current, following)
            drawRectangle({ currentTop, currentBottom, followingBottom, followingTop })
        end
    end
end

local function drawLaser()
    local from = laserStart or GetFinalRenderedCamCoord()
    local to = laserEnd or from
    local color = laserHit and colors.laser or colors.laserMiss

    DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, color[1], color[2], color[3], 235)
    DrawMarker(28, to.x, to.y, to.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, colors.marker[1], colors.marker[2], colors.marker[3], laserHit and 210 or 96, false, false, 0, false, false, false, false)
end

-- walked once so the ring is not rebuilt every frame
local boundsRing = {}
for i = 1, 48 do
    local angle = ((i - 1) / 48) * math.pi * 2
    boundsRing[i] = { math.cos(angle), math.sin(angle) }
end

-- A flat marker that wide reads as haze rather than an edge, so the limit is
-- drawn as a ring instead: a line on the ground, one at head height, and a post
-- every eighth segment tying them together. The fill stays faint underneath.
local function drawBounds()
    if not maxDistance or maxDistance <= 0.0 then return end

    local r, g, b = colors.bounds[1], colors.bounds[2], colors.bounds[3]
    local groundZ = anchor.z - 0.98

    DrawMarker(1, anchor.x, anchor.y, groundZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, maxDistance * 2.0, maxDistance * 2.0, 0.35, r, g, b, 45, false, false, 0, false, false, false, false)

    local count = #boundsRing
    for i = 1, count do
        local from, to = boundsRing[i], boundsRing[i % count + 1]
        local fx, fy = anchor.x + from[1] * maxDistance, anchor.y + from[2] * maxDistance
        local tx, ty = anchor.x + to[1] * maxDistance, anchor.y + to[2] * maxDistance

        DrawLine(fx, fy, groundZ, tx, ty, groundZ, r, g, b, 255)
        DrawLine(fx, fy, groundZ + 2.0, tx, ty, groundZ + 2.0, r, g, b, 180)

        if i % 8 == 1 then
            DrawLine(fx, fy, groundZ, fx, fy, groundZ + 2.0, r, g, b, 180)
        end
    end
end

local function rotationToRight(rotation)
    local yaw = math.rad(rotation.z + 90.0)
    return vec3(-math.sin(yaw), math.cos(yaw), 0.0)
end

-- The box's four corners, rotated about the cursor by the current heading.
-- Returned in ring order so drawLines can walk consecutive pairs and close back
-- to the first corner.
local function buildBoxCorners()
    local angle = math.rad(-heading)
    local sinHeading, cosHeading = math.sin(angle), math.cos(angle)
    local right = vec3(cosHeading, -sinHeading, 0.0)
    local forward = vec3(sinHeading, cosHeading, 0.0)
    local center = vec3(xCoord, yCoord, zCoord)
    local halfWidth, halfLength = width / 2, length / 2

    return {
        center + right * halfWidth + forward * halfLength,
        center - right * halfWidth + forward * halfLength,
        center - right * halfWidth - forward * halfLength,
        center + right * halfWidth - forward * halfLength,
    }
end

local function inBounds(x, y)
    local dx, dy = x - anchor.x, y - anchor.y
    return math.sqrt(dx * dx + dy * dy) <= maxDistance
end

local function clampCursor()
    local dx, dy = xCoord - anchor.x, yCoord - anchor.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > maxDistance then
        local scale = maxDistance / dist
        xCoord = round(anchor.x + dx * scale)
        yCoord = round(anchor.y + dy * scale)
    end
end

local function clampCamera()
    local offset = camPos - anchor
    local dist = #offset

    if dist > maxDistance then
        camPos = anchor + (offset / dist) * maxDistance
    end
end

local function raycast(from, to)
    local hit, coords, entity = ray.probe(from, to, 511, cache.ped)
    if hit and coords then
        return true, coords, entity or 0
    end

    return false, to, entity or 0
end

local function updateLaser()
    local origin = GetFinalRenderedCamCoord()
    local direction = ray.forward(GetFinalRenderedCamRot(2))
    local probeOrigin = origin + (direction * 0.15)
    local hit, coords, entity = raycast(probeOrigin, probeOrigin + direction * (maxDistance + 5.0))

    if hit and placementMode == 'onfoot' and entity == cache.ped then
        hit = false
    end

    laserStart = origin
    laserHit = hit

    if hit and coords then
        laserEnd = origin + direction * #(coords - origin)
    else
        laserEnd = origin + direction * 20.0
    end

    if not hit then return end

    xCoord = round(coords.x)
    yCoord = round(coords.y)
    zCoord = round(coords.z)
    clampCursor()

    if zoneType == 'box' then
        boxChanged = true
    end
end

local function tabletAnim(ped)
    return IsPedMale(ped) and tabletAnims.male or tabletAnims.female, 'base'
end

local function lockMovement()
    if movementLocked then return end

    lib.disableControls:Add(blockedControls)

    local dict, anim = tabletAnim(cache.ped)
    lib.playAnim(cache.ped, dict, anim, 8.0, -8.0, -1, 49)
    movementLocked = true
end

local function unlockMovement()
    if not movementLocked then return end

    lib.disableControls:Remove(blockedControls)
    ClearPedTasks(cache.ped)
    movementLocked = false
end

local function updateMovementLock()
    if not creatorActive or placementMode ~= 'onfoot' then return end

    if allowMovement then
        unlockMovement()
    else
        lockMovement()
    end
end

local function snapToGround(ped)
    local coords = GetEntityCoords(ped)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)

    if found then
        SetEntityCoords(ped, coords.x, coords.y, groundZ, false, false, false, false)
    end
end

local function createClone()
    local coords = GetEntityCoords(cache.ped)
    local ped = ClonePed(cache.ped, false, false, true)

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(cache.ped))
    snapToGround(ped)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityAsMissionEntity(ped, true, true)

    local dict, anim = tabletAnim(ped)
    lib.playAnim(ped, dict, anim, 8.0, -8.0, -1, 1)

    local pedCoords = GetEntityCoords(ped)
    lib.requestModel(tabletModel)
    local tabletObject = CreateObject(tabletModel, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false)
    SetEntityAsMissionEntity(tabletObject, true, true)
    SetModelAsNoLongerNeeded(tabletModel)
    AttachEntityToEntity(tabletObject, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, 0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)

    return ped, tabletObject
end

local function deleteClone()
    if tablet and DoesEntityExist(tablet) then
        DetachEntity(tablet, true, true)
        DeleteEntity(tablet)
    end

    if clone and DoesEntityExist(clone) then
        ClearPedTasks(clone)
        DeleteEntity(clone)
    end
end

local function enterFreecam(options)
    -- hardcoded so anticheats/resources can hook this event name directly
    TriggerEvent('Newb_Bridge:client:zoneCreatorEnteredFreecam', {
        name = zoneName,
        type = zoneType,
        anchor = anchor,
        maxDistance = maxDistance,
    })

    clone, tablet = createClone()

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camHeading = GetEntityHeading(cache.ped)
    local pos, pitch

    if options.elevatedStart == true then
        pos = anchor + vec3(0.0, 0.0, tonumber(options.elevatedHeight) or 18.0)
        pitch = tonumber(options.elevatedPitch) or -35.0
    else
        pos = anchor + vec3(0.0, 0.0, tonumber(options.cameraHeight) or 1.65) -- eye height
        pitch = tonumber(options.cameraPitch) or 0.0
    end

    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, pitch, 0.0, camHeading, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, camEase, true, false) -- ease in from the gameplay cam instead of cutting

    FreezeEntityPosition(cache.ped, true)
    SetEntityVisible(cache.ped, false, false)
    SetEntityCollision(cache.ped, false, false)

    camPos = pos
    camRot = GetCamRot(cam, 2)

    -- the real ped is hidden now, so anchor the zone on the visible clone instead
    local coords = GetEntityCoords(clone)
    xCoord = round(coords.x)
    yCoord = round(coords.y)
    zCoord = round(options.planeZ or (options.anchor and options.anchor.z) or coords.z)

    if not options.anchor then
        anchor = vec3(coords.x, coords.y, zCoord)
    end
end

local function exitFreecam()
    local currentCam = cam
    local ease = camEase

    RenderScriptCams(false, true, ease, true, true)

    -- destroying the cam mid-blend snaps the view, so wait out the ease first
    SetTimeout(ease, function()
        if DoesCamExist(currentCam) then
            DestroyCam(currentCam, false)
        end
    end)

    deleteClone()

    FreezeEntityPosition(cache.ped, false)
    SetEntityVisible(cache.ped, true, false)
    SetEntityCollision(cache.ped, true, true)
end

local function moveCamera()
    local speed = 21.0 * GetFrameTime() * (IsDisabledControlPressed(0, 21) and 3.0 or 1.0)
    local forward = ray.forward(camRot)
    local right = rotationToRight(camRot)

    if IsDisabledControlPressed(0, 32) then camPos += forward * speed end
    if IsDisabledControlPressed(0, 33) then camPos -= forward * speed end
    if IsDisabledControlPressed(0, 34) then camPos += right * speed end
    if IsDisabledControlPressed(0, 35) then camPos -= right * speed end
    if IsDisabledControlPressed(0, 44) then camPos += vec3(0.0, 0.0, speed) end -- q up
    if IsDisabledControlPressed(0, 36) then camPos -= vec3(0.0, 0.0, speed) end -- lctrl down

    clampCamera()
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
end

local function turnCamera()
    local lookX = GetDisabledControlNormal(0, 1) * 4.5
    local lookY = GetDisabledControlNormal(0, 2) * 4.5

    if lookX == 0.0 and lookY == 0.0 then return end

    camRot = vec3(lib.math.clamp(camRot.x - lookY, -89.0, 89.0), camRot.y, camRot.z - lookX)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
end

local function closeCreator()
    creatorActive = false
    updateKeybind()
    updateModeKeybind()

    if placementMode == 'freecam' and cam then
        -- hardcoded so anticheats/resources can hook this event name directly
        TriggerEvent('Newb_Bridge:client:zoneCreatorExitedFreecam', { name = zoneName, type = zoneType })
        exitFreecam()
    elseif placementMode == 'onfoot' then
        unlockMovement()
    end

    SendNUIMessage({ type = 'zoneCreator:close' })
    cam, clone, tablet = nil, nil, nil
    zoneType = nil
end

local function pressed(control)
    return IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
end

local function justPressed(control)
    return IsDisabledControlJustPressed(0, control) or IsControlJustPressed(0, control)
end

local function enableControls(ids)
    for i = 1, #ids do
        EnableControlAction(0, ids[i], true)
    end
end

local function resize(value, amount)
    return round(math.max(0.05, value + amount))
end

local function canSave()
    if zoneType == 'poly' then
        if #points < 2 then
            showError('min_points')
            return false
        end

        return true
    end

    if not laserHit then
        showError('no_aim')
        return false
    end

    if not inBounds(xCoord, yCoord) then
        showError('outside_bounds')
        return false
    end

    return true
end

local function buildResult(includeCursor)
    if zoneType == 'poly' then
        local zonePoints = {}
        for i = 1, #points do
            zonePoints[i] = points[i]
        end

        if includeCursor then
            zonePoints[#zonePoints + 1] = vec3(xCoord, yCoord, zCoord)
        end

        return { name = zoneName, points = zonePoints, thickness = height }
    end

    if zoneType == 'box' then
        return {
            name = zoneName,
            coords = vec3(xCoord, yCoord, zCoord),
            size = vec3(width, length, height),
            rotation = heading,
        }
    end

    return { name = zoneName, coords = vec3(xCoord, yCoord, zCoord), radius = height }
end

local function getName(options)
    local name = options.name or options.zoneid or options.zoneId

    if type(name) ~= 'string' then return end

    name = name:match('^%s*(.-)%s*$')
    if name ~= '' then return name end
end

local function swapMode()
    if not creatorActive then return end

    if placementMode == 'freecam' then
        TriggerEvent('Newb_Bridge:client:zoneCreatorExitedFreecam', { name = zoneName, type = zoneType })
        exitFreecam()
        placementMode = 'onfoot'
        controlsActive = true
        updateMovementLock()
    else
        unlockMovement()
        placementMode = 'freecam'
        controlsActive = true

        local options = createOptions or {}
        enterFreecam({
            anchor = anchor,
            planeZ = zCoord,
            cameraHeight = options.cameraHeight,
            cameraPitch = options.cameraPitch,
            elevatedStart = options.elevatedStart,
            elevatedHeight = options.elevatedHeight,
            elevatedPitch = options.elevatedPitch,
        })
    end

    updateKeybind()
    updateModeKeybind()
    uiChanged = true
    updateText(true)
end

local function startCreator(requestedType, name, options)
    creatorActive = true
    controlsActive = true
    zoneType = requestedType
    zoneName = name
    createOptions = options

    local coords = GetEntityCoords(cache.ped)
    zCoord = round(options.planeZ or (options.anchor and options.anchor.z) or coords.z)
    anchor = options.anchor and vec3(options.anchor.x, options.anchor.y, options.anchor.z) or vec3(coords.x, coords.y, zCoord)
    maxDistance = tonumber(options.maxDistance) or 50.0
    camEase = tonumber(options.camEaseMs) or 1200

    local defaultHeight = 8.0 -- poly wall height
    if zoneType == 'box' then defaultHeight = 2.0 end
    if zoneType == 'sphere' then defaultHeight = 1.05 end

    step = lib.math.clamp(math.floor(tonumber(options.step) or (zoneType == 'sphere' and 1 or 5)), 1, #distanceSteps)
    xCoord = round(coords.x)
    yCoord = round(coords.y)
    heading = tonumber(options.rotation) or GetEntityHeading(cache.ped)
    height = tonumber(options.height) or tonumber(options.thickness) or tonumber(options.radius) or defaultHeight
    width = tonumber(options.width) or 2.0
    length = tonumber(options.length) or 2.0
    points = {}
    boxCorners = {}
    boxChanged = zoneType == 'box'
    laserStart, laserEnd, laserHit = nil, nil, false
    allowMovement = options.allowMovement ~= false
    movementToggle = options.movementToggle ~= false
    movementLocked = false
    uiChanged = true

    -- callers can force the starting mode; otherwise poly opens in the freecam
    -- and box/sphere start on foot
    placementMode = options.mode or options.startMode
    if placementMode ~= 'freecam' and placementMode ~= 'onfoot' then
        placementMode = zoneType == 'poly' and 'freecam' or 'onfoot'
    end

    if placementMode == 'freecam' then
        enterFreecam(options)
    else
        updateMovementLock()
    end

    updateKeybind()
    updateModeKeybind()
    openUI()
    updateText(true)

    local result
    lastPanelPush = GetGameTimer()
    local openedAt = GetGameTimer()

    controls.blockCancelWhile(function() return creatorActive end)

    while creatorActive do
        Wait(0)

        DisableAllControlActions(0)
        enableControls({ 1, 2, 16, 17, 245 }) -- look, scroll, chat; confirm/cancel are read while disabled

        if placementMode == 'freecam' then
            enableControls({ 21, 24, 25, 73 }) -- shift, lmb, rmb, mode toggle

            if not controlsActive then
                enableControls(freecamControls)
            end

            turnCamera()

            if justPressed(73) then -- x swaps between editing and flying the camera
                controlsActive = not controlsActive
                uiChanged = true
                updateText(true)
            end

            if not controlsActive then
                moveCamera()
            end
        elseif allowMovement then
            enableControls({ 21, 22, 30, 31, 32, 33, 34, 35, 36, 19, 44, 38 })
        else
            lib.disableControls()
        end

        if controlsActive then
            local change = false
            local distanceStep = distanceSteps[step]
            local rotationStep = angleSteps[step]

            if justPressed(17) then -- scroll up
                if zoneType == 'sphere' then
                    if pressed(21) then -- shift held down
                        if step < #distanceSteps then
                            change = true
                            step += 1
                        end
                    else
                        change = true
                        height = resize(height, distanceStep)
                    end
                elseif zoneType == 'box' then
                    if pressed(36) then -- ctrl held down
                        change = true
                        width = resize(width, distanceStep)
                        boxChanged = true
                    elseif pressed(19) then -- alt held down
                        change = true
                        length = resize(length, distanceStep)
                        boxChanged = true
                    elseif pressed(21) then -- shift held down
                        if step < #distanceSteps then
                            change = true
                            step += 1
                        end
                    else
                        change = true
                        height = resize(height, distanceStep)
                        boxChanged = true
                    end
                elseif pressed(21) then -- shift held down
                    change = true
                    height = resize(height, distanceStep)
                elseif step < #distanceSteps then
                    change = true
                    step += 1
                end
            elseif justPressed(16) then -- scroll down
                if zoneType == 'sphere' then
                    if pressed(21) then -- shift held down
                        if step > 1 then
                            change = true
                            step -= 1
                        end
                    else
                        change = true
                        height = resize(height, -distanceStep)
                    end
                elseif zoneType == 'box' then
                    if pressed(36) then -- ctrl held down
                        change = true
                        width = resize(width, -distanceStep)
                        boxChanged = true
                    elseif pressed(19) then -- alt held down
                        change = true
                        length = resize(length, -distanceStep)
                        boxChanged = true
                    elseif pressed(21) then -- shift held down
                        if step > 1 then
                            change = true
                            step -= 1
                        end
                    else
                        change = true
                        height = resize(height, -distanceStep)
                        boxChanged = true
                    end
                elseif pressed(21) then -- shift held down
                    change = true
                    height = resize(height, -distanceStep)
                elseif step > 1 then
                    change = true
                    step -= 1
                end
            elseif zoneType == 'box' and justPressed(controls.rotateLeft) then -- left arrow
                change = true
                heading = (heading - rotationStep) % 360
                boxChanged = true
            elseif zoneType == 'box' and justPressed(controls.rotateRight) then -- right arrow
                change = true
                heading = (heading + rotationStep) % 360
                boxChanged = true
            elseif zoneType == 'poly' and justPressed(24) then -- lmb drops a point
                if laserHit then
                    change = true
                    points[#points + 1] = vec3(xCoord, yCoord, zCoord)
                else
                    showError('no_aim')
                end
            elseif zoneType == 'poly' and justPressed(25) and #points > 0 then -- rmb undoes the last point
                change = true
                xCoord = points[#points].x
                yCoord = points[#points].y
                zCoord = points[#points].z
                points[#points] = nil
            end

            if change then
                uiChanged = true
            end

            updateLaser()
            drawLaser()
        end

        if zoneType == 'box' then
            if boxChanged then
                boxCorners = buildBoxCorners()
                boxChanged = false
            end

            drawLines()
        elseif zoneType == 'sphere' then
            DrawMarker(28, xCoord, yCoord, zCoord, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, height, height, height, colors.outline[1], colors.outline[2], colors.outline[3], 100, false, false, 0, false, false, false, false)
        else
            drawLines()
        end

        if placementMode == 'freecam' then
            drawBounds()
        end

        updateText(false)

        if justPressed(controls.place) then -- e confirms
            if canSave() then
                result = buildResult(zoneType == 'poly' and laserHit)
                creatorActive = false
            end
        elseif justPressed(controls.cancel) and GetGameTimer() - openedAt >= controls.cancelGraceMs then -- backspace cancels
            creatorActive = false
        end
    end

    return result
end

---@param options? ZoneCreatorOptions
---@return ZoneCreatorResult|nil
local function createZone(options)
    options = options or {}

    if creatorActive then
        showError('already_active')
        return
    end

    local zType = options.type or options.zoneType or 'poly'
    if zType ~= 'poly' and zType ~= 'box' and zType ~= 'sphere' then
        showError('invalid_type')
        return
    end

    local name = getName(options)
    if not name then
        showError('missing_name')
        return
    end

    creatorOwner = GetInvokingResource()
    local result = startCreator(zType, name, options)
    creatorOwner = nil
    closeCreator()

    return result
end

exports('CreateZone', createZone)

movementKeybind = lib.addKeybind({
    name = '_zoneCreatorMovement',
    description = bridge.locale('zone_creator.toggle_movement'),
    defaultKey = 'B',
    disabled = true,
    onPressed = function()
        if not creatorActive or placementMode ~= 'onfoot' or not movementToggle then return end

        allowMovement = not allowMovement
        updateMovementLock()
        uiChanged = true
        updateText(true)
    end,
})

modeKeybind = lib.addKeybind({
    name = '_zoneCreatorMode',
    description = bridge.locale('zone_creator.toggle_mode_key'),
    defaultKey = 'F',
    disabled = true,
    onPressed = function()
        if not creatorActive then return end
        swapMode()
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if not creatorActive then return end

    if cache.resource == resource then
        closeCreator()
        return
    end

    -- The invoking resource died mid-session; ending the loop lets the pending
    -- createZone call restore the camera/ped and close the UI on its next tick.
    if creatorOwner == resource then
        creatorActive = false
    end
end)
