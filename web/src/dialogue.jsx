import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import DialogueOptionButton from './DialogueOptionButton'
import DialogueImage from './design-system/DialogueImage'
import DialogueMarkdown from './dialogue-markdown'
import {
  getOptionColumnCount,
  getOptionsLayout,
  normalizeOpenPayload,
} from './dialogue-utils'
import { buildStyleSheet } from './design-system/style.js'
import {
  coerceInputValue,
  getInitialInputValue,
  getMenuInputErrors,
  normalizeInputLocales,
  stepInputValue,
  usesArrowStepping,
} from './design-system/input-utils.js'
import { isImageUrl } from './design-system/image-utils.js'
import {
  getInitialFocusTarget,
  moveOptionFocus,
  trapFocus,
} from './dialogue-a11y'
import { useTypewriter } from './design-system/useTypewriter.js'
import { preloadSolidIcons } from './icons'
import { fetchNui } from './fetch'
import './dialogue.css'

const CLOSE_DURATION_MS = 220

const DEFAULT_LOCALES = {
  back: 'Go back',
  options_group: 'Dialogue options',
  dialog: 'Dialogue',
  menu_portrait: '%s portrait',
  menu_portrait_default: 'Menu portrait',
  validation_fix_fields: 'Fix the highlighted fields before continuing.',
  processing: 'Processing %s…',
  input_yes: 'Yes',
  input_no: 'No',
  input_none_selected: 'None selected',
  input_arrow_step_hint: 'Use left and right arrow keys to adjust.',
  input_choose: 'Choose',
  input_selected_count: '{count} selected',
  input_choose_aria: 'Choose {label}',
  input_max_selected: 'Max {count} selected',
  input_decrease_aria: 'Decrease {label}',
  input_increase_aria: 'Increase {label}',
  input_previous_aria: 'Previous {label}',
  input_next_aria: 'Next {label}',
  input_open_options_aria: 'Open {label} options',
  input_remove_aria: 'Remove {label}',
  progress_named: '{label}: {value}%',
  progress_complete: '{value}% complete',
  input_validation_required: '{label} is required',
  input_validation_min_length: '{label} must be at least {min} characters',
  input_validation_max_length: '{label} must be at most {max} characters',
  input_validation_number: '{label} must be a number',
  input_validation_min_value: '{label} must be at least {min}',
  input_validation_max_value: '{label} must be at most {max}',
}

function formatLocale(template, ...values) {
  if (typeof template !== 'string') return ''
  let index = 0
  return template.replace(/%s/g, () => String(values[index++] ?? ''))
}

function normalizeLocales(value) {
  if (!value || typeof value !== 'object') return DEFAULT_LOCALES

  return {
    back: typeof value.back === 'string' ? value.back : DEFAULT_LOCALES.back,
    options_group: typeof value.options_group === 'string'
      ? value.options_group
      : DEFAULT_LOCALES.options_group,
    dialog: typeof value.dialog === 'string' ? value.dialog : DEFAULT_LOCALES.dialog,
    menu_portrait: typeof value.menu_portrait === 'string'
      ? value.menu_portrait
      : DEFAULT_LOCALES.menu_portrait,
    menu_portrait_default: typeof value.menu_portrait_default === 'string'
      ? value.menu_portrait_default
      : DEFAULT_LOCALES.menu_portrait_default,
    validation_fix_fields: typeof value.validation_fix_fields === 'string'
      ? value.validation_fix_fields
      : DEFAULT_LOCALES.validation_fix_fields,
    processing: typeof value.processing === 'string'
      ? value.processing
      : DEFAULT_LOCALES.processing,
    input_yes: typeof value.input_yes === 'string' ? value.input_yes : DEFAULT_LOCALES.input_yes,
    input_no: typeof value.input_no === 'string' ? value.input_no : DEFAULT_LOCALES.input_no,
    input_none_selected: typeof value.input_none_selected === 'string'
      ? value.input_none_selected
      : DEFAULT_LOCALES.input_none_selected,
    input_arrow_step_hint: typeof value.input_arrow_step_hint === 'string'
      ? value.input_arrow_step_hint
      : DEFAULT_LOCALES.input_arrow_step_hint,
    input_choose: typeof value.input_choose === 'string' ? value.input_choose : DEFAULT_LOCALES.input_choose,
    input_selected_count: typeof value.input_selected_count === 'string'
      ? value.input_selected_count
      : DEFAULT_LOCALES.input_selected_count,
    input_choose_aria: typeof value.input_choose_aria === 'string'
      ? value.input_choose_aria
      : DEFAULT_LOCALES.input_choose_aria,
    input_max_selected: typeof value.input_max_selected === 'string'
      ? value.input_max_selected
      : DEFAULT_LOCALES.input_max_selected,
    input_decrease_aria: typeof value.input_decrease_aria === 'string'
      ? value.input_decrease_aria
      : DEFAULT_LOCALES.input_decrease_aria,
    input_increase_aria: typeof value.input_increase_aria === 'string'
      ? value.input_increase_aria
      : DEFAULT_LOCALES.input_increase_aria,
    input_previous_aria: typeof value.input_previous_aria === 'string'
      ? value.input_previous_aria
      : DEFAULT_LOCALES.input_previous_aria,
    input_next_aria: typeof value.input_next_aria === 'string'
      ? value.input_next_aria
      : DEFAULT_LOCALES.input_next_aria,
    input_open_options_aria: typeof value.input_open_options_aria === 'string'
      ? value.input_open_options_aria
      : DEFAULT_LOCALES.input_open_options_aria,
    input_remove_aria: typeof value.input_remove_aria === 'string'
      ? value.input_remove_aria
      : DEFAULT_LOCALES.input_remove_aria,
    progress_named: typeof value.progress_named === 'string'
      ? value.progress_named
      : DEFAULT_LOCALES.progress_named,
    progress_complete: typeof value.progress_complete === 'string'
      ? value.progress_complete
      : DEFAULT_LOCALES.progress_complete,
    input_validation_required: typeof value.input_validation_required === 'string'
      ? value.input_validation_required
      : DEFAULT_LOCALES.input_validation_required,
    input_validation_min_length: typeof value.input_validation_min_length === 'string'
      ? value.input_validation_min_length
      : DEFAULT_LOCALES.input_validation_min_length,
    input_validation_max_length: typeof value.input_validation_max_length === 'string'
      ? value.input_validation_max_length
      : DEFAULT_LOCALES.input_validation_max_length,
    input_validation_number: typeof value.input_validation_number === 'string'
      ? value.input_validation_number
      : DEFAULT_LOCALES.input_validation_number,
    input_validation_min_value: typeof value.input_validation_min_value === 'string'
      ? value.input_validation_min_value
      : DEFAULT_LOCALES.input_validation_min_value,
    input_validation_max_value: typeof value.input_validation_max_value === 'string'
      ? value.input_validation_max_value
      : DEFAULT_LOCALES.input_validation_max_value,
  }
}

function buildInitialInputValues(options) {
  const values = {}

  options.forEach((option) => {
    if (option.input) {
      values[option.optionKey] = getInitialInputValue(option.input)
    }
  })

  return values
}

function getRootElement() {
  return document.getElementById('root')
}

function BackIcon() {
  return (
    <svg className="dialogue-back-icon" viewBox="0 0 320 512" aria-hidden="true">
      <path
        fill="currentColor"
        d="M41.4 233.4c-12.5 12.5-12.5 32.8 0 45.3l160 160c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L109.3 256 246.6 118.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0l-160 160z"
      />
    </svg>
  )
}

function Dialogue() {
  const [dialogueOptions, setDialogueOption] = useState([])
  const [menuTitle, setMenuTitle] = useState('')
  const [menuDescription, setMenuDescription] = useState('')
  const [menuImage, setMenuImage] = useState(null)
  const [currentText, setCurrentText] = useState('')
  const [canGoBack, setCanGoBack] = useState(false)
  const [textVersion, setTextVersion] = useState(0)
  const [optionsVersion, setOptionsVersion] = useState(0)
  const [isOpen, setIsOpen] = useState(false)
  const [isClosing, setIsClosing] = useState(false)
  const [pendingOptionKey, setPendingOptionKey] = useState(null)
  const [customStyle, setCustomStyle] = useState(null)
  const [styleScopeId, setStyleScopeId] = useState('')
  const [contentPhase, setContentPhase] = useState('enter')
  const [typewriterEnabled, setTypewriterEnabled] = useState(false)
  const [optionsRevealed, setOptionsRevealed] = useState(false)
  const [inputValues, setInputValues] = useState({})
  const [inputErrors, setInputErrors] = useState({})
  const [inputValidationMessage, setInputValidationMessage] = useState('')
  const [locales, setLocales] = useState(DEFAULT_LOCALES)
  const closeTimerRef = useRef(null)
  const inputValuesRef = useRef({})
  const activeSessionRef = useRef('')
  const pendingOptionKeyRef = useRef(null)
  const isOpenRef = useRef(false)
  const containerRef = useRef(null)
  const previousFocusRef = useRef(null)

  const { visibleText, isComplete: isTextComplete, isTyping } = useTypewriter(currentText, {
    enabled: typewriterEnabled,
    active: isOpen && !isClosing,
    resetKey: textVersion,
  })

  useEffect(() => {
    if (!typewriterEnabled) {
      setOptionsRevealed(true)
      return
    }

    setOptionsRevealed(isTextComplete)
  }, [isTextComplete, textVersion, typewriterEnabled])

  const clearCloseTimer = useCallback(() => {
    if (closeTimerRef.current !== null) {
      window.clearTimeout(closeTimerRef.current)
      closeTimerRef.current = null
    }
  }, [])

  const closeDialogue = useCallback(() => {
    clearCloseTimer()
    setIsClosing(true)
    setPendingOptionKey(null)
    pendingOptionKeyRef.current = null

    closeTimerRef.current = window.setTimeout(() => {
      setIsOpen(false)
      setIsClosing(false)
      setContentPhase('enter')
      setOptionsRevealed(false)
      activeSessionRef.current = ''
      setCanGoBack(false)
      getRootElement()?.classList.add('hidden')
      closeTimerRef.current = null
    }, CLOSE_DURATION_MS)
  }, [clearCloseTimer])

  const openDialogue = useCallback((payload) => {
    clearCloseTimer()

    const iconNames = payload.options.flatMap((option) => {
      const names = []
      if (option.icon && !option.iconIsUrl) names.push(option.icon)
      if (option.input?.icon && !isImageUrl(option.input.icon)) names.push(option.input.icon)
      return names
    })

    getRootElement()?.classList.remove('hidden')
    setContentPhase(isOpenRef.current ? 'swap' : 'enter')
    setIsClosing(false)
    setIsOpen(true)
    setPendingOptionKey(null)
    pendingOptionKeyRef.current = null
    setTypewriterEnabled(payload.typewriter === true)
    setOptionsRevealed(payload.typewriter !== true)
    const nextInputValues = buildInitialInputValues(payload.options)
    setInputValues(nextInputValues)
    inputValuesRef.current = nextInputValues
    setInputErrors({})
    setInputValidationMessage('')
    setDialogueOption(payload.options)
    setMenuTitle(payload.title)
    setMenuDescription(payload.description)
    setMenuImage(payload.image)
    setCurrentText(payload.text)
    setCanGoBack(payload.canGoBack)
    setLocales(normalizeLocales(payload.locales))
    setCustomStyle(payload.style)
    setStyleScopeId(payload.sessionId)
    activeSessionRef.current = payload.sessionId
    setTextVersion((version) => version + 1)
    setOptionsVersion((version) => version + 1)

    if (iconNames.length > 0) {
      preloadSolidIcons(iconNames)
    }
  }, [clearCloseTimer])

  const requestClose = useCallback(async () => {
    const sessionId = activeSessionRef.current
    if (!sessionId || pendingOptionKeyRef.current !== null) return

    await fetchNui('dialogue:close', { sessionId })
  }, [])

  const requestBack = useCallback(async () => {
    const sessionId = activeSessionRef.current
    if (!sessionId || pendingOptionKeyRef.current !== null) return

    await fetchNui('dialogue:back', { sessionId })
  }, [])

  const handleInputChange = useCallback((optionKey, nextValue, input) => {
    const coercedValue = input ? coerceInputValue(nextValue, input) : nextValue

    setInputValues((current) => {
      const updated = { ...current, [optionKey]: coercedValue }
      inputValuesRef.current = updated
      return updated
    })

    setInputErrors((current) => {
      if (!current[optionKey]) return current
      const next = { ...current }
      delete next[optionKey]
      return next
    })
    setInputValidationMessage('')
  }, [])

  const handleOptionSelect = useCallback(async (option) => {
    if (pendingOptionKeyRef.current !== null) return
    if (option.disabled || option.readOnly) return

    const sessionId = activeSessionRef.current
    if (!sessionId) return

    const validationErrors = getMenuInputErrors(
      dialogueOptions,
      inputValuesRef.current,
      normalizeInputLocales(locales),
    )
    if (Object.keys(validationErrors).length > 0) {
      setInputErrors(validationErrors)
      setInputValidationMessage(locales.validation_fix_fields)
      return
    }

    pendingOptionKeyRef.current = option.optionKey
    setPendingOptionKey(option.optionKey)

    const currentInputValues = inputValuesRef.current

    try {
      await fetchNui('dialogue:selectOption', {
        sessionId,
        optionKey: option.optionKey,
        inputValues: currentInputValues,
        inputValue: currentInputValues[option.optionKey],
      })
    } catch {
      // A newer dialogue may have already opened while this fetch was in flight —
      // only clear pending state if it still belongs to the session that made the request.
      if (activeSessionRef.current !== sessionId) return
      pendingOptionKeyRef.current = null
      setPendingOptionKey(null)
    }
  }, [dialogueOptions, locales])

  useEffect(() => {
    const handleMessage = (event) => {
      const data = event.data

      if (data?.type === 'close') {
        closeDialogue()
        return
      }

      if (data?.type === 'open') {
        const payload = normalizeOpenPayload(data)
        if (!payload) return
        openDialogue(payload)
      }
    }

    window.addEventListener('message', handleMessage)
    return () => {
      window.removeEventListener('message', handleMessage)
      clearCloseTimer()
    }
  }, [clearCloseTimer, closeDialogue, openDialogue])

  useEffect(() => {
    isOpenRef.current = isOpen
  }, [isOpen])

  useEffect(() => {
    const handleKeyDown = (event) => {
      if (!isOpen || isClosing) return

      if (event.key === 'Escape') {
        if (pendingOptionKeyRef.current !== null) return
        event.preventDefault()
        requestClose()
        return
      }

      const container = containerRef.current
      if (!container) return

      trapFocus(container, event)

      if (pendingOptionKeyRef.current !== null) return

      if (event.key === 'Enter') {
        const active = document.activeElement
        const optionHost = active?.closest?.('.dialogue-button[data-option-key]')
          ?? active?.closest?.('[data-option-key]')?.closest?.('.dialogue-button')
        const optionKey = optionHost?.dataset?.optionKey
        const option = dialogueOptions.find((entry) => entry.optionKey === optionKey)

        if (option?.isInputAction && !option.disabled && !option.readOnly) {
          event.preventDefault()
          void handleOptionSelect(option)
          return
        }
      }

      if (['ArrowLeft', 'ArrowRight'].includes(event.key)) {
        const active = document.activeElement
        if (active?.closest('[data-dialogue-dropdown-open="true"]')) return

        const optionHost = active?.matches?.('[data-option-key]')
          ? active
          : active?.closest?.('[data-option-key]')
        const optionKey = optionHost?.dataset?.optionKey
        const option = dialogueOptions.find((entry) => entry.optionKey === optionKey)

        if (
          option?.input
          && usesArrowStepping(option.input)
          && !active?.matches('input, textarea, select')
          && !active?.closest('.dialogue-input-dropdown')
        ) {
          event.preventDefault()
          handleInputChange(
            optionKey,
            stepInputValue(
              inputValuesRef.current[optionKey],
              option.input,
              event.key === 'ArrowRight' ? 1 : -1,
            ),
            option.input,
          )
          return
        }
      }

      if (optionsRevealed) {
        moveOptionFocus(
          container,
          event,
          getOptionColumnCount(dialogueOptions.length),
        )
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, isClosing, requestClose, dialogueOptions, handleInputChange, handleOptionSelect, optionsRevealed])

  useEffect(() => {
    if (!isOpen || isClosing || !optionsRevealed) return

    if (!(previousFocusRef.current instanceof HTMLElement)) {
      previousFocusRef.current = document.activeElement
    }

    const frame = window.requestAnimationFrame(() => {
      // Programmatic focus must not paint :focus-visible (CEF treats it like keyboard).
      getInitialFocusTarget(containerRef.current)?.focus({
        preventScroll: true,
        focusVisible: false,
      })
    })

    return () => window.cancelAnimationFrame(frame)
  }, [isOpen, isClosing, optionsRevealed, optionsVersion])

  useEffect(() => {
    if (isOpen || isClosing) return

    if (previousFocusRef.current instanceof HTMLElement) {
      previousFocusRef.current.focus()
    }
    previousFocusRef.current = null
  }, [isOpen, isClosing])

  const optionsLayout = useMemo(
    () => getOptionsLayout(dialogueOptions.length),
    [dialogueOptions.length],
  )
  const customStyleSheet = useMemo(
    () => buildStyleSheet(customStyle, styleScopeId),
    [customStyle, styleScopeId],
  )

  const containerClassName = [
    'dialogue-container',
    isOpen && !isClosing ? 'is-open' : '',
    isClosing ? 'is-closing' : '',
    typewriterEnabled ? 'dialogue-container--typewriter' : '',
  ]
    .filter(Boolean)
    .join(' ')

  if (!isOpen && !isClosing) {
    return null
  }

  const hasHeader = Boolean(menuTitle || menuDescription || menuImage || canGoBack)
  const hasBody = Boolean(currentText)
  const ariaDescribedBy = [
    menuDescription ? 'dialogue-menu-description' : '',
    currentText ? 'dialogue-text-content' : '',
  ]
    .filter(Boolean)
    .join(' ') || undefined
  const dialogAriaLabel = !menuTitle
    ? (menuDescription || currentText || locales.dialog)
    : undefined
  const pendingOption = dialogueOptions.find(
    (option) => option.optionKey === pendingOptionKey,
  )
  const bodyInHeader = hasHeader && hasBody
  const showHeaderCopy = Boolean(menuTitle || menuDescription || bodyInHeader)

  const renderDialogueText = () => (
    <div className="dialogue-text" aria-live="off">
      <p
        key={textVersion}
        id="dialogue-text-content"
        className={[
          'dialogue-text-content',
          typewriterEnabled ? 'dialogue-text-content--typewriter' : '',
        ]
          .filter(Boolean)
          .join(' ')}
      >
        {typewriterEnabled && (
          <span className="dialogue-text-ghost" aria-hidden="true">
            <DialogueMarkdown text={currentText} />
          </span>
        )}
        <span
          className={[
            typewriterEnabled ? 'dialogue-text-live' : '',
            typewriterEnabled && isTyping ? 'dialogue-text-content--typing' : '',
          ]
            .filter(Boolean)
            .join(' ') || undefined}
        >
          <DialogueMarkdown text={typewriterEnabled ? visibleText : currentText} />
        </span>
      </p>
    </div>
  )

  return (
    <>
      {customStyleSheet ? <style>{customStyleSheet}</style> : null}
      <div
        ref={containerRef}
        className={containerClassName}
        data-content-phase={contentPhase}
        data-typewriter={typewriterEnabled ? 'true' : undefined}
        data-dialogue-style={styleScopeId || undefined}
        role="dialog"
        aria-modal="true"
        aria-label={dialogAriaLabel}
        aria-labelledby={menuTitle ? 'dialogue-title' : undefined}
        aria-describedby={ariaDescribedBy}
      >
      <div className="dialogue-sr-only" aria-live="polite" aria-atomic="true">
        {inputValidationMessage
          || (pendingOption ? formatLocale(locales.processing, pendingOption.title) : '')}
      </div>
      <div className="dialogue-frame">
        {canGoBack && (
          <button
            type="button"
            className="dialogue-back-button"
            onClick={requestBack}
            aria-label={locales.back}
          >
            <BackIcon />
          </button>
        )}
        <div className="dialogue-stack">
      {hasHeader && (
        <div className="dialogue-header">
          {menuImage && (
            <DialogueImage
              src={menuImage}
              variant="menu"
              alt={menuTitle
                ? formatLocale(locales.menu_portrait, menuTitle)
                : locales.menu_portrait_default}
            />
          )}
          {showHeaderCopy && (
            <div className="dialogue-header-copy">
              {menuTitle && (
                <h2 id="dialogue-title" className="dialogue-title">
                  <DialogueMarkdown text={menuTitle} />
                </h2>
              )}
              {menuDescription && (
                <p id="dialogue-menu-description" className="dialogue-menu-description">
                  <DialogueMarkdown text={menuDescription} />
                </p>
              )}
              {bodyInHeader && (
                <>
                  {(menuTitle || menuDescription) && (
                    <hr className="dialogue-speech-divider" aria-hidden="true" />
                  )}
                  {renderDialogueText()}
                </>
              )}
            </div>
          )}
        </div>
      )}

      {hasBody && !bodyInHeader && (
        <div className="dialogue-body">
          {renderDialogueText()}
        </div>
      )}

      {dialogueOptions.length > 0 && (
        <div
          key={optionsVersion}
          className={[
            'dialogue-options',
            'dialogue-options--chips',
            optionsLayout.scrollable ? 'dialogue-options--scrollable' : '',
            optionsRevealed || !typewriterEnabled ? 'dialogue-options--revealed' : 'dialogue-options--pending',
          ]
            .filter(Boolean)
            .join(' ')}
          role="group"
          aria-label={locales.options_group}
          aria-hidden={optionsRevealed ? undefined : true}
          inert={optionsRevealed ? undefined : ''}
          data-option-count={dialogueOptions.length}
          data-content-phase={contentPhase}
          style={{
            '--dialogue-option-cols': getOptionColumnCount(dialogueOptions.length),
            '--dialogue-options-max-height': optionsLayout.maxHeight,
          }}
        >
          {dialogueOptions.map((option, index) => (
            <DialogueOptionButton
              key={option.key}
              option={option}
              index={index}
              isPending={pendingOptionKey === option.optionKey}
              isGloballyDisabled={pendingOptionKey !== null}
              inputValue={inputValues[option.optionKey]}
              inputError={inputErrors[option.optionKey]}
              inputLocales={locales}
              onInputChange={handleInputChange}
              onSelect={handleOptionSelect}
            />
          ))}
        </div>
      )}
        </div>
      </div>
      </div>
    </>
  )
}

export default Dialogue
