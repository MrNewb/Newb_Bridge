local vehiclefuel = {}

---Each fuel script has its own way to be told a vehicle's fuel. The bridge asks all of them the same question, so the
---only difference is this table: the provider name (as written in settings/auto_detect.lua) and what to call.
local function exportSetter(resource, method)
    return function(vehicle, amount)
        local fuelExports = exports[resource]
        fuelExports[method](fuelExports, vehicle, amount)
    end
end

local setters = {
    internal = function(vehicle, amount)
        SetVehicleFuelLevel(vehicle, amount + 0.0)
    end,
    ox_fuel = function(vehicle, amount)
        SetVehicleFuelLevel(vehicle, amount + 0.0)
        Entity(vehicle).state.fuel = amount
    end,
    LegacyFuel = exportSetter('LegacyFuel', 'SetFuel'),
    ['Renewed-Fuel'] = exportSetter('renewed-fuel', 'SetFuel'),
    ['cdn-fuel'] = exportSetter('cdn-fuel', 'SetFuel'),
    lc_fuel = exportSetter('lc_fuel', 'SetFuel'),
    okokGasStation = exportSetter('okokGasStation', 'SetFuel'),
    ['ps-fuel'] = exportSetter('ps-fuel', 'SetFuel'),
    ['qb-fuel'] = exportSetter('qb-fuel', 'SetFuel'),
    ['qs-fuelstations'] = exportSetter('qs-fuelstations', 'SetFuel'),
    rcore_fuel = exportSetter('rcore_fuel', 'SetVehicleFuel'),
    ti_fuel = exportSetter('ti_fuel', 'SetFuel'),
    -- whip_fuel's tank is a vehicle stat only the server writes, so a client call asks the bridge host's server side.
    whip_fuel = function(vehicle, amount)
        if not NetworkGetEntityIsNetworked(vehicle) then return end
        TriggerServerEvent('Newb_Bridge:server:whipFuelRequested', NetworkGetNetworkIdFromEntity(vehicle), amount)
    end,
}

local provider = Config.Providers and Config.Providers.vehiclefuel
local applyFuel = setters[provider]

if not applyFuel then
    print(("^3[Newb_Bridge] Module 'vehiclefuel' has no client implementation for provider '%s'. Add it to the setters table in modules/vehiclefuel/client.lua, or pick a supported provider in settings/bridge_resources.lua (options are listed in settings/auto_detect.lua).^0"):format(tostring(provider)))
    return
end

function vehiclefuel.set(vehicle, amount)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    amount = tonumber(amount)
    if not amount then return end

    applyFuel(vehicle, amount)
end

if bridge.isHost then
    local function handleFuelSet(netId, amount)
        if source ~= 65535 then return end
        vehiclefuel.set(NetworkGetEntityFromNetworkId(netId), amount)
    end

    RegisterNetEvent('Newb_Bridge:client:fuelSet', handleFuelSet)
    RegisterNetEvent('Newb_Bridge:client:setFuel', handleFuelSet) -- deprecated 2026-12-17: use Newb_Bridge:client:fuelSet
end

return vehiclefuel
