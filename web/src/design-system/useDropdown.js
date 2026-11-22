import { useCallback, useEffect, useId, useRef, useState } from 'react'

// Ancestors that must stop clipping while a picker is open. A data attribute does this on every CEF build,
// where the old `:has(.is-open)` rules only worked on newer ones. React never touches an attribute it does not render.
const OPEN_PICKER_ANCESTORS = '.dialogue-container, .dialogue-frame, .dialogue-stack, .dialogue-body, .dialogue-options, .dialogue-button--input'

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

  useEffect(() => {
    const root = rootRef.current
    if (!open || !root) return undefined
    const marked = []
    for (let node = root.parentElement; node; node = node.parentElement) {
      if (node.matches && node.matches(OPEN_PICKER_ANCESTORS)) {
        node.setAttribute('data-open-picker', '')
        marked.push(node)
      }
    }
    return () => marked.forEach((node) => node.removeAttribute('data-open-picker'))
  }, [open])

  return {
    open,
    setOpen,
    toggle,
    close,
    rootRef,
    listId,
  }
}
