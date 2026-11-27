Config = {}

---@type boolean When true, prints which modules loaded with which provider, and warns about a provider that has no code for a side. Also turns on debug drawing in the target and DUI helpers.
Config.Debug = false

---@type boolean When false, no version check runs: not the bridge's own, and not the one every MrNewb script asks the bridge for. When true, GitHub is checked on start and newer versions print to the server console only.
Config.VersionCheck = true

---@type "auto" | "whip_core" | "kora_core" | "qbx_core" | "qb-core" | "es_extended"
Config.Framework = "auto"

---@type "auto" | "whip_core" | "kora_inventory" | "ox_inventory" | "wasabi_inventory" | "m-Inventory" | "one_inventory" | "jaksam_inventory" | "origen_inventory" | "tgiann-inventory" | "codem-inventory" | "core_inventory" | "qs-inventory" | "qb-inventory" | "qb-framework" | "esx-framework"
Config.Inventory = "auto"

---@type "auto" | "whip_core" | "kora_target" | "ox_target" | "tgiann-target" | "core_focus" | "qb-target" | "sleepless_interact"
Config.Target = "auto"

---@type "auto" | "whip_core" | "MrNewbVehicleKeys" | "kora_vehiclekeys" | "jg-vehiclekeys" | "qbx_vehiclekeys" | "cd_garage" | "mVehicle" | "okokGarage" | "qb-vehiclekeys" | "vehicles_keys" | "wasabi_carlock" | "Renewed-Vehiclekeys" | "mk_vehiclekeys" | "ak47_vehiclekeys" | "0r-vehiclekeys"
Config.VehicleKeys = "auto"

---@type "auto" | "whip_fuel" | "ox_fuel" | "rcore_fuel" | "okokGasStation" | "LegacyFuel" | "cdn-fuel" | "lc_fuel" | "qb-fuel" | "Renewed-Fuel" | "ps-fuel" | "qs-fuelstations" | "ti_fuel" | "internal"
Config.VehicleFuel = "auto"

---@type "auto" | "ox_lib" | "lation_ui" | "qb-menu"
Config.Menu = "auto"

---@type "auto" | "whip_core" | "ox_lib" | "vms_notifyv2" | "codem-notification" | "brutal_notify" | "fl-notify" | "mythic_notify" | "okokNotify" | "pnotify" | "solaire_notify" | "t-notify" | "lation_ui" | "wasabi_notify" | "ZSX_UIV2" | "internal"
Config.Notifications = "auto"

---@type "auto" | "whip_core" | "ox_lib" | "lation_ui"
Config.Inputs = "auto"

---@type "auto" | "whip_core" | "ox_lib" | "lation_ui" | "okokTextUI" | "cd_drawtextui" | "jg-textui" | "lab-TextUI" | "ZSX_UIV2"
Config.TextUI = "auto"

---@type "auto" | "whip_core" | "ox_lib" | "lation_ui" | "wasabi_uikit" | "progressbar" | "ZSX_UIV2"
Config.ProgressBar = "auto"

---@type "auto" | "qbx_management" | "qb-management" | "esx_society" | "vms_bossmenu" | "tk_bosstablet" | "okokBossMenu" | "codem-bossmenu" | "zat-bossmenu" | "m-BossMenu" | "lation_jobs" | "ShitDevScripts-Bossmenu" | "apex_bossmenu"
Config.BossMenu = "auto"

---@type "auto" | "ps-dispatch" | "cd_dispatch" | "tk_dispatch" | "rcore_dispatch" | "lb-tablet" | "origen_police" | "core_dispatch" | "kartik-mdt" | "codem-dispatch" | "wasabi_mdt" | "redutzu-mdt" | "internal"
Config.Dispatch = "auto"

---@type "auto" | "Renewed-Banking" | "qb-banking" | "okokBanking" | "lation_banking" | "fd_banking" | "kartik-banking" | "tgg-banking" | "tgiann-bank" | "wasabi_banking" | "esx_addonaccount" | "ShitDevScripts-Banking" | "none"
Config.Banking = "auto"

---@type "auto" | "ox_doorlock" | "qb-doorlock" | "rcore_doorlock" | "doors_creator" | "none"
Config.Doorlock = "auto"

---@type "auto" | "kora_phone" | "sd-phone" | "sky_phone" | "lb-phone" | "gksphone" | "okokPhone" | "qs-smartphone" | "yseries" | "qb-phone" | "none"
Config.Phone = "auto"

---@type "auto" | "Renewed-Weathersync" | "qb-weathersync" | "cd_easytime" | "none"
Config.Weather = "auto"

---Task group menu limits, shared by the client menu and the server callbacks.
Config.TaskGroups = {
    DefaultMaxPlayers = 8,
    MaxMaxPlayers = 8,
    MinMaxPlayers = 2,
    InviteRadius = 10.0,
    JoinCodeLength = 6,
    MaxNameLength = 32,
}
