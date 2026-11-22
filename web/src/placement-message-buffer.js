const OPEN_TYPES = new Set([
  'placer:open',
  'gizmo:open',
  'zoneCreator:open',
  'dui_creator:open',
])

const pendingOpens = new Map()
const pendingUpdates = new Map()
let installed = false

export function installPlacementMessageBuffer() {
  if (installed) return
  installed = true

  window.addEventListener('message', (event) => {
    const type = event?.data?.type
    if (typeof type === 'string' && type.endsWith(':update')) pendingUpdates.set(type, event.data)
    if (!OPEN_TYPES.has(type)) return

    pendingOpens.set(type, event.data)
    window.dispatchEvent(new CustomEvent('placement:open', { detail: { type } }))
  })
}

export function takePendingOpen(type) {
  const payload = pendingOpens.get(type)
  if (payload) pendingOpens.delete(type)
  return payload ?? null
}

/** The newest update that arrived before the panel was ready to listen, or null. */
export function takePendingUpdate(type) {
  const payload = pendingUpdates.get(type)
  if (payload) pendingUpdates.delete(type)
  return payload ?? null
}
