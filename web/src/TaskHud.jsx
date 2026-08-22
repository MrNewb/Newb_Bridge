import { useEffect, useState } from 'react'
import './task-hud.css'

function getRoot() {
  return document.getElementById('root')
}

function otherUiOpen() {
  return document.querySelector('.dialogue-container.is-open')
    || document.querySelector('.prop-placer--visible')
    || document.querySelector('.gizmo-panel--visible')
    || document.querySelector('.zone-creator--visible')
    || document.querySelector('.dui-creator--visible')
    || document.querySelector('.task-group-menu')
}

function maybeHideRoot() {
  requestAnimationFrame(() => {
    if (!otherUiOpen() && !document.querySelector('.task-hud--visible')) {
      getRoot()?.classList.add('hidden')
    }
  })
}

function progressText(task) {
  if (typeof task.value === 'string' && task.value.trim()) return task.value.trim()
  if (typeof task.current === 'number' && typeof task.max === 'number') {
    return `${task.current}/${task.max}`
  }
  if (typeof task.current === 'number') return String(task.current)
  return ''
}

function parseHudType(value) {
  if (value === 'weight' || value === 'gather' || value === 'dense') return value
  return 'dense'
}

function parsePayload(data) {
  if (!data || typeof data !== 'object') return null

  const title = typeof data.title === 'string' ? data.title.trim() : ''
  if (!title) return null

  const tasks = []
  if (Array.isArray(data.tasks)) {
    for (let i = 0; i < data.tasks.length; i++) {
      const entry = data.tasks[i]
      if (!entry || typeof entry.label !== 'string' || !entry.label.trim()) continue
      tasks.push({
        id: typeof entry.id === 'string' ? entry.id : `row-${i}`,
        label: entry.label.trim(),
        current: typeof entry.current === 'number' ? entry.current : undefined,
        max: typeof entry.max === 'number' ? entry.max : undefined,
        value: typeof entry.value === 'string' ? entry.value : undefined,
      })
    }
  }

  const hideKey = typeof data.hideKey === 'string' && data.hideKey.trim()
    ? data.hideKey.trim()
    : 'H'
  const hideLabel = typeof data.hideLabel === 'string' && data.hideLabel.trim()
    ? data.hideLabel.trim()
    : 'Hide'

  return {
    title,
    description: typeof data.description === 'string' ? data.description : '',
    position: data.position === 'right' ? 'right' : 'left',
    type: parseHudType(data.type),
    expanded: data.expanded !== false,
    tasks,
    hideKey,
    hideLabel,
    complete: data.complete === true,
    durationMs: typeof data.durationMs === 'number' && data.durationMs > 0
      ? data.durationMs
      : 30000,
  }
}

export default function TaskHud() {
  const [payload, setPayload] = useState(null)
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const onMessage = (event) => {
      const msg = event.data
      if (!msg?.action) return

      if (msg.action === 'taskHud:show' || msg.action === 'taskHud:complete') {
        const next = parsePayload(msg.data)
        if (!next) return
        if (msg.action === 'taskHud:complete') next.complete = true
        getRoot()?.classList.remove('hidden')
        setPayload(next)
        setOpen(true)
        return
      }

      if (msg.action === 'taskHud:update') {
        const next = parsePayload(msg.data)
        if (!next) return
        setPayload(next)
        return
      }

      if (msg.action === 'taskHud:collapse') {
        setOpen(false)
        maybeHideRoot()
        return
      }

      if (msg.action === 'taskHud:hide') {
        setOpen(false)
        setPayload(null)
        maybeHideRoot()
      }
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  if (!open || !payload) return null

  const showGatheredRows = payload.type !== 'gather' || payload.expanded
  const plateClass = [
    'task-hud',
    `task-hud--${payload.position}`,
    `task-hud--${payload.type}`,
    'task-hud--visible',
    payload.complete ? 'task-hud--complete' : '',
    payload.type === 'gather' && !payload.expanded && !payload.complete ? 'task-hud--resting' : '',
  ].filter(Boolean).join(' ')

  return (
    <aside className={plateClass} aria-label={payload.title}>
      <div className="task-hud__plate">
        <header className="task-hud__header">
          <h2 className="task-hud__title">{payload.title}</h2>
          <div className="task-hud__rule" aria-hidden="true" />
        </header>

        <div className="task-hud__body">
          {payload.complete ? (
            <>
              {payload.description ? (
                <p className="task-hud__description">{payload.description}</p>
              ) : null}
              <div
                className="task-hud__complete-bar"
                aria-hidden="true"
              >
                <div
                  className="task-hud__complete-bar-fill"
                  style={{ animationDuration: `${payload.durationMs}ms` }}
                />
              </div>
            </>
          ) : (
            <>
              {payload.description ? (
                <p className="task-hud__description">{payload.description}</p>
              ) : null}

              {showGatheredRows && payload.tasks.length > 0 ? (
                <ul className="task-hud__list">
                  {payload.tasks.map((task) => {
                    const value = progressText(task)
                    return (
                      <li key={task.id} className="task-hud__row">
                        <span className="task-hud__row-label">{task.label}</span>
                        {value ? <span className="task-hud__row-value">{value}</span> : null}
                      </li>
                    )
                  })}
                </ul>
              ) : null}
            </>
          )}

          <p className="task-hud__hint">
            <kbd className="task-hud__key">{payload.hideKey}</kbd>
            <span>{payload.hideLabel}</span>
          </p>
        </div>
      </div>
    </aside>
  )
}
