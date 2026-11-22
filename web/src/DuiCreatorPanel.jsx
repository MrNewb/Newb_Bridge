import { useCallback, useEffect, useState } from 'react'
import { takePendingOpen, takePendingUpdate } from './placement-message-buffer'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import { ActionKeys, MetaLine, PlacementPanel, Range, Stepper, StatusBlock } from './components/placement-panel'

const DEFAULT_LOCALES = {
  title: 'DUI surface placement',
  subtitle_top_left: 'Aim the top-left corner on a wall or surface',
  subtitle_bottom_right: 'Aim the bottom-right corner to size the board',
  status_ready: 'Ready',
  status_too_far: 'Too far',
  status_aiming: 'Aiming…',
  hint_aiming: 'Aim at a flat surface',
  hint_ready: 'Press the key to set it here',
  hint_too_far: 'Move closer to set it',
  step_one: 'Top-left',
  step_two: 'Bottom-right',
  phase_top_left: 'Step 1 — Top-left corner',
  phase_bottom_right: 'Step 2 — Bottom-right corner',
  subtitle_target: 'Aim at the surface for the laser target',
  phase_target: 'Laser target',
  position: 'Aim position',
  distance: 'Distance',
  world_size: 'Board size',
  controls: 'Controls',
  place_corner: 'Set corner',
  place_target: 'Set position',
  confirm_size: 'Confirm size',
  reset_corner: 'Reset top-left',
  exit: 'Cancel placement',
}

function normalizeLocales(value) {
  if (!value || typeof value !== 'object') return DEFAULT_LOCALES

  return {
    ...DEFAULT_LOCALES,
    ...Object.fromEntries(
      Object.entries(DEFAULT_LOCALES).map(([key]) => [
        key,
        typeof value[key] === 'string' ? value[key] : DEFAULT_LOCALES[key],
      ]),
    ),
  }
}

function formatCoord(value) {
  if (typeof value !== 'number' || Number.isNaN(value)) return '—'
  return value.toFixed(2)
}

function DuiCreatorPanel() {
  const [visible, setVisible] = useState(false)
  const [locales, setLocales] = useState(DEFAULT_LOCALES)
  const [label, setLabel] = useState('')
  const [phase, setPhase] = useState('topLeft')
  const [coords, setCoords] = useState({ x: 0, y: 0, z: 0 })
  const [distance, setDistance] = useState(0)
  const [maxDistance, setMaxDistance] = useState(20)
  const [worldWidth, setWorldWidth] = useState(null)
  const [worldHeight, setWorldHeight] = useState(null)
  const [status, setStatus] = useState('aiming')

  const closePanel = useCallback(() => {
    setVisible(false)
    hideRootIfIdle()
  }, [])

  const openPanel = useCallback((payload) => {
    showRoot()
    setLocales(normalizeLocales(payload?.locales))
    setLabel(typeof payload?.label === 'string' ? payload.label : '')
    setMaxDistance(typeof payload?.maxDistance === 'number' ? payload.maxDistance : 20)
    setPhase(typeof payload?.phase === 'string' ? payload.phase : 'topLeft')
    setWorldWidth(null)
    setWorldHeight(null)
    setStatus('aiming')
    setVisible(true)
  }, [])

  useEffect(() => {
    const handleMessage = (event) => {
      const data = event.data

      if (data?.type === 'dui_creator:open') {
        openPanel(data)
        return
      }

      if (data?.type === 'dui_creator:close') {
        closePanel()
        return
      }

      if (data?.type === 'dui_creator:update') {
        if (typeof data.phase === 'string') setPhase(data.phase)
        if (typeof data.distance === 'number') setDistance(data.distance)
        if (typeof data.maxDistance === 'number') setMaxDistance(data.maxDistance)
        if (typeof data.status === 'string') setStatus(data.status)
        if (typeof data.worldWidth === 'number') setWorldWidth(data.worldWidth)
        if (typeof data.worldHeight === 'number') setWorldHeight(data.worldHeight)
        if (data.coords && typeof data.coords === 'object') {
          setCoords({
            x: typeof data.coords.x === 'number' ? data.coords.x : 0,
            y: typeof data.coords.y === 'number' ? data.coords.y : 0,
            z: typeof data.coords.z === 'number' ? data.coords.z : 0,
          })
        }
      }
    }

    window.addEventListener('message', handleMessage)

    const pendingOpen = takePendingOpen('dui_creator:open')
    if (pendingOpen) openPanel(pendingOpen)
    const pendingUpdate = takePendingUpdate('dui_creator:update')
    if (pendingUpdate) handleMessage({ data: pendingUpdate })

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const statusLabel = (() => {
    if (status === 'ready') return locales.status_ready
    if (status === 'too_far') return locales.status_too_far
    return locales.status_aiming
  })()

  const isTarget = phase === 'target'

  const subtitle = isTarget
    ? locales.subtitle_target
    : phase === 'bottomRight'
      ? locales.subtitle_bottom_right
      : locales.subtitle_top_left

  const phaseLabel = isTarget
    ? locales.phase_target
    : phase === 'bottomRight'
      ? locales.phase_bottom_right
      : locales.phase_top_left

  const controls = isTarget
    ? [
      { key: 'E', label: locales.place_target },
      { key: 'Backspace', label: locales.exit },
    ]
    : phase === 'bottomRight'
      ? [
        { key: 'E', label: locales.confirm_size },
        { key: 'Backspace', label: locales.reset_corner },
      ]
      : [
        { key: 'E', label: locales.place_corner },
        { key: 'Backspace', label: locales.exit },
      ]

  const sizeLabel = worldWidth && worldHeight
    ? `${formatCoord(worldWidth)} × ${formatCoord(worldHeight)} m`
    : '—'

  const hint = status === 'ready' ? locales.hint_ready : status === 'too_far' ? locales.hint_too_far : locales.hint_aiming
  const items = controls.map((control, index) => ({ id: `${control.key}-${index}`, keys: control.key, label: control.label }))

  return (
    <PlacementPanel
      name="dui-creator"
      visible={visible}
      label={locales.title}
      title={locales.title}
      subtitle={label || subtitle}
      footer={<ActionKeys items={items} />}
    >
      {isTarget ? (
        <p className="m-0 text-xs font-medium text-muted-foreground">{phaseLabel}</p>
      ) : (
        <Stepper steps={[locales.step_one, locales.step_two]} current={phase === 'bottomRight' ? 1 : 0} />
      )}

      <StatusBlock status={status === 'ready' || status === 'too_far' ? status : 'aiming'} title={statusLabel} text={hint} />

      <Range label={locales.distance} value={distance} max={maxDistance} status={status} />

      <div className="prop-placer__meta flex flex-col gap-1 text-xs">
        <MetaLine label={locales.position} value={`${formatCoord(coords.x)}, ${formatCoord(coords.y)}, ${formatCoord(coords.z)}`} />
        {phase === 'bottomRight' ? <MetaLine label={locales.world_size} value={sizeLabel} /> : null}
      </div>
    </PlacementPanel>
  )
}

export default DuiCreatorPanel
