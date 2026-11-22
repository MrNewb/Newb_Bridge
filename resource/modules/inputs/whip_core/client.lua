-- whip_core input dialog. Whip's fields are label, type ('text', 'number', 'textarea', 'select', 'checkbox', 'password',
-- 'email', 'tel', 'url', 'date', 'time', 'color', 'range'), placeholder, default, required, min, max and options. The
-- bridge's ox_lib rows convert to them; a row type whip has no field for is shown as the closest one.

local inputs = {}

local TYPE_MAP = {
    input = 'text',
    number = 'number',
    checkbox = 'checkbox',
    toggle = 'checkbox',
    select = 'select',
    ['multi-select'] = 'select',
    slider = 'range',
    color = 'color',
    date = 'date',
    time = 'time',
    textarea = 'textarea',
}

local function convertRow(row)
    if type(row) == 'string' then return { label = row, type = 'text' } end

    local field = {
        label = row.label,
        type = TYPE_MAP[row.type] or 'text',
        placeholder = row.placeholder or row.description,
        default = row.default,
        required = row.required,
        min = row.min,
        max = row.max,
    }

    if row.password then field.type = 'password' end

    if type(row.options) == 'table' then
        field.options = {}
        for _, option in ipairs(row.options) do
            field.options[#field.options + 1] = { label = option.label or option.value, value = option.value }
        end
    end

    return field
end

function inputs.inputdialog(heading, rows)
    local fields = {}
    for index, row in ipairs(rows or {}) do
        fields[index] = convertRow(row)
    end

    local values = exports.whip_core:Input(heading, fields)
    if not values then return nil end
    return values
end

-- Whip closes its dialogs itself (cancel, timeout, or the resource stopping); there is no call to close one.
function inputs.closeinput() end

return inputs
