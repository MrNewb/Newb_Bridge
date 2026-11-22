import { memo } from 'react'
import { Card } from '@/components/ui/card'
import { Kbd } from '@/components/ui/kbd'
import { Separator } from '@/components/ui/separator'
import { cn } from '@/lib/utils'

/*
 * The parts the placement tools share (prop placer, zone creator, gizmo, DUI creator): one panel shell, one status block,
 * the same key caps, control rows and pinned action keys, so the four read as one family.
 */

/**
 * The floating panel. `footer` is pinned under the scrolling content, so the keys that end a session (place, finish, cancel)
 * can never be pushed off the panel on a short screen.
 */
export function PlacementPanel({ name, visible, label, title, subtitle, footer, children }) {
  return (
    <div className={cn('prop-placer', name, visible && 'prop-placer--visible')} aria-hidden={!visible}>
      <Card className="prop-placer__panel flex flex-col bg-background p-4 font-sans" role="complementary" aria-label={label}>
        <div className="prop-placer__scroll flex min-h-0 flex-col gap-4 overflow-y-auto">
          <div className="min-w-0">
            <h2 className="m-0 text-base font-semibold leading-tight tracking-tight text-foreground">{title}</h2>
            {subtitle ? (
              <p className="m-0 mt-1 truncate text-sm text-muted-foreground" title={subtitle}>{subtitle}</p>
            ) : null}
          </div>
          {children}
        </div>
        {footer ? (
          <div className="mt-3 flex shrink-0 flex-col gap-3">
            <Separator />
            {footer}
          </div>
        ) : null}
      </Card>
    </div>
  )
}

function MouseScrollIcon() {
  return (
    <svg className="h-5 w-4" viewBox="0 0 16 22" fill="none" aria-hidden="true">
      <rect x="1" y="1" width="14" height="20" rx="7" stroke="currentColor" strokeWidth="1.5" />
      <rect x="6.5" y="4.5" width="3" height="6" rx="1.5" fill="currentColor" />
    </svg>
  )
}

/** A glyph for each status, so the state is never carried by colour alone. */
function StatusIcon({ status }) {
  const common = { className: 'h-5 w-5 shrink-0', viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true }
  if (status === 'ready') return <svg {...common}><circle cx="12" cy="12" r="9" /><path d="m8 12.5 2.8 2.8L16 9.5" /></svg>
  if (status === 'too_far') return <svg {...common}><path d="M10.3 3.9 2.4 17.5a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z" /><path d="M12 9.5v4M12 17h.01" /></svg>
  if (status === 'invalid_material') return <svg {...common}><circle cx="12" cy="12" r="9" /><path d="m9 9 6 6M15 9l-6 6" /></svg>
  return <svg {...common}><circle cx="12" cy="12" r="9" /><circle cx="12" cy="12" r="3" /><path d="M12 1.5v4M12 18.5v4M1.5 12h4M18.5 12h4" /></svg>
}

const STATUS_TONE = {
  ready: { box: 'border-success/60 bg-success/10', glyph: 'text-success' },
  too_far: { box: 'border-warning/60 bg-warning/10', glyph: 'text-warning' },
  invalid_material: { box: 'border-destructive/60 bg-destructive/10', glyph: 'text-destructive' },
}

/** The status leads the panel: a tinted block with a glyph, the word and, when there is one, what to do about it. */
export function StatusBlock({ status = 'aiming', title, text }) {
  const tone = STATUS_TONE[status]
  return (
    <div
      className={cn('flex gap-3 rounded-md border border-solid px-3 py-2.5', text ? 'items-start' : 'items-center', tone ? tone.box : 'border-border bg-muted/40')}
      role="status"
    >
      <span className={tone ? tone.glyph : 'text-muted-foreground'}><StatusIcon status={status} /></span>
      <div className="min-w-0">
        <p className="m-0 text-sm font-semibold leading-tight text-foreground">{title}</p>
        {text ? <p className="m-0 mt-0.5 text-sm leading-snug text-muted-foreground">{text}</p> : null}
      </div>
    </div>
  )
}

const isScroll = (key) => String(key).toLowerCase() === 'scroll'

const ControlRow = memo(function ControlRow({ control, keyColumn }) {
  const keys = Array.isArray(control.keys) ? control.keys : [control.keys]

  return (
    <div className="flex items-center gap-2 py-1">
      <div className={cn('flex shrink-0 items-center gap-1', keyColumn ? 'min-w-[6.5rem]' : 'min-w-[2.25rem]')} aria-hidden="true">
        {keys.map((key) => (
          <Kbd key={key} className="text-foreground">
            {isScroll(key) ? <MouseScrollIcon /> : key}
          </Kbd>
        ))}
      </div>
      <span className="text-sm text-foreground">{control.label}</span>
      {control.badge ? (
        <span className="rounded border border-solid border-border px-1.5 py-0.5 text-xs font-medium uppercase leading-none text-muted-foreground">{control.badge}</span>
      ) : null}
    </div>
  )
})

/** The closing keys: a key cap with its text to the right, side by side when there are two. */
export const ActionKeys = memo(function ActionKeys({ items }) {
  const roomy = items.length <= 2
  return (
    <div className={roomy ? 'flex flex-wrap gap-x-4 gap-y-2' : 'grid grid-cols-2 gap-x-3 gap-y-2'}>
      {items.map((control) => (
        <div key={control.id} className="flex min-w-0 items-center gap-2">
          <Kbd className="shrink-0 text-foreground" aria-hidden="true">
            {control.keys}
          </Kbd>
          <span className="min-w-0 text-sm leading-tight text-foreground">{control.label}</span>
        </div>
      ))}
    </div>
  )
})

export const ControlGroup = memo(function ControlGroup({ group, showTitle = true }) {
  // a group with a long key such as Shift+Scroll gets a wider key column so its labels still line up
  const keyColumn = group.items.some((control) => !isScroll(control.keys) && String(control.keys).length > 5)
  return (
    <section className="flex flex-col" aria-label={group.title}>
      {showTitle && group.title ? <p className="m-0 mb-1 text-xs font-medium text-muted-foreground">{group.title}</p> : null}
      {group.items.map((control) => (
        <ControlRow key={control.id} control={control} keyColumn={keyColumn} />
      ))}
    </section>
  )
})

/** Label and value on one line, for the small facts under the main readout. */
export const MetaLine = memo(function MetaLine({ label, value }) {
  return (
    <p className="m-0 flex justify-between gap-3">
      <span className="font-medium text-muted-foreground">{label}</span>
      <span className="tabular-nums text-foreground">{value}</span>
    </p>
  )
})

/** A boxed label and value, for text that can be long, such as an animation name. */
export const Stat = memo(function Stat({ label, value }) {
  return (
    <div className="rounded-md border border-solid border-border px-3 py-2">
      <p className="m-0 text-xs font-medium text-muted-foreground">{label}</p>
      <p className="m-0 mt-0.5 text-sm font-medium tabular-nums text-foreground [overflow-wrap:anywhere]">{value}</p>
    </div>
  )
})

/** The reading against its limit: a large number and a flat bar, tinted by the status. */
export function Range({ label, value, max, status }) {
  const fill = max > 0 ? Math.min(1, Math.max(0, value / max)) : 0
  const bar = status === 'too_far' ? 'bg-warning' : status === 'invalid_material' ? 'bg-destructive' : 'bg-foreground'
  const text = (number) => (Number.isInteger(number) ? String(number) : number.toFixed(1))
  return (
    <div>
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-xs font-medium text-muted-foreground">{label}</span>
        <span className="text-xl font-semibold leading-none tabular-nums text-foreground">
          {text(value)}
          <span className="text-sm font-medium text-muted-foreground"> / {text(max)} m</span>
        </span>
      </div>
      <div className="mt-2 h-1 w-full rounded-full bg-muted" role="presentation">
        <div className={cn('h-full origin-left rounded-full transition-transform duration-150', bar)} style={{ transform: `scaleX(${fill})` }} />
      </div>
    </div>
  )
}

/** A row of numbered steps with the current one marked, so a two-step tool says where you are. */
export function Stepper({ steps, current }) {
  return (
    <ol className="m-0 grid list-none auto-cols-fr grid-flow-col gap-2 p-0" aria-label={steps[current]}>
      {steps.map((label, index) => (
        <li
          key={label}
          aria-current={index === current ? 'step' : undefined}
          className={cn(
            'flex min-w-0 items-center gap-2 border-t-2 border-solid pt-2 text-xs font-medium leading-tight',
            index === current ? 'border-foreground text-foreground' : index < current ? 'border-success text-muted-foreground' : 'border-border text-muted-foreground',
          )}
        >
          <span
            className={cn(
              'grid h-5 w-5 shrink-0 place-items-center rounded-full text-xs font-semibold',
              index === current ? 'bg-foreground text-background' : index < current ? 'bg-success text-success-foreground' : 'bg-muted',
            )}
          >
            {index + 1}
          </span>
          {label}
        </li>
      ))}
    </ol>
  )
}
