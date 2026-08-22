import { useCallback, useEffect, useId, useRef, useState } from 'react'

export function useDropdown(disabled = false) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef(null)
  const listId = useId()

  const close = useCallback(() => setOpen(false), [])

  const toggle = useCallback(() => {
    if (disabled) return
    setOpen((previous) => !previous)
  }, [disabled])

  useEffect(() => {
    if (!open) return undefined

    const handlePointerDown = (event) => {
      if (rootRef.current?.contains(event.target)) return
      close()
    }

    const handleKeyDown = (event) => {
      if (event.key !== 'Escape') return
      event.preventDefault()
      event.stopPropagation()
      close()
    }

    document.addEventListener('mousedown', handlePointerDown)
    window.addEventListener('keydown', handleKeyDown, true)

    return () => {
      document.removeEventListener('mousedown', handlePointerDown)
      window.removeEventListener('keydown', handleKeyDown, true)
    }
  }, [open, close])

  return {
    open,
    setOpen,
    toggle,
    close,
    rootRef,
    listId,
  }
}
