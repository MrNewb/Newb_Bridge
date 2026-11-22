# Exports and commands

Every export below is called on the `Newb_Bridge` resource. From a resource that loaded `@Newb_Bridge/import.lua` use `exports[bridge.name]:Name(...)`. From any other resource use `exports.Newb_Bridge:Name(...)`.

Side column: **C** = client, **S** = server, **C/S** = both (separate implementations).

Return values marked `nil` mean the call did nothing or the input was invalid. Always check results you depend on.

## Commands

The bridge registers no chat commands. `bridge.registerCommand` / `bridge.registerKeybind` (below) are helpers for your own commands.

## Core

| Export | Side | Signature | Returns |
|---|---|---|---|
| `BridgeEnvironment` | C/S | `()` | `{ config = Config, resource = "<bridge resource name>" }`. Used by `import.lua`. |
| `Framework` | C/S | `()` | The framework module table (same as `bridge.framework`). |
| `Inventory` | C/S | `()` | The inventory module table. Only used by `import.lua` for `qb-inventory`, `qb-framework` and `esx-framework`. Prefer `bridge.inventory`. |
| `Locale` | C/S | `(key: string, params?: table)` | Translated string for the current `ox:locale`. Same as `bridge.locale`. |
| `Locales` | C/S | `()` | The whole locale table. Same as `bridge.locales`. |
| `GetTheme` | C/S | `()` | The theme token table from `settings/theme.lua`. |
| `GetThemeCss` | C/S | `()` | The theme as a CSS string of `--newb-*` variables. |
| `VersionCheck` | S | `(repoPath: string, resourceName: string)` | Nothing. Prints newer versions to the server console. |

```lua
local theme = exports.Newb_Bridge:GetTheme()
print(theme.accent)
```

## Notifications

| Export | Side | Signature | Returns |
|---|---|---|---|
| `Notify` | C | `(data: table\|string)` | Nothing. Shows a toast in the bridge's own UI. |

`data` fields: `id`, `title`, `description` (markdown allowed), `type` (`inform`, `success`, `error`, `warning`; `info` is accepted as `inform`), `duration` (ms), `showDuration`, `position` (`top`, `top-right`, `top-left`, `bottom`, `bottom-right`, `bottom-left`, `center-right`, `center-left`), `icon`, `iconColor`, `iconAnimation` (`spin`, `spinPulse`, `spinReverse`, `pulse`, `beat`, `fade`, `beatFade`, `bounce`, `shake`), `alignIcon` (`top`, `center`), `image`, `style`, `sound`. At least a title or description is required. A repeated `id` updates one toast instead of stacking.

```lua
exports.Newb_Bridge:Notify({ title = 'Saved', description = 'Your changes were stored.', type = 'success' })
```

To notify through whichever provider you configured, use `bridge.notifications.notify` (see `MODULES.md`) instead.

## Commands and keybinds (client)

| Export | Signature | Returns |
|---|---|---|
| `RegisterCommand` | `(commandName, callback(source, args, raw), restricted?: boolean)` | Nothing |
| `RegisterKeybind` | `(commandName, description, defaultKey: string\|nil, callback(source, args, raw))` | Nothing. Registers the command and, if `defaultKey` is a non-empty string, a keyboard mapping. |
| `GetBoundKey` | `(commandName)` | Label of the player's bound key (`string`) or `nil`. |

```lua
exports.Newb_Bridge:RegisterKeybind('myscript_action', 'Use my action', 'E', function()
    print('pressed')
end)
```

## Interactions (client, plus one server export)

Spawn peds or props near the player and attach target options. They spawn and despawn by distance.

| Export | Side | Signature | Returns |
|---|---|---|---|
| `AddInteraction` | C | `(id: string, payload: InteractionPayload)` | `true`, or `false, 'missing'` / `false, 'coords'`. An existing id is replaced. |
| `AddInteractionsBatch` | C | `(entries, options?)` | Number added. `entries` is a list of `{ id, payload }` or a table keyed by id. Options: `batchSize`, `batchDelayMs`, `batchThreshold`, `sortByDistance`, `onProgress`, `onComplete`. |
| `CancelInteractionBatch` | C | `()` | Nothing. |
| `BeginInteractionBulk` / `CommitInteractionBulk` | C | `()` | Nothing. Wrap many `AddInteraction` calls to register them together. |
| `RemoveInteraction` | C | `(id)` | `boolean` |
| `RemoveInteraction` | S | `(id, target?: number)` | `boolean`. Removes it for one client (`target` = server id) or all clients when omitted. |
| `UpdateInteraction` | C | `(id, updates)` | `boolean` |
| `RemoveAllInteractions` | C | `()` | Nothing. Removes every interaction registered with the bridge. |
| `GetClosestInteraction` | C | `()` | Summary table or `nil`. |
| `GetNearbyInteractions` | C | `()` | List of summaries (`id`, `distance`, `coords`, `heading`, `radius`, `model`, `scenario`). |
| `GetInteractionByEntity` | C | `(entity)` | `id, interaction` or `nil`. |

Payload fields: `model`, `coords`, `heading`, `radius`, `options` (target options), `component`, `anim`, `scenario`, `weapon`, `invincible` (peds), `snapToGround`, `rotation`, `matrix` (props), `bucket`, and callbacks `onSpawn`, `onDespawn`, `onEnter`, `canSpawn`.

```lua
exports.Newb_Bridge:AddInteraction('shop_clerk', {
    model = 's_m_m_ammucountry',
    coords = vec3(24.5, -1346.0, 29.5),
    heading = 270.0,
    radius = 30.0,
    options = {
        { name = 'shop_open', label = 'Open shop', icon = 'fa-solid fa-store', distance = 2.0,
          onSelect = function() print('opened') end },
    },
})
```

## Placement tools (client)

| Export | Signature | Returns |
|---|---|---|
| `PropPlacer` | `(model \| PlacerCallOptions, forceGround?, allowedMaterials?, maxDistance?, placementType?, marker?, previewBehavior?, options?)` | `vector4` (x, y, z, heading), or a result table when a model list or `multi = true` is used, or `false` on cancel, already placing, or invalid model. |
| `useGizmo` | `(entity \| GizmoCallOptions, options?)` | Table with `position`, `rotation`, `heading`, `matrix`, and so on, or `nil`. |
| `CreateZone` | `(options?)` | Zone result (`poly`: `name`, `points`, `thickness`; `box`: `name`, `coords`, `size`, `rotation`; `sphere`: `name`, `coords`, `radius`), a multi result when `multi = true`, or `nil`. A `name` is required. |

```lua
local spot = exports.Newb_Bridge:PropPlacer({ model = 'prop_toolchest_01', maxDistance = 8.0 })
if spot then print(spot.x, spot.y, spot.z, spot.w) end

local zone = exports.Newb_Bridge:CreateZone({ type = 'box', name = 'my_zone' })
```

Placer options include `multi`, `maxPlacements`, `heightAdjust`, `startMode` (`position`, `model`, `animation`), `startHeading`, `groundOffset`, `rotateStep`, `isPositionValid`, `marker`, `placedMarker`, `placedPreview`, `localeOverrides`. Zone options include `type` (`poly`, `box`, `sphere`), `name`, `mode` (`freecam`, `onfoot`), `anchor`, `planeZ`, `maxDistance`, `height`, `width`, `length`, `radius`, `multi`. Gizmo options include `deleteOnConfirm`, `label`, `outline`, and for the spawn form `model`, `coords`, `heading`, `rotation`, `ped`.

## DUI surfaces (client)

Display a web page on a prop or in the world.

| Export | Signature | Returns |
|---|---|---|
| `CreateDuiPlacement` | `(options?)` | `{ ok, cancelled?, reason?, coords?, normal? }` |
| `CreateLaserTargetPlacement` | `(options?)` | Same shape as above. |
| `RegisterDuiSurface` | `(key, { url, width?, height?, coords?, rotation?, scale?, renderTarget?, boardKey? })` | Nothing |
| `UpdateDuiSurface` | `(key, data)` | `boolean` |
| `UnregisterDuiSurface` | `(key)` | Nothing |
| `ClearDuiSurfaces` | `()` | Nothing |
| `HasDuiPlacement` | `(content)` | `boolean` |
| `GetDuiBoardCenter` | `(content, coords?)` | `vector3` or `nil` |
| `GetDuiTargetRadius` | `(content)` | `number` |
| `ApplyPropDuiTexture` | `(key, entity, textureDef, content)` | `boolean` |
| `UpdatePropDuiTexture` | `(key, textureDef, content)` | `boolean` |
| `ClearPropDuiTexture` | `(key)` | Nothing |
| `HasPropDuiTexture` | `(key)` | `boolean` |

These are advanced exports used by Newb resources that draw boards in the world. `content` and `textureDef` are tables whose shape depends on the resource that owns the board.

## Dialogue (client)

| Export | Signature | Returns |
|---|---|---|
| `Dialogue` | `()` | The dialogue API (also `bridge.dialogue`). |

The API: `RegisterMenu(menu) -> id`, `UnregisterMenu(id)`, `UpdateMenu(id, updates)`, `SetMenuOption(id, key, updates)`, `RemoveMenuOption(id, key)`, `RefreshMenu(id)`, `GetMenu(id)`, `OpenMenu(id, target?)`, `GetNavigationArgs()`, `Close(sessionId)`, `PlayPedSpeech(ped, speech, param?)`, `PlayPedAnim(ped, anim, animId?)`.

```lua
local dialogue = exports.Newb_Bridge:Dialogue()
local id = dialogue.RegisterMenu({
    id = 'shopkeeper',
    title = 'Shopkeeper',
    text = 'Welcome in. What can I get you?',
    options = {
        { title = 'Buy', description = 'Browse the shelves', onSelect = function() print('buy') end },
        { title = 'Leave' },
    },
})
dialogue.OpenMenu(id, ped) -- ped (or entity / coords / target table) is optional
```

Option fields include `title`, `description`, `icon`, `image`, `disabled`, `readOnly`, `menu` (open a sub-menu), `onSelect`, `event`, `serverEvent`, `args`, `input` (field of type `input`, `number`, `checkbox`, `select`, `multi-select`, `slider`, `textarea`), `metadata`, `speech`, `anim`.

## Task HUD (client)

| Export | Signature | Returns |
|---|---|---|
| `Task` | `()` | The task HUD API (also `bridge.task`). |
| `CompleteTask` | `()` | Nothing. Marks the active task finished and closes the HUD. |

API: `show(data)`, `update(data)`, `hide()`, `complete()`, `toggle()`, `isOpen()`, `hasTask()`, `isCompleting()`, `get()`.

`data`: `title` (required for `show`), `description`, `icon`, `tasks` (list of `{ id?, label, current?, max?, value?, progress? }`), `position` (`left`, `right`), `type` (`dense`, `weight`, `gather`), `expanded`.

```lua
local task = exports.Newb_Bridge:Task()
task.show({ title = 'Delivery run', description = 'Drop off all crates', tasks = { { label = 'Delivered', current = 0, max = 5 } } })
task.update({ tasks = { { label = 'Delivered', current = 3, max = 5 } } })
task.complete()
```

## Events

Events the bridge triggers. Listen with `AddEventHandler`. Names follow `Newb_Bridge:{client|server}:{subject}{PastTense}`.

| Event | Side | Arguments | When |
|---|---|---|---|
| `Newb_Bridge:client:playerLoaded` | C | none | The framework finished loading the local player. |
| `Newb_Bridge:client:playerUnloaded` | C | none | The local player logged out or was unloaded. |
| `Newb_Bridge:client:playerJobUpdated` | C | `jobName, jobLabel, gradeName, gradeLevel` | The local player's job changed. |
| `Newb_Bridge:server:playerLoaded` | S | `src` | A player finished loading. |
| `Newb_Bridge:server:playerUnloaded` | S | `src` | A player logged out, was unloaded or dropped. |
| `Newb_Bridge:server:playerJobUpdated` | S | `src, jobName` | A player's job changed. |
| `Newb_Bridge:client:notificationShown` | C | `data` | A notification was shown through `bridge.notifications.notify`. |
| `Newb_Bridge:server:dispatchAlertSent` | S | `src, jobs, coords, data, blip, alertFlash` | `bridge.dispatch.sendAlert` was called. |
| `Newb_Bridge:client:themeChanged` | C | none | Trigger it to make the bridge UI re-read and push the theme. |

The old names of renamed events still work for now. See Deprecations below.

## Deprecations

Deprecated names keep working next to their replacements until the removal date, then they are deleted. Nothing here breaks today.

| Step | Date |
|---|---|
| Announced, new names added, old names deprecated | 2026-11-17 |
| Old names still work | until 2026-12-17 (30 days) |
| Old names removed | the first release after 2026-12-17 |

Everything deprecated on 2026-12-17:

| What | Items |
|---|---|
| Events the bridge fires for your scripts | 8 old names, each fired next to its new name |
| Events the bridge sends to itself | 8 old names (the boss menu one has 9 provider variants), each still accepted |
| File paths | 1 require path, forwarded by a small file |
| Configuration | none |

Every old name is marked in the bridge code with a `deprecated 2026-12-17` comment, so they are easy to find and delete.

### Event renames

New names follow `Newb_Bridge:{client|server}:{subject}{PastTense}`. The arguments did not change.

Events the bridge fires for your scripts to listen to. Move your listeners to the new name:

| Old name (deprecated) | New name | Side |
|---|---|---|
| `Newb_Bridge:client:playerLoad` | `Newb_Bridge:client:playerLoaded` | C |
| `Newb_Bridge:client:playerUnload` | `Newb_Bridge:client:playerUnloaded` | C |
| `Newb_Bridge:client:playerJobUpdate` | `Newb_Bridge:client:playerJobUpdated` | C |
| `Newb_Bridge:server:playerLoad` | `Newb_Bridge:server:playerLoaded` | S |
| `Newb_Bridge:server:playerUnload` | `Newb_Bridge:server:playerUnloaded` | S |
| `Newb_Bridge:server:playerJobUpdate` | `Newb_Bridge:server:playerJobUpdated` | S |
| `Newb_Bridge:Client:NotifyShown` | `Newb_Bridge:client:notificationShown` | C |
| `Newb_Bridge:Server:DispatchAlert` | `Newb_Bridge:server:dispatchAlertSent` | S |

Events the bridge sends to itself. Only change these if your own script triggers or listens to them. `<provider>` in the boss menu event is one of `codem`, `esx`, `m`, `okok`, `qb`, `qbx`, `tk`, `vms` or `zat`, for example `Newb_Bridge:client:openBossMenu:qb`:

| Old name (deprecated) | New name | Side |
|---|---|---|
| `Newb_Bridge:client:notify` | `Newb_Bridge:client:notificationSent` | C |
| `Newb_Bridge:client:setFuel` | `Newb_Bridge:client:fuelSet` | C |
| `Newb_Bridge:client:openBossMenu:<provider>` | `Newb_Bridge:client:bossMenuOpened` | C |
| `Newb_Bridge:Interaction:Remove` | `Newb_Bridge:client:interactionRemoved` | C |
| `Newb_Bridge:dispatch:internalAlert` | `Newb_Bridge:client:dispatchAlertReceived` | C |
| `Newb_Bridge:client:openTaskGroupMenu` | `Newb_Bridge:client:taskGroupMenuOpened` | C |
| `Newb_Bridge:client:taskGroupMenuRefresh` | `Newb_Bridge:client:taskGroupMenuRefreshed` | C |
| `Newb_Bridge:server:taskGroupMenu:setOpen` | `Newb_Bridge:server:taskGroupMenuOpenChanged` | S |

### Moved files

The code folders moved under `resource/`, so `settings/` is easy to find at the top. One old path is still forwarded for other scripts:

| Old require (deprecated) | New require |
|---|---|
| `require '@Newb_Bridge/utility/client/camera_ray'` | `require '@Newb_Bridge/resource/utility/client/camera_ray'` |

`import.lua` did not move. Any other `@Newb_Bridge/utility/...` or `@Newb_Bridge/modules/...` require must gain the `resource/` part. Only `camera_ray` is forwarded, and the forwarding file is removed after 2026-12-17.

### How to migrate

1. Search your scripts for the old names above. They are plain strings in `AddEventHandler`, `RegisterNetEvent` and `TriggerEvent` calls.
2. Replace each with its new name. The arguments are identical.
3. Restart the script and check nothing still listens to an old name.

After 2026-12-17 a listener left on an old name simply never fires. There is no error, so check before the date.

### Removal checklist (for maintainers)

Do this in the first release after 2026-12-17:

1. Run `grep -rn "deprecated 2026-12-17"` in the bridge folder. Every match except the shim and its manifest line (step 2) is either a `TriggerEvent` line firing an old name (delete the line, keep the new-name line above it) or a `RegisterNetEvent` line accepting one (delete that line).
2. Delete the `utility/` folder in the bridge root, which only holds the `camera_ray.lua` forwarding file, and the `"utility/client/camera_ray.lua"` line in `fxmanifest.lua`.
3. Delete this Deprecations section, the "Renamed events" notes and the Deprecations pointer in both READMEs, and add the removal to the release notes.
4. Run `code check` on the bridge and fire each new event once to confirm the listeners still run.

