export const INPUT_TYPES = new Set([
  'input',
  'number',
  'checkbox',
  'select',
  'multi-select',
  'slider',
  'textarea',
])

function toNumber(value, fallback = null) {
  if (typeof value === 'number' && !Number.isNaN(value)) return value
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value)
    if (!Number.isNaN(parsed)) return parsed
  }
  return fallback
}

function roundToPrecision(value, precision) {
  if (typeof precision !== 'number' || precision < 0) return value
  const factor = 10 ** precision
  return Math.round(value * factor) / factor
}

export function normalizeSelectOptions(options) {
  if (!options) return []

  const entries = Array.isArray(options)
    ? options.map((entry, index) => [String(index), entry])
    : typeof options === 'object'
      ? Object.entries(options)
      : []

  return entries
    .map(([fallbackValue, entry]) => {
      if (typeof entry === 'string') {
        return { value: entry, label: entry, description: null }
      }

      if (!entry || typeof entry !== 'object') return null

      const value = entry.value ?? entry.id ?? fallbackValue
      const label = typeof entry.label === 'string'
        ? entry.label.trim()
        : typeof entry.title === 'string'
          ? entry.title.trim()
          : String(value)

      return {
        value: String(value),
        label,
        description: typeof entry.description === 'string' ? entry.description.trim() : null,
      }
    })
    .filter(Boolean)
}

export function sanitizeTextValue(value, input) {
  const text = value === null || value === undefined ? '' : String(value)
  if (typeof input.maxLength === 'number' && input.maxLength >= 0) {
    return text.slice(0, input.maxLength)
  }
  return text
}

const NUMBER_DRAFT_PATTERN = /^-?\d*\.?\d*$/

export function isNumberDraft(value) {
  if (value === null || value === undefined) return false
  if (typeof value === 'number') return false
  const text = String(value)
  if (text === '' || text === '-') return true
  return NUMBER_DRAFT_PATTERN.test(text)
}

export function sanitizeNumberDraft(value) {
  const text = value === null || value === undefined ? '' : String(value)
  if (text === '' || text === '-') return text
  const match = text.match(/^-?\d*\.?\d*/)
  return match ? match[0] : ''
}

export function formatNumberFieldValue(value) {
  if (value === null || value === undefined) return ''
  if (isNumberDraft(value)) return String(value)
  return String(value)
}

export function sanitizeNumberValue(value, input) {
  const parsed = toNumber(value, null)
  if (parsed === null) {
    return typeof input.min === 'number' ? input.min : 0
  }
  return clampNumericValue(parsed, input)
}

export function coerceInputValue(value, input) {
  if (!input) return value

  switch (input.type) {
    case 'input':
    case 'textarea':
      return sanitizeTextValue(value, input)
    case 'number':
      return isNumberDraft(value) ? sanitizeNumberDraft(value) : sanitizeNumberValue(value, input)
    case 'slider':
      return sanitizeNumberValue(value, input)
    default:
      return value
  }
}

export function getInputValidationError(value, input, locales = DEFAULT_INPUT_LOCALES) {
  if (!input || input.disabled) return null
  const label = input.label

  if (input.type === 'input' || input.type === 'textarea') {
    const text = value === null || value === undefined ? '' : String(value)

    if (input.required && !text.trim()) {
      return formatInputLocale(locales.validation_required, { label })
    }

    if (typeof input.minLength === 'number' && text.length < input.minLength) {
      return formatInputLocale(locales.validation_min_length, { label, min: input.minLength })
    }

    if (typeof input.maxLength === 'number' && text.length > input.maxLength) {
      return formatInputLocale(locales.validation_max_length, { label, max: input.maxLength })
    }

    return null
  }

  if (input.type === 'number' || input.type === 'slider') {
    if (input.type === 'number' && isNumberDraft(value)) {
      const draft = String(value)
      if (draft === '' || draft === '-') {
        return input.required ? formatInputLocale(locales.validation_required, { label }) : null
      }
    }

    const parsed = toNumber(value, null)

    if (parsed === null || !Number.isFinite(parsed)) {
      return formatInputLocale(locales.validation_number, { label })
    }

    if (typeof input.min === 'number' && parsed < input.min) {
      return formatInputLocale(locales.validation_min_value, { label, min: input.min })
    }

    if (typeof input.max === 'number' && parsed > input.max) {
      return formatInputLocale(locales.validation_max_value, { label, max: input.max })
    }

    return null
  }

  if (input.required && input.type === 'select' && (value === null || value === undefined || value === '')) {
    return formatInputLocale(locales.validation_required, { label })
  }

  if (input.required && input.type === 'checkbox' && !value) {
    return formatInputLocale(locales.validation_required, { label })
  }

  if (input.required && input.type === 'multi-select') {
    const selected = Array.isArray(value) ? value : []
    if (!selected.length) return formatInputLocale(locales.validation_required, { label })
  }

  return null
}

export function getMenuInputErrors(options, values, locales = DEFAULT_INPUT_LOCALES) {
  const errors = {}

  options.forEach((option) => {
    if (!option.input) return
    const error = getInputValidationError(values[option.optionKey], option.input, locales)
    if (error) errors[option.optionKey] = error
  })

  return errors
}

export function normalizeInput(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null

  const type = typeof raw.type === 'string' ? raw.type.trim() : ''
  if (!INPUT_TYPES.has(type)) return null

  const label = typeof raw.label === 'string' ? raw.label.trim() : ''
  if (!label) return null

  const normalized = {
    type,
    label,
    description: typeof raw.description === 'string' ? raw.description.trim() : null,
    placeholder: typeof raw.placeholder === 'string' ? raw.placeholder.trim() : null,
    icon: typeof raw.icon === 'string' && raw.icon.trim() ? raw.icon.trim() : null,
    required: raw.required === true,
    disabled: raw.disabled === true,
    min: toNumber(raw.min),
    max: toNumber(raw.max),
    step: toNumber(raw.step),
    precision: toNumber(raw.precision),
    password: raw.password === true,
    searchable: raw.searchable === true,
    autosize: raw.autosize === true,
    minLength: toNumber(raw.minLength),
    maxLength: toNumber(raw.maxLength),
    maxSelectedValues: toNumber(raw.maxSelectedValues),
    options: normalizeSelectOptions(raw.options),
    defaultValue: raw.default ?? raw.defaultValue ?? null,
  }

  if (type === 'checkbox') {
    normalized.defaultValue = raw.checked ?? raw.default ?? raw.defaultValue ?? false
  } else if (type === 'multi-select') {
    normalized.defaultValue = Array.isArray(raw.default)
      ? raw.default.map(String)
      : Array.isArray(raw.defaultValue)
        ? raw.defaultValue.map(String)
        : []
  } else if (type === 'number' || type === 'slider') {
    const fallback = normalized.min ?? 0
    normalized.defaultValue = toNumber(raw.default ?? raw.defaultValue, fallback)
  } else if (type === 'input' || type === 'textarea') {
    normalized.defaultValue = raw.default ?? raw.defaultValue ?? ''
    if (normalized.defaultValue !== null && normalized.defaultValue !== undefined) {
      normalized.defaultValue = String(normalized.defaultValue)
    } else {
      normalized.defaultValue = ''
    }
  } else if (normalized.defaultValue !== null && normalized.defaultValue !== undefined) {
    normalized.defaultValue = String(normalized.defaultValue)
  } else {
    normalized.defaultValue = ''
  }

  normalized.defaultValue = coerceInputValue(normalized.defaultValue, normalized)
  return normalized
}

export function getInitialInputValue(input) {
  if (!input) return null

  if (input.type === 'multi-select') {
    return Array.isArray(input.defaultValue) ? [...input.defaultValue] : []
  }

  return coerceInputValue(input.defaultValue, input)
}

export function clampNumericValue(value, input) {
  let next = toNumber(value, input.min ?? 0)
  if (typeof input.min === 'number') next = Math.max(input.min, next)
  if (typeof input.max === 'number') next = Math.min(input.max, next)
  if (typeof input.precision === 'number') next = roundToPrecision(next, input.precision)
  return next
}

export function stepNumericValue(value, input, direction) {
  const step = typeof input.step === 'number' && input.step > 0 ? input.step : 1
  const current = clampNumericValue(value, input)
  return clampNumericValue(current + step * direction, input)
}

export function stepSelectValue(value, input, direction) {
  const options = input.options
  if (!options.length) return value

  const stringValue = value === null || value === undefined ? '' : String(value)
  let index = options.findIndex((entry) => entry.value === stringValue)
  if (index === -1) index = 0

  index += direction
  if (index < 0) index = options.length - 1
  if (index >= options.length) index = 0

  return options[index].value
}

export function toggleMultiSelectValue(value, optionValue, input) {
  const selected = Array.isArray(value) ? [...value] : []
  const stringValue = String(optionValue)
  const index = selected.indexOf(stringValue)

  if (index >= 0) {
    selected.splice(index, 1)
    return selected
  }

  if (
    typeof input.maxSelectedValues === 'number'
    && selected.length >= input.maxSelectedValues
  ) {
    return selected
  }

  selected.push(stringValue)
  return selected
}

export function stepMultiSelectValue(value, input, direction) {
  const options = input.options
  if (!options.length) return Array.isArray(value) ? value : []

  const selected = Array.isArray(value) ? [...value] : []
  const optionValues = options.map((entry) => entry.value)
  const focusValue = selected[0] || optionValues[0]
  let index = optionValues.indexOf(focusValue)
  if (index === -1) index = 0

  index += direction
  if (index < 0) index = optionValues.length - 1
  if (index >= optionValues.length) index = 0

  return toggleMultiSelectValue(selected, optionValues[index], input)
}

export function stepInputValue(value, input, direction) {
  if (!input || input.disabled) return value

  switch (input.type) {
    case 'number':
    case 'slider':
      return stepNumericValue(value, input, direction)
    case 'select':
      return stepSelectValue(value, input, direction)
    case 'multi-select':
      return stepMultiSelectValue(value, input, direction)
    case 'checkbox':
      return !value
    default:
      return value
  }
}

export function formatInputLocale(template, params = {}) {
  if (typeof template !== 'string') return ''
  return template.replace(/\{(\w+)\}/g, (_, key) => String(params[key] ?? ''))
}

export const DEFAULT_INPUT_LOCALES = {
  yes: 'Yes',
  no: 'No',
  none_selected: 'None selected',
  arrow_step_hint: 'Use left and right arrow keys to adjust.',
  choose: 'Choose',
  selected_count: '{count} selected',
  choose_aria: 'Choose {label}',
  max_selected: 'Max {count} selected',
  decrease_aria: 'Decrease {label}',
  increase_aria: 'Increase {label}',
  previous_aria: 'Previous {label}',
  next_aria: 'Next {label}',
  open_options_aria: 'Open {label} options',
  remove_aria: 'Remove {label}',
  validation_required: '{label} is required',
  validation_min_length: '{label} must be at least {min} characters',
  validation_max_length: '{label} must be at most {max} characters',
  validation_number: '{label} must be a number',
  validation_min_value: '{label} must be at least {min}',
  validation_max_value: '{label} must be at most {max}',
}

export function formatInputDisplayValue(value, input, locales = DEFAULT_INPUT_LOCALES) {
  if (!input) return ''

  switch (input.type) {
    case 'checkbox':
      return value ? locales.yes : locales.no
    case 'select': {
      const match = input.options.find((entry) => entry.value === String(value))
      return match?.label || String(value ?? '')
    }
    case 'multi-select': {
      const selected = Array.isArray(value) ? value : []
      if (!selected.length) return input.placeholder || locales.none_selected
      return selected
        .map((entry) => input.options.find((option) => option.value === entry)?.label || entry)
        .join(', ')
    }
    case 'number':
    case 'slider':
      return value === null || value === undefined ? '' : String(value)
    default:
      return value === null || value === undefined ? '' : String(value)
  }
}

export function usesArrowStepping(input) {
  if (!input || input.disabled) return false
  return ['number', 'slider', 'select', 'checkbox'].includes(input.type)
}

export function normalizeInputLocales(locales) {
  if (!locales || typeof locales !== 'object') return DEFAULT_INPUT_LOCALES

  return {
    yes: typeof locales.input_yes === 'string' ? locales.input_yes : DEFAULT_INPUT_LOCALES.yes,
    no: typeof locales.input_no === 'string' ? locales.input_no : DEFAULT_INPUT_LOCALES.no,
    none_selected: typeof locales.input_none_selected === 'string'
      ? locales.input_none_selected
      : DEFAULT_INPUT_LOCALES.none_selected,
    arrow_step_hint: typeof locales.input_arrow_step_hint === 'string'
      ? locales.input_arrow_step_hint
      : DEFAULT_INPUT_LOCALES.arrow_step_hint,
    choose: typeof locales.input_choose === 'string' ? locales.input_choose : DEFAULT_INPUT_LOCALES.choose,
    selected_count: typeof locales.input_selected_count === 'string'
      ? locales.input_selected_count
      : DEFAULT_INPUT_LOCALES.selected_count,
    choose_aria: typeof locales.input_choose_aria === 'string'
      ? locales.input_choose_aria
      : DEFAULT_INPUT_LOCALES.choose_aria,
    max_selected: typeof locales.input_max_selected === 'string'
      ? locales.input_max_selected
      : DEFAULT_INPUT_LOCALES.max_selected,
    decrease_aria: typeof locales.input_decrease_aria === 'string'
      ? locales.input_decrease_aria
      : DEFAULT_INPUT_LOCALES.decrease_aria,
    increase_aria: typeof locales.input_increase_aria === 'string'
      ? locales.input_increase_aria
      : DEFAULT_INPUT_LOCALES.increase_aria,
    previous_aria: typeof locales.input_previous_aria === 'string'
      ? locales.input_previous_aria
      : DEFAULT_INPUT_LOCALES.previous_aria,
    next_aria: typeof locales.input_next_aria === 'string'
      ? locales.input_next_aria
      : DEFAULT_INPUT_LOCALES.next_aria,
    open_options_aria: typeof locales.input_open_options_aria === 'string'
      ? locales.input_open_options_aria
      : DEFAULT_INPUT_LOCALES.open_options_aria,
    remove_aria: typeof locales.input_remove_aria === 'string'
      ? locales.input_remove_aria
      : DEFAULT_INPUT_LOCALES.remove_aria,
    validation_required: typeof locales.input_validation_required === 'string'
      ? locales.input_validation_required
      : DEFAULT_INPUT_LOCALES.validation_required,
    validation_min_length: typeof locales.input_validation_min_length === 'string'
      ? locales.input_validation_min_length
      : DEFAULT_INPUT_LOCALES.validation_min_length,
    validation_max_length: typeof locales.input_validation_max_length === 'string'
      ? locales.input_validation_max_length
      : DEFAULT_INPUT_LOCALES.validation_max_length,
    validation_number: typeof locales.input_validation_number === 'string'
      ? locales.input_validation_number
      : DEFAULT_INPUT_LOCALES.validation_number,
    validation_min_value: typeof locales.input_validation_min_value === 'string'
      ? locales.input_validation_min_value
      : DEFAULT_INPUT_LOCALES.validation_min_value,
    validation_max_value: typeof locales.input_validation_max_value === 'string'
      ? locales.input_validation_max_value
      : DEFAULT_INPUT_LOCALES.validation_max_value,
  }
}

export function getSelectSpinIndex(value, input) {
  const options = input?.options ?? []
  if (!options.length) return 0

  const stringValue = value === null || value === undefined ? '' : String(value)
  const index = options.findIndex((entry) => entry.value === stringValue)
  return index === -1 ? 0 : index
}
