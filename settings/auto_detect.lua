-- Resolves Config "auto" values to the first installed provider and publishes
-- Config.Providers, the module -> provider map consumed by import.lua.
-- ox-first resources are listed first; uses `~= "missing"` so detection works
-- during bridge init before dependent resources have started.
--
-- Adding a provider: create its folder in modules/<module>/<resource name>/
-- and add the resource name to the matching list below.
--
-- Whip stack: whip_core is a whole framework (characters, inventory, interactions, notifications, progress bars, input
-- dialogs, text prompts, vehicle keys) and has its own provider folder for each. It is listed before ox_lib wherever
-- ox_lib is a choice because ox_lib is always running (the bridge needs it) and whip wants one screen open at a time.
-- Fuel is whip_fuel. Whip has no list menu, boss menu or dispatch, so those modules keep their usual providers.
--
-- Kora stack: kora_core, kora_inventory and kora_target have their own provider
-- folders that call the native Kora exports. They are listed first because the
-- Kora resources also provide qb-core / ox_inventory / ox_target identities and
-- ship placeholder ox_* resources, which would otherwise be picked up instead.
--
-- Manual-only inventory fallbacks (set Config.Inventory explicitly, never auto):
--   qb-framework  - QBCore player items via qb-core / qbx_core (no qb-inventory)
--   esx-framework - ESX default xPlayer inventory (no ox_inventory / qs / etc.)
local modules = {
    framework = { configKey = "Framework", "whip_core", "kora_core", "qbx_core", "qb-core", "es_extended" },
    inventory = { configKey = "Inventory", "whip_core", "kora_inventory", "ox_inventory", "wasabi_inventory", "m-Inventory", "one_inventory", "jaksam_inventory", "tgiann-inventory", "codem-inventory", "core_inventory", "origen_inventory", "qs-inventory", "qb-inventory" },
    target = { configKey = "Target", "whip_core", "kora_target", "ox_target", "tgiann-target", "core_focus", "qb-target", "sleepless_interact" },
    vehiclekeys = { configKey = "VehicleKeys", "whip_core", "MrNewbVehicleKeys", "qbx_vehiclekeys", "cd_garage", "mVehicle", "okokGarage", "qb-vehiclekeys", "vehicles_keys", "wasabi_carlock", "Renewed-Vehiclekeys", "mk_vehiclekeys", "ak47_vehiclekeys", "0r-vehiclekeys" },
    vehiclefuel = { configKey = "VehicleFuel", fallback = "internal", "whip_fuel", "ox_fuel", "rcore_fuel", "okokGasStation", "LegacyFuel", "cdn-fuel", "lc_fuel", "qb-fuel", "Renewed-Fuel", "ps-fuel", "qs-fuelstations", "ti_fuel" },
    menu = { configKey = "Menu", "ox_lib", "lation_ui", "qb-menu" },
    notifications = { configKey = "Notifications", fallback = "internal", "whip_core", "ox_lib", "vms_notifyv2", "codem-notification", "brutal_notify", "fl-notify", "mythic_notify", "okokNotify", "pnotify", "solaire_notify", "t-notify", "lation_ui", "wasabi_notify", "zsx_uiv2" },
    inputs = { configKey = "Inputs", "whip_core", "ox_lib", "lation_ui" },
    textui = { configKey = "TextUI", "whip_core", "ox_lib", "lation_ui", "okokTextUI", "cd_drawtextui", "jg-textui", "lab-TextUI", "zsx_uiv2" },
    progressbar = { configKey = "ProgressBar", "whip_core", "ox_lib", "lation_ui", "wasabi_uikit", "progressbar", "zsx_uiv2" },
    bossmenu = { configKey = "BossMenu", "qbx_management", "qb-management", "esx_society", "vms_bossmenu", "tk_bosstablet", "okokBossMenu", "codem-bossmenu", "zat-bossmenu", "m-BossMenu", "lation_jobs" },
    dispatch = { configKey = "Dispatch", fallback = "internal", "ps-dispatch", "cd_dispatch", "tk_dispatch", "rcore_dispatch", "lb-tablet", "origen_police", "core_dispatch", "kartik-mdt", "codem-dispatch", "wasabi_mdt", "redutzu-mdt" },
}

local function resolveAuto(entry, value)
    if value ~= nil and value ~= "auto" then return value end

    for _, resource in ipairs(entry) do
        if GetResourceState(resource) == "started" then
            return resource
        end
    end

    for _, resource in ipairs(entry) do
        if GetResourceState(resource) ~= "missing" then
            return resource
        end
    end

    return entry.fallback
end

Config.Providers = {}

for module, entry in pairs(modules) do
    local configured = Config[entry.configKey]
    local resolved = resolveAuto(entry, configured)
    if not resolved then
        print(("^3[Newb_Bridge] No installed provider found for %s (Config.%s = \"auto\"). Install a supported resource or set an explicit provider.^0"):format(module, entry.configKey))
    end
    Config[entry.configKey] = resolved
    Config.Providers[module] = resolved
end
