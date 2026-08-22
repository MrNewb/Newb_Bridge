const FOCUSABLE_SELECTOR = [
  'button:not(:disabled)',
  '[href]',
  'input:not(:disabled)',
  'select:not(:disabled)',
  'textarea:not(:disabled)',
  '[tabindex]:not([tabindex="-1"])',
].join(', ')

const OPTION_FOCUS_SELECTOR = '[data-dialogue-focus-option]:not([aria-disabled="true"]):not(:disabled)'

export function getFocusableElements(container) {
  if (!container) return []

  return Array.from(container.querySelectorAll(FOCUSABLE_SELECTOR)).filter(
    (element) => element.offsetParent !== null || element === document.activeElement,
  )
}

export function getOptionFocusTargets(container) {
  if (!container) return []

  return Array.from(container.querySelectorAll(OPTION_FOCUS_SELECTOR)).filter(
    (element) => element.offsetParent !== null || element === document.activeElement,
  )
}

export function getInitialFocusTarget(container) {
  if (!container) return null

  return (
    container.querySelector('.dialogue-back-button')
    || container.querySelector(OPTION_FOCUS_SELECTOR)
  )
}

export function trapFocus(container, event) {
  if (event.key !== 'Tab' || !container) return

  const focusable = getFocusableElements(container)
  if (focusable.length === 0) return

  const first = focusable[0]
  const last = focusable[focusable.length - 1]
  const active = document.activeElement

  if (event.shiftKey && active === first) {
    event.preventDefault()
    last.focus()
    return
  }

  if (!event.shiftKey && active === last) {
    event.preventDefault()
    first.focus()
  }
}

export function moveOptionFocus(container, event, columnCount) {
  const key = event.key
  if (!['ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp'].includes(key)) return false

  const items = getOptionFocusTargets(container)
  if (items.length === 0) return false

  const activeIndex = items.indexOf(document.activeElement)
  if (activeIndex === -1) return false

  const cols = Math.max(1, columnCount)
  let nextIndex = activeIndex

  if (key === 'ArrowRight') nextIndex = activeIndex + 1
  if (key === 'ArrowLeft') nextIndex = activeIndex - 1
  if (key === 'ArrowDown') nextIndex = activeIndex + cols
  if (key === 'ArrowUp') nextIndex = activeIndex - cols

  if (nextIndex < 0 || nextIndex >= items.length) return false

  event.preventDefault()
  items[nextIndex].focus({ preventScroll: true })
  return true
}
