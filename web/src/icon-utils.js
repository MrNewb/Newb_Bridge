const FA_STYLE_TOKENS = new Set([
  'fa',
  'fas',
  'far',
  'fal',
  'fat',
  'fad',
  'fab',
  'fa-solid',
  'fa-regular',
  'fa-light',
  'fa-thin',
  'fa-duotone',
  'fa-brands',
])

const PREFIX_BY_TOKEN = {
  fa: 'fas',
  fas: 'fas',
  'fa-solid': 'fas',
  far: 'far',
  'fa-regular': 'far',
  fab: 'fab',
  'fa-brands': 'fab',
}

export function parseIconProp(iconName) {
  if (!iconName || typeof iconName !== 'string') return null

  const tokens = iconName.trim().split(/\s+/).filter(Boolean)
  if (!tokens.length) return null

  let prefix = 'fas'
  let iconNameKebab = ''

  for (const rawToken of tokens) {
    const token = rawToken.toLowerCase()

    if (PREFIX_BY_TOKEN[token]) {
      prefix = PREFIX_BY_TOKEN[token]
      continue
    }

    if (FA_STYLE_TOKENS.has(token)) continue

    if (token.startsWith('fa-')) {
      iconNameKebab = token.slice(3)
      continue
    }

    if (/^[a-z0-9-]+$/i.test(token)) {
      iconNameKebab = token
    }
  }

  if (!iconNameKebab && tokens.length === 1) {
    const token = tokens[0].toLowerCase()
    iconNameKebab = token.startsWith('fa-') ? token.slice(3) : token
  }

  if (!iconNameKebab) return null

  return { prefix, iconName: iconNameKebab }
}
