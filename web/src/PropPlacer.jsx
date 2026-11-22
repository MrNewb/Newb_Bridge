import { useCallback, useEffect, useMemo, useState } from 'react'
import { takePendingOpen, takePendingUpdate } from './placement-message-buffer'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import { ActionKeys, ControlGroup, MetaLine, PlacementPanel, Range, Stat, StatusBlock } from './components/placement-panel'
import { Separator } from '@/components/ui/separator'

const DEFAULT_LOCALES = {
  title: 'Prop placement',
  subtitle: 'Aim at a surface to preview',
  status_ready: 'Ready',
  status_invalid_material: 'Invalid surface',
  status_too_far: 'Too far',
  status_aiming: 'Aiming…',
  hint_aiming: 'Aim at a surface to preview',
  hint_ready: 'Press the place key to put it here',
  hint_too_far: 'Move closer to place it',
  hint_invalid_material: 'Aim at solid ground',
  position: 'Position',
  heading: 'Heading',
  distance: 'Distance',
  controls: 'Controls',
  controls_position: 'Position',
  controls_preview: 'Preview',
  controls_actions: 'Actions',
  rotate: 'Rotate prop',
  place: 'Place prop',
  animation: 'Animation',
  cycle_animation: 'Cycle animation',
  clear_animation: 'Clear animation',
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
  debug: 'Copy surface material',
}

function formatCoord(value) {
  if (typeof value !== 'number' || Number.isNaN(value)) return '—'
  return value.toFixed(2)
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
      label: locales.rotate,
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
      label: locales.place,
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
  ]
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
  const [adjustmentMode, setAdjustmentMode] = useState(null)
  const [adjustmentModeToggleAvailable, setAdjustmentModeToggleAvailable] = useState(false)
  const [gizmoToggleAvailable, setGizmoToggleAvailable] = useState(false)
  const [animationLabel, setAnimationLabel] = useState('')
  const [multiPlace, setMultiPlace] = useState(false)
  const [placedCount, setPlacedCount] = useState(0)
  const [maxPlacements, setMaxPlacements] = useState(null)

  const closePanel = useCallback(() => {
    setVisible(false)
    hideRootIfIdle()
  }, [])

  const openPanel = useCallback((payload) => {
    showRoot()
    setLocales(normalizeLocales(payload?.locales))
    setDebugEnabled(payload?.debug === true)
    setAnimationCycling(payload?.animationCycling === true)
    setAdjustmentMode(typeof payload?.adjustmentMode === 'string' ? payload.adjustmentMode : null)
    setAdjustmentModeToggleAvailable(payload?.adjustmentModeToggleAvailable === true)
    setGizmoToggleAvailable(payload?.gizmoToggleAvailable === true)
    setMultiPlace(payload?.multiPlace === true)
    setPlacedCount(typeof payload?.placedCount === 'number' ? payload.placedCount : 0)
    setMaxPlacements(typeof payload?.maxPlacements === 'number' ? payload.maxPlacements : null)
    setModelLabel(typeof payload?.modelLabel === 'string' ? payload.modelLabel : '')
    setMaxDistance(typeof payload?.maxDistance === 'number' ? payload.maxDistance : 10)
    setCoords({ x: 0, y: 0, z: 0 })
    setHeading(0)
    setDistance(0)
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
        if (typeof data.modelLabel === 'string') setModelLabel(data.modelLabel)
        if (data.coords && typeof data.coords === 'object') {
          const next = {
            x: typeof data.coords.x === 'number' ? data.coords.x : 0,
            y: typeof data.coords.y === 'number' ? data.coords.y : 0,
            z: typeof data.coords.z === 'number' ? data.coords.z : 0,
          }
          setCoords((current) => (current.x === next.x && current.y === next.y && current.z === next.z ? current : next))
        }
        if (typeof data.status === 'string') setStatus(data.status)
        if (typeof data.animationLabel === 'string') setAnimationLabel(data.animationLabel)
        if (typeof data.adjustmentMode === 'string') setAdjustmentMode(data.adjustmentMode)
        if (typeof data.adjustmentModeToggleAvailable === 'boolean') {
          setAdjustmentModeToggleAvailable(data.adjustmentModeToggleAvailable)
        }
        if (typeof data.gizmoToggleAvailable === 'boolean') {
          setGizmoToggleAvailable(data.gizmoToggleAvailable)
        }
        if (typeof data.multiPlace === 'boolean') setMultiPlace(data.multiPlace)
        if (typeof data.placedCount === 'number') setPlacedCount(data.placedCount)
        if (typeof data.maxPlacements === 'number') setMaxPlacements(data.maxPlacements)
      }
    }

    window.addEventListener('message', handleMessage)

    const pendingOpen = takePendingOpen('placer:open')
    if (pendingOpen) openPanel(pendingOpen)
    const pendingUpdate = takePendingUpdate('placer:update')
    if (pendingUpdate) handleMessage({ data: pendingUpdate })

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const controlGroups = useMemo(
    () => buildControlGroups(locales, {
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

  const statusLabel = (() => {
    if (status === 'ready') return locales.status_ready
    if (status === 'invalid_material') return locales.status_invalid_material
    if (status === 'too_far') return locales.status_too_far
    return locales.status_aiming
  })()

  const hint = status === 'ready'
    ? locales.hint_ready
    : status === 'too_far'
      ? locales.hint_too_far
      : status === 'invalid_material'
        ? locales.hint_invalid_material
        : locales.hint_aiming

  const actionGroup = controlGroups.find((group) => group.id === 'actions')
  const scrollingGroups = controlGroups.filter((group) => group.id !== 'actions' && group.items.length > 0)

  return (
    <PlacementPanel
      name="prop-placer"
      visible={visible}
      label={locales.title}
      title={locales.title}
      subtitle={modelLabel || locales.subtitle}
      footer={actionGroup ? <ActionKeys items={actionGroup.items} /> : null}
    >
      <StatusBlock status={status} title={statusLabel} text={hint} />

      <Range label={locales.distance} value={distance} max={maxDistance} status={status} />

      <div className="prop-placer__meta flex flex-col gap-1 text-xs">
        <MetaLine label={locales.position} value={`${formatCoord(coords.x)}, ${formatCoord(coords.y)}, ${formatCoord(coords.z)}`} />
        <MetaLine label={locales.heading} value={`${Math.round(heading)}°`} />
      </div>

      {animationCycling && adjustmentMode === 'animation' ? <Stat label={locales.animation} value={animationLabel || '—'} /> : null}

      <Separator />

      <div className="flex flex-col gap-3">
        <p className="m-0 text-sm font-semibold text-foreground">{locales.controls}</p>
        {scrollingGroups.map((group) => (
          <ControlGroup key={group.id} group={group} showTitle={scrollingGroups.length > 1} />
        ))}
      </div>
    </PlacementPanel>
  )
}

export default PropPlacer
