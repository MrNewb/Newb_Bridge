# Attributions

The Lua resource — `import.lua`, `modules/`, `utility/`, `settings/`, `types/`, and `locales/` — is distributed under the **GNU General Public License, version 3** (`GPL-3.0-only`). See [LICENSE](LICENSE) for the full terms, or <https://www.gnu.org/licenses/>. It is distributed WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

GPL-3.0 is the strongest copyleft among the components below, so it governs that work; the LGPL-3.0 and MIT components are compatible and are conveyed under those same GPL-3.0 terms. LGPL-3.0 is GPL-3.0 plus additional permissions, and GPL-3.0 section 7 allows a distributor to remove those additional permissions — the LGPL text is included as [LICENSES/LGPL-3.0.txt](LICENSES/LGPL-3.0.txt) so the notices in `import.lua` resolve to something in this repository.

Version 3 is used without the "or any later version" option, because the GPL-3.0 components incorporated here do not elect it.

The web interface in `web/` contains no GPL-licensed code and is not part of that work — see [The web interface](#the-web-interface) below.

Each entry below lists the file(s) in this repository, the upstream source, authors where known, and the license that applies to that upstream work.

If you redistribute this resource, you are responsible for complying with the license terms of each attributed component.

---

## Lazy loader

| File | Upstream | License |
|---|---|---|
| [`import.lua`](import.lua) | [overextended/ox_lib](https://github.com/overextended/ox_lib) — `init.lua` lazy-load pattern | **LGPL-3.0-or-later** |

- Copyright (C) 2021 Linden ([@thelindat](https://github.com/thelindat))
- Modified for Newb_Bridge module loading
- License text: <https://www.gnu.org/licenses/lgpl-3.0.html>

---

## DataView

| File | Upstream | License |
|---|---|---|
| [`utility/client/dataview.lua`](utility/client/dataview.lua) | [overextended/ox_lib](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/modules/DataView/init.lua) — `modules/DataView/init.lua`, commit b8f5a04 | **MIT** |

- Copyright © 2026 Linden ([@thelindat](https://github.com/thelindat))
- Copyright © 2020 gottfriedleibniz ([@gottfriedleibniz](https://github.com/gottfriedleibniz)), whose [citizenfx/lua dataview example](https://github.com/citizenfx/lua/blob/luaglm-548/libs/scripts/examples/dataview.lua) ox_lib's version is adapted from
- Modified for Newb_Bridge: the `---@meta` annotation was removed so the file loads as an ordinary module. The license notice in the file is unchanged.
- License text: [LICENSES/MIT-DataView.txt](LICENSES/MIT-DataView.txt)

The gizmo uses it for matrix buffer operations. It is included here, not required from ox_lib, because ox_lib's v3.40.0 release zip is built without ox_lib's `modules` folder, so the module is missing on servers running that release. The file is the same code ox_lib publishes, with credit to its authors.

---

## Gizmo

| File | Upstream | License |
|---|---|---|
| [`utility/client/gizmo.lua`](utility/client/gizmo.lua) | [overextended/ox_lib PR #453](https://github.com/overextended/ox_lib/pull/453) — Andyyy7666 | **LGPL-3.0-or-later** (ox_lib) |
| [`utility/client/gizmo.lua`](utility/client/gizmo.lua) | [Cfx.re forum — DrawGizmo discussion](https://forum.cfx.re/t/allow-drawgizmo-to-be-used-outside-of-fxdk/5091845/8) — AvarianKnight | Community contribution |
| [`utility/client/gizmo.lua`](utility/client/gizmo.lua) | [DemiAutomatic/object_gizmo](https://github.com/DemiAutomatic/object_gizmo/blob/main/client/gizmo.lua) — DemiAutomatic | **GPL-3.0** |

Exported as `useGizmo` from Newb_Bridge.

---

## Community Bridge (interaction / entity system)

Newb_Bridge is a **ground-up rewrite** and does **not** ship Community Bridge source code. The `AddInteraction` proximity and spawn pipeline is **inspired by** Community Bridge’s entity/point registration model: radius-gated local spawn, `onEnter` / `onExit` / `canSpawn` hooks, and avoiding per-entity `lib.zones` at scale.

| File | Upstream concept | License |
|---|---|---|
| [`utility/client/interaction_points.lua`](utility/client/interaction_points.lua) | Cell-bucket proximity manager, 3×3 cell scan, dense-area stagger, immediate spawn on enter | **GPL-3.0** (upstream project) |
| [`utility/client/interactions.lua`](utility/client/interactions.lua) | Entity spawn/despawn, target registration, bulk/batch registration, job/duty refresh | **GPL-3.0** (upstream project) |
| [`utility/server/interactions.lua`](utility/server/interactions.lua) | Server-side interaction helpers | **GPL-3.0** (upstream project) |

- Upstream: [The-Order-of-the-Sacred-Framework/community_bridge](https://github.com/The-Order-of-the-Sacred-Framework/community_bridge) — The Order of the Sacred Framework
- MrNewbScripts fork: [MrNewb/community_bridge](https://github.com/MrNewb/community_bridge)
- Newb_Bridge implementation is original; concepts are credited for transparency with the ecosystem this project succeeds.

---

## Renewed-Lib (object placer, groups & routing buckets)

Two different relationships to [Renewed-Lib](https://github.com/Renewed-Scripts/Renewed-Lib) are credited here: the object placer is **derived code**, while the group and routing-bucket work follows **patterns** with original implementations.

### Object placer

| File | Upstream | License |
|---|---|---|
| [`utility/client/placer.lua`](utility/client/placer.lua) | [Renewed-Scripts/Renewed-Lib](https://github.com/Renewed-Scripts/Renewed-Lib) — object placement system | **GPL-3.0** |

**Purpose:** object placer functionality.

**Code used:** the object placement system.

**Modifications made:**

- Updated variable naming for consistency
- Added missing parameters for native functions
- Updated deprecated ox_lib raycast camera export
- Enhanced showtext UI to work with multiple systems
- Moved placement text to locales for internationalization
- Replaced ox_lib model request exports with our bridge functions

The raycast change lives in [`utility/client/camera_ray.lua`](utility/client/camera_ray.lua), which the placer shares with the gizmo, zone creator and DUI tools; that helper and [`utility/client/placement_controls.lua`](utility/client/placement_controls.lua) are original to this repository.

### Routing buckets & player cache

Portions of the framework player cache and interaction bucket gating follow **patterns popularized by** Renewed-Lib. Implementation code in Newb_Bridge is original (ox_lib `lib.player` routing buckets, `lib.class` snapshots, bridge API wiring). Newb_Bridge does not track jobs/gangs as a generic group system — job/duty tracking lives in `server_helpers.lua`'s duty cache and `player_registry.lua`'s `BridgePlayer` snapshot (`jobName`/`onDuty`) instead.

| File | Renewed-Lib concept | License |
|---|---|---|
| [`modules/framework/player_registry.lua`](modules/framework/player_registry.lua) | Cached `BridgePlayer` snapshot, char id lookup | **GPL-3.0** |
| [`modules/framework/server_helpers.lua`](modules/framework/server_helpers.lua) | Incremental `GlobalState` job counts (`newbsJobCounts`) | **GPL-3.0** |
| [`utility/client/interaction_points.lua`](utility/client/interaction_points.lua) | Interaction `bucket` field — spawn only when player bucket matches | **GPL-3.0** |
| [`utility/client/interactions.lua`](utility/client/interactions.lua) | `bucket` on `AddInteraction` / `UpdateInteraction` | **GPL-3.0** |

- Upstream: [Renewed-Scripts/Renewed-Lib](https://github.com/Renewed-Scripts/Renewed-Lib) — Renewed Scripts (FjamZoo et al.)
- Docs: [renewed.dev/lib](https://renewed.dev/lib)
- Server bucket set/get: `bridge.framework.setPlayerBucket` / `getPlayerBucket` delegate to ox_lib `lib.player`.

---

## ox_lib (runtime dependency)

Newb_Bridge depends on [ox_lib](https://github.com/overextended/ox_lib) at runtime for utilities such as `lib.print`, `lib.requestModel`, locale helpers, and UI primitives. ox_lib is **not** bundled in this repository.

| Resource | License |
|---|---|
| [overextended/ox_lib](https://github.com/overextended/ox_lib) | **LGPL-3.0-or-later** |

---

## Font Awesome (dialogue NUI icons)

The bridge web UI draws icons with the Font Awesome Free webfonts, the same approach [ox_target](https://github.com/overextended/ox_target/blob/main/web/index.html) uses, except the stylesheet and fonts are shipped inside `web/build/assets` instead of being linked from a CDN. The stylesheet defines a class for every icon name, and the browser downloads a font file only when an icon of that style is first drawn: `fa-solid-900` (115 KB), `fa-regular-400` (19 KB) or `fa-brands-400` (110 KB).

| Package | Role | License |
|---|---|---|
| [`@fortawesome/fontawesome-free`](https://www.npmjs.com/package/@fortawesome/fontawesome-free) | Stylesheets and webfonts for solid, regular and brands icons | **CC BY 4.0** (icons), **SIL OFL 1.1** (fonts), **MIT** (code) |

- Icons by [Font Awesome](https://fontawesome.com)
- Full license: <https://fontawesome.com/license/free>
- Attribution: include a Font Awesome notice in distributions that ship the built `web/` assets (this file satisfies that for Newb_Bridge).

Implementation files: [`web/src/icon-utils.js`](web/src/icon-utils.js), [`web/src/DialogueIcon.jsx`](web/src/DialogueIcon.jsx).

---

## API shapes

Several bridge modules intentionally mirror **ox_lib**-style APIs (context menus, progress bars, notifications, inputs) so scripts written against common industry patterns work across providers. Those interfaces are documented in [`types/types.lua`](types/types.lua); implementation code in `modules/` is original to Newb_Bridge unless noted above.

Interaction and framework bucket/group behaviour draws on **Community Bridge** and **Renewed-Lib** patterns as described in the sections above; that code is implemented independently in this repository. The object placer is the exception — it is derived from Renewed-Lib and is listed as such above.

---

## Summary

The Lua resource is distributed under **GPL-3.0-only**. The components below are grouped by whether they carry a license obligation or are credited as a courtesy.

### Licensed code in the Lua resource

| License | Components |
|---|---|
| **GPL-3.0** | `gizmo.lua` portions from [object_gizmo](https://github.com/DemiAutomatic/object_gizmo) — the strongest copyleft here, and the reason the Lua resource is GPL-3.0 |
| **LGPL-3.0-or-later** | `import.lua` (ox_lib `init.lua` pattern), gizmo portions from ox_lib PR #453 — LGPL-3.0-or-later permits conveying under GPL-3.0 |
| **MIT** | `dataview.lua` from ox_lib's DataView module (Linden, gottfriedleibniz) — MIT permits conveying under GPL-3.0; its notice is kept in the file |

### Credited concepts (no license obligation)

Ideas, APIs, and architectural patterns are not subject to copyright. The entries below are credited for transparency with the ecosystem this project succeeds; the implementation code in this repository is original and carries no upstream license terms.

| Project | Concept credited |
|---|---|
| [Community Bridge](#community-bridge-interaction--entity-system) | Entity/point interaction and spawn-pipeline model |
| [Renewed-Lib](#renewed-lib-object-placer-groups--routing-buckets) | Object placer (derived); group system, routing bucket gating and cached player snapshots (patterns) |

### The web interface

The NUI in `web/` is original to this project and contains no GPL-licensed code. It runs in the CEF browser process and talks to the Lua resource only by JSON message passing, so it is a separate work from the GPL-licensed Lua code it ships beside. Releases include the compiled bundle in `web/build/` only.

The third-party code bundled into it is permissively licensed, and each package's notice is retained inside the built assets:

| Package | Role | License |
|---|---|---|
| [React](https://react.dev) and React-DOM | UI runtime | **MIT** |
| Font Awesome Free (`@fortawesome/fontawesome-free`) | Icon stylesheets and webfonts | **CC BY 4.0** (icons), **SIL OFL 1.1** (fonts), **MIT** (code) |

### Runtime dependencies (not bundled)

| Resource | License |
|---|---|
| [overextended/ox_lib](https://github.com/overextended/ox_lib) | LGPL-3.0-or-later — required at runtime, not redistributed here |

For questions about Newb_Bridge licensing outside these attributions, open an issue on this repository.
