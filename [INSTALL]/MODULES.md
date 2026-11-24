# Modules (`bridge.*`)

After you load `@Newb_Bridge/import.lua` (see `INTEGRATION.md`) a global `bridge` table is available. Each module below loads the first time you touch it and is backed by the provider chosen in `settings/bridge_resources.lua`. If no provider is available the module is a no-op: every call does nothing and returns `nil`. Only call a module on the side listed for it; for example `bridge.dialogue` and `bridge.task` raise an error if used on the server, and `bridge.dispatch` and `bridge.bossmenu` do nothing on the client.

Every provider-backed module also has `bridge.<module>.getResourceName()`, which returns the provider resource name.

Also on `bridge`: `bridge.name` (the bridge resource name), `bridge.context` (`'client'` or `'server'`), `bridge.resource` (your resource), `bridge.locale(key, params?)`, `bridge.locales()`, and on the client `bridge.registerCommand(name, cb, restricted?)` and `bridge.registerKeybind(name, description, defaultKey, cb)`.

Money types are `'cash'`, `'bank'` or `'crypto'`. `src` is a player server id. Details of every table shape are in `resource/types/types.lua` (point your Lua language server at it for autocomplete).

| Module | Side |
|---|---|
| `bridge.framework` | C/S |
| `bridge.inventory` | C/S |
| `bridge.target` | C |
| `bridge.menu` | C |
| `bridge.notifications` | C (`notify(data)`) and S (`notify(src, data)`) |
| `bridge.inputs` | C |
| `bridge.textui` | C |
| `bridge.progressbar` | C |
| `bridge.vehiclekeys` | C/S |
| `bridge.vehiclefuel` | C/S |
| `bridge.bossmenu` | S |
| `bridge.dispatch` | S |
| `bridge.banking` | S |
| `bridge.doorlock` | C/S |
| `bridge.phone` | S |
| `bridge.weather` | C |
| `bridge.dialogue`, `bridge.task` | C (see `EXPORTS.md`) |

## bridge.framework

Server:

| Method | Returns |
|---|---|
| `getIdentifier(src)` | Character identifier or `nil` |
| `getSrcFromIdentifier(identifier)` / `getSourceByCharId(charId)` | Server id or `nil` |
| `getCharacterName(identifier)` | Full name, first name, last name |
| `getPlayer(src)` | Cached snapshot `{ source, charId, name, jobName, onDuty }` or `nil` |
| `getPlayers()` | List of server ids |
| `getPlayerDob(src)` | Date of birth or `nil` |
| `isAdmin(src)` | `boolean` |
| `setPlayerJob(src, name, grade)` / `setPlayerDuty(src, onDuty)` | `boolean` |
| `hasJob(src, job, grade?, duty?)` | `boolean` |
| `getPlayerJobData(src)` | `{ jobName, jobLabel, grade, gradeName, onDuty, isBoss }` or `nil` |
| `getPlayersByJob(job)` | List of server ids |
| `getPlayersOnDuty(job)` / `getPlayersWithJob(job)` | Table of `[src] = true` |
| `getDutyCountJob(job)` / `getOnlineCountJob(job)` | `number` |
| `getJobCounts(job)` | `{ count, onDuty }` |
| `addMoney(src, type, amount, reason?)` / `removeMoney(...)` | `boolean` |
| `getMoney(src, type)` | `number` |
| `addHunger(src, value)` / `addThirst(src, value)` | New value or `nil` |
| `getPlayerMetadata(src, key)` / `setPlayerMetadata(src, key, value)` | Value / nothing |
| `setMetadata(src, { key = { type = 'set'\|'add'\|'remove', value = v } })` | Nothing |
| `getPlayerBucket(src)` / `setPlayerBucket(src, bucket)` | `number` / `boolean` |
| `getOwnedVehicles(src)` | List of `{ vehicle, plate }` (reads your database through oxmysql) |
| `registerItemUse(item, cb(src, item))` | Registers a usable item |
| `registerCommand(name, help, params?, restrictedGroup?, cb(src, args, raw))` | Registers a server command through ox_lib |
| `getFrameworkJobs()` | Table of the framework's jobs |

Job counts are also mirrored to `GlobalState.newbsJobCounts` as `{ [job] = { count, onDuty } }`.

Client: `getStress()`, `getHunger()`, `getThirst()`, `setStatus(type, value)`, `isOnDuty()`, `hasJob(job, grade?, duty?)`, `getPlayerBucket()`, `getPlayerJobData()`, `getPlayerData()`, `getPlayerMetadata(key)`, `getFrameworkJobs()`, `getIdentifier()`, `getCharacterName()`, `getIsPlayerLoaded()`, `getAccountBalance(type)` (display only; do not trust it for security), `isPlayerDead()`, `getPlayerDob()`.

```lua
-- server
if bridge.framework.hasJob(src, 'police', 2, true) then
    bridge.framework.addMoney(src, 'bank', 250, 'bounty')
end
```

## bridge.inventory

Server: `Items(name?)`, `getImagePath(item)`, `getItemInfo(item)`, `addItem(inv, item, count?, metadata?, slot?)`, `removeItem(inv, item, count?, metadata?, slot?)`, `hasItem(inv, item, count?, metadata?)`, `getItemCount(inv, item, metadata?)`, `getInventoryItems(inv)`, `getSlot(inv, slot)`, `setMetadata(inv, slot, metadata)`, `canCarryItem(inv, item, count?, metadata?)`, `clearInventory(inv, keep?)`, `registerStash(id, label, slots, maxWeight, owner?, groups?, coords?)`, `openStash(src, id)`, `registerShop(type, data)`, `openShop(src, type)`, `registerHook(event, cb, options?)`, `removeHooks(hookId?)`.

Client: `Items(name?)`, `hasItem(item, count?, metadata?)`, `getItemCount(item, metadata?)`, `getImagePath(item)`, `getItemInfo(item)`, `getInventoryItems()`.

`inv` is a server id (player) or a string (stash id). Item tables use the ox_inventory shape (`name`, `count`, `slot`, `metadata`, ...). Methods a provider cannot do return `nil` or `false`; `registerHook` returns `nil` on providers without hook support.

```lua
if bridge.inventory.canCarryItem(src, 'water', 2) then
    bridge.inventory.addItem(src, 'water', 2)
end
```

### Item images

`bridge.inventory.getImagePath(item)` is the one place to get an item's NUI image path, on client and server, for every supported inventory. It returns a `nui://<inventory resource>/<image folder>/<file>` URL built from the active inventory's own item definition and image folder, so a script never builds image paths itself and does not need to know which inventory is running. The result works as an `<img src>` in any NUI page or as a notification `image`. `bridge.inventory.getItemInfo(item)` returns the item definition with the same URL in its `image` field. Both return `nil` when no inventory provider is active.

```lua
local src = bridge.inventory.getImagePath('water')
-- e.g. send it to your UI: SendNUIMessage({ action = 'item', image = src })
```

## bridge.target (client)

`addBoxZone`, `addSphereZone` (return a zone id), `removeZone(id)`, `addLocalEntity` / `removeLocalEntity`, `addEntity` / `removeEntity` (network ids), `addGlobalPed`, `addGlobalPlayer`, `addGlobalVehicle` and their `remove...` counterparts, `addModel` / `removeModel`, `disableTargeting(bool)`.

Option fields: `name`, `label`, `icon`, `distance`, `groups`, `items`, `anyItem`, `canInteract`, `onSelect`, `event`, `serverEvent`, `args`.

```lua
bridge.target.addSphereZone({
    name = 'my_zone', coords = vec3(0.0, 0.0, 70.0), radius = 1.5,
    options = { { name = 'my_zone_use', label = 'Use', icon = 'fa-solid fa-hand', onSelect = function() end } },
})
```

## bridge.menu (client)

`openMenu(data) -> id` (ox_lib context menu table: `id`, `title`, `options`, `menu`, `onExit`, ...) and `closeMenu()`.

## bridge.notifications

Client `notify(data)`, server `notify(src, data)`. `data` follows the ox_lib notification table: `title`, `description`, `type` (`inform`, `error`, `success`, `warning`), `duration`, `position`, `icon`, and so on. Providers ignore fields they do not support.

```lua
bridge.notifications.notify({ description = 'Hello', type = 'success' })   -- client
bridge.notifications.notify(src, { description = 'Hello', type = 'success' }) -- server
```

## bridge.inputs (client)

`inputdialog(heading, rows, options?)` returns the submitted values as a list, or `nil` if cancelled. Row types: `input`, `number`, `checkbox`, `select`, `multi-select`, `slider`, `color`, `date`, `date-range`, `time`, `textarea`, `toggle` (not every provider supports all of them). `closeinput()` closes it where supported.

```lua
local values = bridge.inputs.inputdialog('Name your crew', { { type = 'input', label = 'Name', required = true } })
if values then print(values[1]) end
```

## bridge.textui (client)

`showTextUI(text, options?)`, `hideTextUI()`, `isTextUIOpen()` (not on every provider).

## bridge.progressbar (client)

`openprogressbar(data) -> boolean` (`true` = completed, `false` = cancelled), `progressActive()`, `cancelProgress()`. Data: `duration` (ms), `label`, `canCancel`, `anim`, `prop`, `disable`, and provider-specific extras such as `description`, `icon`, `steps`.

```lua
local done = bridge.progressbar.openprogressbar({ duration = 4000, label = 'Repairing', canCancel = true, disable = { move = true } })
```

## bridge.vehiclekeys

Client `give(vehicle, plate?)`, `remove(vehicle, plate?)` for the local player. Server `give(src, vehicle, plate?)`, `remove(src, vehicle, plate?)`. `vehicle` is an entity handle.

## bridge.vehiclefuel

Client `set(vehicle, amount)`. Server `set(src, vehicle, amount)` asks that player's client to set the fuel.

To support another fuel script, add one entry to the `setters` table in `resource/modules/vehiclefuel/client.lua` (the provider name, and the call that sets the fuel) and add the name to the fuel list in `settings/auto_detect.lua`. The server side needs no change.

## bridge.bossmenu (server)

`openBossMenu(src, jobName, jobType?)` opens the configured boss menu for that player.

## bridge.dispatch (server)

`sendAlert(src, jobs, coords, data, blip, alertFlash?) -> boolean|nil`. `jobs` is a job name or a list. `data`: `code`, `icon`, `title`, `description`, `length`, `sound`. `blip`: `sprite`, `scale`, `colour`, `text`, `length`, `flash`, `radius`. A provider error is printed to the console and the call returns `false`.

```lua
bridge.dispatch.sendAlert(src, { 'police' }, GetEntityCoords(GetPlayerPed(src)),
    { code = '10-90', title = 'Alarm', description = 'Silent alarm triggered' },
    { sprite = 161, scale = 1.0, colour = 1, text = 'Alarm', length = 2 })
```

## Missing or broken providers (banking, doorlock, phone, weather)

These four modules never throw into your script. With no provider installed they use the `default` provider, which does nothing. Arguments of the wrong type (a non-string account, an amount that is not a number above 0, a door id that is not a string or number, a non-numeric player id, non-string mail text) return the fallback without reaching the provider. If the provider resource is stopped later, or one of its exports errors, the call returns the same fallback (`0`, `false` or `nil`) and the bridge prints one console line per call name.

## bridge.banking (server)

Society (job) accounts. `account` is the job or society name.

| Method | Returns |
|---|---|
| `getAccountMoney(account)` | Balance, `0` when the account is unknown |
| `addAccountMoney(account, amount, reason?)` | `boolean` from the banking resource |
| `removeAccountMoney(account, amount, reason?)` | `boolean` from the banking resource |

Not every banking resource uses `reason`; those that do not ignore it. With no banking resource, or one that is stopped or errors, the getter returns `0` and the others return `false`.

```lua
if bridge.banking.removeAccountMoney('police', 500, 'equipment') then
    bridge.inventory.addItem(src, 'radio', 1)
end
```

## bridge.doorlock

Server: `lockDoor(doorId) -> boolean`, `unlockDoor(doorId) -> boolean`. Client: `getClosestDoor() -> id|nil`. The id is whatever the doorlock resource uses (a number for `rcore_doorlock`, a string for `ox_doorlock`, the door entry for `qb-doorlock`), so pass it back to `lockDoor` or `unlockDoor` unchanged. With no doorlock resource those return `false` and `getClosestDoor` returns `nil`.

## bridge.phone (server)

`getPlayerPhone(src) -> number|string|false`, `sendEmail(src, email, title, message) -> boolean`. `email` is the sender shown in the inbox (qs-smartphone has no sender field, so it is dropped there; sky_phone has no way to send mail, so `sendEmail` returns `false`; kora_phone delivers it as system mail to the character's Mail app). Phones are server only: a client cannot ask the bridge to send mail, so a client script that needs one sends it through a server event of its own after checking the request. On the client `bridge.phone` does nothing. With no phone resource everything returns `false`.

## bridge.weather (client)

`disableSync()` turns the weather script's sync off for the local player and `enableSync()` turns it back on, for example while a script sets its own weather in an interior. It does nothing when no weather resource is found.

## Running on WHIP (`whip_core`)

[WHIP](https://github.com/WHIPFX/whip_core) is a whole framework, so the bridge has a `whip_core` provider for framework, inventory, target, notifications, inputs, textui, progressbar and vehiclekeys, and a `whip_fuel` provider for fuel. Auto-detect picks them when WHIP is running; set the provider by name in `settings/bridge_resources.lua` to force one. Do not run the bridge's other framework, inventory or target providers beside it.

What differs from the other stacks:

| Area | On WHIP |
|---|---|
| Identifier | The charId, returned as text. Numbers are accepted when you pass one in. |
| Jobs | A character can hold several jobs. `bridge.framework` reports the job they are on duty at, else the job where their role is highest. A grade is the job's roles ordered by level, lowest first, numbered from zero. `setPlayerJob` hires or re-ranks at a job and role that already exist; it never creates one. |
| Money | `cash` and `bank` only (`money` means cash). Cash is a banknote item, so it can be dropped or stolen. There is no `crypto`. |
| Needs | `hunger` and `thirst` are WHIP stats (0 to 100). `stress` is plain metadata: WHIP has no stress stat. |
| Item use | `registerItemUse` handlers take the item themselves, as on QBCore. The bridge answers WHIP's use call with "keep the item". |
| Items | The bridge adds no items. Register yours with WHIP (`RegisterItem` in your own resource, or `/whip` > Economy > Items). Weights are kilograms in WHIP and grams through the bridge. |
| Stashes | A WHIP container at a hidden spot. A stash's coordinates and owner are ignored; `groups` keep the job names only. |
| Shops | An `infinite`-mode WHIP shop. WHIP only opens a shop within range of it, so pass `coords` (or `locations`) to `registerShop`. |
| Hooks | WHIP has none: `registerHook` returns `nil`. |
| Target | One WHIP action per zone or entity. Prompts, not an eye cursor. Models must be names, not hashes. `groups` keep the job names only. |
| Keys | Keys are items cut for one vehicle. Server `give`/`remove` take an entity (a car WHIP has not seen is adopted) or a known plate. Client `give`/`remove` ask the host's server side, which checks the car is within 15 m and not owned by someone else. |
| Fuel | `whip_fuel`'s tank is a vehicle stat only the server writes. Server `set` writes it directly; client `set` asks the host's server side, which checks the car is within 15 m. |
| Menu, boss menu, dispatch | WHIP has no list menu, boss menu or dispatch. Menu keeps `ox_lib`; boss menu has no provider (businesses are managed in the phone's Business app); dispatch keeps the `internal` fallback. |

The bridge re-declares what it registered with WHIP (use handlers, target actions) when `whip_core` restarts.
