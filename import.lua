---@meta
---This file was based on ox_lib init.lua file.
---ox_lib <https://github.com/overextended/ox_lib>
---Copyright (C) 2021 Linden <https://github.com/thelindat>
---LGPL-3.0-or-later <https://www.gnu.org/licenses/lgpl-3.0.en.html>

Config = Config or {}

local thisResource = GetCurrentResourceName()
local isHost = GetResourceMetadata(thisResource, "newb_bridge_host", 0) == "yes"
local hostResource = isHost and thisResource or "Newb_Bridge"
local runtime = IsDuplicityVersion() and "server" or "client"
local MODULE_ROOT = "resource/modules"

if not isHost and GetResourceState(hostResource) ~= "started" then
    error(("^1%s imports %s, which is not started. Fix the start order in server.cfg.^0"):format(thisResource, hostResource), 0)
end

if not isHost then
    Config = exports[hostResource]:BridgeEnvironment().config
end

local providers = Config.Providers or {}

local function noop() end

local noopModule = setmetatable({}, {
    __index = function() return noop end,
    __call = noop,
})

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

local hostOnlyClientModules = { dispatch = true, bossmenu = true, banking = true, phone = true }

local readHostSource ---@type fun(module: string): string?, string?

local function fetchSource(module)
    if readHostSource then return readHostSource(module) end
    local found = exports[hostResource]:ModuleSource(module)
    if not found then return end
    return found.source, found.entry
end

local mounting = {} ---@type table<string, true>

-- Another resource's exports throw when that resource is stopped or gone, and these modules take arguments from other
-- scripts. Each entry is { module, call, fallback, isValid? }: bad arguments and a failing provider both return the
-- fallback (nil when there is none), and a failing provider also prints one console line per call.
local function isText(value) return type(value) == "string" end
local function isSource(value) return type(value) == "number" end
local function isDoorId(value) return type(value) == "string" or type(value) == "number" end
local function isAmount(value) return type(value) == "number" and value > 0 and value < math.huge end
local function isBankChange(account, amount) return isText(account) and isAmount(amount) end
local function isPhoneMail(src, email, title, message) return isSource(src) and isText(email) and isText(title) and isText(message) end

local guardedCalls = {
    { "banking", "getAccountMoney", 0, isText },
    { "banking", "addAccountMoney", false, isBankChange },
    { "banking", "removeAccountMoney", false, isBankChange },
    { "doorlock", "lockDoor", false, isDoorId },
    { "doorlock", "unlockDoor", false, isDoorId },
    { "doorlock", "getClosestDoor" },
    { "phone", "getPlayerPhone", false, isSource },
    { "phone", "sendEmail", false, isPhoneMail },
    { "weather", "enableSync" },
    { "weather", "disableSync" },
}

local reportedFailures = {} ---@type table<string, true>

local function guardCall(module, provider, name, call, fallback, isValid)
    return function(...)
        if isValid and not isValid(...) then return fallback end

        local ok, result = pcall(call, ...)
        if ok then return result end

        local key = module .. name
        if not reportedFailures[key] then
            reportedFailures[key] = true
            print(("^1[Newb_Bridge] %s provider '%s' failed in %s: %s^0"):format(module, tostring(provider), name, tostring(result)))
        end
        return fallback
    end
end

local function guardModule(api, module, provider)
    for i = 1, #guardedCalls do
        local entry = guardedCalls[i]
        local name = entry[2]
        if entry[1] == module and type(api[name]) == "function" then
            api[name] = guardCall(module, provider, name, api[name], entry[3], entry[4])
        end
    end
end

local function mountModule(self, module)
    mounting[module] = true

    if runtime == "client" and not isHost and hostOnlyClientModules[module] then
        self[module] = noopModule
        mounting[module] = nil
        return noopModule
    end

    local provider = providers[module]
    local source, entryFile = fetchSource(module)

    lib.print.debug("Mounting bridge module", module, provider, runtime)

    if not source then
        self[module] = noopModule
        mounting[module] = nil
        return noopModule
    end

    -- errors and stack traces name the file the code really came from, which is the generic file when no provider file exists
    local factory, parseError = load(source, ("@@%s/%s"):format(hostResource, entryFile), "t", _G)

    if not factory then
        mounting[module] = nil
        return error(("\n^1Failed to mount bridge module %s: %s^0"):format(module, parseError), 3)
    end

    local api = factory() or noopModule

    if api ~= noopModule and type(api) == "table" then
        guardModule(api, module, provider)

        if api.getResourceName == nil then
            function api.getResourceName()
                return provider
            end
        end
    end

    if module == "notifications" and runtime == "client" and api ~= noopModule and type(api) == "table" and type(api.notify) == "function" then
        local showNotification = api.notify
        function api.notify(data)
            TriggerEvent("Newb_Bridge:client:notificationShown", data)
            TriggerEvent("Newb_Bridge:Client:NotifyShown", data) -- deprecated 2026-12-17: use Newb_Bridge:client:notificationShown
            return showNotification(data)
        end
    end

    if module == "dispatch" and runtime == "server" and api ~= noopModule and type(api) == "table" and type(api.sendAlert) == "function" then
        local sendDispatchAlert = api.sendAlert
        function api.sendAlert(src, jobs, coords, data, blip, alertFlash)
            -- Providers index data/blip directly; default them so a partial call can't throw inside the provider.
            local ok, sent = pcall(sendDispatchAlert, src, jobs, coords, type(data) == "table" and data or {}, type(blip) == "table" and blip or {}, alertFlash)
            if not ok then
                print(("^1[Newb_Bridge] Dispatch provider '%s' failed: %s^0"):format(tostring(provider), tostring(sent)))
                sent = false
            end
            TriggerEvent("Newb_Bridge:server:dispatchAlertSent", src, jobs, coords, data, blip, alertFlash)
            TriggerEvent("Newb_Bridge:Server:DispatchAlert", src, jobs, coords, data, blip, alertFlash) -- deprecated 2026-12-17: use Newb_Bridge:server:dispatchAlertSent
            return sent
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

            if index == "framework" and runtime == "client" then
                require(("@%s/resource/utility/client/framework_cache"):format(hostResource))(api)
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
    require(("@%s/resource/host/host"):format(thisResource))({
        bridge = bridge,
        mountModule = mountModule,
        mounting = mounting,
        providers = providers,
        hostResource = hostResource,
        runtime = runtime,
        moduleRoot = MODULE_ROOT,
        noopModule = noopModule,
        setSourceReader = function(reader) readHostSource = reader end,
    })
end
