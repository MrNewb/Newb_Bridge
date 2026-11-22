import {
  DEFAULT_TYPE,
  MANTINE_COLORS,
  VALID_ICON_ANIMATIONS,
  VALID_TYPES,
} from './design-system/constants.js'
import { mergeStyles } from './design-system/style.js'
import { isImageUrl, normalizeImageSource } from './design-system/image-utils.js'
import { normalizeInput } from './design-system/input-utils.js'

function clampProgress(value) {
  if (typeof value !== 'number' || Number.isNaN(value)) return null
  return Math.max(0, Math.min(100, value))
}

function normalizeColorScheme(value) {
  if (typeof value !== 'string') return null
  const scheme = value.trim().toLowerCase()
  return MANTINE_COLORS.has(scheme) ? scheme : null
}

function normalizeMetadata(metadata) {
  if (!metadata) return null

  if (Array.isArray(metadata)) {
    return metadata
      .map((entry) => {
        if (typeof entry === 'string') {
          return { label: entry, value: null }
        }

        if (!entry || typeof entry !== 'object') return null

        const label = typeof entry.label === 'string' ? entry.label.trim() : ''
        if (!label) return null

        return {
          label,
          value: entry.value ?? null,
          progress: clampProgress(entry.progress),
          colorScheme: normalizeColorScheme(entry.colorScheme),
        }
      })
      .filter(Boolean)
  }

  if (typeof metadata === 'object') {
    return Object.entries(metadata).map(([label, value]) => ({
      label: String(label),
      value,
      progress: null,
      colorScheme: null,
    }))
  }

  return null
}

export function normalizeOpenPayload(data) {
  if (!data || data.type !== 'open') return null

  const sessionId = typeof data.sessionId === 'string' ? data.sessionId.trim() : ''
  const menuId = typeof data.menuId === 'string' ? data.menuId.trim() : ''
  const title = typeof data.title === 'string' ? data.title.trim() : ''
  const description = typeof data.description === 'string' ? data.description.trim() : ''
  const text = typeof data.text === 'string' ? data.text.trim() : ''
  const image = normalizeImageSource(data.image)
  const menu = typeof data.menu === 'string' ? data.menu.trim() : ''
  const options = normalizeOptions(data.options)
  const locales = data.locales && typeof data.locales === 'object' ? data.locales : null

  if (!sessionId && !title && !description && !text && options.length === 0) {
    return null
  }

  return {
    sessionId: sessionId || menuId || 'dialogue',
    menuId,
    title,
    description,
    image,
    text,
    typewriter: data.typewriter === true,
    menu,
    canGoBack: Boolean(data.canGoBack),
    options,
    locales,
    style: mergeStyles(data.style),
  }
}

function normalizeOptions(options) {
  if (!options) return []

  const entries = Array.isArray(options)
    ? options.map((option, index) => [String(index + 1), option])
    : typeof options === 'object'
      ? Object.entries(options)
      : []

  return entries
    .map(([key, option], index) => {
      if (!option || typeof option !== 'object') return null

      const optionKey = typeof option.key === 'string' && option.key.trim()
        ? option.key.trim()
        : key

      const input = normalizeInput(option.input)
      const title = typeof option.title === 'string'
        ? option.title.trim()
        : input?.label || ''

      if (!title && !input) return null

      const icon = typeof option.icon === 'string' && option.icon.trim() ? option.icon.trim() : null
      const image = normalizeImageSource(option.image)
      const iconIsImage = isImageUrl(icon)
      const type = option.type && VALID_TYPES.has(option.type) ? option.type : DEFAULT_TYPE
      const progress = clampProgress(option.progress)
      const colorScheme = normalizeColorScheme(option.colorScheme)
      const menu = typeof option.menu === 'string' && option.menu.trim()
        ? option.menu.trim()
        : null
      const hasSubmenu = Boolean(menu)
      const isInputAction = Boolean(option.selectable)
      const arrow = option.arrow === false
        ? false
        : hasSubmenu || option.arrow === true

      return {
        key: `${optionKey}-${index}`,
        optionKey,
        id: option.id ?? optionKey,
        title: title || input?.label || optionKey,
        input,
        isInputAction,
        description: typeof option.description === 'string' ? option.description.trim() : null,
        disabled: option.disabled === true,
        readOnly: option.readOnly === true,
        menu,
        icon: iconIsImage ? null : icon,
        iconIsUrl: iconIsImage,
        iconImage: iconIsImage ? icon : null,
        iconColor: typeof option.iconColor === 'string' ? option.iconColor.trim() : null,
        iconAnimation: iconIsImage ? null : (
          VALID_ICON_ANIMATIONS.has(option.iconAnimation) ? option.iconAnimation : null
        ),
        progress,
        colorScheme,
        arrow,
        image,
        metadata: normalizeMetadata(option.metadata),
        type,
      }
    })
    .filter(Boolean)
}

/** Three to a line once there are more than four, so long lists stay short and every tile is wide enough to read. */
export function getOptionColumnCount(optionCount) {
  if (optionCount <= 1) return 1
  if (optionCount === 2) return 2
  if (optionCount === 3) return 3
  if (optionCount === 4) return 2
  return 3
}

/**
 * Any list longer than a single row scrolls. The old height estimate guessed 44px a row, but a tile with a
 * description is twice that, so a long list was cut off with nothing to scroll.
 */
export function getOptionsLayout(optionCount) {
  const scrollable = optionCount > 3

  return {
    scrollable,
    maxHeight: scrollable ? 'min(52vh, 27rem)' : 'none',
  }
}

export { DEFAULT_TYPE, VALID_TYPES, MANTINE_COLORS }
