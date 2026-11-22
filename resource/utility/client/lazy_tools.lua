---The prop placer, zone creator, DUI surface and dialogue tools are about 170 KB of source that most sessions never touch. Their exports
---and callbacks are registered here as small forwarders, and the real file is loaded on the first call.
---While a tool file loads, `exports` and `lib.callback.register` are swapped so the functions it registers are kept for the forwarders
---instead of replacing them. Keep the name lists in step with the tool files: tools/check_lazy_tools.py compares them.
local toolsFolder = ("@%s/resource/utility/client/"):format(cache.resource)
local loadedTools = {}

local function loadTool(file, registered)
    if loadedTools[file] then return end
    loadedTools[file] = true

    local realExports = exports
    local realRegister = lib.callback.register

    local function keep(name, fn)
        registered[name] = fn
    end

    _G.exports = setmetatable({}, { __call = function(_, name, fn) keep(name, fn) end, __index = realExports })
    lib.callback.register = keep

    local loaded, err = pcall(require, toolsFolder .. file)

    _G.exports = realExports
    lib.callback.register = realRegister

    if not loaded then
        loadedTools[file] = nil
        error(("Newb_Bridge could not load %s: %s"):format(file, err), 0)
    end
end

local function forwarder(file, registered, name)
    return function(...)
        loadTool(file, registered)
        local fn = registered[name]
        assert(fn, ("%s did not register %s"):format(file, name))
        return fn(...)
    end
end

---@param file string
---@param tool { exports: string[]?, callbacks: string[]? }
local function lazyTool(file, tool)
    local registered = {}

    for _, name in ipairs(tool.exports or {}) do
        exports(name, forwarder(file, registered, name))
    end

    for _, name in ipairs(tool.callbacks or {}) do
        lib.callback.register(name, forwarder(file, registered, name))
    end
end

lazyTool("placer", { exports = { "PropPlacer" }, callbacks = { "Newb_Bridge:callback:PlaceProp" } })
lazyTool("zone_creator", { exports = { "CreateZone" } })
lazyTool("dialogue", { exports = { "Dialogue" } })
lazyTool("dui_surface", {
    exports = {
        "CreateDuiPlacement",
        "CreateLaserTargetPlacement",
        "RegisterDuiSurface",
        "UpdateDuiSurface",
        "UnregisterDuiSurface",
        "ClearDuiSurfaces",
        "HasDuiPlacement",
        "GetDuiBoardCenter",
        "GetDuiTargetRadius",
        "ApplyPropDuiTexture",
        "UpdatePropDuiTexture",
        "ClearPropDuiTexture",
        "HasPropDuiTexture",
    },
})

exports("LazyToolsLoaded", function()
    return loadedTools
end)
