fx_version "cerulean"
game "gta5"
lua54 "yes"

name "Newb_Bridge"

newb_bridge_host "yes"

author "MrNewb"
description "Newb_Bridge is a lightweight FiveM resource that provides a unified, efficient API for interacting with frameworks and third-party resources through a single, consistent interface."
version "0.1.2"

dependencies {
    "ox_lib",
    "oxmysql",
}

shared_scripts {
    "@ox_lib/init.lua",
    "settings/bridge_resources.lua",
    "settings/theme.lua",
    "settings/auto_detect.lua",
    "import.lua",
    "resource/utility/shared/task_groups_config.lua",
    "resource/utility/shared/locale.lua",
}

ui_page "web/build/index.html"

client_scripts {
    "resource/utility/client/interaction_points.lua",
    "resource/utility/client/interactions.lua",
    "resource/utility/client/gizmo.lua",
    "resource/utility/client/keybinds.lua",
    "resource/utility/client/lazy_tools.lua",
    "resource/utility/client/task_groups.lua",
    "resource/utility/client/task_hud.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "resource/utility/server/interactions.lua",
    "resource/utility/server/task_groups.lua",
    "resource/utility/server/version.lua",
}

files {
    "import.lua",
    "resource/modules/**/client.lua",
    "resource/modules/**/server.lua",
    "resource/modules/**/shared.lua",
    "resource/modules/framework/*.lua",
    "locales/*.json",
    "resource/types/**/*.lua",
    "resource/host/*.lua",
    "resource/utility/client/*.lua",
    "utility/client/camera_ray.lua", -- deprecated 2026-12-17: old require path, see the shim
    "web/build/**",
}

exports {
    "BridgeEnvironment",
    "ModuleSource",
    "LazyToolsLoaded",
    "Framework",
    "Inventory",
    "Locale",
    "Locales",
    "GetTheme",
    "GetThemeCss",
    "Dialogue",
    "PropPlacer",
    "useGizmo",
    "GetBoundKey",
    "RegisterCommand",
    "RegisterKeybind",
    "AddInteraction",
    "AddInteractionsBatch",
    "CancelInteractionBatch",
    "BeginInteractionBulk",
    "CommitInteractionBulk",
    "RemoveInteraction",
    "UpdateInteraction",
    "RemoveAllInteractions",
    "GetClosestInteraction",
    "GetNearbyInteractions",
    "GetInteractionByEntity",
    "VersionCheck",
    "CreateZone",
    "CreateDuiPlacement",
    "CreateLaserTargetPlacement",
    "RegisterDuiSurface",
    "UpdateDuiSurface",
    "UnregisterDuiSurface",
    "ClearDuiSurfaces",
    "HasDuiPlacement",
    "GetDuiBoardCenter",
    "GetDuiTargetRadius",
    "ApplyPropDuiTexture",
    "UpdatePropDuiTexture",
    "ClearPropDuiTexture",
    "HasPropDuiTexture",
    "CreateTaskGroup",
    "AddToTaskGroup",
    "RemoveFromTaskGroup",
    "ClearTaskGroup",
    "DeleteTaskGroup",
    "IsInTaskGroup",
    "IsTaskGroupLeader",
    "GetTaskGroupLeader",
    "SetTaskGroupLeader",
    "GetTaskGroupMembers",
    "GetPlayerTaskGroups",
    "GetTaskGroupMemberCount",
    "GetLocalTaskGroups",
    "TaskGroups",
    "OpenTaskGroupMenu",
    "CloseTaskGroupMenu",
    "IsTaskGroupMenuOpen",
    "Notify",
    "Task",
    "CompleteTask",
}