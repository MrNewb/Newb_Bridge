# Newb_Bridge install guide

Newb_Bridge is a shared resource. It does nothing on its own for players. Other scripts call it so they can run on any framework, inventory, target, notification system and so on without being rewritten.

This folder is the install kit:

| File | What it covers |
|---|---|
| `README.md` (this file) | Requirements, install, provider settings, FAQ |
| `EXPORTS.md` | Every export and command, with parameters, return values and examples |
| `MODULES.md` | The `bridge.*` modules (framework, inventory, target, menu, and so on) |
| `INTEGRATION.md` | How to use the bridge from your own resource |

## Requirements

These must be installed and started before Newb_Bridge:

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- A game build with Lua 5.4 (`lua54 'yes'`, the default on current servers)

Plus at least one supported framework: Qbox (`qbx_core`), QBCore (`qb-core`) or ESX (`es_extended`). Everything else (inventory, target, menus, notifications, dispatch, fuel, keys) is optional. Install only what your server runs.

## Install

1. Put the `Newb_Bridge` folder in your resources folder.
2. Start it after ox_lib and oxmysql, and before every resource that uses it. Your framework, inventory and target resources should also start before the bridge so they can be detected:

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core            # or qb-core / es_extended
ensure ox_inventory        # your inventory
ensure ox_target           # your target
ensure Newb_Bridge

ensure your_script_that_uses_the_bridge
```

3. (Optional) Set the language with the same convar ox_lib uses, in `server.cfg`:

```cfg
setr ox:locale en
```

Locale files live in `locales/`. The default is `en`.

4. Start the server. The console prints a line for every module that could not find a provider, and the bridge checks GitHub for a newer version (see `Config.VersionCheck` below).

There is no SQL to import and no items or images to add. The bridge defines no inventory items.

## Folder layout

- `settings/` is the folder you edit: which providers to use, the theme and the auto-detect lists. Start here.
- `locales/` holds the translations.
- `resource/` is the bridge code (modules, utilities and types). You normally never edit it.
- `import.lua` is what other scripts load with `@Newb_Bridge/import.lua`, so it stays in the resource root.
- `web/` is the built UI.

When you update the bridge, keep your `settings/` folder and replace the rest.

A setting you delete, or one a newer version adds that your kept file lacks, behaves like the shipped value: providers use `"auto"`, `VersionCheck` stays on and the task group limits keep their shipped numbers.

### How the bridge keeps other scripts light

- The `newb_bridge_host 'yes'` line in `fxmanifest.lua` marks the resource that runs the bridge. Keep it if you rename the folder. A script that imports the bridge asks that resource for each module's finished source once, instead of searching the disk for it.
- The prop placer, zone creator, DUI surface and dialogue tools load the first time one of their exports is called, not when the resource starts. `exports.Newb_Bridge:LazyToolsLoaded()` lists the ones that have loaded.
- On the client, `bridge.framework.getIsPlayerLoaded`, `getPlayerJobData`, `hasJob` and `isOnDuty` are answered from a copy inside the calling script. The copy is dropped when `Newb_Bridge:client:playerLoaded`, `playerUnloaded` or `playerJobUpdated` fires.
- The UI draws icons with the Font Awesome webfonts. Nothing icon-related downloads at start, and each font file (solid 115 KB, regular 19 KB, brands 110 KB) downloads the first time an icon of that style is shown.

## Choosing providers

Open `settings/bridge_resources.lua`. Each setting is either:

- `"auto"`: the first matching resource that is started wins (the order is listed in `settings/auto_detect.lua`), or
- a resource name from the table below: that provider is used and nothing else is checked.

Every setting in the table below ships as `"auto"`. If you pin a resource that is not installed, the module does nothing, so keep `"auto"` or set the resource you run.

**Auto detection order.** For each setting the bridge walks the list below in order and takes the first resource that is `started`. If none is started, it takes the first one that is installed but not yet started. If none exists at all, it uses the fallback shown, or (for modules with no fallback) logs a yellow `No installed provider found` line and the module does nothing. Startup is never blocked.

| Setting | Default | Valid values and auto order (first match wins) |
|---|---|---|
| `Config.Framework` | `auto` | `qbx_core`, `qb-core`, `es_extended` |
| `Config.Inventory` | `auto` | `ox_inventory`, `wasabi_inventory`, `m-Inventory`, `one_inventory`, `jaksam_inventory`, `tgiann-inventory`, `codem-inventory`, `core_inventory`, `origen_inventory`, `qs-inventory`, `qb-inventory`, plus manual-only `qb-framework`, `esx-framework` |
| `Config.Target` | `auto` | `ox_target`, `tgiann-target`, `core_focus`, `qb-target`, `sleepless_interact` |
| `Config.VehicleKeys` | `auto` | `MrNewbVehicleKeys`, `qbx_vehiclekeys`, `cd_garage`, `mVehicle`, `okokGarage`, `qb-vehiclekeys`, `vehicles_keys`, `wasabi_carlock`, `Renewed-Vehiclekeys`, `mk_vehiclekeys`, `ak47_vehiclekeys`, `0r-vehiclekeys` |
| `Config.VehicleFuel` | `auto` | `ox_fuel`, `rcore_fuel`, `okokGasStation`, `LegacyFuel`, `cdn-fuel`, `lc_fuel`, `qb-fuel`, `Renewed-Fuel`, `ps-fuel`, `qs-fuelstations`, `ti_fuel`, `internal` |
| `Config.Menu` | `auto` | `ox_lib`, `lation_ui`, `qb-menu` (no fallback) |
| `Config.Notifications` | `auto` | `ox_lib`, `vms_notifyv2`, `codem-notification`, `brutal_notify`, `fl-notify`, `mythic_notify`, `okokNotify`, `pnotify`, `solaire_notify`, `t-notify`, `lation_ui`, `wasabi_notify`, `zsx_uiv2` (fallback `internal`) |
| `Config.Inputs` | `auto` | `ox_lib`, `lation_ui` (no fallback) |
| `Config.TextUI` | `auto` | `ox_lib`, `lation_ui`, `okokTextUI`, `cd_drawtextui`, `jg-textui`, `lab-TextUI`, `zsx_uiv2` (no fallback) |
| `Config.ProgressBar` | `auto` | `ox_lib`, `lation_ui`, `wasabi_uikit`, `progressbar`, `zsx_uiv2` (no fallback) |
| `Config.BossMenu` | `auto` | `qbx_management`, `qb-management`, `esx_society`, `vms_bossmenu`, `tk_bosstablet`, `okokBossMenu`, `codem-bossmenu`, `zat-bossmenu`, `m-BossMenu`, `lation_jobs` |
| `Config.Dispatch` | `auto` | `ps-dispatch`, `cd_dispatch`, `tk_dispatch`, `rcore_dispatch`, `lb-tablet`, `origen_police`, `core_dispatch`, `kartik-mdt`, `codem-dispatch`, `wasabi_mdt`, `redutzu-mdt`, `internal` |

Notes:

- The values in each row are listed in auto-detection order. `internal` for notifications is the toast built into the bridge's own web UI. For fuel and dispatch it is a fallback used when nothing else is found.
- `qb-framework` and `esx-framework` are for servers with no separate inventory resource: items are read from the framework's own player inventory. They are never picked by `"auto"`; set them by hand.
- If you set a name that is not in the list, the module prints a warning that it has no implementation for that provider and does nothing.

Other settings in the same file:

| Setting | Meaning |
|---|---|
| `Config.Debug` | `true` prints extra debug lines. Leave `false` in production. |
| `Config.VersionCheck` | `true` checks GitHub on start and prints newer versions to the server console only. |

### Theme

`settings/theme.lua` holds one colour palette used by every Newb UI (backgrounds, text, buttons, status colours, corner radius and font). Change a value, restart `Newb_Bridge`, then restart or reopen the resources that use it. Leave a token out and each resource keeps its own built-in colour. Colours are `#rgb` or `#rrggbb`; tokens marked `(any)` in the file also accept `rgb()` and `rgba()`.

## Checking that it works

1. Look at the server console after start. A provider that could not be resolved prints a yellow `[Newb_Bridge] No installed provider found for ...` line.
2. From any resource that depends on the bridge, show a notification (see `INTEGRATION.md`).

## Deprecations

Event names were renamed on 2026-11-17 to one pattern, `Newb_Bridge:{client|server}:{subject}{PastTense}`. The old names keep working until 2026-12-17 and are then removed. The full list and how to migrate are in `EXPORTS.md`, section Deprecations.

## Support

- Documentation: https://mrnewb.github.io/docs/
- Community Discord: https://discord.gg/mrnewbscripts

## Web UI

The compiled interface is already in `web/build`. You do not need Node or to build anything to run the resource. The `web/` source is only needed if you want to modify the UI (`npm install`, then `npm run build` inside `web/`).

## FAQ

**The console says "imports Newb_Bridge, which is not started".**
The resource using the bridge started before it, or the bridge failed to start. Put `ensure Newb_Bridge` above that resource in `server.cfg` and check the console for errors from the bridge itself.

**"No installed provider found for <module>".**
The setting is `"auto"` and none of the supported resources for that module are started. Either install one, make sure it starts before `Newb_Bridge`, or set the setting to the resource you use. Modules you never call do not need a provider.

**I set a provider but nothing happens.**
Check the spelling against the table above (it is case sensitive, for example `Renewed-Fuel`, `m-Inventory`). If the console prints "has no client/server implementation for provider", the name is not supported. Also confirm that resource is running.

**Menus, input dialogs, notifications or progress bars do not appear.**
Check that a supported UI resource (ox_lib is required by the bridge, so it is normally present) is started and that the setting is `"auto"` or names a resource you run. Notifications fall back to the bridge's own toast (`internal`) when no provider is found.

**Items, stashes or shops do nothing.**
The inventory module must match your inventory. Set `Config.Inventory` explicitly if two inventory resources are present. Stash and shop functions are not available on every inventory; they return `nil` or `false` where the provider cannot do it.

**A resource errors because `bridge` is nil.**
The resource's `fxmanifest.lua` must list `@Newb_Bridge/import.lua` in `shared_scripts` after `@ox_lib/init.lua`, and Newb_Bridge must be started first. See `INTEGRATION.md`.

**`bridge.dialogue`, `bridge.task`, `bridge.target` or `bridge.menu` error on the server.**
Those modules are client only. Server-only modules are `bridge.bossmenu` and `bridge.dispatch`. See `MODULES.md`.

**The UI shows nothing or looks wrong.**
Make sure `web/build` is present (it ships with the resource). After changing `settings/theme.lua`, restart `Newb_Bridge` and then the resources using the theme.

**A text is untranslated.**
Your `ox:locale` value may point at a locale that lacks that key. Switch to a locale that exists in `locales/` or add the key to your locale file.

**I get a version update message on start.**
A newer release exists. It is informational and only prints to the server console. Set `Config.VersionCheck = false` to silence it.

**Version mismatches.**
If an export or method is missing after you updated only some resources, update Newb_Bridge and the resources that use it to their latest releases and restart them together. Resources built on the bridge say which version they need.
