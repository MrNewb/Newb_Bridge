local controls = require '@Newb_Bridge/utility/client/placement_controls'
local ray = require '@Newb_Bridge/utility/client/camera_ray'

-- placement laser colours and marker sizes
local laserLine = { 84, 227, 129 }
local laserDot = { 34, 139, 230 }
local cornerDot = { 250, 176, 5 }
local aimSize, cornerSize = 0.12, 0.10

local surfaceOffset = 0.01 -- lift quads off the surface to avoid z-fighting
local defaultWorldWidth = 1.5
local minWorld, maxWorld = 0.25, 12.0 -- world size clamp in meters
local minDui, maxDui = 256, 2048 -- DUI texture clamp in pixels
local drawDistance = 60.0
local placementMax = 20.0 -- default max placement distance
local poolMax = 8 -- max pooled DUI browsers
local shellUrl = 'nui://Newb_Bridge/web/build/dui_surface.html'
local poolShellUrl = shellUrl .. '#pool=1'

local creatorActive, cancelPlacement = false, false
local poolAvailable, poolInUse, contentSlots = {}, {}, {}
local poolNextId, poolPrewarmed = 0, false

local function readSrc(raw)
    if type(raw) == 'string' then return raw:match('^%s*(.-)%s*$') or '' end
    if type(raw) ~= 'table' then return '' end
    local src = raw.src or raw.url or ''
    return type(src) == 'string' and (src:match('^%s*(.-)%s*$') or '') or ''
end

local function urlEncode(value)
    return type(value) == 'string' and value:gsub('([^%w%-%.%_%~])', function(c)
        return ('%%%02X'):format(string.byte(c))
    end) or ''
end

local function clampDuiDimensions(width, height)
    width = math.max(minDui, math.min(math.floor(tonumber(width) or 1024), maxDui))
    height = math.max(minDui, math.min(math.floor(tonumber(height) or 1024), maxDui))
    return width, height
end

local function clampWorldSize(size)
    return math.max(minWorld, math.min(math.abs(size), maxWorld))
end

local function normalizeCorner(raw)
    if type(raw) == 'vector3' then return { x = raw.x, y = raw.y, z = raw.z } end
    if type(raw) ~= 'table' then return end
    local x, y, z = tonumber(raw.x), tonumber(raw.y), tonumber(raw.z)
    if x and y and z then return { x = x, y = y, z = z } end
end

local function normalizeNormal(raw)
    if type(raw) == 'vector3' then return normalizeNormal({ x = raw.x, y = raw.y, z = raw.z }) end
    if type(raw) ~= 'table' then return end
    local x, y, z = tonumber(raw.x), tonumber(raw.y), tonumber(raw.z)
    if not x or not y or not z then return end
    local len = math.sqrt((x * x) + (y * y) + (z * z))
    if len < 0.0001 then return end
    return { x = x / len, y = y / len, z = z / len }
end

local function normalizeContent(raw)
    raw = type(raw) == 'table' and raw or {}
    local width = math.floor(tonumber(raw.width) or 1024)
    local height = math.floor(tonumber(raw.height) or 1024)
    width = math.max(minDui, math.min(width, maxDui))
    height = math.max(minDui, math.min(height, maxDui))
    local worldWidth, worldHeight = tonumber(raw.worldWidth), tonumber(raw.worldHeight)
    if worldWidth then worldWidth = clampWorldSize(worldWidth) end
    if worldHeight then worldHeight = clampWorldSize(worldHeight) end
    local aspect = tonumber(raw.aspect)
    if not aspect or aspect <= 0 then aspect = height / width end
    return {
        contentType = 'image',
        src = readSrc(raw),
        width = width,
        height = height,
        worldWidth = worldWidth,
        worldHeight = worldHeight,
        aspect = aspect,
        normal = normalizeNormal(raw.normal),
        cornerTL = normalizeCorner(raw.cornerTL),
        cornerBR = normalizeCorner(raw.cornerBR),
        planeW = tonumber(raw.planeW),
        planeH = tonumber(raw.planeH),
        txd = type(raw.txd) == 'string' and raw.txd ~= '' and raw.txd or nil,
        txn = type(raw.txn) == 'string' and raw.txn ~= '' and raw.txn or nil,
    }
end

local function resolveWorldWidth(dui)
    local w = type(dui) == 'table' and tonumber(dui.worldWidth) or nil
    return w and w > 0 and clampWorldSize(w) or defaultWorldWidth
end

local function resolveWorldHeight(dui, fallbackWidth)
    local h = type(dui) == 'table' and tonumber(dui.worldHeight) or nil
    if h and h > 0 then return clampWorldSize(h) end
    local width = fallbackWidth or resolveWorldWidth(dui)
    local aspect = type(dui) == 'table' and tonumber(dui.aspect) or 1
    return clampWorldSize(width * aspect)
end

local function resolveNormal(dui, coords)
    local normal = type(dui) == 'table' and normalizeNormal(dui.normal) or nil
    if normal then return vector3(normal.x, normal.y, normal.z) end
    local heading = type(coords) == 'vector4' and (coords.w or 0.0)
        or type(coords) == 'table' and (tonumber(coords.w) or 0.0) or 0.0
    local rad = math.rad(heading)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function cross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

local function normalizeVector(v)
    local len = #v
    return len < 0.0001 and vector3(0.0, 0.0, 1.0) or (v / len)
end

local function buildPlaneBasis(normal)
    normal = normalizeVector(normal)
    local worldUp = math.abs(normal.z) > 0.95 and vector3(0.0, 1.0, 0.0) or vector3(0.0, 0.0, 1.0)
    local right = normalizeVector(cross(worldUp, normal))
    return right, normalizeVector(cross(normal, right)), normal
end

local function fitAxesToAspect(w, h, aspect)
    if not aspect or aspect <= 0 then return w, h end
    if math.abs(w) < 0.001 and math.abs(h) < 0.001 then return 0.5, 0.5 * aspect end
    if math.abs(w) < 0.001 then return math.abs(h) / aspect * (h < 0 and -1 or 1), h end
    if math.abs(h) < 0.001 then return w, math.abs(w) * aspect * (h < 0 and -1 or 1) end
    local dragAspect = math.abs(h) / math.abs(w)
    if dragAspect > aspect then
        h = (h < 0 and -1 or 1) * math.abs(w) * aspect
    else
        w = (w < 0 and -1 or 1) * math.abs(h) / aspect
    end
    return w, h
end

local function buildQuadFromCorners(topLeft, bottomRight, normal, lockAspect)
    local right, up, planeNormal = buildPlaneBasis(normal)
    local origin = topLeft + (planeNormal * surfaceOffset)
    local diff = bottomRight - topLeft
    local w = (diff.x * right.x) + (diff.y * right.y) + (diff.z * right.z)
    local h = (diff.x * up.x) + (diff.y * up.y) + (diff.z * up.z)
    if lockAspect and lockAspect > 0 then w, h = fitAxesToAspect(w, h, lockAspect) end
    if math.abs(w) < 0.05 then w = w < 0 and -0.5 or 0.5 end
    if math.abs(h) < 0.05 then h = h < 0 and -0.5 or 0.5 end
    w = w < 0 and -clampWorldSize(w) or clampWorldSize(w)
    h = h < 0 and -clampWorldSize(h) or clampWorldSize(h)
    local tr = origin + (right * w)
    local bl = origin + (up * h)
    local br = origin + (right * w) + (up * h)
    return origin, tr, br, bl, math.abs(w), math.abs(h), origin + (right * (w * 0.5)) + (up * (h * 0.5)), w, h
end

local function buildQuadFromTopLeft(topLeft, normal, planeW, planeH)
    local right, up, planeNormal = buildPlaneBasis(normal)
    local origin = topLeft + (planeNormal * surfaceOffset)
    return origin, origin + (right * planeW), origin + (right * planeW) + (up * planeH), origin + (up * planeH)
end

local function hasPlacement(dui)
    dui = normalizeContent(dui)
    if not dui.cornerTL then return false end
    local planeW = tonumber(dui.planeW)
    if planeW and math.abs(planeW) >= 0.05 then return true end
    local worldWidth = tonumber(dui.worldWidth)
    return worldWidth ~= nil and worldWidth > 0
end

local function toCenter(coords)
    if type(coords) == 'vector3' then return coords end
    if type(coords) == 'vector4' then return vector3(coords.x, coords.y, coords.z) end
    if type(coords) == 'table' then return vector3(coords.x or 0, coords.y or 0, coords.z or 0) end
    return vector3(0, 0, 0)
end

local function resolveQuadCorners(dui, coords)
    dui = normalizeContent(dui)
    local normal = resolveNormal(dui, coords)
    if dui.cornerTL and (dui.planeW or dui.worldWidth) then
        local topLeft = vector3(dui.cornerTL.x, dui.cornerTL.y, dui.cornerTL.z)
        local planeW = tonumber(dui.planeW) or resolveWorldWidth(dui)
        local planeH = tonumber(dui.planeH)
        if not planeH then
            local aspect = dui.aspect > 0 and dui.aspect or 1
            planeH = planeW * aspect
            if dui.cornerBR then
                local br = vector3(dui.cornerBR.x, dui.cornerBR.y, dui.cornerBR.z)
                local _, up = buildPlaneBasis(normal)
                local diff = br - topLeft
                planeH = (diff.x * up.x) + (diff.y * up.y) + (diff.z * up.z)
                if math.abs(planeH) < 0.001 then planeH = planeW * aspect end
            end
        end
        return buildQuadFromTopLeft(topLeft, normal, planeW, planeH)
    end
    if dui.cornerTL and dui.cornerBR then
        local topLeft = vector3(dui.cornerTL.x, dui.cornerTL.y, dui.cornerTL.z)
        local bottomRight = vector3(dui.cornerBR.x, dui.cornerBR.y, dui.cornerBR.z)
        return buildQuadFromCorners(topLeft, bottomRight, normal, nil)
    end
    local center = toCenter(coords)
    local worldWidth, worldHeight = resolveWorldWidth(dui), resolveWorldHeight(dui)
    local right, up, planeNormal = buildPlaneBasis(normal)
    local origin = center + (planeNormal * surfaceOffset)
    local halfW, halfH = worldWidth * 0.5, worldHeight * 0.5
    local tl = origin - (right * halfW) + (up * halfH)
    local tr = origin + (right * halfW) + (up * halfH)
    local br = origin + (right * halfW) - (up * halfH)
    local bl = origin - (right * halfW) - (up * halfH)
    return tl, tr, br, bl
end

local function resolveBoardCenter(dui, coords)
    if not hasPlacement(dui) then return end
    local tl, tr, br, bl = resolveQuadCorners(dui, coords)
    return vector3((tl.x + tr.x + br.x + bl.x) * 0.25, (tl.y + tr.y + br.y + bl.y) * 0.25, (tl.z + tr.z + br.z + bl.z) * 0.25)
end

local function resolveTargetZoneRadius(dui)
    dui = normalizeContent(dui)
    local worldWidth, worldHeight = resolveWorldWidth(dui), resolveWorldHeight(dui)
    return math.min(1.0, math.max(0.45, math.min(worldWidth, worldHeight) * 0.5))
end

local function buildShellUrl(content, boardKey)
    content = normalizeContent(content)
    local hash = {}
    if type(boardKey) == 'string' and boardKey ~= '' then
        hash[#hash + 1] = ('boardKey=%s'):format(urlEncode(boardKey))
    end
    if content.src ~= '' then
        hash[#hash + 1] = ('src=%s'):format(urlEncode(content.src))
    end
    return #hash == 0 and shellUrl or ('%s#%s'):format(shellUrl, table.concat(hash, '&'))
end

local function contentSignature(dui)
    return normalizeContent(dui).src
end

local function syncDuiContent(libDui, content, boardKey)
    if not libDui or type(libDui.sendMessage) ~= 'function' then return end
    content = normalizeContent(content)
    if content.src == '' then return end
    libDui:sendMessage({
        action = 'duiSurfaceSetContent',
        src = content.src,
        boardKey = boardKey,
    })
end

local function resetPooledDui(libDui)
    if libDui and type(libDui.sendMessage) == 'function' then
        libDui:sendMessage({ action = 'duiSurfaceReset' })
    end
end

local function createPooledDui()
    local width, height = clampDuiDimensions(1024, 1024)
    local libDui = lib.dui:new({ url = poolShellUrl, width = width, height = height, debug = Config.Debug == true })
    if not libDui then return end
    poolNextId = poolNextId + 1
    return { id = poolNextId, libDui = libDui }
end

local function acquirePooledDui()
    if #poolAvailable > 0 then
        local wrapper = table.remove(poolAvailable)
        poolInUse[wrapper.id] = wrapper
        return wrapper
    end
    if poolNextId >= poolMax then return end
    local wrapper = createPooledDui()
    if wrapper then poolInUse[wrapper.id] = wrapper end
    return wrapper
end

local function releasePooledDui(id)
    local wrapper = poolInUse[id]
    if not wrapper then return end
    poolInUse[id] = nil
    resetPooledDui(wrapper.libDui)
    poolAvailable[#poolAvailable + 1] = wrapper
end

local function cleanupDuiPool()
    contentSlots = {}
    for _, wrapper in pairs(poolInUse) do wrapper.libDui:remove() end
    poolInUse = {}
    for i = 1, #poolAvailable do poolAvailable[i].libDui:remove() end
    poolAvailable, poolNextId, poolPrewarmed = {}, 0, false
end

local function resolveBoardLibDui(surface)
    if not surface then return end
    if not surface.pooled then return surface.libDui end
    local slot = contentSlots[surface.contentSignature]
    if not slot then return end
    local wrapper = poolInUse[slot.poolId]
    return wrapper and wrapper.libDui
end

local function releaseContentHolder(signature, boardKey)
    local slot = contentSlots[signature]
    if not slot or not slot.holders[boardKey] then return end
    slot.holders[boardKey] = nil
    slot.refCount = slot.refCount - 1
    if slot.refCount > 0 then return end
    contentSlots[signature] = nil
    releasePooledDui(slot.poolId)
end

local function stealPooledWrapper(manager, camCoord, excludeKey)
    local stealSig, stealDistSq = nil, -1.0
    for signature, slot in pairs(contentSlots) do
        if slot.refCount == 1 then
            local holderKey = next(slot.holders)
            local center = holderKey and holderKey ~= excludeKey and manager.boards[holderKey] and manager.boards[holderKey].cachedCenter
            if center then
                local dx, dy, dz = camCoord.x - center.x, camCoord.y - center.y, camCoord.z - center.z
                local distSq = (dx * dx) + (dy * dy) + (dz * dz)
                if distSq > stealDistSq then stealDistSq, stealSig = distSq, signature end
            end
        end
    end
    if not stealSig then return end
    for holderKey in pairs(contentSlots[stealSig].holders) do
        local board = manager.boards[holderKey]
        if board then manager:releaseBoardSurface(board) end
    end
    return acquirePooledDui()
end

local function acquireContentSlot(manager, signature, dui, boardKey, camCoord)
    local slot = contentSlots[signature]
    if slot then
        if not slot.holders[boardKey] then
            slot.holders[boardKey] = true
            slot.refCount = slot.refCount + 1
        end
        slot.dui = dui
        return slot
    end
    local wrapper = acquirePooledDui() or (camCoord and stealPooledWrapper(manager, camCoord, boardKey))
    if not wrapper then return end
    slot = { signature = signature, poolId = wrapper.id, refCount = 1, holders = { [boardKey] = true }, dui = dui }
    contentSlots[signature] = slot
    syncDuiContent(wrapper.libDui, dui, boardKey)
    return slot
end

local function rebuildBoardGeometry(board)
    if not board.coords then
        board.cachedCenter, board.cachedCorners, board.cachedNormal = nil, nil, nil
        return
    end
    local dui = normalizeContent(board.dui)
    local tl, tr, br, bl = resolveQuadCorners(dui, board.coords)
    board.cachedCorners = { tl, tr, br, bl }
    board.cachedCenter = vector3((tl.x + tr.x + br.x + bl.x) * 0.25, (tl.y + tr.y + br.y + bl.y) * 0.25, (tl.z + tr.z + br.z + bl.z) * 0.25)
    board.cachedNormal = resolveNormal(dui, board.coords)
end

local function isQuadOnScreen(tl, tr, br, bl)
    -- GetScreenCoordFromWorldCoord returns a boolean retval, not an int
    if GetScreenCoordFromWorldCoord(tl.x, tl.y, tl.z) then return true end
    if GetScreenCoordFromWorldCoord(tr.x, tr.y, tr.z) then return true end
    if GetScreenCoordFromWorldCoord(br.x, br.y, br.z) then return true end
    if GetScreenCoordFromWorldCoord(bl.x, bl.y, bl.z) then return true end
    local cx = (tl.x + tr.x + br.x + bl.x) * 0.25
    local cy = (tl.y + tr.y + br.y + bl.y) * 0.25
    local cz = (tl.z + tr.z + br.z + bl.z) * 0.25
    return (GetScreenCoordFromWorldCoord(cx, cy, cz))
end

local creatorLocaleKeys = {
    'title', 'subtitle_top_left', 'subtitle_bottom_right', 'subtitle_target',
    'status_ready', 'status_too_far', 'status_aiming', 'phase_top_left',
    'phase_bottom_right', 'phase_target', 'position', 'distance', 'max_distance',
    'world_size', 'controls', 'place_corner', 'place_target', 'confirm_size',
    'reset_corner', 'exit',
}

local function creatorLocales()
    local strings = {}
    for i = 1, #creatorLocaleKeys do
        strings[creatorLocaleKeys[i]] = bridge.locale('dui_creator.' .. creatorLocaleKeys[i])
    end
    return strings
end

local function drawTooFarWarning()
    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(240, 62, 62, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(bridge.locale('dui_creator.status_too_far'))
    EndTextCommandDisplayText(0.5, 0.88)
end

-- frontend cancel/back stays disabled for the whole placement session
local function drainCancelWhile(isActive)
    CreateThread(function()
        while isActive() do
            DisableControlAction(0, controls.cancel, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 202, true)
            DisableControlAction(0, 177, true)
            Wait(0)
        end
    end)
end

local function computeBoardAlpha(distance)
    local fadeDistance = drawDistance * 0.85
    if distance <= fadeDistance then return 255 end
    if distance >= drawDistance then return 0 end
    return math.floor(255 * (1.0 - ((distance - fadeDistance) / (drawDistance - fadeDistance))))
end

local DuiSurfaceManager = lib.class('DuiSurfaceManager')

function DuiSurfaceManager:constructor()
    self.boards = {}
    self.preview = nil
    self.visibleDrawList = {}
    self.visibilityThreadActive = false
    self.drawThreadActive = false
end

function DuiSurfaceManager:raycastFromCamera(maxDistance)
    local camCoord = GetFinalRenderedCamCoord()
    local destination = camCoord + (ray.forward() * (maxDistance + 5.0))
    local hit, endCoords, _, _, surfaceNormal = ray.probe(camCoord, destination, -1, cache.ped)
    if not hit or not endCoords then return false, nil, camCoord, nil end
    return true, endCoords, camCoord, surfaceNormal
end

function DuiSurfaceManager:applyContentSize(boardKey, width, height)
    width, height = clampDuiDimensions(width, height)
    if width < 1 or height < 1 then return end
    local board = (boardKey == 'preview' and self.preview) or self.boards[boardKey]
    if not board or not board.surface or board.surface.pooled then return end
    local dui = normalizeContent(board.dui)
    if dui.width == width and dui.height == height then return end
    dui.width, dui.height, dui.aspect = width, height, height / width
    board.dui = dui
    self:ensurePreviewDui(board)
end

function DuiSurfaceManager:pushDuiContent(boardKey)
    local board = (boardKey == 'preview' and self.preview) or self.boards[boardKey]
    if not board or not board.surface then return end
    local libDui = resolveBoardLibDui(board.surface)
    if not libDui then return end
    if board.surface.pooled then
        syncDuiContent(libDui, board.dui, boardKey)
        return
    end
    local dui, generation = board.dui, (board.surface.pushGeneration or 0) + 1
    board.surface.pushGeneration = generation
    CreateThread(function()
        for attempt = 1, 3 do
            if not board.surface or resolveBoardLibDui(board.surface) ~= libDui or board.surface.pushGeneration ~= generation then return end
            syncDuiContent(libDui, dui, boardKey)
            Wait(attempt == 1 and 50 or 150)
        end
    end)
end

function DuiSurfaceManager:ensurePreviewDui(board)
    local dui = normalizeContent(board.dui)
    local boardKey, signature = board.key or 'preview', contentSignature(dui)
    local surface, url = board.surface, buildShellUrl(dui, boardKey)
    if surface and surface.signature == signature then return surface end
    if surface and surface.libDui and surface.dui and surface.dui.width == dui.width and surface.dui.height == dui.height then
        surface.libDui:setUrl(url)
        surface.signature, surface.dui = signature, dui
        self:pushDuiContent(boardKey)
        return surface
    end
    self:releaseBoardSurface(board)
    local libDui = lib.dui:new({ url = url, width = dui.width, height = dui.height, debug = Config.Debug == true })
    if not libDui then
        bridge.notifications.notify({ description = bridge.locale('dui_creator.errors.dui_failed'), type = 'error' })
        return
    end
    board.surface = { signature = signature, libDui = libDui, dui = dui, pooled = false }
    self:pushDuiContent(boardKey)
    return board.surface
end

function DuiSurfaceManager:syncBoardContent(board)
    local surface = board.surface
    if not surface or not surface.pooled then return end
    local boardKey, newSignature = board.key or 'unknown', contentSignature(board.dui)
    if surface.contentSignature == newSignature then
        local slot = contentSlots[newSignature]
        if slot then slot.dui = normalizeContent(board.dui) end
        return
    end
    releaseContentHolder(surface.contentSignature, boardKey)
    board.surface = nil
    board.renderGeneration = (board.renderGeneration or 0) + 1
end

function DuiSurfaceManager:acquireBoardSurface(board, camCoord)
    if board.surface then return board.surface end
    local dui, boardKey, signature = normalizeContent(board.dui), board.key or 'unknown', contentSignature(board.dui)
    if not acquireContentSlot(self, signature, dui, boardKey, camCoord) then return end
    board.surface = { pooled = true, contentSignature = signature }
    board.renderGeneration = (board.renderGeneration or 0) + 1
    return board.surface
end

function DuiSurfaceManager:releaseBoardSurface(board)
    local surface = board.surface
    if not surface then return end
    if surface.pooled and surface.contentSignature then
        releaseContentHolder(surface.contentSignature, board.key or 'unknown')
    elseif surface.libDui then
        surface.libDui:remove()
    end
    board.surface = nil
    board.renderGeneration = (board.renderGeneration or 0) + 1
end

function DuiSurfaceManager:updateVisibility()
    local camCoord = GetFinalRenderedCamCoord()
    local drawDistanceSq = drawDistance * drawDistance
    local visibleDrawList = {}
    for _, board in pairs(self.boards) do
        if not board.coords or not board.cachedCenter then
            if board.surface then self:releaseBoardSurface(board) end
            goto continue
        end
        local center = board.cachedCenter
        local dx, dy, dz = camCoord.x - center.x, camCoord.y - center.y, camCoord.z - center.z
        local distSq = (dx * dx) + (dy * dy) + (dz * dz)
        local shouldRender, alpha = false, 0
        if distSq > 0.0025 and distSq <= drawDistanceSq then
            local normal = board.cachedNormal
            if not normal or ((normal.x * dx) + (normal.y * dy) + (normal.z * dz)) > 0.0 then
                local corners = board.cachedCorners
                if corners and isQuadOnScreen(corners[1], corners[2], corners[3], corners[4]) then
                    alpha = computeBoardAlpha(math.sqrt(distSq))
                    shouldRender = alpha > 0
                end
            end
        end
        if shouldRender then
            if not board.surface then self:acquireBoardSurface(board, camCoord) end
            if board.surface then
                visibleDrawList[#visibleDrawList + 1] = { board = board, alpha = alpha, renderGeneration = board.renderGeneration }
            end
        elseif board.surface then
            self:releaseBoardSurface(board)
        end
        ::continue::
    end
    self.visibleDrawList = visibleDrawList
end

function DuiSurfaceManager:drawBoardAtWorld(coords, dui, surface, alpha, cachedCorners)
    local libDui = resolveBoardLibDui(surface)
    if not libDui or not libDui.dictName or not libDui.txtName then return end
    if libDui.duiObject and not IsDuiAvailable(libDui.duiObject) then return end
    alpha = math.floor(tonumber(alpha) or 255)
    if alpha <= 0 then return end
    local tl, tr, br, bl
    if cachedCorners then
        tl, tr, br, bl = cachedCorners[1], cachedCorners[2], cachedCorners[3], cachedCorners[4]
    else
        tl, tr, br, bl = resolveQuadCorners(normalizeContent(dui), coords)
    end
    local dict, txt = libDui.dictName, libDui.txtName
    DrawTexturedPoly(bl.x, bl.y, bl.z, br.x, br.y, br.z, tr.x, tr.y, tr.z, 255, 255, 255, alpha, dict, txt, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0)
    DrawTexturedPoly(bl.x, bl.y, bl.z, tr.x, tr.y, tr.z, tl.x, tl.y, tl.z, 255, 255, 255, alpha, dict, txt, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function DuiSurfaceManager:drawFrame()
    local camCoord, hasWork = GetFinalRenderedCamCoord(), false
    for i = 1, #self.visibleDrawList do
        local entry = self.visibleDrawList[i]
        local board = entry.board
        if board.coords and board.surface and board.renderGeneration == entry.renderGeneration then
            hasWork = true
            self:drawBoardAtWorld(board.coords, board.dui, board.surface, entry.alpha, board.cachedCorners)
        end
    end
    local preview = self.preview
    if not preview then return hasWork or #self.visibleDrawList > 0 end
    if preview.phase == 'target' and preview.hitCoords then
        hasWork = true
        local hitCoords = preview.hitCoords
        local origin = GetPedBoneCoords(cache.ped, 57005, 0.05, 0.0, 0.0)
        DrawLine(origin.x, origin.y, origin.z, hitCoords.x, hitCoords.y, hitCoords.z, laserLine[1], laserLine[2], laserLine[3], 220)
        DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, aimSize, aimSize, aimSize, laserDot[1], laserDot[2], laserDot[3], 190, false, false, 2, false, nil, nil, false)
        local cam = preview.camCoord or camCoord
        if cam and #(cam - hitCoords) > (preview.maxDistance or placementMax) then
            drawTooFarWarning()
        end
    end
    if preview.phase == 'bottomRight' and preview.topLeft and preview.hitCoords and preview.surface then
        hasWork = true
        self:drawBoardAtWorld(preview.topLeft, preview.dui, preview.surface, 255)
    end
    local hitCoords = preview.hitCoords
    if hitCoords then
        hasWork = true
        local cam, topLeft = preview.camCoord or camCoord, preview.topLeft
        local origin = GetPedBoneCoords(cache.ped, 57005, 0.05, 0.0, 0.0)
        DrawLine(origin.x, origin.y, origin.z, hitCoords.x, hitCoords.y, hitCoords.z, laserLine[1], laserLine[2], laserLine[3], 220)
        if topLeft then
            DrawLine(topLeft.x, topLeft.y, topLeft.z, hitCoords.x, hitCoords.y, hitCoords.z, laserDot[1], laserDot[2], laserDot[3], 220)
            DrawMarker(28, topLeft.x, topLeft.y, topLeft.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, cornerSize, cornerSize, cornerSize, laserDot[1], laserDot[2], laserDot[3], 210, false, false, 2, false, nil, nil, false)
        end
        local markerColor = topLeft and cornerDot or laserDot
        DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, aimSize, aimSize, aimSize, markerColor[1], markerColor[2], markerColor[3], 190, false, false, 2, false, nil, nil, false)
        if #(cam - hitCoords) > (preview.maxDistance or placementMax) then
            drawTooFarWarning()
        end
    end
    return hasWork or self.preview ~= nil
end

function DuiSurfaceManager:shouldKeepRenderThreads()
    return self.preview ~= nil or next(self.boards) ~= nil
end

local function prewarmDuiPool(manager)
    if poolPrewarmed then return end
    poolPrewarmed = true
    CreateThread(function()
        Wait(1000)
        if poolNextId < poolMax then
            local wrapper = createPooledDui()
            if wrapper then poolAvailable[#poolAvailable + 1] = wrapper end
        end
        if manager:shouldKeepRenderThreads() then manager:ensureRenderThreads() end
    end)
end

function DuiSurfaceManager:ensureRenderThreads()
    prewarmDuiPool(self)
    if not self.visibilityThreadActive then
        self.visibilityThreadActive = true
        CreateThread(function()
            while true do
                if self:shouldKeepRenderThreads() then self:updateVisibility() else self.visibleDrawList = {} end
                Wait(self.preview and 0 or 100)
                if not self:shouldKeepRenderThreads() then self.visibilityThreadActive = false break end
            end
        end)
    end
    if not self.drawThreadActive then
        self.drawThreadActive = true
        CreateThread(function()
            while true do
                local hasWork = self:shouldKeepRenderThreads() and self:drawFrame()
                Wait(hasWork and (self.preview and 0 or 1) or 250)
                if not self:shouldKeepRenderThreads() then self.drawThreadActive = false break end
            end
        end)
    end
end

function DuiSurfaceManager:setBoardData(board, data)
    board.coords = data.coords
    board.dui = normalizeContent(data.content or data.dui)
    rebuildBoardGeometry(board)
    if board.surface then self:syncBoardContent(board) end
end

function DuiSurfaceManager:register(key, data)
    if type(data) ~= 'table' or not data.coords then return end
    local board = self.boards[key] or { key = key }
    self.boards[key] = board
    self:setBoardData(board, data)
    prewarmDuiPool(self)
    self:ensureRenderThreads()
end

function DuiSurfaceManager:update(key, data)
    if type(data) ~= 'table' then return false end
    local board = self.boards[key]
    if not board then return false end
    if data.coords then board.coords = data.coords end
    if data.content or data.dui then board.dui = normalizeContent(data.content or data.dui) end
    rebuildBoardGeometry(board)
    if board.surface then self:syncBoardContent(board) end
    return true
end

function DuiSurfaceManager:unregister(key)
    local board = self.boards[key]
    if not board then return end
    self:releaseBoardSurface(board)
    self.boards[key] = nil
end

function DuiSurfaceManager:clear()
    self:stopPreview()
    for key in pairs(self.boards) do self:unregister(key) end
    self.visibleDrawList = {}
    -- don't reset the thread-active flags: the render threads live until their
    -- next wake and clear them on exit, and forcing them false lets a quick
    -- re-register spawn duplicates
    cleanupDuiPool()
end

function DuiSurfaceManager:stopPreview()
    if not self.preview then return end
    self:releaseBoardSurface(self.preview)
    self.preview = nil
end

function DuiSurfaceManager:runPlacementSession(options)
    options = type(options) == 'table' and options or {}
    local content = normalizeContent(options.content or options)
    content.worldWidth, content.worldHeight = nil, nil
    content.cornerTL, content.cornerBR, content.planeW, content.planeH = nil, nil, nil, nil
    local maxDistance = tonumber(options.maxDistance) or placementMax
    local placing, phase = true, 'topLeft'
    local topLeft, planeNormal, finalCoords, finalContent = nil, nil, nil, nil
    local openedAt = GetGameTimer()
    local previewWorldWidth, previewWorldHeight = nil, nil
    creatorActive, cancelPlacement = true, false
    SendNUIMessage({
        type = 'dui_creator:open',
        label = type(options.label) == 'string' and options.label or '',
        maxDistance = maxDistance,
        debug = Config.Debug == true,
        locales = creatorLocales(),
    })
    self.preview = { key = 'preview', phase = phase, dui = content, surface = nil, topLeft = nil, maxDistance = maxDistance }
    self.preview.surface = self:ensurePreviewDui(self.preview)
    self:ensureRenderThreads()
    drainCancelWhile(function() return placing end)
    CreateThread(function()
        local lastUiUpdate = 0
        while placing do
            local now = GetGameTimer()
            if now - lastUiUpdate >= 150 then
                lastUiUpdate = now
                local hitCoords, camCoord = self.preview and self.preview.hitCoords, self.preview and self.preview.camCoord
                local distance, status = 0.0, 'aiming'
                if hitCoords and camCoord then
                    distance = #(camCoord - hitCoords)
                    status = distance <= maxDistance and 'ready' or 'too_far'
                end
                SendNUIMessage({
                    type = 'dui_creator:update',
                    phase = phase,
                    status = status,
                    coords = hitCoords and { x = hitCoords.x, y = hitCoords.y, z = hitCoords.z } or nil,
                    distance = distance,
                    maxDistance = maxDistance,
                    worldWidth = previewWorldWidth,
                    worldHeight = previewWorldHeight,
                })
            end
            Wait(0)
        end
    end)
    while placing do
        if cancelPlacement then placing = false break end
        local hit, endCoords, camCoord, surfaceNormal = self:raycastFromCamera(maxDistance)
        if hit and endCoords and self.preview then
            self.preview.hitCoords, self.preview.camCoord = endCoords, camCoord
            self.preview.phase, self.preview.topLeft, self.preview.planeNormal = phase, topLeft, planeNormal
            local distance = #(camCoord - endCoords)
            local canPlace = distance <= maxDistance
            local previewDui = normalizeContent(self.preview.dui)
            local aspect = previewDui.aspect > 0 and previewDui.aspect or 1.0
            previewWorldWidth, previewWorldHeight = nil, nil
            if phase == 'bottomRight' and topLeft and planeNormal then
                local _, _, _, _, worldWidth, worldHeight, _, planeW, planeH = buildQuadFromCorners(topLeft, endCoords, planeNormal, aspect)
                previewWorldWidth, previewWorldHeight = worldWidth, worldHeight
                self.preview.dui = normalizeContent({
                    src = content.src, width = content.width, height = content.height,
                    aspect = aspect, worldWidth = worldWidth, worldHeight = worldHeight, planeW = planeW, planeH = planeH,
                    cornerTL = { x = topLeft.x, y = topLeft.y, z = topLeft.z },
                    normal = { x = planeNormal.x, y = planeNormal.y, z = planeNormal.z },
                })
            end
            EnableControlAction(0, controls.place, true)
            EnableControlAction(0, controls.cancel, true)
            local placePressed = IsControlJustPressed(0, controls.place) or IsDisabledControlJustPressed(0, controls.place)
            local cancelPressed = (IsControlJustPressed(0, controls.cancel) or IsDisabledControlJustPressed(0, controls.cancel))
                and (GetGameTimer() - openedAt) >= controls.cancelGraceMs
            if cancelPressed then
                if phase == 'bottomRight' then
                    phase, topLeft, planeNormal, openedAt = 'topLeft', nil, nil, GetGameTimer()
                else
                    placing = false
                end
            elseif placePressed and canPlace then
                if phase == 'topLeft' then
                    topLeft = endCoords
                    planeNormal = surfaceNormal or resolveNormal({}, vector4(endCoords.x, endCoords.y, endCoords.z, GetEntityHeading(cache.ped)))
                    phase, openedAt = 'bottomRight', GetGameTimer()
                else
                    local _, _, _, _, worldWidth, worldHeight, center, planeW, planeH = buildQuadFromCorners(topLeft, endCoords, planeNormal, aspect)
                    finalCoords = vector4(center.x, center.y, center.z, GetEntityHeading(cache.ped))
                    finalContent = normalizeContent({
                        src = content.src, width = content.width, height = content.height,
                        aspect = aspect, worldWidth = worldWidth, worldHeight = worldHeight, planeW = planeW, planeH = planeH,
                        cornerTL = { x = topLeft.x, y = topLeft.y, z = topLeft.z },
                        normal = { x = planeNormal.x, y = planeNormal.y, z = planeNormal.z },
                    })
                    placing = false
                end
            elseif placePressed then
                bridge.notifications.notify({ description = bridge.locale('dui_creator.status_too_far'), type = 'error' })
            end
        end
        Wait(0)
    end
    self:stopPreview()
    SendNUIMessage({ type = 'dui_creator:close' })
    creatorActive, cancelPlacement = false, false
    if not finalCoords or not finalContent then return { ok = false, cancelled = true } end
    return { ok = true, coords = finalCoords, content = finalContent }
end

function DuiSurfaceManager:runTargetPlacementSession(options)
    if creatorActive then
        return { ok = false, reason = 'already_active' }
    end

    options = type(options) == 'table' and options or {}
    local maxDistance = tonumber(options.maxDistance) or placementMax
    local placing = true
    local finalCoords, finalNormal = nil, nil
    local openedAt = GetGameTimer()
    creatorActive, cancelPlacement = true, false

    SendNUIMessage({
        type = 'dui_creator:open',
        label = type(options.label) == 'string' and options.label or '',
        maxDistance = maxDistance,
        phase = 'target',
        debug = Config.Debug == true,
        locales = creatorLocales(),
    })

    self.preview = { key = 'target', phase = 'target', maxDistance = maxDistance }
    self:ensureRenderThreads()

    drainCancelWhile(function() return placing end)

    CreateThread(function()
        local lastUiUpdate = 0
        while placing do
            local now = GetGameTimer()
            if now - lastUiUpdate >= 150 then
                lastUiUpdate = now
                local hitCoords, camCoord = self.preview and self.preview.hitCoords, self.preview and self.preview.camCoord
                local distance, status = 0.0, 'aiming'
                if hitCoords and camCoord then
                    distance = #(camCoord - hitCoords)
                    status = distance <= maxDistance and 'ready' or 'too_far'
                end
                SendNUIMessage({
                    type = 'dui_creator:update',
                    phase = 'target',
                    status = status,
                    coords = hitCoords and { x = hitCoords.x, y = hitCoords.y, z = hitCoords.z } or nil,
                    distance = distance,
                    maxDistance = maxDistance,
                })
            end
            Wait(0)
        end
    end)

    while placing do
        if cancelPlacement then
            placing = false
            break
        end

        local hit, endCoords, camCoord, surfaceNormal = self:raycastFromCamera(maxDistance)
        if self.preview then
            self.preview.hitCoords = hit and endCoords or nil
            self.preview.camCoord = camCoord
        end

        if hit and endCoords then
            local distance = #(camCoord - endCoords)
            local canPlace = distance <= maxDistance
            EnableControlAction(0, controls.place, true)
            EnableControlAction(0, controls.cancel, true)

            local placePressed = IsControlJustPressed(0, controls.place) or IsDisabledControlJustPressed(0, controls.place)
            local cancelPressed = (IsControlJustPressed(0, controls.cancel) or IsDisabledControlJustPressed(0, controls.cancel))
                and (GetGameTimer() - openedAt) >= controls.cancelGraceMs

            if cancelPressed then
                placing = false
            elseif placePressed and canPlace then
                finalCoords = vector4(endCoords.x, endCoords.y, endCoords.z, GetEntityHeading(cache.ped))
                finalNormal = normalizeNormal(surfaceNormal)
                placing = false
            elseif placePressed then
                bridge.notifications.notify({ description = bridge.locale('dui_creator.status_too_far'), type = 'error' })
            end
        end

        Wait(0)
    end

    self:stopPreview()
    SendNUIMessage({ type = 'dui_creator:close' })
    creatorActive, cancelPlacement = false, false

    if not finalCoords then
        return { ok = false, cancelled = true }
    end

    return { ok = true, coords = finalCoords, normal = finalNormal }
end

local duiSurfaceManager = DuiSurfaceManager:new()

RegisterNUICallback('duiSurfaceReportSize', function(data, cb)
    if type(data) == 'table' and data.pooled ~= true then
        duiSurfaceManager:applyContentSize(data.boardKey or 'preview', data.width, data.height)
    end
    cb('ok')
end)

RegisterNUICallback('duiSurfaceReady', function(data, cb)
    duiSurfaceManager:pushDuiContent(type(data) == 'table' and data.boardKey or 'preview')
    cb('ok')
end)

exports('CreateDuiPlacement', function(options)
    if creatorActive then
        bridge.notifications.notify({
            title = bridge.locale('common.error'),
            description = bridge.locale('dui_creator.errors.already_active'),
            type = 'error',
        })
        return { ok = false, reason = 'already_active' }
    end
    return duiSurfaceManager:runPlacementSession(options)
end)

exports('CreateLaserTargetPlacement', function(options)
    if creatorActive then
        bridge.notifications.notify({
            title = bridge.locale('common.error'),
            description = bridge.locale('dui_creator.errors.already_active'),
            type = 'error',
        })
        return { ok = false, reason = 'already_active' }
    end
    return duiSurfaceManager:runTargetPlacementSession(options)
end)

exports('RegisterDuiSurface', function(key, data) duiSurfaceManager:register(key, data) end)
exports('UpdateDuiSurface', function(key, data) return duiSurfaceManager:update(key, data) end)
exports('UnregisterDuiSurface', function(key) duiSurfaceManager:unregister(key) end)
exports('ClearDuiSurfaces', function() duiSurfaceManager:clear() end)
exports('HasDuiPlacement', function(content) return hasPlacement(normalizeContent(content)) end)
exports('GetDuiBoardCenter', function(content, coords) return resolveBoardCenter(normalizeContent(content), coords) end)
exports('GetDuiTargetRadius', function(content) return resolveTargetZoneRadius(normalizeContent(content)) end)

-- Prop texture replacement (AddReplaceTexture)
-- Replaces a named texture slot on a prop with a DUI-backed runtime texture.
-- readSrc / urlEncode / minDui / maxDui / shellUrl reused from above.

---@type table<string, { dui: number, origTxd: string, origTxn: string, runtimeTxd: string, runtimeTxn: string }>
local propDuiActive = {}

local function clampPropDimension(value, fallback)
    value = math.floor(tonumber(value) or fallback)
    return math.max(minDui, math.min(value, maxDui))
end

local function sanitizePropKey(key)
    return tostring(key):gsub('[^%w]', '_')
end

local function buildPropShellUrl(src)
    return ('%s#src=%s'):format(shellUrl, urlEncode(src))
end

local function clearPropEntry(key)
    local entry = propDuiActive[key]
    if not entry then return end
    RemoveReplaceTexture(entry.origTxd, entry.origTxn)
    if entry.dui and IsDuiAvailable(entry.dui) then
        DestroyDui(entry.dui)
    end
    propDuiActive[key] = nil
end

local function applyPropTexture(key, textureDef, content)
    if type(textureDef) ~= 'table' then return false end
    if type(textureDef.txd) ~= 'string' or textureDef.txd == '' then return false end
    if type(textureDef.txn) ~= 'string' or textureDef.txn == '' then return false end

    content = type(content) == 'table' and content or {}
    local src = readSrc(content)
    if src == '' then return false end

    clearPropEntry(key)

    local width  = clampPropDimension(content.width  or textureDef.width,  1024)
    local height = clampPropDimension(content.height or textureDef.height, 1024)
    local runtimeTxd = ('nb_dpt_%s'):format(sanitizePropKey(key))
    local runtimeTxn = 'screen'

    local dui    = CreateDui(buildPropShellUrl(src), width, height)
    local handle = GetDuiHandle(dui)
    local txd    = CreateRuntimeTxd(runtimeTxd)
    CreateRuntimeTextureFromDuiHandle(txd, runtimeTxn, handle)
    AddReplaceTexture(textureDef.txd, textureDef.txn, runtimeTxd, runtimeTxn)

    propDuiActive[key] = {
        dui      = dui,
        origTxd  = textureDef.txd,
        origTxn  = textureDef.txn,
        runtimeTxd = runtimeTxd,
        runtimeTxn = runtimeTxn,
    }
    return true
end

local function updatePropTexture(key, content)
    local entry = propDuiActive[key]
    if not entry or not entry.dui or not IsDuiAvailable(entry.dui) then return false end

    content = type(content) == 'table' and content or {}
    local src = readSrc(content)
    if src == '' then return false end

    SendDuiMessage(entry.dui, json.encode({
        action   = 'duiSurfaceSetContent',
        src      = src,
        boardKey = key,
    }))
    return true
end

exports('ApplyPropDuiTexture',  function(key, _entity, textureDef, content) return applyPropTexture(key, textureDef, content) end)
exports('UpdatePropDuiTexture', updatePropTexture)
exports('ClearPropDuiTexture',  clearPropEntry)
exports('HasPropDuiTexture',    function(key) return propDuiActive[key] ~= nil end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    cancelPlacement = true
    SendNUIMessage({ type = 'dui_creator:close' })
    duiSurfaceManager:clear()
    for key in pairs(propDuiActive) do clearPropEntry(key) end
end)
