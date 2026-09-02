import { useEffect, useState } from 'react'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import { Card } from '@/components/ui/card'
import { Kbd } from '@/components/ui/kbd'
import { cn } from '@/lib/utils'
import './task-hud.css'

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
        showRoot()
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
        document.querySelector('.task-hud--visible')?.classList.remove('task-hud--visible')
        hideRootIfIdle()
        return
      }

      if (msg.action === 'taskHud:hide') {
        setOpen(false)
        setPayload(null)
        document.querySelector('.task-hud--visible')?.classList.remove('task-hud--visible')
        hideRootIfIdle()
      }
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  if (!open || !payload) return null

  const showGatheredRows = payload.type !== 'gather' || payload.expanded
  const resting = payload.type === 'gather' && !payload.expanded && !payload.complete

  return (
    <aside
      className={cn(
        'task-hud task-hud--visible pointer-events-none fixed top-[18vh] z-20 font-sans text-card-foreground',
        payload.position === 'right' ? 'right-6' : 'left-6',
        payload.type === 'dense' && 'w-[min(24rem,calc(100vw-2rem))]',
        payload.type === 'weight' && 'w-[min(20rem,calc(100vw-2rem))]',
        payload.type === 'gather' && 'w-[min(22rem,calc(100vw-2rem))]',
      )}
      aria-label={payload.title}
    >
      <Card className={cn('flex flex-col gap-2 p-3', payload.type === 'weight' && 'gap-1.5 p-2.5')}>
        <header className="flex flex-col gap-1.5">
          <h2 className={cn(
            'm-0 text-lg font-semibold leading-snug tracking-tight text-foreground',
            payload.type === 'weight' && 'text-base',
          )}>
            {payload.title}
          </h2>
          <div
            className={cn(
              'h-px rounded-[1px] bg-border',
              payload.complete && 'bg-primary',
              payload.type === 'weight' && 'w-10',
              resting && 'w-8',
              payload.type !== 'weight' && !resting && 'w-full',
            )}
            aria-hidden="true"
          />
        </header>

        <div className="flex flex-col gap-2">
          {payload.complete ? (
            <>
              {payload.description ? (
                <p className="m-0 text-sm font-medium leading-relaxed text-muted-foreground">
                  {payload.description}
                </p>
              ) : null}
              <div className="h-1.5 w-full overflow-hidden rounded-md bg-muted" aria-hidden="true">
                <div
                  className="task-hud__complete-bar-fill h-full w-full origin-left bg-primary"
                  style={{ animationDuration: `${payload.durationMs}ms` }}
                />
              </div>
            </>
          ) : (
            <>
              {payload.description ? (
                <p className={cn(
                  'm-0 font-medium leading-relaxed text-muted-foreground',
                  payload.type === 'gather' ? 'text-icon' : 'text-sm',
                  payload.type === 'weight' && 'text-meta',
                )}>
                  {payload.description}
                </p>
              ) : null}

              {showGatheredRows && payload.tasks.length > 0 ? (
                <ul className={cn(
                  'm-0 flex list-none flex-col gap-1 p-0',
                  payload.type === 'dense' && 'max-h-[min(42vh,18rem)] overflow-y-auto pr-0.5',
                  payload.type === 'gather' && 'gap-0.5 border-t border-border pt-1.5',
                )}>
                  {payload.tasks.map((task) => {
                    const value = progressText(task)
                    return (
                      <li
                        key={task.id}
                        className="flex items-baseline justify-between gap-3 text-sm leading-relaxed text-muted-foreground [font-variant-numeric:tabular-nums]"
                      >
                        <span className="min-w-0 flex-1">{task.label}</span>
                        {value ? (
                          <span className="flex-none font-medium text-foreground">{value}</span>
                        ) : null}
                      </li>
                    )
                  })}
                </ul>
              ) : null}
            </>
          )}

          <p className="mt-0.5 mb-0 flex items-center gap-1.5 text-xs leading-snug text-muted-foreground">
            <Kbd className="min-h-6 min-w-6 px-1.5 py-0.5">{payload.hideKey}</Kbd>
            <span>{payload.hideLabel}</span>
          </p>
        </div>
      </Card>
    </aside>
  )
}
