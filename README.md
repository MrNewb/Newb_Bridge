# Newb_Bridge

![Newb_Bridge](.github/assets/banner.webp)

**The shared foundation under every MrNewbScripts resource.**

Newb_Bridge is the compatibility layer my scripts are built on. Instead of each script carrying its own framework, inventory, target, menu and notification code, they all call one set of `bridge.*` functions, and Newb_Bridge maps those calls onto whatever your server actually runs. Qbox, QBCore or ESX. ox_inventory or qs-inventory. ox_target or qb-target. One script, any stack, nothing rewritten.

It is also the spiritual successor to [Community Bridge](https://github.com/TheOrderFivem/community_bridge): the same idea, started over with a tighter scope and lazy loading built in from the first line, and none of the extras that piled up along the way.

> **Running MrNewbScripts?** You need this resource. Install it once, start it before my scripts, and they handle the rest. You do not need to write any code.
>
> **Building your own scripts?** You are welcome to use it. Just know the roadmap answers to my scripts first. See [Scope and maintenance](#scope-and-maintenance).

[Documentation](https://mrnewb.github.io/docs/newb_bridge) · [Install guide](https://mrnewb.github.io/docs/newb_bridge/getting-started) · [Tebex](https://mrnewbscripts.tebex.io/) · [Discord](https://discord.gg/mrnewbscripts)

[Modules](https://mrnewb.github.io/docs/newb_bridge/developers/modules) · [Migrating](https://mrnewb.github.io/docs/newb_bridge/developers/migrating) · [Utilities](https://mrnewb.github.io/docs/newb_bridge/developers/utilities) · [Config](https://mrnewb.github.io/docs/newb_bridge/configuration)

[![Total downloads](https://img.shields.io/github/downloads/MrNewb/Newb_Bridge/total?style=for-the-badge&logo=github)](https://github.com/MrNewb/Newb_Bridge/releases/latest/download/Newb_Bridge.zip)
[![Latest release downloads](https://img.shields.io/github/downloads/MrNewb/Newb_Bridge/latest/total?style=for-the-badge&logo=github)](https://github.com/MrNewb/Newb_Bridge/releases/latest/download/Newb_Bridge.zip)
[![Latest version](https://img.shields.io/github/v/release/MrNewb/Newb_Bridge?style=for-the-badge&logo=github)](https://github.com/MrNewb/Newb_Bridge/releases/latest/)
[![Server rank](https://badges.5metrics.dev/Newb_Bridge/serverRank.svg?style=for-the-badge)](https://5metrics.dev/resource/Newb_Bridge)
[![Servers](https://badges.5metrics.dev/Newb_Bridge/servers.svg?style=for-the-badge)](https://5metrics.dev/resource/Newb_Bridge)
[![Players](https://badges.5metrics.dev/Newb_Bridge/players.svg?style=for-the-badge)](https://5metrics.dev/resource/Newb_Bridge)

## Why it exists

MrNewbScripts ships to servers running every combination of framework, inventory, target and UI resource. Supporting all of that inside each script means the same detection and adapter code copied dozens of times, and every new provider means touching every script.

Newb_Bridge moves that work to one place:

- **Write once.** A script calls `bridge.inventory.addItem(...)` and never asks which inventory is installed.
- **Fix once.** A provider fix or a new provider lands in the bridge and every MrNewbScripts resource gets it.
- **Consistent everywhere.** Menus, notifications, inputs, progress bars and text UI behave the same across my scripts, and share one colour palette ([see below](#server-colour-palette)).
- **Pay only for what you run.** Modules load the first time something touches them. A server with no dispatch resource never loads the dispatch module.

## What it is, and what it isn't

**It is** a small set of focused modules plus a handful of utilities (interaction points, a prop placer, a gizmo, a task HUD, dialogue) that my scripts share.

**It is not** a kitchen-sink library. There is no catch-all compatibility layer for old exports, no feature that exists only because someone once asked for it, and no module nothing of mine uses. That narrow scope is what keeps it fast, readable and predictable. For why I started over instead of trimming Community Bridge, see [Community Bridge](#community-bridge).

ox_lib, ox_inventory and ox_target are the reference implementations. Every other provider maps onto the same calls.

## Used by

Newb_Bridge is a required dependency of the MrNewbScripts catalogue, including:

| | | |
|---|---|---|
| MrNewb_Banking | MrNewb_Dealerships | MrNewb_DigitalPets |
| MrNewb_Fishing | MrNewb_Fuel | MrNewb_Garage |
| MrNewb_Hud | MrNewb_Medical | MrNewb_Recycling |
| MrNewb_Shops | MrNewb_Collectables | MrNewb_TrafficCreator |
| MrNewbBeeKeeping | MrNewbCustomPlates | MrNewbLootTables |
| MrNewbNameChanger | MrNewbOrganics | MrNewbPawn |
| MrNewbPhoneTracker | MrNewbPlateCarriers | MrNewbPrescriptions |
| MrNewbVehicleKeys | MrNewbVehicleKeysPhone | MrNewbVehicleRentals |
| MrNewbWeaponTints | | |

If a MrNewbScripts product lists Newb_Bridge in its install notes, this is the one it means. Start it before the script that needs it.

## Install

The full guide is in the online docs: install steps and start order, every provider setting with its valid values, every module and export, and troubleshooting.

- [Installation](https://mrnewb.github.io/docs/newb_bridge/getting-started)
- [Configuration](https://mrnewb.github.io/docs/newb_bridge/configuration)
- [Supported resources](https://mrnewb.github.io/docs/newb_bridge/supported)
- [Modules](https://mrnewb.github.io/docs/newb_bridge/developers/modules)
- [Troubleshooting](https://mrnewb.github.io/docs/newb_bridge/troubleshooting)

Quick version: needs [ox_lib](https://github.com/overextended/ox_lib), [oxmysql](https://github.com/overextended/oxmysql) (loaded for `getOwnedVehicles`), and a server with `lua54`. Drop the folder in resources and start it before anything that uses it:

```cfg
ensure ox_lib
ensure oxmysql
ensure Newb_Bridge

ensure your_script
```

In that script's `fxmanifest.lua`:

```lua
shared_scripts {
    '@ox_lib/init.lua',
    '@Newb_Bridge/import.lua',
}
```

Modules load the first time you touch them, so you only pay for the providers you actually run.

## Usage

```lua
-- Server
bridge.inventory.addItem(source, 'water', 1)
bridge.framework.addMoney(source, 'cash', 500)

-- Client
bridge.notifications.notify({ description = 'Hello', type = 'success' })
bridge.menu.openMenu({ id = 'my_menu', title = 'Shop', options = { ... } })
```

Works the same on Qbox, QB, or ESX. UI modules take ox_lib-shaped tables, so code written against ox_lib moves over with little change.

The full method list lives in the [docs](https://mrnewb.github.io/docs/newb_bridge/developers/modules), not here. For editor autocomplete, point LuaLS at [`resource/types/types.lua`](resource/types/types.lua).

## Folder layout

- `settings/` is the folder you edit: which providers to use, the theme and the auto-detect lists.
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

## Config

Edit `settings/bridge_resources.lua`. Leave a setting on `"auto"` and the first installed match wins. Set a resource name if you need to pin one. Every setting ships as `"auto"`, including menu, notifications, inputs, text UI and progress bar. Detection order is in the install guide and `settings/auto_detect.lua`.

```lua
Config.Framework = "auto"      -- qbx_core, qb-core, es_extended
Config.Inventory = "auto"      -- ox_inventory, qs-inventory, qb-inventory, ...
Config.Target = "auto"         -- ox_target, core_focus, qb-target, ...
Config.Menu = "auto"           -- ox_lib, lation_ui, qb-menu
Config.Notifications = "auto"
```

On start, the server console prints which provider each module resolved to.

## Modules

| Module | Side | Docs |
|---|:---:|---|
| `bridge.framework` | client / server | [Framework](https://mrnewb.github.io/docs/newb_bridge/developers/modules/framework) |
| `bridge.inventory` | client / server | [Inventory](https://mrnewb.github.io/docs/newb_bridge/developers/modules/inventory) |
| `bridge.target` | client | [Target](https://mrnewb.github.io/docs/newb_bridge/developers/modules/target) |
| `bridge.menu` | client | [Menu](https://mrnewb.github.io/docs/newb_bridge/developers/modules/menu) |
| `bridge.notifications` | client | [Notifications](https://mrnewb.github.io/docs/newb_bridge/developers/modules/notifications) |
| `bridge.inputs` | client | [Inputs](https://mrnewb.github.io/docs/newb_bridge/developers/modules/inputs) |
| `bridge.textui` | client | [TextUI](https://mrnewb.github.io/docs/newb_bridge/developers/modules/textui) |
| `bridge.progressbar` | client | [Progress bar](https://mrnewb.github.io/docs/newb_bridge/developers/modules/progressbar) |
| `bridge.vehiclekeys` | client / server | [Vehicle keys](https://mrnewb.github.io/docs/newb_bridge/developers/modules/vehiclekeys) |
| `bridge.vehiclefuel` | client / server | [Vehicle fuel](https://mrnewb.github.io/docs/newb_bridge/developers/modules/vehiclefuel) |
| `bridge.bossmenu` | server | [Boss menu](https://mrnewb.github.io/docs/newb_bridge/developers/modules/bossmenu) |
| `bridge.dispatch` | server | [Dispatch](https://mrnewb.github.io/docs/newb_bridge/developers/modules/dispatch) |
| `bridge.banking` | server | Society accounts |
| `bridge.doorlock` | client / server | Door locking |
| `bridge.phone` | server | Phone emails and numbers |
| `bridge.weather` | client | Weather sync toggle |
| `bridge.dialogue` | client | [Dialogue](https://mrnewb.github.io/docs/newb_bridge/developers/modules/dialogue) |
| `bridge.task` | client | [Task HUD](https://mrnewb.github.io/docs/newb_bridge/developers/modules/task) |
| `bridge.theme` | client / server | [Server colour palette](#server-colour-palette) |

Also shipped: `AddInteraction`, `PropPlacer`, `useGizmo`, `VersionCheck`, and a few others. See [Utilities](https://mrnewb.github.io/docs/newb_bridge/developers/utilities).

<details>
<summary>Supported providers</summary>

| Category | Providers |
|---|---|
| Framework | whip_core, kora_core, qbx_core, qb-core, es_extended |
| Inventory | whip_core, kora_inventory, ox_inventory, wasabi_inventory, m-Inventory, one_inventory, jaksam_inventory, tgiann-inventory, codem-inventory, core_inventory, origen_inventory, qs-inventory, qb-inventory |
| Target | whip_core, kora_target, ox_target, tgiann-target, core_focus, qb-target, sleepless_interact |
| Vehicle keys | whip_core, MrNewbVehicleKeys, kora_vehiclekeys, jg-vehiclekeys, qbx_vehiclekeys, cd_garage, mVehicle, okokGarage, qb-vehiclekeys, vehicles_keys, wasabi_carlock, Renewed-Vehiclekeys, mk_vehiclekeys, ak47_vehiclekeys, 0r-vehiclekeys |
| Fuel | whip_fuel, ox_fuel, rcore_fuel, okokGasStation, LegacyFuel, cdn-fuel, lc_fuel, qb-fuel, Renewed-Fuel, ps-fuel, qs-fuelstations, ti_fuel (plus an internal fallback) |
| Menu | ox_lib, lation_ui, qb-menu |
| Notifications | whip_core, ox_lib, vms_notifyv2, codem-notification, brutal_notify, fl-notify, mythic_notify, okokNotify, pnotify, solaire_notify, t-notify, lation_ui, wasabi_notify, ZSX_UIV2 |
| Inputs | whip_core, ox_lib, lation_ui |
| TextUI | whip_core, ox_lib, lation_ui, okokTextUI, cd_drawtextui, jg-textui, lab-TextUI, ZSX_UIV2 |
| Progress bar | whip_core, ox_lib, lation_ui, wasabi_uikit, progressbar, ZSX_UIV2 |
| Boss menu | qbx_management, qb-management, esx_society, vms_bossmenu, tk_bosstablet, okokBossMenu, codem-bossmenu, zat-bossmenu, m-BossMenu, lation_jobs, ShitDevScripts-Bossmenu |
| Banking | Renewed-Banking, qb-banking, okokBanking, lation_banking, fd_banking, kartik-banking, tgg-banking, tgiann-bank, wasabi_banking, esx_addonaccount, ShitDevScripts-Banking |
| Doorlock | ox_doorlock, qb-doorlock, rcore_doorlock, doors_creator |
| Phone | kora_phone, sd-phone, sky_phone, lb-phone, gksphone, okokPhone, qs-smartphone, yseries, qb-phone |
| Weather | Renewed-Weathersync, qb-weathersync, cd_easytime |
| Dispatch | ps-dispatch, cd_dispatch, tk_dispatch, rcore_dispatch, lb-tablet, origen_police, core_dispatch, kartik-mdt, codem-dispatch, wasabi_mdt, redutzu-mdt (plus an internal fallback) |

Detection order is in [`settings/auto_detect.lua`](settings/auto_detect.lua). Two values are not resources: `internal` is the bridge's own built-in version (notifications, fuel, dispatch), and `none` means nothing was found so the module does nothing (banking, doorlock, phone, weather). To add a provider, copy an existing folder under `resource/modules/<category>/` and open a PR.

</details>

## Community Bridge

[Community Bridge](https://github.com/TheOrderFivem/community_bridge) is still maintained if you're on it, and nothing here forces you off it.

I'll be straight about why this exists. I strongly believe Community Bridge diverged so far past the scope it started with that it can't be pulled back. I wanted that project to work. By the time it was clear how far it had derailed, the damage was structural rather than something a few PRs would fix.

Trimming it back is not an option I have. Its compatibility surface is load-bearing for resources whose authors may have moved on years ago, and plenty of those ship escrowed — if an export disappears, the server owner can't open the file and patch the call themselves. They'd be left with something broken over a decision they had no part in and no way to work around. So Community Bridge keeps every bit of compatibility it has, and I keep maintaining it for the creators who built on it. That's an obligation to their users, not a roadmap.

Newb_Bridge is what I'd write if I started over, which is exactly what it is. A successor in intent, not a rename or a fork. No Community Bridge source ships here — the interaction and spawn pipeline is a ground-up rewrite that borrows the model, and anything genuinely derived from another project is listed in [ATTRIBUTIONS.md](ATTRIBUTIONS.md). I wanted lazy loading and wasn't willing to break years of existing exports to get it, so this became its own resource with its own scope from day one.

Per-module conversion notes: [Migrating from community_bridge](https://mrnewb.github.io/docs/newb_bridge/developers/migrating).

## Scope and maintenance

Read this before you build something load-bearing on it.

- **I maintain this alone.** One maintainer, one roadmap. There is no team behind it and no plan for one.
- **Scope is deliberately narrow.** It covers what MrNewbScripts resources need. A provider or module that nothing of mine uses is unlikely to land, however reasonable the request — that is the cost of keeping it small and predictable.
- **Deprecation is short.** Functions marked deprecated get two weeks, then they come out. Read the changelog inside that window. If a two-week cycle doesn't suit how you ship, pin a release tag.
- **Issues and PRs are welcome.** Bug reports, provider fixes, and new provider folders under `resource/modules/<category>/` are the ones most likely to be merged. Ping me on [Discord](https://discord.gg/mrnewbscripts) if something needs a conversation first.

None of this restricts what the licence grants you — it's GPL-3.0, fork it if my scope doesn't fit yours. It's here so nobody plans around a support model that doesn't exist.

## License

The Lua resource is **GPL-3.0-only** — see [LICENSE](LICENSE). It is distributed
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.

[`import.lua`](import.lua) carries LGPL-3.0-or-later notices from ox_lib and is
conveyed under GPL-3.0; the LGPL text is in [LICENSES/LGPL-3.0.txt](LICENSES/LGPL-3.0.txt).

The NUI in `web/` is original to this project and ships permissively licensed
dependencies (React, Font Awesome) whose notices are retained in the built assets.

Adapted code from other projects is listed in [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

## Server colour palette

`settings/theme.lua` holds the colours every Newb UI shares: backgrounds, text, the primary and accent colours, the exit button, and the success, warning, danger and info colours. Change a value, restart Newb_Bridge, then restart the resources using it. Each token becomes a CSS variable, `--newb-<token-in-kebab-case>` (for example `closeHover` is `--newb-close-hover`). Hover, soft and border variants are derived for the status, primary, accent and close colours.

In the script's client Lua (the script already imports the bridge):

```lua
bridge.theme.register()
```

In its UI, ask for the palette once the page loads and apply it. Newb_Bridge also pushes a `NEWB_THEME` message with the same payload:

```ts
const payload = await fetch(`https://${GetParentResourceName()}/newbTheme`, { method: 'POST', body: '{}' }).then((r) => r.json())
for (const [name, value] of Object.entries(payload.vars)) document.documentElement.style.setProperty(name, value)
```

Read the variables with a fallback, so a UI looks right with or without the palette and keeps its own layout and shape:

```css
.panel { background: var(--newb-surface, #171717); color: var(--newb-text, #fafafa); }
```

From Lua, `bridge.theme.get()` returns the tokens, `bridge.theme.vars()` the CSS variable map and `bridge.theme.css()` a ready-made `:root{...}` string. Other resources can use `exports.Newb_Bridge:GetTheme()` and `exports.Newb_Bridge:GetThemeCss()`.
