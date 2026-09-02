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
} from './components/overlay-panel'

const DEFAULT_LOCALES = {
  title: 'Object gizmo',
  subtitle: 'LMB drag axes · G toggles cursor & free move',
  mode: 'Mode',
  space: 'Space',
  position: 'Position',
  rotation: 'Rotation',
  controls_heading: 'Controls',
  cursor_toggle: 'Toggle cursor / free move',
  translate: 'Switch to translate',
  rotate_mode: 'Switch to rotate',
  toggle_space: 'Toggle local / world axes',
  snap_ground: 'Snap to ground',
  confirm: 'Confirm placement',
  cancel: 'Cancel',
  drag_axis: 'Drag gizmo axis',
  cursor_on: 'Cursor on',
  cursor_off: 'Free move',
  space_world: 'World',
  space_relative: 'Relative',
  mode_translate: 'Translate',
  mode_rotate: 'Rotate',
}

const MODE_NAME_KEYS = {
  Translate: 'mode_translate',
  Rotate: 'mode_rotate',
}

const SPACE_LABEL_KEYS = {
  world: 'space_world',
  relative: 'space_relative',
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

function GizmoPanel() {
  const [visible, setVisible] = useState(false)
  const [locales, setLocales] = useState(DEFAULT_LOCALES)
  const [entityLabel, setEntityLabel] = useState('')
  const [mode, setMode] = useState('Translate')
  const [space, setSpace] = useState('world')
  const [cursorActive, setCursorActive] = useState(true)
  const [position, setPosition] = useState({ x: 0, y: 0, z: 0 })
  const [rotation, setRotation] = useState({ x: 0, y: 0, z: 0 })

  const closePanel = useCallback(() => {
    setVisible(false)
    hideRootIfIdle()
  }, [])

  const openPanel = useCallback((payload) => {
    showRoot()
    setLocales(normalizeLocales(payload?.locales))
    setEntityLabel(typeof payload?.entityLabel === 'string' ? payload.entityLabel : '')
    setMode(typeof payload?.mode === 'string' ? payload.mode : 'Translate')
    setSpace(payload?.space === 'relative' ? 'relative' : 'world')
    setCursorActive(payload?.cursorActive !== false)
    setVisible(true)
  }, [])

  useEffect(() => {
    const handleMessage = (event) => {
      const data = event.data

      if (data?.type === 'gizmo:open') {
        openPanel(data)
        return
      }

      if (data?.type === 'gizmo:close') {
        closePanel()
        return
      }

      if (data?.type === 'gizmo:update') {
        if (typeof data.mode === 'string') setMode(data.mode)
        if (typeof data.space === 'string') setSpace(data.space)
        if (typeof data.cursorActive === 'boolean') setCursorActive(data.cursorActive)
        if (data.position && typeof data.position === 'object') {
          setPosition({
            x: typeof data.position.x === 'number' ? data.position.x : 0,
            y: typeof data.position.y === 'number' ? data.position.y : 0,
            z: typeof data.position.z === 'number' ? data.position.z : 0,
          })
        }
        if (data.rotation && typeof data.rotation === 'object') {
          setRotation({
            x: typeof data.rotation.x === 'number' ? data.rotation.x : 0,
            y: typeof data.rotation.y === 'number' ? data.rotation.y : 0,
            z: typeof data.rotation.z === 'number' ? data.rotation.z : 0,
          })
        }
      }
    }

    window.addEventListener('message', handleMessage)

    const pendingOpen = takePendingOpen('gizmo:open')
    if (pendingOpen) openPanel(pendingOpen)

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const modeName = locales[MODE_NAME_KEYS[mode] || MODE_NAME_KEYS.Translate] || mode
  const spaceLabel = locales[SPACE_LABEL_KEYS[space] || SPACE_LABEL_KEYS.world] || space

  const controls = useMemo(() => {
    const items = [
      { id: 'drag', key: 'LMB', label: locales.drag_axis },
      {
        id: 'cursor',
        key: 'G',
        label: locales.cursor_toggle,
        active: cursorActive,
        badge: cursorActive ? locales.cursor_on : locales.cursor_off,
        showBadgeAlways: true,
      },
      {
        id: 'translate',
        key: 'W',
        label: locales.translate,
        active: mode === 'Translate',
        badge: mode === 'Translate' ? locales.mode_translate : null,
      },
      {
        id: 'rotate',
        key: 'R',
        label: locales.rotate_mode,
        active: mode === 'Rotate',
        badge: mode === 'Rotate' ? locales.mode_rotate : null,
      },
      {
        id: 'space',
        key: 'Q',
        label: locales.toggle_space,
        active: false,
        badge: spaceLabel,
        showBadgeAlways: true,
        keyActive: true,
      },
      { id: 'snap', key: 'LAlt', label: locales.snap_ground },
      { id: 'confirm', key: 'E', label: locales.confirm },
      { id: 'cancel', key: 'Backspace', label: locales.cancel },
    ]

    return items
  }, [cursorActive, locales, mode, spaceLabel])

  return (
    <OverlayShell visible={visible} name="gizmo-panel" label={locales.title}>
      <OverlayHeader
        title={locales.title}
        subtitle={entityLabel || locales.subtitle}
        status={cursorActive ? locales.cursor_on : locales.cursor_off}
        statusTone={cursorActive ? 'success' : 'info'}
      />
      <OverlayStats>
        <OverlayStat label={locales.mode} value={modeName} />
        <OverlayStat label={locales.space} value={spaceLabel} />
        <OverlayStat
          wide
          label={locales.position}
          value={`${formatCoord(position.x)}, ${formatCoord(position.y)}, ${formatCoord(position.z)}`}
        />
        <OverlayStat
          wide
          label={locales.rotation}
          value={`${formatCoord(rotation.x)}, ${formatCoord(rotation.y)}, ${formatCoord(rotation.z)}`}
        />
      </OverlayStats>
      <OverlayControls title={locales.controls_heading}>
        {controls.map((control) => {
          const showBadge = control.badge && (control.active || control.showBadgeAlways)
          const keyTone = control.active ? 'success' : control.keyActive ? 'info' : undefined
          return (
            <OverlayControl
              key={control.id}
              active={control.active}
              keys={control.key}
              label={control.label}
              badge={showBadge ? control.badge : undefined}
              keyTone={keyTone}
            />
          )
        })}
      </OverlayControls>
    </OverlayShell>
  )
}

export default GizmoPanel
