const SELECTOR_ALIASES = {
  '.description': [
    '.dialogue-menu-description',
    '.dialogue-text-content',
    '.dialogue-button-description',
  ],
  '.subtitle': ['.dialogue-menu-description'],
  '.title': ['.dialogue-title'],
  '.label': ['.dialogue-button-title'],
  '.button': ['.dialogue-button'],
  '.header': ['.dialogue-header'],
  '.text': ['.dialogue-text'],
  '.options': ['.dialogue-options'],
  '.back': ['.dialogue-back-button'],
  '.metadata': [
    '.dialogue-button-metadata-inline',
    '.dialogue-button-metadata-label',
    '.dialogue-button-metadata-value',
  ],
  '.image': ['.dialogue-image', '.dialogue-image--menu', '.dialogue-image--option'],
}

function isSelectorKey(key) {
  return typeof key === 'string' && /^[.#[]/.test(key)
}

function isStyleValue(value) {
  return typeof value === 'string' || typeof value === 'number'
}

function toCssProperty(key) {
  if (key.includes('-')) return key
  return key.replace(/[A-Z]/g, (match) => `-${match.toLowerCase()}`)
}

function propsToDeclaration(props) {
  return Object.entries(props)
    .filter(([, value]) => isStyleValue(value))
    .map(([key, value]) => `${toCssProperty(key)}: ${value};`)
    .join('')
}

function resolveSelectorTargets(selector) {
  if (SELECTOR_ALIASES[selector]) {
    return SELECTOR_ALIASES[selector]
  }

  if (selector.startsWith('.')) {
    return [selector]
  }

  return [selector]
}

function normalizeStyle(style) {
  if (!style || typeof style !== 'object' || Array.isArray(style)) {
    return null
  }

  const root = {}
  const selectors = {}

  for (const [key, value] of Object.entries(style)) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      if (isSelectorKey(key)) {
        const normalizedSelector = {}
        for (const [childKey, childValue] of Object.entries(value)) {
          if (isStyleValue(childValue)) {
            normalizedSelector[childKey] = childValue
          }
        }

        if (Object.keys(normalizedSelector).length > 0) {
          selectors[key] = normalizedSelector
        }
      }
      continue
    }

    if (isStyleValue(value)) {
      root[key] = value
    }
  }

  if (Object.keys(root).length === 0 && Object.keys(selectors).length === 0) {
    return null
  }

  return { root, selectors }
}

export function mergeStyles(...styles) {
  const merged = { root: {}, selectors: {} }

  for (const style of styles) {
    const normalized = normalizeStyle(style)
    if (!normalized) continue

    Object.assign(merged.root, normalized.root)

    for (const [selector, props] of Object.entries(normalized.selectors)) {
      merged.selectors[selector] = {
        ...merged.selectors[selector],
        ...props,
      }
    }
  }

  if (Object.keys(merged.root).length === 0 && Object.keys(merged.selectors).length === 0) {
    return null
  }

  return merged
}

export function buildStyleSheet(style, scopeId) {
  const normalized = normalizeStyle(style)
  if (!normalized || !scopeId) return ''

  const scope = `[data-dialogue-style="${scopeId}"]`
  let css = ''

  if (Object.keys(normalized.root).length > 0) {
    css += `${scope}.dialogue-container{${propsToDeclaration(normalized.root)}}`
  }

  for (const [selector, props] of Object.entries(normalized.selectors)) {
    const targets = resolveSelectorTargets(selector)
    const selectorList = targets
      .map((target) => `${scope}.dialogue-container ${target}`)
      .join(',')

    css += `${selectorList}{${propsToDeclaration(props)}}`
  }

  return css
}
