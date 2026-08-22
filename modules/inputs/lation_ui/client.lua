local inputs = {}

local function normalizeOption(option)
    if type(option) ~= 'table' then
        return option
    end

    return {
        value = option.value,
        label = option.label,
        disable = option.disabled or option.disable,
    }
end

local function normalizeField(row)
    if type(row) == 'string' then
        return {
            type = 'input',
            label = row,
        }
    end

    local fieldType = row.type == 'multi-select' and 'multi-select' or row.type

    local field = {
        type = fieldType or 'input',
        label = row.label,
        description = row.description,
        placeholder = row.placeholder,
        icon = row.icon,
        iconColor = row.iconColor,
        required = row.required,
        disabled = row.disabled,
        default = row.default,
        min = row.min,
        max = row.max,
        step = row.step,
        password = row.password,
        unit = row.unit,
        format = row.format,
        clearable = row.clearable,
        searchable = row.searchable,
    }

    if row.type == 'checkbox' or row.type == 'toggle' then
        field.type = 'checkbox'
        field.default = row.default
        if field.default == nil then
            field.default = row.checked
        end
    elseif row.type == 'select' or row.type == 'multi-select' then
        field.options = {}
        for index, option in ipairs(row.options or {}) do
            field.options[index] = normalizeOption(option)
        end
    elseif row.type == 'date-range' and row.default and row.default[1] and row.default[2] then
        field.default = { row.default[1], row.default[2] }
    end

    return field
end

function inputs.inputdialog(heading, rows, options)
    local normalizedRows = {}
    local dialogOptions = options or {}

    for index, row in ipairs(rows or {}) do
        normalizedRows[index] = normalizeField(row)
    end

    return exports.lation_ui:input({
        title = heading,
        options = normalizedRows,
        cancel = dialogOptions.allowCancel ~= false,
    })
end

function inputs.closeinput()
    return exports.lation_ui:closeInput()
end

return inputs