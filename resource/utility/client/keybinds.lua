-- Resolves the display label for a registered key mapping / command binding.

local specialKeyLocales = {
    ['b_116'] = 'keys.scroll_up',
    ['b_115'] = 'keys.scroll_down',
    ['b_100'] = 'keys.lmb',
    ['b_101'] = 'keys.rmb',
    ['b_102'] = 'keys.mmb',
    ['b_103'] = 'keys.extra_1',
    ['b_104'] = 'keys.extra_2',
    ['b_105'] = 'keys.extra_3',
    ['b_106'] = 'keys.extra_4',
    ['b_107'] = 'keys.extra_5',
    ['b_108'] = 'keys.extra_6',
    ['b_109'] = 'keys.extra_7',
    ['b_110'] = 'keys.extra_8',
    ['b_1015'] = 'keys.alt_left',
    ['b_1000'] = 'keys.shift_left',
    ['b_2000'] = 'keys.space',
    ['b_1013'] = 'keys.control_left',
    ['b_1002'] = 'keys.tab',
    ['b_1014'] = 'keys.control_right',
    ['b_140'] = 'keys.numpad_4',
    ['b_142'] = 'keys.numpad_6',
    ['b_144'] = 'keys.numpad_8',
    ['b_141'] = 'keys.numpad_5',
    ['b_143'] = 'keys.numpad_7',
    ['b_145'] = 'keys.numpad_9',
    ['b_200'] = 'keys.insert',
    ['b_1012'] = 'keys.caps_lock',
    ['b_170'] = 'keys.f1',
    ['b_171'] = 'keys.f2',
    ['b_172'] = 'keys.f3',
    ['b_173'] = 'keys.f4',
    ['b_174'] = 'keys.f5',
    ['b_175'] = 'keys.f6',
    ['b_176'] = 'keys.f7',
    ['b_177'] = 'keys.f8',
    ['b_178'] = 'keys.f9',
    ['b_179'] = 'keys.f10',
    ['b_180'] = 'keys.f11',
    ['b_181'] = 'keys.f12',
    ['b_194'] = 'keys.arrow_up',
    ['b_195'] = 'keys.arrow_down',
    ['b_196'] = 'keys.arrow_left',
    ['b_197'] = 'keys.arrow_right',
    ['b_1003'] = 'keys.enter',
    ['b_1004'] = 'keys.backspace',
    ['b_198'] = 'keys.delete',
    ['b_199'] = 'keys.escape',
    ['b_1009'] = 'keys.page_up',
    ['b_1010'] = 'keys.page_down',
    ['b_1008'] = 'keys.home',
    ['b_131'] = 'keys.numpad_add',
    ['b_130'] = 'keys.numpad_subtract',
    ['b_211'] = 'keys.insert',
    ['b_210'] = 'keys.delete',
    ['b_212'] = 'keys.end',
    ['b_1055'] = 'keys.home',
    ['b_1056'] = 'keys.page_up',
}

local function translateKey(key)
    if not key or key == '' or key == 'NULL' then return nil end

    if key:sub(1, 2) == 't_' then
        return key:sub(3)
    end

    local localeKey = specialKeyLocales[key]
    if localeKey then
        return bridge.locale(localeKey)
    end

    return key
end

local function readInstructionalButton(commandName)
    local hashed = joaat(commandName) | 0x80000000
    local button = GetControlInstructionalButton(0, hashed, true)
    if button and button ~= '' and button ~= 'NULL' then return button end
    button = GetControlInstructionalButton(2, hashed, true)
    if button and button ~= '' and button ~= 'NULL' then return button end
    button = GetControlInstructionalButton(0, joaat(commandName), true)
    if button and button ~= '' and button ~= 'NULL' then return button end
    button = GetControlInstructionalButton(2, joaat(commandName), true)
    if button and button ~= '' and button ~= 'NULL' then return button end
end

local function getBoundKey(commandName)
    if type(commandName) ~= 'string' or commandName == '' then return nil end
    local button = readInstructionalButton(commandName)
    if (not button or button == '') and commandName:sub(1, 1) ~= '+' then
        button = readInstructionalButton('+' .. commandName)
    end
    return translateKey(button)
end

-- bridge.registerCommand / bridge.registerKeybind are defined in import.lua for
-- every client resource; the host just exposes them as exports here.
exports('RegisterCommand', bridge.registerCommand)
exports('RegisterKeybind', bridge.registerKeybind)
exports('GetBoundKey', getBoundKey)
