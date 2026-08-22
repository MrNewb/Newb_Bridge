-- Resolves Config "auto" values to the first installed provider and publishes
-- Config.Providers, the module -> provider map consumed by import.lua.
-- ox-first resources are listed first; uses `~= "missing"` so detection works
-- during bridge init before dependent resources have started.
--
-- Adding a provider: create its folder in modules/<module>/<resource name>/
-- and add the resource name to the matching list below.
--
-- Manual-only inventory fallbacks (set Config.Inventory explicitly, never auto):
--   qb-framework  — QBCore player items via qb-core / qbx_core (no qb-inventory)
--   esx-framework — ESX default xPlayer inventory (no ox_inventory / qs / etc.)
local modules = {
    framework = { configKey = "Framework", "qbx_core", "qb-core", "es_extended" },
    inventory = { configKey = "Inventory", "ox_inventory", "m-Inventory", "one_inventory", "jaksam_inventory", "tgiann-inventory", "codem-inventory", "core_inventory", "origen_inventory", "qs-inventory", "qb-inventory" },
    target = { configKey = "Target", "ox_target", "tgiann-target", "core_focus", "qb-target", "sleepless_interact" },
    vehiclekeys = { configKey = "VehicleKeys", "MrNewbVehicleKeys", "qbx_vehiclekeys", "cd_garage", "mVehicle", "okokGarage", "qb-vehiclekeys", "vehicles_keys", "wasabi_carlock", "Renewed-Vehiclekeys", "mk_vehiclekeys", "ak47_vehiclekeys", "0r-vehiclekeys" },
    vehiclefuel = { configKey = "VehicleFuel", fallback = "internal", "ox_fuel", "rcore_fuel", "okokGasStation", "LegacyFuel", "cdn-fuel", "lc_fuel", "qb-fuel", "Renewed-Fuel", "renewed-fuel", "ps-fuel", "qs-fuelstations", "hrs_fuel", "ti_fuel" },
    menu = { configKey = "Menu", "ox_lib", "lation_ui", "qb-menu" },
    notifications = { configKey = "Notifications", "ox_lib", "vms_notifyv2", "codem-notification", "brutal_notify", "fl-notify", "mythic_notify", "okokNotify", "pnotify", "solaire_notify", "t-notify", "lation_ui", "wasabi_notify", "zsx_uiv2" },
    inputs = { configKey = "Inputs", "ox_lib", "lation_ui" },
    textui = { configKey = "TextUI", "ox_lib", "lation_ui", "okokTextUI", "cd_drawtextui", "jg-textui", "lab-hintui", "zsx_uiv2" },
    progressbar = { configKey = "ProgressBar", "ox_lib", "lation_ui", "wasabi_uikit", "progressbar", "zsx_uiv2" },
    bossmenu = { configKey = "BossMenu", "qbx_management", "qb-management", "esx_society", "vms_bossmenu", "tk_bosstablet", "okokBossMenu", "codem-bossmenu", "zat-bossmenu", "m-BossMenu" },
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

local summary = {}

for module, entry in pairs(modules) do
    local configured = Config[entry.configKey]
    local resolved = resolveAuto(entry, configured)
    if not resolved then
        print(("^3[Newb_Bridge] No installed provider found for %s (Config.%s = \"auto\"). Install a supported resource or set an explicit provider.^0"):format(module, entry.configKey))
    end
    Config[entry.configKey] = resolved
    Config.Providers[module] = resolved

    summary[#summary + 1] = {
        module = module,
        provider = resolved,
        manual = configured ~= nil and configured ~= "auto",
        fallback = resolved ~= nil and resolved == entry.fallback,
    }
end

-- One-time server-console summary so owners can confirm detection without debug.
if IsDuplicityVersion() then
    table.sort(summary, function(a, b) return a.module < b.module end)

    print("^5[Newb_Bridge]^7 detected scripts:")
    for i = 1, #summary do
        local row = summary[i]
        local provider = row.provider or "^1none^7"
        local source = row.manual and "manual" or "auto"
        if row.fallback then source = source .. ", fallback" end
        print(("  ^7%-14s^0 -> %s ^8(%s)^0"):format(row.module, provider, source))
    end
end
