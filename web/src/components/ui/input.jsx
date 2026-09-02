import { cn } from '@/lib/utils'

function Input({ className, type = 'text', ...props }) {
  return (
    <input
      type={type}
      className={cn(
        'flex h-11 w-full min-w-0 rounded-md border border-solid border-input bg-background px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground',
        'outline-none transition-colors duration-120',
        'hover:border-zinc-600',
        'focus:border-ring focus-visible:border-ring',
        'disabled:cursor-not-allowed disabled:opacity-50',
        className,
      )}
      {...props}
    />
  )
}

export { Input }
