import { useCallback, useEffect, useMemo, useState } from 'react'
import { takePendingOpen, takePendingUpdate } from './placement-message-buffer'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import { Kbd } from '@/components/ui/kbd'
import { Separator } from '@/components/ui/separator'
import { ActionKeys, ControlGroup, MetaLine, PlacementPanel, StatusBlock } from './components/placement-panel'

const DEFAULT_LOCALES = {
  title: 'Zone creator',
  mode_edit: 'Editing',
  mode_camera: 'Camera',
  mode_onfoot: 'On foot',
  step: 'Step size',
  heading: 'Heading',
  height: 'Height',
  width: 'Width',
  length: 'Length',
  radius: 'Radius',
  points: 'Points',
  size: 'Size',
  distance: 'From center',
  controls_heading: 'Controls',
  controls_size: 'Size and points',
  controls_mode: 'Camera',
  controls_actions: 'Actions',
  toggle_mode: 'Toggle edit / camera',
  scroll_step: 'Change step size',
  move_cursor: 'Fly camera',
  move_vertical: 'Move camera up / down',
  move_faster: 'Move faster',
  height_scroll: 'Adjust height',
  width_scroll: 'Adjust width',
  length_scroll: 'Adjust length',
  radius_scroll: 'Adjust radius',
  rotate: 'Rotate heading',
  add_point: 'Add polygon point',
  undo_point: 'Undo last point',
  lmb: 'LMB',
  rmb: 'RMB',
  movement_free: 'Move freely',
  movement_locked: 'Locked in place',
  toggle_movement: 'Toggle free movement',
  swap_mode: 'Fly / on foot',
  confirm: 'Finish zone',
  confirm_next: 'Place zone',
  finish: 'Finish',
  undo: 'Undo last zone',
  cancel: 'Cancel',
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

function ZoneCreatorPanel() {
  const [visible, setVisible] = useState(false)
  const [locales, setLocales] = useState(DEFAULT_LOCALES)
  const [zoneType, setZoneType] = useState('poly')
  const [zoneName, setZoneName] = useState('')
  const [placementMode, setPlacementMode] = useState('freecam')
  const [controlsActive, setControlsActive] = useState(true)
  const [step, setStep] = useState({ distance: 1, rotation: 5 })
  const [heading, setHeading] = useState(0)
  const [height, setHeight] = useState(4)
  const [width, setWidth] = useState(4)
  const [length, setLength] = useState(4)
  const [pointCount, setPointCount] = useState(0)
  const [allowMovement, setAllowMovement] = useState(true)
  const [movementToggle, setMovementToggle] = useState(true)
  const [movementToggleKey, setMovementToggleKey] = useState('B')
  const [modeToggleKey, setModeToggleKey] = useState('F')
  const [multiPlace, setMultiPlace] = useState(false)
  const [placedCount, setPlacedCount] = useState(0)

  const closePanel = useCallback(() => {
    setVisible(false)
    hideRootIfIdle()
  }, [])

  const openPanel = useCallback((payload) => {
    showRoot()
    setLocales(normalizeLocales(payload?.locales))
    setZoneType(typeof payload?.zoneType === 'string' ? payload.zoneType : 'poly')
    setZoneName(typeof payload?.zoneName === 'string' ? payload.zoneName : '')
    setPlacementMode(typeof payload?.placementMode === 'string' ? payload.placementMode : 'freecam')
    setAllowMovement(payload?.allowMovement !== false)
    setMovementToggle(payload?.movementToggle !== false)
    setMovementToggleKey(typeof payload?.movementToggleKey === 'string' ? payload.movementToggleKey : 'B')
    setModeToggleKey(typeof payload?.modeToggleKey === 'string' ? payload.modeToggleKey : 'F')
    setMultiPlace(payload?.multiPlace === true)
    setPlacedCount(typeof payload?.placedCount === 'number' ? payload.placedCount : 0)
    setVisible(true)
  }, [])

  useEffect(() => {
    const handleMessage = (event) => {
      const data = event.data

      if (data?.type === 'zoneCreator:open') {
        openPanel(data)
        return
      }

      if (data?.type === 'zoneCreator:close') {
        closePanel()
        return
      }

      if (data?.type === 'zoneCreator:update') {
        if (typeof data.zoneType === 'string') setZoneType(data.zoneType)
        if (typeof data.zoneName === 'string') setZoneName(data.zoneName)
        if (typeof data.placementMode === 'string') setPlacementMode(data.placementMode)
        if (typeof data.controlsActive === 'boolean') setControlsActive(data.controlsActive)
        if (data.step && typeof data.step === 'object') {
          setStep({
            distance: typeof data.step.distance === 'number' ? data.step.distance : 1,
            rotation: typeof data.step.rotation === 'number' ? data.step.rotation : 5,
          })
        }
        if (typeof data.heading === 'number') setHeading(data.heading)
        if (typeof data.height === 'number') setHeight(data.height)
        if (typeof data.width === 'number') setWidth(data.width)
        if (typeof data.length === 'number') setLength(data.length)
        if (typeof data.pointCount === 'number') setPointCount(data.pointCount)
        if (typeof data.allowMovement === 'boolean') setAllowMovement(data.allowMovement)
        if (typeof data.movementToggle === 'boolean') setMovementToggle(data.movementToggle)
        if (typeof data.movementToggleKey === 'string') setMovementToggleKey(data.movementToggleKey)
        if (typeof data.modeToggleKey === 'string') setModeToggleKey(data.modeToggleKey)
        if (typeof data.multiPlace === 'boolean') setMultiPlace(data.multiPlace)
        if (typeof data.placedCount === 'number') setPlacedCount(data.placedCount)
      }
    }

    window.addEventListener('message', handleMessage)

    const pendingOpen = takePendingOpen('zoneCreator:open')
    if (pendingOpen) openPanel(pendingOpen)
    const pendingUpdate = takePendingUpdate('zoneCreator:update')
    if (pendingUpdate) handleMessage({ data: pendingUpdate })

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const statusLabel = useMemo(() => {
    if (placementMode === 'onfoot') return locales.mode_onfoot
    return controlsActive ? locales.mode_edit : locales.mode_camera
  }, [controlsActive, locales, placementMode])

  // scroll always changes the zone's main size and Shift+Scroll always changes the step, for every zone type
  const groups = useMemo(() => {
    const size = []
    const mode = []

    if (zoneType === 'poly') {
      if (placementMode === 'freecam') {
        mode.push({ key: 'X', label: locales.toggle_mode })
      }
      size.push({ key: 'Scroll', label: locales.height_scroll })
      size.push({ key: 'Shift+Scroll', label: locales.scroll_step })
      size.push({ key: locales.lmb, label: locales.add_point })
      size.push({ key: locales.rmb, label: locales.undo_point })

      if (placementMode === 'freecam' && !controlsActive) {
        mode.push({ key: 'WASD', label: locales.move_cursor })
        mode.push({ key: 'Q/Ctrl', label: locales.move_vertical })
        mode.push({ key: 'Shift', label: locales.move_faster })
      }
    } else if (zoneType === 'box') {
      size.push({ key: 'Scroll', label: locales.height_scroll })
      size.push({ key: 'Shift+Scroll', label: locales.scroll_step })
      size.push({ key: 'Ctrl+Scroll', label: locales.width_scroll })
      size.push({ key: 'Alt+Scroll', label: locales.length_scroll })
      size.push({ key: '← →', label: locales.rotate })
    } else {
      size.push({ key: 'Scroll', label: locales.radius_scroll })
      size.push({ key: 'Shift+Scroll', label: locales.scroll_step })
    }

    // only polygon zones can swap between flying and on foot
    if (zoneType === 'poly') mode.push({ key: modeToggleKey, label: locales.swap_mode })

    const actions = [{ key: 'E', label: multiPlace ? locales.confirm_next : locales.confirm }]
    if (multiPlace) {
      actions.push({ key: 'Z', label: locales.undo })
    }
    actions.push({
      key: 'Backspace',
      label: multiPlace ? `${locales.finish} (${placedCount})` : locales.cancel,
    })

    return {
      scrolling: [
        { id: 'size', title: locales.controls_size, items: size },
        { id: 'mode', title: locales.controls_mode, items: mode },
      ],
      actions: [{ id: 'actions', title: locales.controls_actions, items: actions }],
    }
  }, [controlsActive, locales, modeToggleKey, multiPlace, placedCount, placementMode, zoneType])

  const needsPoints = zoneType === 'poly' && pointCount < 3

  // the shared rows want { id, keys, label }
  const { scrollingGroups, actionGroup } = useMemo(() => {
    const shape = (group) => ({
      ...group,
      items: group.items.map((item) => ({ id: `${item.key}-${item.label}`, keys: item.key, label: item.label })),
    })
    return {
      scrollingGroups: groups.scrolling.map(shape).filter((group) => group.items.length > 0),
      actionGroup: shape(groups.actions[0]),
    }
  }, [groups])

  const sizeLine = zoneType === 'box' ? `${formatCoord(width)} × ${formatCoord(length)} × ${formatCoord(height)}` : formatCoord(height)
  const sizeLabel = zoneType === 'box'
    ? `${locales.width} × ${locales.length} × ${locales.height}`
    : zoneType === 'sphere'
      ? locales.radius
      : locales.height

  return (
    <PlacementPanel
      name="zone-creator"
      visible={visible}
      label={locales.title}
      title={locales.title}
      subtitle={zoneName}
      footer={<ActionKeys items={actionGroup.items} />}
    >
      <StatusBlock status="aiming" title={statusLabel} />

      <div className="prop-placer__meta flex flex-col gap-1 text-xs">
        <MetaLine label={locales.step} value={`${formatCoord(step.distance)}m / ${formatCoord(step.rotation)}°`} />
        <MetaLine label={sizeLabel} value={sizeLine} />
        {zoneType === 'box' ? <MetaLine label={locales.heading} value={`${Math.round(heading)}°`} /> : null}
        {zoneType === 'poly' ? <MetaLine label={locales.points} value={needsPoints ? `${pointCount} (3+)` : pointCount} /> : null}
      </div>

      {placementMode === 'onfoot' && movementToggle ? (
        <div className="flex items-center gap-2">
          <Kbd className="text-foreground" aria-hidden="true">{movementToggleKey}</Kbd>
          <span className="text-sm text-foreground">{locales.toggle_movement}</span>
          <span className="ml-auto text-xs font-medium text-muted-foreground">{allowMovement ? locales.movement_free : locales.movement_locked}</span>
        </div>
      ) : null}

      <Separator />

      <div className="flex flex-col gap-3">
        <p className="m-0 text-sm font-semibold text-foreground">{locales.controls_heading}</p>
        {scrollingGroups.map((group) => (
          <ControlGroup key={group.id} group={group} showTitle={scrollingGroups.length > 1} />
        ))}
      </div>
    </PlacementPanel>
  )
}

export default ZoneCreatorPanel
