import { useCallback, useEffect, useState } from 'react'
import { takePendingOpen } from './placement-message-buffer'
import './design-system/index.css'

const DEFAULT_LOCALES = {
  title: 'DUI surface placement',
  subtitle_top_left: 'Aim the top-left corner on a wall or surface',
  subtitle_bottom_right: 'Aim the bottom-right corner to size the board',
  status_ready: 'Ready',
  status_too_far: 'Too far',
  status_aiming: 'Aiming…',
  phase_top_left: 'Step 1 — Top-left corner',
  phase_bottom_right: 'Step 2 — Bottom-right corner',
  subtitle_target: 'Aim at the surface for the laser target',
  phase_target: 'Laser target',
  position: 'Aim position',
  distance: 'Distance',
  max_distance: 'Max distance',
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

function shouldHideRoot() {
  return !document.querySelector('.dialogue-container.is-open')
    && !document.querySelector('.prop-placer--visible')
    && !document.querySelector('.gizmo-panel--visible')
    && !document.querySelector('.zone-creator--visible')
    && !document.querySelector('.dui-creator--visible')
    && !document.querySelector('.task-group-menu')
    && !document.querySelector('.task-hud--visible')
}

function getRootElement() {
  return document.getElementById('root')
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
    if (shouldHideRoot()) {
      getRootElement()?.classList.add('hidden')
    }
  }, [])

  const openPanel = useCallback((payload) => {
    getRootElement()?.classList.remove('hidden')
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

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const statusLabel = (() => {
    if (status === 'ready') return locales.status_ready
    if (status === 'too_far') return locales.status_too_far
    return locales.status_aiming
  })()

  const statusClass = status === 'ready'
    ? 'dui-creator__status--success'
    : status === 'too_far'
      ? 'dui-creator__status--warning'
      : 'dui-creator__status--info'

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

  return (
    <div className={`dui-creator${visible ? ' dui-creator--visible' : ''}`} aria-hidden={!visible}>
      <aside className="dui-creator__panel" role="complementary" aria-label={locales.title}>
        <div className="dui-creator__header">
          <div>
            <h2 className="dui-creator__title">{locales.title}</h2>
            <p className="dui-creator__subtitle">{label || subtitle}</p>
            <p className="dui-creator__phase">{phaseLabel}</p>
          </div>
          <span className={`dui-creator__status ${statusClass}`}>{statusLabel}</span>
        </div>

        <div className="dui-creator__stats">
          <div className="dui-creator__stat">
            <span className="dui-creator__stat-label">{locales.position}</span>
            <span className="dui-creator__stat-value">
              {formatCoord(coords.x)}, {formatCoord(coords.y)}, {formatCoord(coords.z)}
            </span>
          </div>
          <div className="dui-creator__stat">
            <span className="dui-creator__stat-label">{locales.distance}</span>
            <span className="dui-creator__stat-value">{formatCoord(distance)} m</span>
          </div>
          <div className="dui-creator__stat">
            <span className="dui-creator__stat-label">{locales.max_distance}</span>
            <span className="dui-creator__stat-value">{formatCoord(maxDistance)} m</span>
          </div>
          {isTarget ? null : (
            <div className="dui-creator__stat">
              <span className="dui-creator__stat-label">{locales.world_size}</span>
              <span className="dui-creator__stat-value">{sizeLabel}</span>
            </div>
          )}
        </div>

        <div className="dui-creator__controls">
          <p className="dui-creator__controls-title">{locales.controls}</p>
          {controls.map((control, index) => (
            <div className="dui-creator__control" key={`${control.key}-${index}`}>
              <kbd className="dui-creator__key">{control.key}</kbd>
              <span className="dui-creator__control-label">{control.label}</span>
            </div>
          ))}
        </div>
      </aside>
    </div>
  )
}

export default DuiCreatorPanel
