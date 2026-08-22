import { useEffect, useState } from 'react'

const DEFAULT_CHAR_DELAY_MS = 28
const CHAR_DELAY_VARIANCE_MS = 14

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export function useTypewriter(text, {
  enabled = false,
  active = true,
  resetKey = 0,
  charDelayMs = DEFAULT_CHAR_DELAY_MS,
} = {}) {
  const [visibleText, setVisibleText] = useState('')
  const [isComplete, setIsComplete] = useState(false)
  const [isTyping, setIsTyping] = useState(false)

  useEffect(() => {
    if (!active) {
      setVisibleText('')
      setIsComplete(false)
      setIsTyping(false)
      return undefined
    }

    if (!enabled || !text || prefersReducedMotion()) {
      setVisibleText(text || '')
      setIsComplete(true)
      setIsTyping(false)
      return undefined
    }

    setVisibleText('')
    setIsComplete(false)
    setIsTyping(true)

    let index = 0
    let cancelled = false
    let timeoutId = null

    const schedule = (delay) => {
      timeoutId = window.setTimeout(tick, delay)
    }

    const tick = () => {
      if (cancelled) return

      index += 1
      setVisibleText(text.slice(0, index))

      if (index >= text.length) {
        setIsTyping(false)
        setIsComplete(true)
        return
      }

      const variance = Math.floor(Math.random() * CHAR_DELAY_VARIANCE_MS)
      schedule(charDelayMs + variance)
    }

    schedule(charDelayMs)

    return () => {
      cancelled = true
      if (timeoutId !== null) window.clearTimeout(timeoutId)
    }
  }, [text, enabled, active, resetKey, charDelayMs])

  return { visibleText, isComplete, isTyping }
}
