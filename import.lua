---@meta
---This file was based on ox_lib init.lua file.
---ox_lib <https://github.com/overextended/ox_lib>
---Copyright (C) 2021 Linden <https://github.com/thelindat>
---LGPL-3.0-or-later <https://www.gnu.org/licenses/lgpl-3.0.en.html>

Config = Config or {}

local LoadResourceFile = LoadResourceFile
local thisResource = GetCurrentResourceName()
local hostResource = LoadResourceFile(thisResource, "settings/bridge_resources.lua") and thisResource or "Newb_Bridge"
local isHost = thisResource == hostResource
local runtime = IsDuplicityVersion() and "server" or "client"

if isHost then
    exports("BridgeEnvironment", function()
        return { config = Config, resource = hostResource }
    end)
elseif GetResourceState(hostResource) ~= "started" then
    error(("^1%s imports %s, which is not started. Fix the start order in server.cfg.^0"):format(thisResource, hostResource), 0)
else
    Config = exports[hostResource]:BridgeEnvironment().config
end

local providers = Config.Providers or {}

local function noop() end

local noopModule = setmetatable({}, {
    __index = function() return noop end,
    __call = noop,
})

-- Exporting a module table turns its methods into CFX funcrefs in the consumer
-- (type "table"). Wrap them as local functions so `type(bridge.inventory.registerShop)
-- == 'function'` and call sites match community_bridge.
local function wrapHostApi(hostApi, useNoopFallback)
    if type(hostApi) ~= 'table' then return hostApi end

    local wrapped = {}

    local function wrapHostMethod(method)
        return function(...)
            return method(...)
        end
    end

    for name, value in pairs(hostApi) do
        local valueType = type(value)
        if valueType == 'function' or valueType == 'table' then
            wrapped[name] = wrapHostMethod(value)
        else
            wrapped[name] = value
        end
    end

    return setmetatable(wrapped, {
        __index = function(self, key)
            local value = hostApi[key]
            if value == nil then
                if useNoopFallback then return noop end
                return nil
            end

            local valueType = type(value)
            if valueType == 'function' or valueType == 'table' then
                local method = wrapHostMethod(value)
                self[key] = method
                return method
            end

            return value
        end,
    })
end

local hostBacked = {
    taskGroups = { export = "TaskGroups" },
    dialogue = { export = "Dialogue", clientOnly = true },
    task = { export = "Task", clientOnly = true },
}

local coreBoundInventories = {
    ["qb-inventory"] = true,
    ["qb-framework"] = true,
    ["esx-framework"] = true,
}

if not isHost then
    hostBacked.framework = { export = "Framework", providerBacked = true }

    if coreBoundInventories[providers.inventory] then
        hostBacked.inventory = { export = "Inventory", providerBacked = true }
    end
end

local hostOnlyClientModules = { dispatch = true, bossmenu = true }

local function moduleSources(module, provider)
    local sources = {}

    local function append(path)
        local code = LoadResourceFile(hostResource, path)
        if code then
            sources[#sources + 1] = code
        end
        return code ~= nil
    end

    append(("modules/%s/shared.lua"):format(module))

    if provider then
        append(("modules/%s/%s/shared.lua"):format(module, provider))
        if append(("modules/%s/%s/%s.lua"):format(module, provider, runtime)) then
            return sources
        end
    end

    append(("modules/%s/%s.lua"):format(module, runtime))
    return sources
end

local mounting = {} ---@type table<string, true>

local function mountModule(self, module)
    mounting[module] = true

    if runtime == "client" and not isHost and hostOnlyClientModules[module] then
        self[module] = noopModule
        mounting[module] = nil
        return noopModule
    end

    local provider = providers[module]
    local sources = moduleSources(module, provider)

    lib.print.debug("Mounting bridge module", module, provider, runtime)

    if #sources == 0 then
        if provider then
            print(("^3[Newb_Bridge] Module '%s' has no %s implementation for provider '%s'. Add modules/%s/%s/%s.lua, or pick a supported provider in settings/bridge_resources.lua (options are listed in settings/auto_detect.lua).^0"):format(module, runtime, provider, module, provider, runtime))
        end
        self[module] = noopModule
        mounting[module] = nil
        return noopModule
    end

    local chunkName = provider
        and ("@@%s/modules/%s/%s/%s.lua"):format(hostResource, module, provider, runtime)
        or ("@@%s/modules/%s/%s.lua"):format(hostResource, module, runtime)

    local factory, parseError = load(table.concat(sources, "\n"), chunkName, "t", _G)

    if not factory then
        mounting[module] = nil
        return error(("\n^1Failed to mount bridge module %s: %s^0"):format(module, parseError), 3)
    end

    local api = factory() or noopModule

    if api ~= noopModule and type(api) == "table" and api.getResourceName == nil then
        function api.getResourceName()
            return provider
        end
    end

    -- Each consumer mounts its own notifications table, so wrap here or pause-menu
    -- history never sees bridge.notifications.notify from other resources.
    if module == "notifications" and runtime == "client" and api ~= noopModule and type(api) == "table" and type(api.notify) == "function" then
        local showNotification = api.notify
        function api.notify(data)
            TriggerEvent("Newb_Bridge:Client:NotifyShown", data)
            return showNotification(data)
        end
    end

    self[module] = api
    mounting[module] = nil
    return api
end

local bridge = setmetatable({
    name = hostResource,
    context = runtime,
    resource = thisResource,
    isHost = isHost,
}, {
    __index = function(self, index)
        local hosted = hostBacked[index]

        if hosted then
            if hosted.clientOnly and runtime ~= "client" then
                return error(("^1bridge.%s is only available on the client^0"):format(index), 2)
            end

            local host = exports[hostResource]
            local api = wrapHostApi(host[hosted.export](host), hosted.providerBacked)

            if type(api) == "table" and not hosted.providerBacked and rawget(api, "getResourceName") == nil then
                function api.getResourceName()
                    return hostResource
                end
            end

            rawset(self, index, api)
            return api
        end

        rawset(self, index, noopModule)
        return mountModule(self, index)
    end,
})

if runtime == "client" then
    function bridge.registerCommand(commandName, callback, restricted)
        RegisterCommand(commandName, callback, restricted == true)
    end

    function bridge.registerKeybind(commandName, description, defaultKey, callback)
        RegisterCommand(commandName, callback, false)

        if type(defaultKey) == 'string' and defaultKey ~= '' then
            RegisterKeyMapping(commandName, description, 'keyboard', defaultKey)
        end
    end
end

-- utility/shared/locale.lua only loads inside the bridge resource, so consumers
-- reach bridge.locale through the host instead of parsing their own copy.
if not isHost then
    local host = exports[hostResource]

    function bridge.locale(key, params)
        return host:Locale(key, params)
    end

    function bridge.locales()
        return host:Locales()
    end
end

_ENV.bridge = bridge

if isHost then
    local function servedModule(module)
        local api = bridge[module]
        local waited = 0
        while mounting[module] do
            Wait(25)
            waited = waited + 25
            if waited >= 15000 then
                mounting[module] = nil
                print(("^1[Newb_Bridge] Timed out waiting for module '%s' to mount.^0"):format(module))
                return rawget(bridge, module) or noopModule
            end
            api = rawget(bridge, module)
        end
        return api
    end

    exports("Framework", function()
        return servedModule("framework")
    end)
    exports("Inventory", function()
        return servedModule("inventory")
    end)

    for module in pairs(providers) do
        Citizen.CreateThreadNow(function()
            if rawget(bridge, module) == nil then
                mountModule(bridge, module)
            end
        end)
    end
end