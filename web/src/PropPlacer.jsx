import { useCallback, useEffect, useMemo, useState } from 'react'
import { takePendingOpen } from './placement-message-buffer'
import './design-system/index.css'

const DEFAULT_LOCALES = {
  title: 'Prop placement',
  subtitle: 'Aim at a surface to preview',
  status_ready: 'Ready',
  status_invalid_material: 'Invalid surface',
  status_too_far: 'Too far',
  status_aiming: 'Aiming…',
  position: 'Position',
  heading: 'Heading',
  distance: 'Distance',
  max_distance: 'Max distance',
  controls: 'Controls',
  controls_position: 'Position',
  controls_preview: 'Preview',
  controls_actions: 'Actions',
  rotate: 'Rotate prop',
  place: 'Place prop',
  title_ped: 'Ped placement',
  subtitle_ped: 'Aim at a surface to preview ped',
  rotate_ped: 'Rotate ped',
  place_ped: 'Place ped',
  title_vehicle: 'Vehicle placement',
  subtitle_vehicle: 'Aim at a surface to preview vehicle',
  rotate_vehicle: 'Rotate vehicle',
  place_vehicle: 'Place vehicle',
  animation: 'Animation',
  cycle_animation: 'Cycle animation',
  clear_animation: 'Clear animation',
  raise_lower_ped: 'Raise / lower ped',
  raise_lower: 'Raise / lower',
  cycle_model: 'Cycle model',
  toggle_preview_mode: 'Switch adjustment',
  preview_mode_position: 'Height',
  preview_mode_model: 'Model',
  preview_mode_animation: 'Animation',
  toggle_gizmo: 'Fine-tune with gizmo',
  exit: 'Exit placer',
  finish: 'Finish',
  undo: 'Undo last',
  placed: 'Placed',
  debug: 'Copy surface material',
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

function getAdjustmentModeLabel(locales, adjustmentMode) {
  if (adjustmentMode === 'position') return locales.preview_mode_position
  if (adjustmentMode === 'model') return locales.preview_mode_model
  if (adjustmentMode === 'animation') return locales.preview_mode_animation
  return '—'
}

function getArrowActionLabel(locales, adjustmentMode) {
  if (adjustmentMode === 'position') return locales.raise_lower
  if (adjustmentMode === 'model') return locales.cycle_model
  if (adjustmentMode === 'animation') return locales.cycle_animation
  return null
}

function buildControlGroups(locales, options) {
  const {
    pedVerticalAdjust,
    animationCycling,
    adjustmentMode,
    adjustmentModeToggleAvailable,
    gizmoToggleAvailable,
    debugEnabled,
    multiPlace,
    placedCount,
    maxPlacements,
  } = options

  const arrowLabel = getArrowActionLabel(locales, adjustmentMode)

  const position = [
    {
      id: 'rotate',
      keys: ['Scroll'],
      label: pedVerticalAdjust ? locales.rotate_ped : locales.rotate,
    },
  ]

  if (arrowLabel) {
    position.push({
      id: 'arrow-action',
      keys: ['↑ ↓'],
      label: arrowLabel,
    })
  }

  const preview = []

  if (adjustmentModeToggleAvailable) {
    preview.push({
      id: 'adjustment-toggle',
      keys: ['Tab'],
      label: locales.toggle_preview_mode,
      keyActive: true,
      badge: getAdjustmentModeLabel(locales, adjustmentMode),
      showBadgeAlways: true,
    })
  }

  if (animationCycling && adjustmentMode === 'animation') {
    preview.push({
      id: 'clear-animation',
      keys: ['X'],
      label: locales.clear_animation,
    })
  }

  if (gizmoToggleAvailable) {
    preview.push({
      id: 'gizmo-toggle',
      keys: ['G'],
      label: locales.toggle_gizmo,
    })
  }

  const actions = [
    {
      id: 'place',
      keys: ['E'],
      label: pedVerticalAdjust ? locales.place_ped : locales.place,
    },
  ]

  if (multiPlace) {
    actions.push({
      id: 'undo',
      keys: ['Z'],
      label: locales.undo,
    })
  }

  const placedLabel = maxPlacements ? `${placedCount} / ${maxPlacements}` : `${placedCount}`

  actions.push({
    id: 'exit',
    keys: ['Backspace'],
    label: multiPlace ? `${locales.finish} (${placedLabel})` : locales.exit,
  })

  if (debugEnabled) {
    actions.push({
      id: 'debug',
      keys: ['H'],
      label: locales.debug,
    })
  }

  return [
    { id: 'position', title: locales.controls_position, items: position },
    { id: 'preview', title: locales.controls_preview, items: preview },
    { id: 'actions', title: locales.controls_actions, items: actions },
  ].filter((group) => group.items.length > 0)
}

function ControlRow({ control }) {
  const showBadge = control.badge && control.showBadgeAlways

  return (
    <div className={`prop-placer__control${control.active ? ' prop-placer__control--active' : ''}`}>
      <div className="prop-placer__keys" aria-hidden="true">
        {control.keys.map((key) => (
          <kbd
            className={`prop-placer__key${control.keyActive ? ' prop-placer__key--state' : ''}`}
            key={key}
          >
            {key}
            {showBadge ? (
              <span className="prop-placer__key-badge">{control.badge}</span>
            ) : null}
          </kbd>
        ))}
      </div>
      <span className="prop-placer__control-label">{control.label}</span>
    </div>
  )
}

function PropPlacer() {
  const [visible, setVisible] = useState(false)
  const [locales, setLocales] = useState(DEFAULT_LOCALES)
  const [modelLabel, setModelLabel] = useState('')
  const [coords, setCoords] = useState({ x: 0, y: 0, z: 0 })
  const [heading, setHeading] = useState(0)
  const [distance, setDistance] = useState(0)
  const [maxDistance, setMaxDistance] = useState(10)
  const [status, setStatus] = useState('aiming')
  const [debugEnabled, setDebugEnabled] = useState(false)
  const [animationCycling, setAnimationCycling] = useState(false)
  const [modelCycling, setModelCycling] = useState(false)
  const [pedVerticalAdjust, setPedVerticalAdjust] = useState(false)
  const [adjustmentMode, setAdjustmentMode] = useState(null)
  const [adjustmentModeToggleAvailable, setAdjustmentModeToggleAvailable] = useState(false)
  const [gizmoToggleAvailable, setGizmoToggleAvailable] = useState(false)
  const [animationLabel, setAnimationLabel] = useState('')
  const [multiPlace, setMultiPlace] = useState(false)
  const [placedCount, setPlacedCount] = useState(0)
  const [maxPlacements, setMaxPlacements] = useState(null)

  const closePanel = useCallback(() => {
    setVisible(false)
    if (shouldHideRoot()) {
      getRootElement()?.classList.add('hidden')
    }
  }, [])

  const openPanel = useCallback((payload) => {
    getRootElement()?.classList.remove('hidden')
    setLocales(normalizeLocales(payload?.locales))
    setModelLabel(typeof payload?.modelLabel === 'string' ? payload.modelLabel : '')
    setMaxDistance(typeof payload?.maxDistance === 'number' ? payload.maxDistance : 10)
    setDebugEnabled(payload?.debug === true)
    setAnimationCycling(payload?.animationCycling === true)
    setModelCycling(payload?.modelCycling === true)
    setPedVerticalAdjust(payload?.pedVerticalAdjust === true)
    setAdjustmentMode(typeof payload?.adjustmentMode === 'string' ? payload.adjustmentMode : null)
    setAdjustmentModeToggleAvailable(payload?.adjustmentModeToggleAvailable === true)
    setGizmoToggleAvailable(payload?.gizmoToggleAvailable === true)
    setMultiPlace(payload?.multiPlace === true)
    setPlacedCount(typeof payload?.placedCount === 'number' ? payload.placedCount : 0)
    setMaxPlacements(typeof payload?.maxPlacements === 'number' ? payload.maxPlacements : null)
    setAnimationLabel('')
    setStatus('aiming')
    setVisible(true)
  }, [])

  useEffect(() => {
    const handleMessage = (event) => {
      const data = event.data

      if (data?.type === 'placer:open') {
        openPanel(data)
        return
      }

      if (data?.type === 'placer:close') {
        closePanel()
        return
      }

      if (data?.type === 'placer:update') {
        if (typeof data.heading === 'number') setHeading(data.heading)
        if (typeof data.distance === 'number') setDistance(data.distance)
        if (typeof data.maxDistance === 'number') setMaxDistance(data.maxDistance)
        if (typeof data.status === 'string') setStatus(data.status)
        if (typeof data.animationLabel === 'string') setAnimationLabel(data.animationLabel)
        if (typeof data.modelLabel === 'string') setModelLabel(data.modelLabel)
        if (typeof data.adjustmentMode === 'string') setAdjustmentMode(data.adjustmentMode)
        if (typeof data.adjustmentModeToggleAvailable === 'boolean') {
          setAdjustmentModeToggleAvailable(data.adjustmentModeToggleAvailable)
        }
        if (typeof data.pedVerticalAdjust === 'boolean') setPedVerticalAdjust(data.pedVerticalAdjust)
        if (typeof data.gizmoToggleAvailable === 'boolean') {
          setGizmoToggleAvailable(data.gizmoToggleAvailable)
        }
        if (typeof data.multiPlace === 'boolean') setMultiPlace(data.multiPlace)
        if (typeof data.placedCount === 'number') setPlacedCount(data.placedCount)
        if (typeof data.maxPlacements === 'number') setMaxPlacements(data.maxPlacements)
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

    const pendingOpen = takePendingOpen('placer:open')
    if (pendingOpen) openPanel(pendingOpen)

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const controlGroups = useMemo(
    () => buildControlGroups(locales, {
      pedVerticalAdjust,
      animationCycling,
      adjustmentMode,
      adjustmentModeToggleAvailable,
      gizmoToggleAvailable,
      debugEnabled,
      multiPlace,
      placedCount,
      maxPlacements,
    }),
    [
      locales,
      pedVerticalAdjust,
      animationCycling,
      adjustmentMode,
      adjustmentModeToggleAvailable,
      gizmoToggleAvailable,
      debugEnabled,
      multiPlace,
      placedCount,
      maxPlacements,
    ],
  )

  const adjustmentModeLabel = getAdjustmentModeLabel(locales, adjustmentMode)

  const statusLabel = (() => {
    if (status === 'ready') return locales.status_ready
    if (status === 'invalid_material') return locales.status_invalid_material
    if (status === 'too_far') return locales.status_too_far
    return locales.status_aiming
  })()

  const statusClass = status === 'ready'
    ? 'prop-placer__status--success'
    : status === 'too_far'
      ? 'prop-placer__status--warning'
      : status === 'invalid_material'
        ? 'prop-placer__status--error'
        : 'prop-placer__status--info'

  return (
    <div className={`prop-placer${visible ? ' prop-placer--visible' : ''}`} aria-hidden={!visible}>
      <aside className="prop-placer__panel" role="complementary" aria-label={locales.title}>
        <div className="prop-placer__header">
          <div>
            <h2 className="prop-placer__title">{locales.title}</h2>
            <p className="prop-placer__subtitle">
              {modelLabel || locales.subtitle}
            </p>
          </div>
          <span className={`prop-placer__status ${statusClass}`}>{statusLabel}</span>
        </div>

        <div className="prop-placer__stats">
          {multiPlace ? (
            <div className="prop-placer__stat">
              <span className="prop-placer__stat-label">{locales.placed}</span>
              <span className="prop-placer__stat-value">
                {maxPlacements ? `${placedCount} / ${maxPlacements}` : placedCount}
              </span>
            </div>
          ) : null}
          {adjustmentModeToggleAvailable ? (
            <div className="prop-placer__stat">
              <span className="prop-placer__stat-label">{locales.controls_preview}</span>
              <span className="prop-placer__stat-value">{adjustmentModeLabel}</span>
            </div>
          ) : null}
          <div className="prop-placer__stat">
            <span className="prop-placer__stat-label">{locales.position}</span>
            <span className="prop-placer__stat-value">
              {formatCoord(coords.x)}, {formatCoord(coords.y)}, {formatCoord(coords.z)}
            </span>
          </div>
          <div className="prop-placer__stat">
            <span className="prop-placer__stat-label">{locales.heading}</span>
            <span className="prop-placer__stat-value">{formatCoord(heading)}°</span>
          </div>
          <div className="prop-placer__stat">
            <span className="prop-placer__stat-label">{locales.distance}</span>
            <span className="prop-placer__stat-value">{formatCoord(distance)} m</span>
          </div>
          <div className="prop-placer__stat">
            <span className="prop-placer__stat-label">{locales.max_distance}</span>
            <span className="prop-placer__stat-value">{formatCoord(maxDistance)} m</span>
          </div>
          {animationCycling && adjustmentMode === 'animation' ? (
            <div className="prop-placer__stat">
              <span className="prop-placer__stat-label">{locales.animation}</span>
              <span className="prop-placer__stat-value">{animationLabel || '—'}</span>
            </div>
          ) : null}
        </div>

        <div className="prop-placer__controls">
          <p className="prop-placer__controls-title">{locales.controls}</p>
          {controlGroups.map((group) => (
            <section className="prop-placer__control-group" key={group.id} aria-label={group.title}>
              <p className="prop-placer__controls-title">{group.title}</p>
              {group.items.map((control) => (
                <ControlRow key={control.id} control={control} />
              ))}
            </section>
          ))}
        </div>
      </aside>
    </div>
  )
}

export default PropPlacer
