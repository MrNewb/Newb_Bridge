-- Shared camera raycast for the placement suite so the shape-test and the
-- surface-normal handling live in one place and every tool aims the same way.

local ray = {}

-- forward vector for a camera rotation, defaulting to the rendered gameplay cam
function ray.forward(rot)
    rot = rot or GetFinalRenderedCamRot(2)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)
    local cosPitch = math.abs(math.cos(pitch))

    return vector3(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
end

-- the normal is flipped back toward the origin so callers never see a back-face
---@return boolean hit
---@return vector3|nil coords
---@return number entity
---@return number|nil material
---@return vector3|nil normal
function ray.probe(origin, target, rayFlags, ignoreEntity)
    rayFlags = rayFlags or 511
    local handle = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, target.x, target.y, target.z, rayFlags, ignoreEntity or cache.ped, 0)
    local _, hit, coords, normal, material, entity = GetShapeTestResultIncludingMaterial(handle)

    if hit ~= 1 or not coords then
        return false, nil, entity or 0, material
    end

    if normal then
        local toOrigin = origin - coords
        if (normal.x * toOrigin.x) + (normal.y * toOrigin.y) + (normal.z * toOrigin.z) < 0.0 then
            normal = vector3(-normal.x, -normal.y, -normal.z)
        end
    end

    return true, coords, entity or 0, material, normal
end

-- steps through ignored entities until something solid is hit
---@param maxDistance number
---@param ignoreEntity number|nil
---@param rayFlags number|nil
---@param skipObjectEntities boolean|nil Step through prop/object entities (type 3)
---@return boolean hit
---@return vector3|nil coords
---@return number entity
---@return number|nil material
---@return vector3|nil normal
---@return vector3 origin Camera coord the ray started from
function ray.cast(maxDistance, ignoreEntity, rayFlags, skipObjectEntities)
    rayFlags = rayFlags or 511
    local camCoord = GetFinalRenderedCamCoord()
    local direction = ray.forward()
    local origin = camCoord
    local remaining = maxDistance + 5.0
    local ignored = { [cache.ped] = true }
    local material, normal
    local maxSteps = skipObjectEntities and 14 or 6

    if ignoreEntity and ignoreEntity ~= 0 then
        ignored[ignoreEntity] = true
    end

    for _ = 1, maxSteps do
        if remaining <= 0.05 then break end

        local target = origin + (direction * remaining)
        local hit, coords, entity, hitMaterial, hitNormal = ray.probe(origin, target, rayFlags, ignoreEntity or cache.ped)

        material = hitMaterial or material
        normal = hitNormal or normal

        if not hit or not coords then
            return false, nil, entity, material, normal, camCoord
        end

        local stepThrough = ignored[entity]
            or (skipObjectEntities and entity ~= 0 and GetEntityType(entity) == 3)

        if not stepThrough then
            return true, coords, entity, material, hitNormal, camCoord
        end

        ignored[entity] = true

        local traveled = #(coords - origin)
        if traveled < 0.01 then
            return false, coords, entity, material, normal, camCoord
        end

        origin = coords + (direction * 0.08)
        remaining = remaining - traveled - 0.08
    end

    return false, nil, 0, material, normal, camCoord
end

return ray
