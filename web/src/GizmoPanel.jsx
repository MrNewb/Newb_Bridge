import { useCallback, useEffect, useMemo, useState } from 'react'
import { takePendingOpen, takePendingUpdate } from './placement-message-buffer'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import { ActionKeys, ControlGroup, MetaLine, PlacementPanel, StatusBlock } from './components/placement-panel'
import { Separator } from '@/components/ui/separator'

const DEFAULT_LOCALES = {
  title: 'Object gizmo',
  subtitle: 'LMB drag axes · G toggles cursor & free move',
  mode: 'Mode',
  space: 'Space',
  position: 'Position',
  rotation: 'Rotation',
  controls_heading: 'Controls',
  controls_adjust: 'Adjust',
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
    const pendingUpdate = takePendingUpdate('gizmo:update')
    if (pendingUpdate) handleMessage({ data: pendingUpdate })

    return () => window.removeEventListener('message', handleMessage)
  }, [closePanel, openPanel])

  const spaceLabel = locales[SPACE_LABEL_KEYS[space] || SPACE_LABEL_KEYS.world] || space

  // the keys that adjust the gizmo; the active mode and the cursor state are shown next to their rows
  const adjust = useMemo(
    () => ({
      id: 'adjust',
      title: locales.controls_adjust,
      items: [
        { id: 'drag', keys: 'LMB', label: locales.drag_axis },
        { id: 'cursor', keys: 'G', label: locales.cursor_toggle },
        { id: 'translate', keys: 'W', label: locales.translate, badge: mode === 'Translate' ? locales.mode_translate : undefined },
        { id: 'rotate', keys: 'R', label: locales.rotate_mode, badge: mode === 'Rotate' ? locales.mode_rotate : undefined },
        { id: 'space', keys: 'Q', label: locales.toggle_space, badge: spaceLabel },
        { id: 'snap', keys: 'LAlt', label: locales.snap_ground },
      ],
    }),
    [locales, mode, spaceLabel],
  )
  const closing = useMemo(
    () => [
      { id: 'confirm', keys: 'E', label: locales.confirm },
      { id: 'cancel', keys: 'Backspace', label: locales.cancel },
    ],
    [locales],
  )

  return (
    <PlacementPanel
      name="gizmo-panel"
      visible={visible}
      label={locales.title}
      title={locales.title}
      subtitle={entityLabel || locales.subtitle}
      footer={<ActionKeys items={closing} />}
    >
      <StatusBlock status={cursorActive ? 'ready' : 'aiming'} title={cursorActive ? locales.cursor_on : locales.cursor_off} />

      <div className="prop-placer__meta flex flex-col gap-1 text-xs">
        <MetaLine label={locales.position} value={`${formatCoord(position.x)}, ${formatCoord(position.y)}, ${formatCoord(position.z)}`} />
        <MetaLine label={locales.rotation} value={`${formatCoord(rotation.x)}, ${formatCoord(rotation.y)}, ${formatCoord(rotation.z)}`} />
      </div>

      <Separator />

      <div className="flex flex-col gap-3">
        <p className="m-0 text-sm font-semibold text-foreground">{locales.controls_heading}</p>
        <ControlGroup group={adjust} showTitle={false} />
      </div>
    </PlacementPanel>
  )
}

export default GizmoPanel
