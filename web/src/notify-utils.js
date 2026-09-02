const notifyTypes = {
  inform: 'inform',
  info: 'inform',
  success: 'success',
  error: 'error',
  warning: 'warning',
}

const notifyPositions = {
  top: 'top',
  'top-right': 'top-right',
  'top-left': 'top-left',
  bottom: 'bottom',
  'bottom-right': 'bottom-right',
  'bottom-left': 'bottom-left',
  'center-right': 'center-right',
  'center-left': 'center-left',
}

const notifyAnimations = {
  spin: true,
  spinPulse: true,
  spinReverse: true,
  pulse: true,
  beat: true,
  fade: true,
  beatFade: true,
  bounce: true,
  shake: true,
}

const defaultIcons = {
  inform: 'circle-info',
  success: 'circle-check',
  error: 'circle-xmark',
  warning: 'circle-exclamation',
}

const notifyListeners = new Set()

export function subscribeNotify(listener) {
  notifyListeners.add(listener)
  return () => notifyListeners.delete(listener)
}

export function showNotify(data) {
  const toast = normalizeNotify(data)
  if (!toast) return
  for (const listener of notifyListeners) listener({ action: 'show', toast })
}

export function hideNotify(id) {
  for (const listener of notifyListeners) listener({ action: 'hide', id })
}

function coerceText(value) {
  if (typeof value === 'string') return value
  if (typeof value === 'number' && Number.isFinite(value)) return String(value)
  return ''
}

function coerceNotifyId(value) {
  if (typeof value === 'string' && value) return value
  if (typeof value === 'number' && Number.isFinite(value)) return String(value)
  return ''
}

function coerceNotifyIcon(icon, type) {
  if (typeof icon === 'string' && icon.trim()) return icon.trim()
  if (Array.isArray(icon)) {
    const parts = []
    for (let index = 0; index < icon.length; index += 1) {
      const part = icon[index]
      if (typeof part === 'string' && part.trim()) parts.push(part.trim())
    }
    if (parts.length) return parts.join(' ')
  }
  return defaultIcons[type]
}

function coerceNotifyImage(value) {
  if (typeof value !== 'string') return ''
  const image = value.trim()
  if (!image) return ''
  const lower = image.toLowerCase()
  if (lower.startsWith('javascript:') || lower.startsWith('vbscript:')) return ''
  if (lower.startsWith('data:') && !lower.startsWith('data:image/')) return ''
  if (!image.includes('://') && /^[a-z0-9._-]+\//i.test(image)) return `nui://${image}`
  return image
}

function coerceShowDuration(value) {
  if (value === undefined || value === null) return true
  return value !== false && value !== 0 && value !== 'false'
}

function toCamelCaseKey(key) {
  return String(key).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())
}

function flattenCssStyle(style) {
  const out = {}
  for (const [key, value] of Object.entries(style)) {
    if (value == null || typeof value === 'object') continue
    out[toCamelCaseKey(key)] = value
  }
  return Object.keys(out).length ? out : null
}

function parseCssColor(value) {
  if (typeof value !== 'string') return null
  const text = value.trim()
  const hex = text.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i)
  if (hex) {
    let digits = hex[1]
    if (digits.length === 3) digits = digits[0] + digits[0] + digits[1] + digits[1] + digits[2] + digits[2]
    return [parseInt(digits.slice(0, 2), 16), parseInt(digits.slice(2, 4), 16), parseInt(digits.slice(4, 6), 16)]
  }
  const rgb = text.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i)
  if (rgb) return [Number(rgb[1]), Number(rgb[2]), Number(rgb[3])]
  return null
}

function channelToLinear(channel) {
  const value = channel / 255
  return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
}

function relativeLuminance(rgb) {
  return 0.2126 * channelToLinear(rgb[0]) + 0.7152 * channelToLinear(rgb[1]) + 0.0722 * channelToLinear(rgb[2])
}

function contrastRatio(first, second) {
  const lighter = Math.max(first, second)
  const darker = Math.min(first, second)
  return (lighter + 0.05) / (darker + 0.05)
}

function contrastFallback(background) {
  const parsed = parseCssColor(background)
  if (!parsed) return '#fafafa'
  return relativeLuminance(parsed) > 0.45 ? '#09090b' : '#fafafa'
}

function clampContrastColor(foreground, background) {
  const fg = parseCssColor(foreground)
  const bg = parseCssColor(background)
  if (!fg || !bg) return foreground
  if (contrastRatio(relativeLuminance(fg), relativeLuminance(bg)) >= 4.5) return foreground
  return contrastFallback(background)
}

function clampStyleColor(style, background) {
  if (!style?.color) return style
  const color = clampContrastColor(style.color, background)
  if (color === style.color) return style
  return { ...style, color }
}

function clampNotifyStyles(styles) {
  const background = styles.root?.backgroundColor || styles.root?.background || '#09090b'
  return {
    root: clampStyleColor(styles.root, background),
    title: clampStyleColor(styles.title, background),
    description: clampStyleColor(styles.description, background),
  }
}

function nestedStyleName(key) {
  return String(key).replace(/^&/, '').replace(/^\s*\./, '').trim()
}

export function splitNotifyStyle(style) {
  if (!style || typeof style !== 'object' || Array.isArray(style)) {
    return { root: null, title: null, description: null }
  }

  const root = {}
  const nested = {}

  for (const [key, value] of Object.entries(style)) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      const name = nestedStyleName(key)
      if (name) nested[name] = flattenCssStyle(value)
      continue
    }
    if (value == null) continue
    root[toCamelCaseKey(key)] = value
  }

  return {
    root: Object.keys(root).length ? root : null,
    title: nested.title || null,
    description: nested.description || null,
  }
}

export function normalizeNotify(data) {
  if (data == null) return null

  const source = typeof data === 'string'
    ? { description: data }
    : (typeof data === 'object' && !Array.isArray(data) ? data : null)

  if (!source) return null

  const title = coerceText(source.title)
  const description = coerceText(source.description) || coerceText(source.message)
  if (!title && !description) return null

  const type = notifyTypes[source.type] || 'inform'
  const position = notifyPositions[source.position] || 'top-right'
  const duration = Number(source.duration)
  const id = coerceNotifyId(source.id) || `notify-${Date.now()}-${Math.random().toString(16).slice(2)}`
  const iconColor = typeof source.iconColor === 'string' ? source.iconColor.trim() : ''
  const iconAnimation = notifyAnimations[source.iconAnimation] ? source.iconAnimation : ''
  const styles = clampNotifyStyles(splitNotifyStyle(source.style))
  const image = coerceNotifyImage(source.image)

  return {
    id,
    title,
    description,
    type,
    position,
    duration: Number.isFinite(duration) && duration > 0 ? duration : 3000,
    showDuration: coerceShowDuration(source.showDuration),
    icon: coerceNotifyIcon(source.icon, type),
    image,
    iconColor,
    iconAnimation,
    alignIcon: source.alignIcon === 'top' ? 'top' : 'center',
    style: styles.root,
    titleStyle: styles.title,
    descriptionStyle: styles.description,
  }
}

const stringPayload = normalizeNotify('Saved')
if (!stringPayload || stringPayload.type !== 'inform' || stringPayload.description !== 'Saved') {
  throw new Error('notify string payload')
}

const infoAlias = normalizeNotify({ type: 'info', description: 'Hello' })
if (!infoAlias || infoAlias.type !== 'inform' || infoAlias.position !== 'top-right') {
  throw new Error('notify info alias')
}

const customPayload = normalizeNotify({
  id: 12,
  type: 'success',
  title: 'Notification title',
  description: 'Notification description',
  showDuration: false,
  position: 'top',
  icon: ['fas', 'ban'],
  image: 'ox_inventory/web/images/lockpick.png',
  iconColor: '#C53030',
  iconAnimation: 'spin',
  alignIcon: 'top',
  style: {
    backgroundColor: '#141517',
    color: '#C1C2C5',
    '.description': { color: '#909296' },
  },
})
if (
  !customPayload
  || customPayload.id !== '12'
  || customPayload.showDuration !== false
  || customPayload.icon !== 'fas ban'
  || customPayload.image !== 'nui://ox_inventory/web/images/lockpick.png'
  || customPayload.iconColor !== '#C53030'
  || customPayload.alignIcon !== 'top'
  || customPayload.style?.backgroundColor !== '#141517'
  || customPayload.descriptionStyle?.color !== '#909296'
) {
  throw new Error('notify ox_lib custom payload')
}

const darkClamp = normalizeNotify({
  description: 'Saved',
  style: { backgroundColor: '#09090b', color: '#333333' },
})
if (!darkClamp || darkClamp.style?.color !== '#fafafa') {
  throw new Error('notify contrast clamp dark')
}

const lightClamp = normalizeNotify({
  description: 'Saved',
  style: { backgroundColor: '#fafafa', color: '#eeeeee' },
})
if (!lightClamp || lightClamp.style?.color !== '#09090b') {
  throw new Error('notify contrast clamp light')
}
