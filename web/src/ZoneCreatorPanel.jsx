import { useCallback, useEffect, useMemo, useState } from 'react'
import { takePendingOpen } from './placement-message-buffer'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import {
  OverlayControls,
  OverlayControl,
  OverlayHeader,
  OverlayShell,
  OverlayStat,
  OverlayStats,
  OverlayToggle,
} from './components/overlay-panel'

const DEFAULT_LOCALES = {
  title: 'Zone creator',
  subtitle_poly: 'Polygon zone',
  subtitle_box: 'Box zone',
  subtitle_sphere: 'Sphere zone',
  zone_name: 'Zone',
  mode_edit: 'Editing',
  mode_camera: 'Camera',
  mode_onfoot: 'On foot',
  step: 'Step size',
  position: 'Cursor position',
  heading: 'Heading',
  height: 'Height',
  width: 'Width',
  length: 'Length',
  radius: 'Radius',
  points: 'Points',
  bounds: 'Max area',
  distance: 'From center',
  controls_heading: 'Controls',
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
  center_position: 'Zone center',
  allow_movement: 'Free movement',
  movement_free: 'Move freely',
  movement_locked: 'Locked in place',
  toggle_movement: 'Toggle free movement',
  swap_mode: 'Fly / on foot',
  confirm: 'Finish zone',
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
  const [position, setPosition] = useState({ x: 0, y: 0, z: 0 })
  const [heading, setHeading] = useState(0)
  const [height, setHeight] = useState(4)
  const [width, setWidth] = useState(4)
  const [length, setLength] = useState(4)
  const [pointCount, setPointCount] = useState(0)
  const [maxDistance, setMaxDistance] = useState(50)
  const [distanceFromCenter, setDistanceFromCenter] = useState(0)
  const [allowMovement, setAllowMovement] = useState(true)
  const [movementToggle, setMovementToggle] = useState(true)
  const [movementToggleKey, setMovementToggleKey] = useState('B')
  const [modeToggleKey, setModeToggleKey] = useState('F')

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
    setMaxDistance(typeof payload?.maxDistance === 'number' ? payload.maxDistance : 50)
    setAllowMovement(payload?.allowMovement !== false)
    setMovementToggle(payload?.movementToggle !== false)
    setMovementToggleKey(typeof payload?.movementToggleKey === 'string' ? payload.movementToggleKey : 'B')
    setModeToggleKey(typeof payload?.modeToggleKey === 'string' ? payload.modeToggleKey : 'F')
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
        if (data.position && typeof data.position === 'object') {
          setPosition({
            x: typeof data.position.x === 'number' ? data.position.x : 0,
            y: typeof data.position.y === 'number' ? data.position.y : 0,
            z: typeof data.position.z === 'number' ? data.position.z : 0,
          })
        }
        if (typeof data.heading === 'number') setHeading(data.heading)
        if (typeof data.height === 'number') setHeight(data.height)
        if (typeof data.width === 'number') setWidth(data.width)
        if (typeof data.length === 'number') setLength(data.length)
        if (typeof data.pointCount === 'number') setPointCount(data.pointCount)
        if (typeof data.maxDistance === 'number') setMaxDistance(data.maxDistance)
        if (typeof data.distanceFromCenter === 'number') setDistanceFromCenter(data.distanceFromCenter)
        if (typeof data.allowMovement === 'boolean') setAllowMovement(data.allowMovement)
        if (typeof data.movementToggle === 'boolean') setMovementToggle(data.movementToggle)
        if (typeof data.movementToggleKey === 'string') setMovementToggleKey(data.movementToggleKey)
        if (typeof data.modeToggleKey === 'string') setModeToggleKey(data.modeToggleKey)
      }
    }

    window.addEventListener('message', handleMessage)

    const pendingOpen = takePendingOpen('zoneCreator:open')
    if (pendingOpen) openPanel(pendingOpen)

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const subtitle = useMemo(() => {
    if (zoneType === 'box') return locales.subtitle_box
    if (zoneType === 'sphere') return locales.subtitle_sphere
    return locales.subtitle_poly
  }, [locales, zoneType])

  const statusLabel = useMemo(() => {
    if (placementMode === 'onfoot') return locales.mode_onfoot
    return controlsActive ? locales.mode_edit : locales.mode_camera
  }, [controlsActive, locales, placementMode])

  const positionLabel = useMemo(() => {
    if (zoneType === 'sphere' || zoneType === 'box') {
      return locales.center_position
    }

    return locales.position
  }, [locales, zoneType])

  const controls = useMemo(() => {
    const items = []

    if (zoneType === 'poly') {
      if (placementMode === 'freecam') {
        items.push({ key: 'X', label: locales.toggle_mode })
      }
      items.push({ key: 'Scroll', label: locales.scroll_step })
      items.push({ key: 'Shift+Scroll', label: locales.height_scroll })
      items.push({ key: locales.lmb, label: locales.add_point })
      items.push({ key: locales.rmb, label: locales.undo_point })

      if (placementMode === 'freecam' && !controlsActive) {
        items.push({ key: 'WASD', label: locales.move_cursor })
        items.push({ key: 'Q/Ctrl', label: locales.move_vertical })
        items.push({ key: 'Shift', label: locales.move_faster })
      }
    } else if (zoneType === 'box') {
      items.push({ key: 'Scroll', label: locales.height_scroll })
      items.push({ key: 'Shift+Scroll', label: locales.scroll_step })
      items.push({ key: 'Ctrl+Scroll', label: locales.width_scroll })
      items.push({ key: 'Alt+Scroll', label: locales.length_scroll })
      items.push({ key: '← →', label: locales.rotate })
    } else {
      items.push({ key: 'Scroll', label: locales.radius_scroll })
      items.push({ key: 'Shift+Scroll', label: locales.scroll_step })
    }

    items.push({ key: modeToggleKey, label: locales.swap_mode })
    items.push({ key: 'E', label: locales.confirm })
    items.push({ key: 'Backspace', label: locales.cancel })

    return items
  }, [controlsActive, locales, modeToggleKey, placementMode, zoneType])

  return (
    <OverlayShell visible={visible} name="zone-creator" label={locales.title}>
      <OverlayHeader
        title={locales.title}
        subtitle={subtitle}
        extra={zoneName ? (
          <p className="overlay-section-label mt-1">{locales.zone_name}: {zoneName}</p>
        ) : null}
        status={statusLabel}
        statusTone={placementMode === 'onfoot' ? 'onfoot' : controlsActive ? 'edit' : 'camera'}
      />
      <OverlayStats>
        <OverlayStat
          label={locales.step}
          value={`${formatCoord(step.distance)}m / ${formatCoord(step.rotation)}°`}
        />
        {placementMode === 'freecam' ? (
          <OverlayStat label={locales.bounds} value={`${formatCoord(maxDistance)}m`} />
        ) : null}
        <OverlayStat
          wide
          label={positionLabel}
          value={`${formatCoord(position.x)}, ${formatCoord(position.y)}, ${formatCoord(position.z)}`}
        />
        {placementMode === 'freecam' ? (
          <OverlayStat label={locales.distance} value={`${formatCoord(distanceFromCenter)}m`} />
        ) : null}
        {zoneType === 'poly' ? (
          <OverlayStat label={locales.points} value={pointCount} />
        ) : null}
        {zoneType === 'box' ? (
          <>
            <OverlayStat label={locales.heading} value={`${formatCoord(heading)}°`} />
            <OverlayStat label={locales.width} value={formatCoord(width)} />
            <OverlayStat label={locales.length} value={formatCoord(length)} />
            <OverlayStat label={locales.height} value={formatCoord(height)} />
          </>
        ) : null}
        {zoneType === 'sphere' ? (
          <OverlayStat label={locales.radius} value={formatCoord(height)} />
        ) : null}
        {zoneType === 'poly' ? (
          <OverlayStat label={locales.height} value={formatCoord(height)} />
        ) : null}
      </OverlayStats>
      {placementMode === 'onfoot' && movementToggle ? (
        <OverlayToggle
          label={locales.toggle_movement}
          pressed={allowMovement}
          onLabel={locales.movement_free}
          offLabel={locales.movement_locked}
          shortcut={movementToggleKey}
        />
      ) : null}
      <OverlayControls title={locales.controls_heading}>
        {controls.map((control) => (
          <OverlayControl
            key={`${control.key}-${control.label}`}
            keys={control.key}
            label={control.label}
          />
        ))}
      </OverlayControls>
    </OverlayShell>
  )
}

export default ZoneCreatorPanel
