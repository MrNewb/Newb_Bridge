import { cn } from '@/lib/utils'

function Kbd({ className, tone, children, badge, ...props }) {
  return (
    <kbd
      className={cn(
        'pointer-events-none inline-flex min-h-7 min-w-8 flex-col items-center justify-center gap-0.5 rounded-md border border-solid border-border bg-muted px-1.5 py-1 font-mono text-kbd font-medium leading-none text-muted-foreground',
        tone === 'success' && 'border-success bg-success text-success-foreground',
        tone === 'info' && 'border-info bg-info text-info-foreground',
        className,
      )}
      {...props}
    >
      {children}
      {badge ? (
        <span className="max-w-[4.5rem] overflow-hidden text-ellipsis whitespace-nowrap text-kbd-badge font-medium uppercase leading-none text-current">
          {badge}
        </span>
      ) : null}
    </kbd>
  )
}

export { Kbd }
