const OPEN_TYPES = new Set([
  'placer:open',
  'gizmo:open',
  'zoneCreator:open',
  'dui_creator:open',
])

const pendingOpens = new Map()
let installed = false

export function installPlacementMessageBuffer() {
  if (installed) return
  installed = true

  window.addEventListener('message', (event) => {
    const type = event?.data?.type
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

export function isPlacementOpenType(type) {
  return OPEN_TYPES.has(type)
}
