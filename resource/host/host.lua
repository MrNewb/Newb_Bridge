---Everything only the bridge host needs, kept out of import.lua so the other resources do not compile it: the exports they call, the
---module source cache and the start-up mount of every provider. import.lua loads this file in the host and hands it what it needs.
---@param context { bridge: table, mountModule: function, mounting: table, providers: table, hostResource: string, runtime: string, moduleRoot: string, setSourceReader: function }
return function(context)
    local bridge = context.bridge
    local mountModule = context.mountModule
    local mounting = context.mounting
    local providers = context.providers
    local hostResource = context.hostResource
    local runtime = context.runtime
    local moduleRoot = context.moduleRoot

    ---Each file is read once for the whole server. A file that does not exist costs about 1.3 ms to find out, so the resources that
    ---import the bridge ask for the finished source instead of probing for it themselves.
    local sourceCache = {} ---@type table<string, { source: string, entry: string }|false>

    local function probeSource(module)
        local provider = providers[module]
        local parts = {}

        local function append(path)
            local code = LoadResourceFile(hostResource, path)
            if code then parts[#parts + 1] = code end
            return code ~= nil
        end

        append(("%s/%s/shared.lua"):format(moduleRoot, module))

        local entry
        if provider then
            append(("%s/%s/%s/shared.lua"):format(moduleRoot, module, provider))
            local providerFile = ("%s/%s/%s/%s.lua"):format(moduleRoot, module, provider, runtime)
            if append(providerFile) then entry = providerFile end
        end

        if not entry then
            local genericFile = ("%s/%s/%s.lua"):format(moduleRoot, module, runtime)
            if append(genericFile) then entry = genericFile end
        end

        if #parts == 0 then
            if provider and Config.Debug then
                print(("^3[Newb_Bridge] Module '%s' has no %s implementation for provider '%s'. This is expected for a module that only exists on the other side. Otherwise add %s/%s/%s/%s.lua, or pick a supported provider in settings/bridge_resources.lua (options are listed in settings/auto_detect.lua).^0"):format(module, runtime, provider, moduleRoot, module, provider, runtime))
            end
            return false
        end

        return { source = table.concat(parts, "\n"), entry = entry or ("%s/%s/shared.lua"):format(moduleRoot, module) }
    end

    local function readSource(module)
        local cached = sourceCache[module]
        if cached == nil then
            cached = probeSource(module)
            sourceCache[module] = cached
        end
        return cached or nil
    end

    context.setSourceReader(function(module)
        local found = readSource(module)
        if not found then return end
        return found.source, found.entry
    end)

    exports("BridgeEnvironment", function()
        return { config = Config, resource = hostResource }
    end)

    exports("ModuleSource", function(module)
        if type(module) ~= "string" or not module:match("^%a[%w_]*$") then return end
        return readSource(module)
    end)

    local function servedModule(module)
        local api = bridge[module]
        local waited = 0
        while mounting[module] do
            Wait(25)
            waited = waited + 25
            if waited >= 15000 then
                mounting[module] = nil
                print(("^1[Newb_Bridge] Timed out waiting for module '%s' to mount.^0"):format(module))
                return rawget(bridge, module) or context.noopModule
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
    exports("GetTheme", function()
        return bridge.theme.get()
    end)
    exports("GetThemeCss", function()
        return bridge.theme.css()
    end)

    local moduleNames = {}
    for module in pairs(providers) do
        moduleNames[#moduleNames + 1] = module
    end
    table.sort(moduleNames)

    for i = 1, #moduleNames do
        local module = moduleNames[i]
        Citizen.CreateThreadNow(function()
            if rawget(bridge, module) == nil then
                mountModule(bridge, module)
            end

            if Config.Debug then
                local loaded = rawget(bridge, module) ~= context.noopModule
                print(("^5[Newb_Bridge]^0 %s module %s: provider '%s'%s"):format(runtime, module, tostring(providers[module]), loaded and "" or " (no " .. runtime .. " implementation)"))
            end
        end)
    end
end
