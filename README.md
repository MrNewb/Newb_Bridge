# Newb_Bridge

The spiritual successor to [Community Bridge](https://github.com/TheOrderFivem/community_bridge).

Built first and foremost for MrNewbScripts resources. That is what sets the scope, the release cadence, and what gets added. You are welcome to use it, ship against it, and open issues or PRs — just go in knowing the roadmap answers to my scripts, not to a feature backlog.

ox_lib, ox_inventory, and ox_target are the reference implementations. Other providers map onto the same calls.

[Documentation](https://mrnewb.github.io/docs/newb_bridge) · [Install guide](https://mrnewb.github.io/docs/newb_bridge/getting-started) · [Tebex](https://mrnewbscripts.tebex.io/) · [Discord](https://discord.gg/mrnewbscripts)

[Modules](https://mrnewb.github.io/docs/newb_bridge/modules) · [Migrating](https://mrnewb.github.io/docs/newb_bridge/migrating) · [Utilities](https://mrnewb.github.io/docs/newb_bridge/utilities) · [Config](https://mrnewb.github.io/docs/newb_bridge/configuration)

[![Total downloads](https://img.shields.io/github/downloads/MrNewb/Newb_Bridge/total?style=for-the-badge&logo=github)](https://github.com/MrNewb/Newb_Bridge/releases/latest/download/Newb_Bridge.zip)
[![Latest release downloads](https://img.shields.io/github/downloads/MrNewb/Newb_Bridge/latest/total?style=for-the-badge&logo=github)](https://github.com/MrNewb/Newb_Bridge/releases/latest/download/Newb_Bridge.zip)
[![Latest version](https://img.shields.io/github/v/release/MrNewb/Newb_Bridge?style=for-the-badge&logo=github)](https://github.com/MrNewb/Newb_Bridge/releases/latest/)
[![Server rank](https://badges.5metrics.dev/Newb_Bridge/serverRank.svg?style=for-the-badge)](https://5metrics.dev/resource/Newb_Bridge)
[![Servers](https://badges.5metrics.dev/Newb_Bridge/servers.svg?style=for-the-badge)](https://5metrics.dev/resource/Newb_Bridge)
[![Players](https://badges.5metrics.dev/Newb_Bridge/players.svg?style=for-the-badge)](https://5metrics.dev/resource/Newb_Bridge)

## Install

Needs [ox_lib](https://github.com/overextended/ox_lib), [oxmysql](https://github.com/overextended/oxmysql) (loaded for `getOwnedVehicles`), and a server with `lua54`. Drop the folder in resources and start it before anything that uses it:

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

Modules load the first time you touch them. You only need the providers you actually run.

## Usage

```lua
-- Server
bridge.inventory.addItem(source, 'water', 1)
bridge.framework.addMoney(source, 'cash', 500)

-- Client
bridge.notifications.notify({ description = 'Hello', type = 'success' })
bridge.menu.openMenu({ id = 'my_menu', title = 'Shop', options = { ... } })
```

Works the same on Qbox, QB, or ESX. UI modules take ox_lib-shaped tables.

The full method list lives in the [docs](https://mrnewb.github.io/docs/newb_bridge/modules), not here. For editor autocomplete, point LuaLS at [`types/types.lua`](types/types.lua).

## Config

Edit `settings/bridge_resources.lua`. Leave a setting on `"auto"` and the first installed match wins. Set a resource name if you need to pin one.

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
| `bridge.framework` | client / server | [Framework](https://mrnewb.github.io/docs/newb_bridge/modules/framework) |
| `bridge.inventory` | client / server | [Inventory](https://mrnewb.github.io/docs/newb_bridge/modules/inventory) |
| `bridge.target` | client | [Target](https://mrnewb.github.io/docs/newb_bridge/modules/target) |
| `bridge.menu` | client | [Menu](https://mrnewb.github.io/docs/newb_bridge/modules/menu) |
| `bridge.notifications` | client | [Notifications](https://mrnewb.github.io/docs/newb_bridge/modules/notifications) |
| `bridge.inputs` | client | [Inputs](https://mrnewb.github.io/docs/newb_bridge/modules/inputs) |
| `bridge.textui` | client | [TextUI](https://mrnewb.github.io/docs/newb_bridge/modules/textui) |
| `bridge.progressbar` | client | [Progress bar](https://mrnewb.github.io/docs/newb_bridge/modules/progressbar) |
| `bridge.vehiclekeys` | client / server | [Vehicle keys](https://mrnewb.github.io/docs/newb_bridge/modules/vehiclekeys) |
| `bridge.vehiclefuel` | client / server | [Vehicle fuel](https://mrnewb.github.io/docs/newb_bridge/modules/vehiclefuel) |
| `bridge.bossmenu` | server | [Boss menu](https://mrnewb.github.io/docs/newb_bridge/modules/bossmenu) |
| `bridge.dispatch` | server | [Dispatch](https://mrnewb.github.io/docs/newb_bridge/modules/dispatch) |
| `bridge.dialogue` | client | [Dialogue](https://mrnewb.github.io/docs/newb_bridge/modules/dialogue) |
| `bridge.taskGroups` | client / server | [Task Groups](https://mrnewb.github.io/docs/newb_bridge/modules/taskgroups) |
| `bridge.task` | client | [Task HUD](https://mrnewb.github.io/docs/newb_bridge/modules/task) |

Also shipped: `AddInteraction`, `PropPlacer`, `useGizmo`, `VersionCheck`, and a few others. See [Utilities](https://mrnewb.github.io/docs/newb_bridge/utilities).

<details>
<summary>Supported providers</summary>

| Category | Providers |
|---|---|
| Framework | qbx_core, qb-core, es_extended |
| Inventory | ox_inventory, m-Inventory, one_inventory, jaksam_inventory, tgiann-inventory, codem-inventory, core_inventory, origen_inventory, qs-inventory, qb-inventory |
| Target | ox_target, tgiann-target, core_focus, qb-target, sleepless_interact |
| Vehicle keys | MrNewbVehicleKeys, qbx_vehiclekeys, cd_garage, mVehicle, okokGarage, qb-vehiclekeys, vehicles_keys, wasabi_carlock, Renewed-Vehiclekeys, mk_vehiclekeys, ak47_vehiclekeys, 0r-vehiclekeys |
| Fuel | ox_fuel, rcore_fuel, okokGasStation, LegacyFuel, cdn-fuel, lc_fuel, qb-fuel, Renewed-Fuel, ps-fuel, qs-fuelstations, ti_fuel (plus an internal fallback) |
| Menu | ox_lib, lation_ui, qb-menu |
| Notifications | ox_lib, vms_notifyv2, codem-notification, brutal_notify, fl-notify, mythic_notify, okokNotify, pnotify, solaire_notify, t-notify, lation_ui, wasabi_notify, zsx_uiv2 |
| Inputs | ox_lib, lation_ui |
| TextUI | ox_lib, lation_ui, okokTextUI, cd_drawtextui, jg-textui, lab-TextUI, zsx_uiv2 |
| Progress bar | ox_lib, lation_ui, wasabi_uikit, progressbar, zsx_uiv2 |
| Boss menu | qbx_management, qb-management, esx_society, vms_bossmenu, tk_bosstablet, okokBossMenu, codem-bossmenu, zat-bossmenu, m-BossMenu |
| Dispatch | ps-dispatch, cd_dispatch, tk_dispatch, rcore_dispatch, lb-tablet, origen_police, core_dispatch, kartik-mdt, codem-dispatch, wasabi_mdt, redutzu-mdt (plus an internal fallback) |

Detection order is in [`settings/auto_detect.lua`](settings/auto_detect.lua). To add a provider, copy an existing folder under `modules/<category>/` and open a PR.

</details>

## Community Bridge

[Community Bridge](https://github.com/TheOrderFivem/community_bridge) is still maintained if you're on it, and nothing here forces you off it.

I'll be straight about why this exists. I strongly believe Community Bridge diverged so far past the scope it started with that it can't be pulled back. I wanted that project to work. By the time it was clear how far it had derailed, the damage was structural rather than something a few PRs would fix.

Trimming it back is not an option I have. Its compatibility surface is load-bearing for resources whose authors may have moved on years ago, and plenty of those ship escrowed — if an export disappears, the server owner can't open the file and patch the call themselves. They'd be left with something broken over a decision they had no part in and no way to work around. So Community Bridge keeps every bit of compatibility it has, and I keep maintaining it for the creators who built on it. That's an obligation to their users, not a roadmap.

Newb_Bridge is what I'd write if I started over, which is exactly what it is. A successor in intent, not a rename or a fork. No Community Bridge source ships here — the interaction and spawn pipeline is a ground-up rewrite that borrows the model, and anything genuinely derived from another project is listed in [ATTRIBUTIONS.md](ATTRIBUTIONS.md). I wanted lazy loading and wasn't willing to break years of existing exports to get it, so this became its own resource with its own scope from day one.

Per-module conversion notes: [Migrating from community_bridge](https://mrnewb.github.io/docs/newb_bridge/migrating).

## Scope and maintenance

Read this before you build something load-bearing on it.

- **I maintain this alone.** One maintainer, one roadmap. There is no team behind it and no plan for one.
- **Scope is deliberately narrow.** It covers what MrNewbScripts resources need. A provider or module that nothing of mine uses is unlikely to land, however reasonable the request — that is the cost of keeping it small and predictable.
- **Deprecation is short.** Functions marked deprecated get two weeks, then they come out. Read the changelog inside that window. If a two-week cycle doesn't suit how you ship, pin a release tag.
- **Issues and PRs are welcome.** Bug reports, provider fixes, and new provider folders under `modules/<category>/` are the ones most likely to be merged. Ping me on [Discord](https://discord.gg/mrnewbscripts) if something needs a conversation first.

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