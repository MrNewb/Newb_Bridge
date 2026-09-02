import { cn } from '@/lib/utils'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'
import { Kbd } from '@/components/ui/kbd'

export function OverlayShell({ visible, name, label, children }) {
  return (
    <div
      className={cn(
        'pointer-events-none fixed inset-0 z-20 select-none font-sans text-sm font-normal leading-normal',
        visible && `${name}--visible`,
        name,
      )}
      aria-hidden={!visible}
    >
      <Card
        className={cn(
          'overlay-shell-card absolute right-[clamp(1rem,3vw,1.5rem)] top-1/2 flex w-[min(20rem,calc(100vw-48px))] max-h-[calc(100vh-2rem)] -translate-y-1/2 translate-x-3 flex-col gap-4 overflow-y-auto p-6 opacity-0 invisible shadow-toast transition-[opacity,visibility,transform] duration-300 motion-reduce:transition-none motion-reduce:translate-x-0',
          visible && 'visible translate-x-0 opacity-100',
        )}
        role="complementary"
        aria-label={label}
      >
        {children}
      </Card>
    </div>
  )
}

export function OverlayHeader({ title, subtitle, extra, status, statusTone = 'secondary' }) {
  return (
    <div className="overlay-header flex items-start justify-between gap-3">
      <div>
        <h2 className="overlay-header__title">{title}</h2>
        {subtitle ? <p className="overlay-header__subtitle">{subtitle}</p> : null}
        {extra}
      </div>
      {status ? <Badge variant={statusTone}>{status}</Badge> : null}
    </div>
  )
}

export function OverlayStats({ children }) {
  return <div className="grid grid-cols-2 gap-2">{children}</div>
}

export function OverlayStat({ label, value, wide }) {
  return (
    <div className={cn('overlay-stat', wide && 'col-span-2')}>
      <span className="overlay-stat__label">{label}</span>
      <span className="overlay-stat__value">{value}</span>
    </div>
  )
}

export function OverlayControls({ title, children }) {
  return (
    <div className="flex flex-col gap-2">
      {title ? <p className="overlay-section-label">{title}</p> : null}
      {children}
    </div>
  )
}

export function OverlayControl({ active, keys, label, badge, keyTone }) {
  const list = Array.isArray(keys) ? keys : [keys]

  return (
    <div className={cn('overlay-control', active && 'overlay-control--active')}>
      <div className="flex items-center gap-1" aria-hidden="true">
        {list.map((key, index) => (
          <Kbd key={key} tone={keyTone} badge={index === 0 ? badge : undefined}>
            {key}
          </Kbd>
        ))}
      </div>
      <span className="overlay-control__label">{label}</span>
    </div>
  )
}

export function OverlayToggle({ label, pressed, onLabel, offLabel, shortcut }) {
  return (
    <div className="overlay-control" aria-label={label}>
      <Kbd>{shortcut}</Kbd>
      <span className="overlay-control__label flex-1">{label}</span>
      <span className="overlay-section-label">{pressed ? onLabel : offLabel}</span>
      <span
        className={cn(
          'relative h-6 w-11 shrink-0 rounded-full border-2 border-solid border-transparent bg-muted',
          pressed && 'bg-foreground',
        )}
        aria-hidden="true"
      >
        <span
          className={cn(
            'absolute top-0.5 h-5 w-5 rounded-full bg-foreground shadow-sm',
            pressed ? 'right-0.5 bg-background' : 'left-0.5',
          )}
        />
      </span>
    </div>
  )
}
