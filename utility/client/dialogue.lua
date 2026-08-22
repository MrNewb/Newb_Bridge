---@alias DialogueType 'info' | 'error' | 'success' | 'warning'

---@class DialogueMetadataEntry
---@field label string
---@field value? any
---@field progress? number
---@field colorScheme? string

---@class DialoguePedActionContext
---@field entity? number Target entity for the active dialogue session.
---@field ped? number Target ped when the dialogue target is a ped.
---@field sessionId string Active dialogue session id.
---@field menuId string Menu currently being shown.
---@field optionKey? string Option key when the action was triggered by a selection.
---@field args? any Option args when the action was triggered by a selection.
---@field inputValues? table<string, any> Current menu input values keyed by option key.
---@field inputValue? any Value for the selected option when it has an `input` field.
---@field source 'menu'|'option' Whether the action came from menu enter or option select.
---@field playSpeech fun(speech: string|DialogueSpeechOptions, param?: string): boolean Play speech on the target ped.
---@field playAnim fun(anim: DialogueAnimOptions): boolean Request the dict and play an animation on the target ped.

---@class DialogueSpeechOptions
---@field speech string Ambient speech name (e.g. `GENERIC_HI`).
---@field param? string Speech params. Default `SPEECH_PARAMS_FORCE`.

---@class DialogueAnimOptions
---@field dict string Animation dictionary.
---@field clip string Animation clip.
---@field flag? number TaskPlayAnim flag. Default `48` (upper body, play once). Use `49` to loop (`1` = repeat).
---@field duration? number Default `-1` (full clip). Set ms to force a cutoff.
---@field blendIn? number Default `8.0`.
---@field blendOut? number Default `-8.0`.
---@field playbackRate? number Default `0.0`.

---@class DialogueInputSelectOption
---@field value string
---@field label? string
---@field description? string

---@class DialogueInputField
---@field type 'input'|'number'|'checkbox'|'select'|'multi-select'|'slider'|'textarea'
---@field label string
---@field description? string
---@field placeholder? string
---@field icon? string
---@field required? boolean
---@field disabled? boolean
---@field default? any Default value.
---@field password? boolean Only for `input`.
---@field min? number Minimum for numeric types or textarea row count.
---@field max? number Maximum for numeric types or textarea row count.
---@field precision? number Only for `number`.
---@field step? number For `number` and `slider`.
---@field checked? boolean Alias for checkbox default.
---@field options? DialogueInputSelectOption[]|table For `select` and `multi-select`.
---@field searchable? boolean Reserved for future UI.
---@field maxSelectedValues? number Only for `multi-select`.
---@field autosize? boolean Only for `textarea`.
---@field minLength? number Minimum string length for `input` and `textarea`.
---@field maxLength? number Maximum string length for `input` and `textarea`.

---@class DialogueOptionItem
---@field item string Item name passed to `bridge.inventory.hasItem`.
---@field count? number Required count. Defaults to `1`.
---@field metadata? table Optional metadata filter passed to `bridge.inventory.hasItem`.

---@class DialogueOption
---@field title? string Required unless the option only defines `input`.
---@field input? DialogueInputField Inline input control for this option row.
---@field description? string
---@field disabled? boolean
---@field readOnly? boolean
---@field item? string|DialogueOptionItem When set, the option is only shown if `bridge.inventory.hasItem` passes when the menu is built (open, navigation, or `RefreshMenu`). Not sent to NUI.
---@field menu? string Registered menu id to open when selected.
---@field onSelect? fun(args: any) Called when selected. `args` may include `inputValues`, `inputValue`, and option `args`.
---@field icon? string Font Awesome icon name or image URL.
---@field iconColor? string
---@field iconAnimation? 'spin'|'spinPulse'|'spinReverse'|'pulse'|'beat'|'fade'|'beatFade'|'bounce'|'shake'
---@field progress? number Progress bar value from `0` to `100`.
---@field colorScheme? string Mantine-style color scheme key for the option chip.
---@field arrow? boolean Show a submenu arrow. Defaults to `true` for submenu/input-action rows.
---@field image? string Optional image URL shown beside the option label.
---@field metadata? DialogueMetadataEntry[]|table<string, any>|string[] Extra rows rendered under the option label.
---@field event? string Client event triggered when selected. Closes the session after firing.
---@field serverEvent? string Server event triggered when selected. Closes the session after firing.
---@field args? any Merged into the payload for `onSelect`, `event`, and `serverEvent`.
---@field type? DialogueType Semantic color (`info`, `success`, `warning`, `error`). Omit for neutral styling.
---@field speech? string|DialogueSpeechOptions Optional ambient speech when the option is selected.
---@field param? string Optional speech params when `speech` is a string.
---@field anim? DialogueAnimOptions Optional animation when the option is selected.
---@field custom? fun(entity: number|nil, context: DialoguePedActionContext) Optional custom target action when the option is selected. `entity` is nil for coord-only targets.

---@class DialogueStyle

---@class DialogueMenu
---@field id? string Auto-generated via `lib.uuid.generate()` when omitted during registration.
---@field title string
---@field description? string Optional subtitle shown under the title (role, traits, etc.).
---@field image? string Optional image URL (`nui://`, `https://`, or path ending in `.png`/`.webp`/etc.).
---@field text? string Optional body copy shown above options (NPC dialogue).
---@field typewriter? boolean When `true`, body text types out before options appear. Defaults to `false`.
---@field menu? string Registered parent menu id shown via the back button.
---@field onEnter? fun() Called when this menu is pushed onto the stack (initial open or submenu navigation).
---@field onExit? fun() Called when the session closes. Only the root menu passed to `OpenMenu` supplies the session `onExit`.
---@field onBack? fun() Called when the back button is pressed, before navigating to the parent menu.
---@field options DialogueOption[]|table<string, DialogueOption> Array or string-keyed map of options.
---@field speech? string|DialogueSpeechOptions Optional ambient speech when the menu is entered.
---@field param? string Optional speech params when `speech` is a string.
---@field anim? DialogueAnimOptions Optional animation when the menu is entered.
---@field custom? fun(entity: number|nil, context: DialoguePedActionContext) Optional custom target action when the menu is entered. `entity` is nil for coord-only targets.
---@field style? DialogueStyle Optional per-menu CSS overrides.
---@field resource? string Set at registration to the invoking resource; the menu is dropped when that resource stops.

---@class DialogueRotationOptions
---@field x? number Pitch.
---@field y? number Roll.
---@field z? number Yaw.

---@class DialogueTargetOptions : DialogueRotationOptions
---@field ped? number Ped entity handle used for camera framing and ped actions.
---@field entity? number Entity handle used for camera framing and ped actions.
---@field object? number Prop/object entity handle.
---@field coords? vector3|vector4 World position used when no entity is provided.
---@field x? number Used with `y`/`z` when `coords` is omitted.
---@field y? number
---@field z? number
---@field heading? number Optional forward facing for camera placement.
---@field rotation? vector3|DialogueRotationOptions Optional full camera rotation override.
---@field camForward? number Optional distance in front of the target along its forward vector. Default `1.2`.
---@field camHeight? number Optional height added to the camera position. Default `0.52`.
---@field camRotZOffset? number Optional yaw offset when rotation is not fully overridden. Default `181.0`.
---@field camFov? number Optional camera field of view. Defaults to gameplay cam FOV.
---@field maxDistance? number Max distance from the player before `OpenMenu` is blocked. Default `5.0`.

---@class Dialogue
local Dialogue = {}

local menus = {}
local sessions = {}
local activeId ---@type string|nil
local pendingCamDestroy = false
local cam ---@type number|nil
local playerHidden = false

local function hidePlayer()
    if playerHidden then return end

    SetEntityAlpha(cache.ped, 0, true)
    playerHidden = true
end

local function showPlayer()
    if not playerHidden then return end

    ResetEntityAlpha(cache.ped)
    playerHidden = false
end

local function isArray(tbl)
    if type(tbl) ~= 'table' then return false end

    local length = 0
    for key in pairs(tbl) do
        if type(key) ~= 'number' then
            return false
        end
        length = length + 1
    end

    return length > 0
end

local function parseSpeech(value, fallbackParam)
    if type(value) == 'string' and value ~= '' then
        return { speech = value, param = fallbackParam or 'SPEECH_PARAMS_FORCE' }
    end

    if type(value) == 'table' and type(value.speech) == 'string' and value.speech ~= '' then
        return { speech = value.speech, param = value.param or fallbackParam or 'SPEECH_PARAMS_FORCE' }
    end
end

local function parseAnim(value)
    if type(value) ~= 'table' then return end
    if not value.dict or not value.clip then return end

    return {
        dict = value.dict,
        clip = value.clip,
        flag = value.flag or 48,
        duration = value.duration or -1,
        blendIn = value.blendIn or 8.0,
        blendOut = value.blendOut or -8.0,
        playbackRate = value.playbackRate or 0.0,
    }
end

local function loadAnimDict(session, dict)
    if not dict or dict == '' then return false end

    local wasLoaded = HasAnimDictLoaded(dict)
    if not lib.requestAnimDict(dict) then return false end

    if session and not wasLoaded then
        session.animDicts = session.animDicts or {}
        session.animDicts[dict] = true
    end

    return true
end

local function unloadAnimDicts(session)
    if not session or not session.animDicts then return end

    for dict in pairs(session.animDicts) do
        RemoveAnimDict(dict)
    end

    session.animDicts = nil
end

local function stopAnim(session)
    if not session or not session.animId then return end

    if Anim and Anim.Stop then
        Anim.Stop(session.animId)
    end

    session.animId = nil
end

local function playAnim(ped, anim, animId, skipDictRequest)
    if not ped or not anim then return false end
    if not skipDictRequest and not lib.requestAnimDict(anim.dict) then return false end

    if Anim and Anim.Play then
        Anim.Play(animId, ped, anim.dict, anim.clip, anim.blendIn, anim.blendOut, anim.duration, anim.flag, anim.playbackRate)
        return true
    end

    TaskPlayAnim(ped, anim.dict, anim.clip, anim.blendIn, anim.blendOut, anim.duration, anim.flag, anim.playbackRate, false, false, false)
    return true
end

local function startSessionAnim(session, ped, anim)
    if not session or not ped or not anim then return false end

    stopAnim(session)
    session.animId = ('dialogue:%s'):format(session.id)
    if not loadAnimDict(session, anim.dict) then return false end
    return playAnim(ped, anim, session.animId, true)
end

local function hasRequiredItem(requirement)
    if not requirement then return true end

    local item, count, metadata
    if type(requirement) == 'string' then
        item = requirement
    elseif type(requirement) == 'table' and type(requirement.item) == 'string' then
        item, count, metadata = requirement.item, requirement.count, requirement.metadata
    end

    if not item then return true end

    local inventory = bridge.inventory
    if type(inventory) ~= 'table' or type(inventory.hasItem) ~= 'function' then
        return false
    end

    return inventory.hasItem(item, count, metadata) == true
end

local function toNuiOption(option, optionKey)
    return {
        key = optionKey,
        title = option.title or (option.input and option.input.label) or optionKey,
        description = option.description,
        disabled = option.disabled == true,
        readOnly = option.readOnly == true,
        menu = option.menu,
        icon = option.icon,
        iconColor = option.iconColor,
        iconAnimation = option.iconAnimation,
        progress = option.progress,
        colorScheme = option.colorScheme,
        arrow = option.arrow,
        image = option.image,
        metadata = option.metadata,
        input = option.input,
        selectable = option.menu ~= nil
            or option.onSelect ~= nil
            or option.event ~= nil
            or option.serverEvent ~= nil,
        type = option.type,
    }
end

local function buildOptions(options)
    local handlers = {}
    local nuiOptions = {}

    local function addOption(optionKey, option)
        if type(option) ~= 'table' then return end
        if not hasRequiredItem(option.item) then return end

        handlers[optionKey] = {
            onSelect = option.onSelect,
            event = option.event,
            serverEvent = option.serverEvent,
            args = option.args,
            menu = option.menu,
            disabled = option.disabled == true,
            readOnly = option.readOnly == true,
            speech = option.speech,
            param = option.param,
            anim = option.anim,
            custom = option.custom,
        }

        nuiOptions[#nuiOptions + 1] = toNuiOption(option, optionKey)
    end

    if isArray(options) then
        for index, option in ipairs(options) do
            addOption(tostring(index), option)
        end
    elseif type(options) == 'table' then
        for key, option in pairs(options) do
            addOption(tostring(key), option)
        end
    end

    return nuiOptions, handlers
end

local function destroyCamera()
    if cam then
        RenderScriptCams(false, true, 900, true, false)
        SetCamActive(cam, false)
        DestroyCam(cam, false)
        cam = nil
    end

    showPlayer()
end

local function parseCoords(value)
    if not value then return end

    if type(value) == 'vector3' then
        return value, nil
    end

    if type(value) == 'vector4' then
        return vector3(value.x, value.y, value.z), value.w
    end

    if type(value) == 'table' then
        if value.coords then
            local coords, heading = parseCoords(value.coords)
            if coords then return coords, value.heading or heading end
        end

        if value.x and value.y and value.z then
            return vector3(value.x, value.y, value.z), value.heading or value.w
        end
    end
end

local function resolveTarget(target)
    if not target then return end

    if type(target) == 'number' then
        if DoesEntityExist(target) then
            return { type = 'entity', entity = target }
        end
        return
    end

    if type(target) == 'vector3' or type(target) == 'vector4' then
        local coords, heading = parseCoords(target)
        if coords then
            return { type = 'coords', coords = coords, heading = heading }
        end
        return
    end

    if type(target) == 'table' then
        local entity = target.ped or target.entity or target.object

        if entity and DoesEntityExist(entity) then
            return { type = 'entity', entity = entity }
        end

        local coords, heading = parseCoords(target)
        if coords then
            return { type = 'coords', coords = coords, heading = target.heading or heading }
        end
    end
end

local function targetCoords(target)
    if not target then return end
    if target.type == 'entity' then return GetEntityCoords(target.entity, true) end
    if target.type == 'coords' then return target.coords end
end

local function headingToForward(heading)
    local radians = math.rad(heading)
    return -math.sin(radians), math.cos(radians)
end

local function parseRotation(value)
    if not value then return end
    if type(value) == 'vector3' then return { x = value.x, y = value.y, z = value.z } end
    if type(value) == 'table' then
        return { x = value.x or value[1] or 0.0, y = value.y or value[2] or 0.0, z = value.z or value[3] or 0.0 }
    end
end

local function cameraOptions(target)
    local options = { forward = 1.2, height = 0.52, rotZOffset = 181.0 }

    if type(target) ~= 'table' then return options end

    if target.camForward then options.forward = target.camForward end
    if target.camHeight then options.height = target.camHeight end
    if target.camRotZOffset then options.rotZOffset = target.camRotZOffset end
    if target.heading then options.heading = target.heading end

    options.fov = target.camFov
    options.rotation = parseRotation(target.rotation)

    return options
end

local function inRange(target)
    local resolved = resolveTarget(target)
    if not resolved then return true end

    local coords = targetCoords(resolved)
    if not coords then return true end

    local maxDistance = type(target) == 'table' and target.maxDistance or 5.0
    return #(GetEntityCoords(cache.ped) - coords) <= maxDistance
end

local function sessionEntity(session)
    if not session then return end

    local resolved = resolveTarget(session.target)
    if not resolved or resolved.type ~= 'entity' then return end

    if DoesEntityExist(resolved.entity) then
        return resolved.entity
    end
end

local function sessionPed(session)
    local entity = sessionEntity(session)
    if entity and IsEntityAPed(entity) then
        return entity
    end
end

local function buildContext(session, source, optionKey, args, inputValues, inputValue)
    local entity = sessionEntity(session)
    local context = {
        entity = entity,
        ped = entity and IsEntityAPed(entity) and entity or nil,
        sessionId = session.id,
        menuId = session.menuId,
        optionKey = optionKey,
        args = args,
        inputValues = inputValues,
        inputValue = inputValue,
        source = source,
    }

    function context.playSpeech(speechValue, param)
        local ped = context.ped or sessionPed(session)
        if not ped then return false end

        local speech = parseSpeech(speechValue, param)
        if not speech then return false end

        PlayPedAmbientSpeechNative(ped, speech.speech, speech.param)
        return true
    end

    function context.playAnim(animValue)
        local ped = context.ped or sessionPed(session)
        local anim = parseAnim(animValue)
        if not ped or not anim then return false end

        return startSessionAnim(session, ped, anim)
    end

    return context
end

local function runPedActions(session, source, actions, optionKey, args, inputValues, inputValue)
    if type(actions) ~= 'table' then return end

    local context = buildContext(session, source, optionKey, args, inputValues, inputValue)
    local ped = context.ped

    if ped then
        local speech = parseSpeech(actions.speech, actions.param)
        if speech then
            PlayPedAmbientSpeechNative(ped, speech.speech, speech.param)
        end

        local anim = parseAnim(actions.anim)
        if anim then
            startSessionAnim(session, ped, anim)
        end
    end

    if type(actions.custom) == 'function' then
        actions.custom(context.entity, context)
    end
end

local function stopPedActions(session)
    if not session then return end

    local ped = sessionPed(session)
    if ped then StopCurrentPlayingAmbientSpeech(ped) end

    stopAnim(session)
    unloadAnimDicts(session)
end

local function cameraTransform(target, camera)
    local coords, forwardX, forwardY, rotX, rotY, rotZ

    if target.type == 'entity' then
        local entity = target.entity
        coords = GetEntityCoords(entity, true)

        if camera.heading then
            forwardX, forwardY = headingToForward(camera.heading)
        else
            forwardX = GetEntityForwardX(entity)
            forwardY = GetEntityForwardY(entity)
        end

        if camera.rotation then
            rotX, rotY, rotZ = camera.rotation.x, camera.rotation.y, camera.rotation.z
        else
            local rotation = GetEntityRotation(entity, 2)
            rotX, rotY = rotation.x, rotation.y
            rotZ = rotation.z + camera.rotZOffset
        end
    else
        coords = target.coords
        local heading = camera.heading or target.heading

        -- no heading anywhere: face the camera back toward the player
        if not heading then
            local playerCoords = GetEntityCoords(cache.ped)
            heading = GetHeadingFromVector_2d(playerCoords.x - coords.x, playerCoords.y - coords.y)
        end

        forwardX, forwardY = headingToForward(heading)

        if camera.rotation then
            rotX, rotY, rotZ = camera.rotation.x, camera.rotation.y, camera.rotation.z
        else
            rotX, rotY = 0.0, 0.0
            rotZ = heading + camera.rotZOffset
        end
    end

    return coords, forwardX, forwardY, rotX, rotY, rotZ
end

local function setupCamera(target)
    local resolved = resolveTarget(target)
    if not resolved then return end

    local camera = cameraOptions(target)
    pendingCamDestroy = false

    local coords, forwardX, forwardY, rotX, rotY, rotZ = cameraTransform(resolved, camera)
    local x = coords.x + forwardX * camera.forward
    local y = coords.y + forwardY * camera.forward
    local z = coords.z + camera.height

    if cam then
        SetCamActive(cam, false)
        DestroyCam(cam, false)
        cam = nil
    end

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', x, y, z, rotX, rotY, rotZ, camera.fov or GetGameplayCamFov(), false, 0)

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 900, true, true)
    hidePlayer()
end

local function closeSession(sessionId, cancelled)
    local session = sessions[sessionId]
    if not session then return end

    stopPedActions(session)
    sessions[sessionId] = nil

    if activeId == sessionId then
        activeId = nil
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close', sessionId = sessionId })

    -- wait out the 900ms camera blend, and only destroy if nothing reopened meanwhile
    pendingCamDestroy = true
    CreateThread(function()
        Wait(1000)
        if pendingCamDestroy and not activeId then
            destroyCamera()
        end
    end)

    if cancelled and session.onExit then
        session.onExit()
    end
end

local localeCache ---@type table<string, string>|nil

local function dialogueLocales()
    if localeCache then return localeCache end

    localeCache = {
        back = bridge.locale('dialogue.back'),
        options_group = bridge.locale('dialogue.options_group'),
        dialog = bridge.locale('dialogue.dialog'),
        menu_portrait = bridge.locale('dialogue.menu_portrait'),
        menu_portrait_default = bridge.locale('dialogue.menu_portrait_default'),
        validation_fix_fields = bridge.locale('dialogue.validation_fix_fields'),
        processing = bridge.locale('dialogue.processing'),
        input_yes = bridge.locale('dialogue.input.yes'),
        input_no = bridge.locale('dialogue.input.no'),
        input_none_selected = bridge.locale('dialogue.input.none_selected'),
        input_arrow_step_hint = bridge.locale('dialogue.input.arrow_step_hint'),
        input_choose = bridge.locale('dialogue.input.choose'),
        input_selected_count = bridge.locale('dialogue.input.selected_count'),
        input_choose_aria = bridge.locale('dialogue.input.choose_aria'),
        input_max_selected = bridge.locale('dialogue.input.max_selected'),
        input_decrease_aria = bridge.locale('dialogue.input.decrease_aria'),
        input_increase_aria = bridge.locale('dialogue.input.increase_aria'),
        input_previous_aria = bridge.locale('dialogue.input.previous_aria'),
        input_next_aria = bridge.locale('dialogue.input.next_aria'),
        input_open_options_aria = bridge.locale('dialogue.input.open_options_aria'),
        input_remove_aria = bridge.locale('dialogue.input.remove_aria'),
        progress_named = bridge.locale('dialogue.progress_named'),
        progress_complete = bridge.locale('dialogue.progress_complete'),
        input_validation_required = bridge.locale('dialogue.input.validation.required'),
        input_validation_min_length = bridge.locale('dialogue.input.validation.min_length'),
        input_validation_max_length = bridge.locale('dialogue.input.validation.max_length'),
        input_validation_number = bridge.locale('dialogue.input.validation.number'),
        input_validation_min_value = bridge.locale('dialogue.input.validation.min_value'),
        input_validation_max_value = bridge.locale('dialogue.input.validation.max_value'),
    }

    return localeCache
end

local function renderMenu(session, menuDef, pushToStack)
    session.menuId = menuDef.id

    if pushToStack then
        session.menuStack[#session.menuStack + 1] = menuDef.id
    elseif #session.menuStack > 0 then
        session.menuStack[#session.menuStack] = menuDef.id
    else
        session.menuStack[1] = menuDef.id
    end

    local nuiOptions, handlers = buildOptions(menuDef.options)
    session.handlers = handlers

    SendNUIMessage({
        type = 'open',
        sessionId = session.id,
        menuId = menuDef.id,
        title = menuDef.title,
        description = menuDef.description,
        image = menuDef.image,
        text = menuDef.text,
        typewriter = menuDef.typewriter == true,
        menu = menuDef.menu,
        canGoBack = menuDef.menu ~= nil or #session.menuStack > 1,
        options = nuiOptions,
        style = type(menuDef.style) == 'table' and menuDef.style or nil,
        locales = dialogueLocales(),
    })

    if pushToStack then
        runPedActions(session, 'menu', menuDef)

        if menuDef.onEnter then
            menuDef.onEnter()
        end
    end
end

local function refreshIfOpen(menuId)
    local session = activeId and sessions[activeId]
    if not session or session.menuId ~= menuId then return end

    local menuDef = menus[menuId]
    if menuDef then
        renderMenu(session, menuDef, false)
    end
end

local function openSession(menuDef, target)
    if not inRange(target) then return end

    if activeId then
        closeSession(activeId, true)
    end

    pendingCamDestroy = false

    local sessionId = menuDef.id
    activeId = sessionId

    sessions[sessionId] = {
        id = sessionId,
        menuId = menuDef.id,
        menuStack = {},
        target = target,
        onExit = menuDef.onExit,
    }

    setupCamera(target)
    renderMenu(sessions[sessionId], menuDef, true)
    SetNuiFocus(true, true)
end

local function findOption(menu, optionKey)
    local options = menu.options
    if not options then return end

    if isArray(options) then
        return options[tonumber(optionKey)], tonumber(optionKey)
    end

    return options[optionKey], optionKey
end

local function canEnterMenu(session, menuId)
    if not menuId or not menus[menuId] then return false end

    for i = 1, #session.menuStack do
        if session.menuStack[i] == menuId then return true end
    end

    local handlers = session.handlers
    if handlers then
        for _, handler in pairs(handlers) do
            if handler.menu == menuId then return true end
        end
    end

    local current = menus[session.menuId]
    return current ~= nil and current.menu == menuId
end

local function enterMenu(session, menuId)
    if not canEnterMenu(session, menuId) then return end

    local menuDef = menus[menuId]
    if not menuDef then return end

    renderMenu(session, menuDef, true)
end

local function goBack(session)
    local currentMenu = menus[session.menuId]

    if currentMenu and currentMenu.onBack then
        currentMenu.onBack()
    end

    -- explicit parent link wins over the navigation stack
    if currentMenu and currentMenu.menu then
        local parentMenu = menus[currentMenu.menu]
        if parentMenu then
            if #session.menuStack > 0 then
                table.remove(session.menuStack)
            end
            renderMenu(session, parentMenu, false)
            return
        end
    end

    if #session.menuStack > 1 then
        table.remove(session.menuStack)
        local previousMenu = menus[session.menuStack[#session.menuStack]]
        if previousMenu then
            renderMenu(session, previousMenu, false)
        end
    end
end

local function buildArgs(handlerArgs, inputValues, inputValue)
    local args = {}

    if type(handlerArgs) == 'table' then
        for key, value in pairs(handlerArgs) do
            args[key] = value
        end
    end

    if type(inputValues) == 'table' then
        args.inputValues = inputValues
    end

    if inputValue ~= nil then
        args.inputValue = inputValue
    end

    return args
end

local function selectOption(sessionId, optionKey, inputValues, inputValue)
    local session = sessions[sessionId]
    if not session then return end

    local handler = session.handlers[optionKey]
    if not handler or handler.disabled or handler.readOnly then return end

    local args = buildArgs(handler.args, inputValues, inputValue)
    runPedActions(session, 'option', handler, optionKey, args, inputValues, inputValue)

    if handler.menu then
        session.navigationArgs = args
        enterMenu(session, handler.menu)
        return
    end

    if handler.onSelect then
        handler.onSelect(args)
    end

    if handler.event then
        TriggerEvent(handler.event, args)
    end

    if handler.serverEvent then
        TriggerServerEvent(handler.serverEvent, args)
    end

    closeSession(sessionId, false)
end

---@param menu DialogueMenu
---@return string id The menu id (provided or auto-generated).
function Dialogue.RegisterMenu(menu)
    assert(menu, 'Menu is required')
    assert(menu.title, 'Menu title is required')
    assert(menu.options, 'Menu options are required')

    if not menu.id or menu.id == '' then
        menu.id = lib.uuid.generate()
    end

    -- owner tag so menus die with the resource that registered them instead of
    -- lingering with dead callback refs
    menu.resource = GetInvokingResource() or cache.resource

    menus[menu.id] = menu
    return menu.id
end

---@param id string
---@return boolean removed
function Dialogue.UnregisterMenu(id)
    if not menus[id] then return false end

    menus[id] = nil
    return true
end

---@param id string
---@param updates DialogueMenu|table
---@return boolean updated
function Dialogue.UpdateMenu(id, updates)
    local menu = menus[id]
    if not menu or type(updates) ~= 'table' then return false end

    for key, value in pairs(updates) do
        if key ~= 'id' then
            menu[key] = value
        end
    end

    refreshIfOpen(id)
    return true
end

---@param id string
---@param optionKey string|number
---@param updates DialogueOption
---@return boolean updated
function Dialogue.SetMenuOption(id, optionKey, updates)
    local menu = menus[id]
    if not menu or type(updates) ~= 'table' then return false end

    local option, resolvedKey = findOption(menu, tostring(optionKey))
    if not option then return false end

    for key, value in pairs(updates) do
        option[key] = value
    end

    if menu.options and not isArray(menu.options) then
        menu.options[resolvedKey] = option
    end

    refreshIfOpen(id)
    return true
end

---@param id string
---@param optionKey string|number
---@return boolean removed
function Dialogue.RemoveMenuOption(id, optionKey)
    local menu = menus[id]
    if not menu or not menu.options then return false end

    local options = menu.options
    local key = tostring(optionKey)

    if isArray(options) then
        local index = tonumber(key)
        if not index or not options[index] then
            return false
        end
        table.remove(options, index)
    else
        if options[key] == nil then
            return false
        end
        options[key] = nil
    end

    refreshIfOpen(id)
    return true
end

---@param id string
---@return boolean refreshed
function Dialogue.RefreshMenu(id)
    if not menus[id] then return false end

    refreshIfOpen(id)
    return true
end

---@param id string
---@return DialogueMenu|nil
function Dialogue.GetMenu(id)
    return menus[id]
end

---@param id string
---@param target? number|vector3|vector4|DialogueTargetOptions Entity handle, coords, or target options for distance/camera.
function Dialogue.OpenMenu(id, target)
    local menuDef = menus[id]
    assert(menuDef, ('Dialogue menu "%s" is not registered'):format(id))

    openSession(menuDef, target)
end

---@return table|nil
function Dialogue.GetNavigationArgs()
    local session = activeId and sessions[activeId]
    if not session then return end

    local args = session.navigationArgs
    session.navigationArgs = nil
    return args
end

---@param sessionId string
function Dialogue.Close(sessionId)
    closeSession(sessionId, true)
end

---@param ped number
---@param speech string|DialogueSpeechOptions
---@param param? string
---@return boolean played
function Dialogue.PlayPedSpeech(ped, speech, param)
    if not ped or not DoesEntityExist(ped) or not IsEntityAPed(ped) then return false end

    local config = parseSpeech(speech, param)
    if not config then return false end

    PlayPedAmbientSpeechNative(ped, config.speech, config.param)
    return true
end

---@param ped number
---@param anim DialogueAnimOptions
---@param animId? string Optional Anim module tracking id.
---@return boolean played
function Dialogue.PlayPedAnim(ped, anim, animId)
    if not ped or not DoesEntityExist(ped) or not IsEntityAPed(ped) then return false end

    local config = parseAnim(anim)
    if not config then return false end

    return playAnim(ped, config, animId)
end

RegisterNuiCallback('dialogue:selectOption', function(data, cb)
    if data and data.sessionId and data.optionKey then
        selectOption(data.sessionId, data.optionKey, data.inputValues, data.inputValue)
    end
    cb({ ok = true })
end)

RegisterNuiCallback('dialogue:navigate', function(data, cb)
    local session = data and sessions[data.sessionId]
    -- new submenus go through selectOption so option handlers run; navigate only
    -- revisits menus already on the session stack
    if session and data.menuId then
        local onStack = false
        for i = 1, #session.menuStack do
            if session.menuStack[i] == data.menuId then
                onStack = true
                break
            end
        end
        if onStack then
            local menuDef = menus[data.menuId]
            if menuDef then
                renderMenu(session, menuDef, false)
            end
        end
    end
    cb({ ok = true })
end)

RegisterNuiCallback('dialogue:back', function(data, cb)
    local session = data and sessions[data.sessionId]
    if session then
        goBack(session)
    end
    cb({ ok = true })
end)

RegisterNuiCallback('dialogue:close', function(data, cb)
    if data and data.sessionId then
        closeSession(data.sessionId, true)
    end
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if cache.resource ~= resource then
        local removed = {}
        for id, menu in pairs(menus) do
            if menu.resource == resource then
                menus[id] = nil
                removed[id] = true
            end
        end

        -- close sessions whose root or current menu died; onExit comes from the
        -- root menu so only drop it when the root owner stopped
        for sessionId, session in pairs(sessions) do
            if removed[session.id] or removed[session.menuId] then
                if removed[session.id] then
                    session.onExit = nil
                end
                closeSession(sessionId, true)
            end
        end
        return
    end

    for sessionId in pairs(sessions) do
        closeSession(sessionId, true)
    end
end)

exports('Dialogue', function()
    return Dialogue
end)
