import { parseIconProp } from './icon-utils'

const iconCache = new Map()
const listeners = new Set()
const packLoads = {
  fas: null,
  far: null,
  fab: null,
}
const readyPacks = new Set()

let iconApi = null
let version = 0

function emit() {
  version += 1
  for (const listener of listeners) listener()
}

function packForPrefix(prefix) {
  if (prefix === 'far') return 'far'
  if (prefix === 'fab') return 'fab'
  return 'fas'
}

// Solid + core stay off the join bundle. Regular and brands load only when an
// icon name actually asks for that style (~1.6 MB together).
function ensurePack(prefix) {
  if (!packLoads.fas) {
    packLoads.fas = import('./icons-register.js').then((module) => {
      iconApi = module
      readyPacks.add('fas')
      return module
    })
  }

  const pack = packForPrefix(prefix)
  if (pack === 'fas') return packLoads.fas

  if (pack === 'far') {
    if (!packLoads.far) {
      packLoads.far = packLoads.fas.then(() => import('./icons-register-regular.js')).then(() => {
        readyPacks.add('far')
      })
    }
    return packLoads.far
  }

  if (!packLoads.fab) {
    packLoads.fab = packLoads.fas.then(() => import('./icons-register-brands.js')).then(() => {
      readyPacks.add('fab')
    })
  }
  return packLoads.fab
}

function resolveIcon(iconName) {
  const iconProp = parseIconProp(iconName)
  if (!iconProp || !iconApi) return null

  let definition = null
  try {
    definition = iconApi.icon(iconProp) ?? null
  } catch {
    definition = null
  }

  iconCache.set(iconName, definition)
  return definition
}

export function loadSolidIcon(iconName) {
  if (!iconName) return null
  if (iconCache.has(iconName)) return iconCache.get(iconName)

  const iconProp = parseIconProp(iconName)
  if (!iconProp) return null

  const pack = packForPrefix(iconProp.prefix)
  if (iconApi && readyPacks.has(pack)) return resolveIcon(iconName)

  void ensurePack(iconProp.prefix).then(() => {
    resolveIcon(iconName)
    emit()
  })

  return null
}

export function preloadSolidIcons(iconNames) {
  const uniqueNames = [...new Set(iconNames.filter((name) => name && parseIconProp(name)))]
  if (uniqueNames.length === 0) return

  const prefixes = new Set()
  uniqueNames.forEach((name) => {
    prefixes.add(parseIconProp(name).prefix)
  })

  void Promise.all([...prefixes].map((prefix) => ensurePack(prefix))).then(() => {
    uniqueNames.forEach(resolveIcon)
    emit()
  })
}

export function subscribeToIcons(listener) {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function getIconVersion() {
  return version
}
