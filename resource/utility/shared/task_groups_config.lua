---Task group limits live in settings/bridge_resources.lua. A settings file kept from an older version can lack a value or the
---whole table, so anything missing falls back to the value the bridge ships with.
local SHIPPED = {
    DefaultMaxPlayers = 8,
    MaxMaxPlayers = 8,
    MinMaxPlayers = 2,
    InviteRadius = 10.0,
    JoinCodeLength = 6,
    MaxNameLength = 32,
}

Config.TaskGroups = setmetatable(Config.TaskGroups or {}, { __index = SHIPPED })
