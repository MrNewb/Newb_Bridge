# Using the bridge from your own resource

## 1. Start order

Newb_Bridge must be running before your resource. In `server.cfg`:

```cfg
ensure ox_lib
ensure oxmysql
ensure Newb_Bridge
ensure my_resource
```

If the bridge is not started, your resource fails to load with a message saying so.

## 2. Manifest

Load ox_lib first, then the bridge import, in `shared_scripts`:

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

dependencies { 'ox_lib', 'Newb_Bridge' }

shared_scripts {
    '@ox_lib/init.lua',
    '@Newb_Bridge/import.lua',
}

client_scripts { 'client.lua' }
server_scripts { 'server.lua' }
```

This gives every script in your resource a global `bridge`. Nothing is copied into your resource; the provider code is loaded from the bridge when you first use a module.

## 3. Use the modules

Server:

```lua
RegisterNetEvent('my_resource:buy', function()
    local src = source
    if bridge.framework.removeMoney(src, 'cash', 100, 'my_resource purchase') then
        bridge.inventory.addItem(src, 'water', 1)
        bridge.notifications.notify(src, { description = 'Purchased.', type = 'success' })
    end
end)
```

Client:

```lua
bridge.target.addSphereZone({
    name = 'my_resource_counter',
    coords = vec3(0.0, 0.0, 70.0),
    radius = 1.5,
    options = {
        { name = 'my_resource_open', label = 'Open', icon = 'fa-solid fa-store',
          onSelect = function()
              bridge.menu.openMenu({
                  id = 'my_resource_menu', title = 'Counter',
                  options = { { title = 'Buy water', onSelect = function() TriggerServerEvent('my_resource:buy') end } },
              })
          end },
    },
})
```

Only the providers you use need to exist. A module with no installed provider does nothing, so guard anything critical:

```lua
if not bridge.inventory.getResourceName() then
    print('my_resource: no supported inventory found')
end
```

## 4. Calling exports directly

If you do not want the `bridge` global, call the exports instead (see `EXPORTS.md`):

```lua
local task = exports.Newb_Bridge:Task()
task.show({ title = 'Job', tasks = { { label = 'Done', current = 0, max = 3 } } })
```

## 5. Strings

`bridge.locale('some.key', { name = 'Bob' })` returns text from the bridge's `locales/<ox:locale>.json`. Resource-specific text should live in your own resource.

## 6. Items and images

The bridge adds no items and ships no item images. Newb_Bridge is the single source of item image paths for your NUI: call `bridge.inventory.getImagePath(item)` (client or server) and use the returned `nui://` URL as the image source. It resolves the path for whichever supported inventory is active, so do not hard-code any inventory's image folder.

```lua
local image = bridge.inventory.getImagePath('water')
bridge.notifications.notify({ description = 'Water', image = image })
```

## 7. Checking for updates

```lua
-- server
exports.Newb_Bridge:VersionCheck('your-github-user/your-repo', GetCurrentResourceName())
```

This reads `resources.json` from the repository's `main` (or `master`) branch and prints newer versions to the server console.

## 8. Tips

- Check the return values documented in `EXPORTS.md` and `MODULES.md`; failed calls return `nil` or `false` rather than raising an error.
- Do not trust client-side balances or item counts for anything that matters. Use the server methods.
- Distance-check and permission-check on the server before calling `openStash` or `openShop`.
