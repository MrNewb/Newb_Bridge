import { useCallback, useEffect, useRef, useState } from 'react'
import DialogueMarkdown from '@/dialogue-markdown'
import DialogueIcon from '@/DialogueIcon'
import { cn } from '@/lib/utils'
import { normalizeNotify, subscribeNotify } from '@/notify-utils'
import { preloadSolidIcons } from '@/icons'
import { fetchNui } from '@/fetch'

const positionClass = {
  top: 'inset-x-0 top-[max(1rem,env(safe-area-inset-top,0px))] items-center',
  'top-right': 'right-[max(1rem,env(safe-area-inset-right,0px))] top-[max(1rem,env(safe-area-inset-top,0px))] items-end',
  'top-left': 'left-[max(1rem,env(safe-area-inset-left,0px))] top-[max(1rem,env(safe-area-inset-top,0px))] items-start',
  bottom: 'inset-x-0 bottom-[max(1rem,env(safe-area-inset-bottom,0px))] items-center',
  'bottom-right': 'bottom-[max(1rem,env(safe-area-inset-bottom,0px))] right-[max(1rem,env(safe-area-inset-right,0px))] items-end',
  'bottom-left': 'bottom-[max(1rem,env(safe-area-inset-bottom,0px))] left-[max(1rem,env(safe-area-inset-left,0px))] items-start',
  'center-right': 'right-[max(1rem,env(safe-area-inset-right,0px))] top-1/2 -translate-y-1/2 items-end',
  'center-left': 'left-[max(1rem,env(safe-area-inset-left,0px))] top-1/2 -translate-y-1/2 items-start',
}

const typeIconClass = {
  inform: 'text-foreground',
  success: 'text-success',
  error: 'text-destructive',
  warning: 'text-warning',
}

const typeBarClass = {
  inform: 'bg-zinc-400',
  success: 'bg-success',
  error: 'bg-destructive',
  warning: 'bg-warning',
}

const animationClass = {
  spin: 'notify-icon--spin',
  spinPulse: 'notify-icon--spin-pulse',
  spinReverse: 'notify-icon--spin-reverse',
  pulse: 'notify-icon--pulse',
  beat: 'notify-icon--beat',
  fade: 'notify-icon--fade',
  beatFade: 'notify-icon--beat-fade',
  bounce: 'notify-icon--bounce',
  shake: 'notify-icon--shake',
}

const maxToasts = 5

function NotifyMedia({ toast }) {
  const [imageFailed, setImageFailed] = useState(false)
  const showImage = Boolean(toast.image) && !imageFailed
  const customIcon = Boolean(toast.iconColor)

  useEffect(() => {
    setImageFailed(false)
  }, [toast.image])

  useEffect(() => {
    if (!showImage && toast.icon) preloadSolidIcons([toast.icon])
  }, [showImage, toast.icon])

  if (showImage) {
    return (
      <img
        src={toast.image}
        alt=""
        className={cn('notify-toast-image shrink-0', animationClass[toast.iconAnimation])}
        draggable={false}
        onError={() => setImageFailed(true)}
      />
    )
  }

  return (
    <span
      className={cn(
        'flex h-8 w-8 shrink-0 items-center justify-center text-lg',
        customIcon ? 'text-foreground' : (typeIconClass[toast.type] || typeIconClass.inform),
        animationClass[toast.iconAnimation],
      )}
      style={customIcon ? { color: toast.iconColor } : undefined}
    >
      <DialogueIcon name={toast.icon} />
    </span>
  )
}

function NotifyCard({ toast }) {
  return (
    <article
      className="notify-toast pointer-events-none relative overflow-hidden"
      style={toast.style || undefined}
      role="status"
      aria-live="polite"
      aria-atomic="true"
    >
      <div className={cn('flex gap-3', toast.alignIcon === 'top' ? 'items-start' : 'items-center')}>
        <NotifyMedia toast={toast} />
        <div className="min-w-0 flex-1">
          {toast.title ? (
            <p className="title m-0 text-sm font-semibold leading-snug" style={toast.titleStyle || undefined}>
              {toast.title}
            </p>
          ) : null}
          {toast.description ? (
            <p
              className={cn('description m-0 text-sm leading-relaxed', toast.title && 'mt-1')}
              style={toast.descriptionStyle || undefined}
            >
              <DialogueMarkdown text={toast.description} />
            </p>
          ) : null}
        </div>
      </div>
      {toast.showDuration ? (
        <span
          className={cn('notify-duration', typeBarClass[toast.type] || typeBarClass.inform)}
          style={{ animationDuration: `${toast.duration}ms` }}
          aria-hidden="true"
        />
      ) : null}
    </article>
  )
}

export default function NotifyToaster() {
  const [toasts, setToasts] = useState([])
  const timersRef = useRef(new Map())

  const dismiss = useCallback((id) => {
    setToasts((current) => current.filter((toast) => toast.id !== id))
  }, [])

  const push = useCallback((toast) => {
    setToasts((current) => {
      const existingIndex = current.findIndex((entry) => entry.id === toast.id)
      const next = existingIndex >= 0
        ? current.map((entry, index) => (index === existingIndex ? toast : entry))
        : [...current, toast]

      const atPosition = next.filter((entry) => entry.position === toast.position)
      if (atPosition.length <= maxToasts) return next

      const overflow = atPosition.slice(0, atPosition.length - maxToasts)
      const drop = new Set(overflow.map((entry) => entry.id))
      return next.filter((entry) => !drop.has(entry.id))
    })

    const existing = timersRef.current.get(toast.id)
    if (existing) window.clearTimeout(existing)
    timersRef.current.set(
      toast.id,
      window.setTimeout(() => dismiss(toast.id), toast.duration),
    )
  }, [dismiss])

  useEffect(() => {
    const live = new Set(toasts.map((toast) => toast.id))
    for (const [id, timer] of timersRef.current) {
      if (live.has(id)) continue
      window.clearTimeout(timer)
      timersRef.current.delete(id)
    }
  }, [toasts])

  useEffect(() => () => {
    for (const timer of timersRef.current.values()) window.clearTimeout(timer)
    timersRef.current.clear()
  }, [])

  useEffect(() => {
    preloadSolidIcons(['circle-info', 'circle-check', 'circle-xmark', 'circle-exclamation'])
  }, [])

  useEffect(() => {
    let cancelled = false
    let attempts = 0

    const pingReady = () => {
      fetchNui('notify:ready').catch(() => {
        attempts += 1
        if (!cancelled && attempts < 20) window.setTimeout(pingReady, 250)
      })
    }

    pingReady()
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    const onBridge = (event) => {
      if (event.action === 'show') push(event.toast)
      if (event.action === 'hide') dismiss(event.id)
    }

    return subscribeNotify(onBridge)
  }, [dismiss, push])

  useEffect(() => {
    const onMessage = (event) => {
      const payload = event.data
      if (payload?.type === 'notify:show') {
        const toast = normalizeNotify(payload.data ?? payload)
        if (toast) push(toast)
        return
      }

      if (payload?.type === 'notify:hide') {
        dismiss(payload.id ?? payload.data?.id)
      }
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [dismiss, push])

  const groups = {}
  for (const toast of toasts) {
    const key = toast.position
    if (!groups[key]) groups[key] = []
    groups[key].push(toast)
  }

  return (
    <>
      {Object.entries(groups).map(([position, entries]) => (
        <div
          key={position}
          className={cn(
            'notify-stack pointer-events-none fixed z-toast flex gap-2',
            position.startsWith('bottom') ? 'flex-col-reverse' : 'flex-col',
            positionClass[position] || positionClass['top-right'],
          )}
        >
          {entries.map((toast) => (
            <NotifyCard key={toast.id} toast={toast} />
          ))}
        </div>
      ))}
    </>
  )
}
