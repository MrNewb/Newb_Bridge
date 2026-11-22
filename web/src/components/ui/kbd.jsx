import { cn } from '@/lib/utils'

function Kbd({ className, children, ...props }) {
  return (
    <kbd
      className={cn(
        'pointer-events-none inline-flex min-h-8 min-w-8 flex-col items-center justify-center gap-0.5 rounded border border-solid border-border bg-muted px-1.5 py-1 font-mono text-sm font-medium leading-none text-muted-foreground',
        className,
      )}
      {...props}
    >
      {children}
    </kbd>
  )
}

export { Kbd }
