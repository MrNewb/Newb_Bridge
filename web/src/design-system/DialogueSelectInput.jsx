import { memo, useCallback, useEffect, useMemo, useState } from 'react'
import ChevronDownIcon from './ChevronDownIcon.jsx'
import DialogueInputDropdown from './DialogueInputDropdown.jsx'
import {
  formatInputDisplayValue,
  formatInputLocale,
  getSelectSpinIndex,
  normalizeInputLocales,
  stepSelectValue,
} from './input-utils.js'
import { useDropdown } from './useDropdown.js'

function DialogueSelectInput({
  input,
  value,
  onChange,
  controlId,
  optionKey,
  describedBy,
  error,
  errorId,
  arrowHint,
  errorMessage,
  inputLocales,
}) {
  const disabled = input.disabled
  const resolvedInputLocales = normalizeInputLocales(inputLocales)
  const displayValue = formatInputDisplayValue(value, input, resolvedInputLocales)
  const { open, toggle, close, rootRef, listId } = useDropdown(disabled)
  const [highlightedIndex, setHighlightedIndex] = useState(() => getSelectSpinIndex(value, input))

  const ariaDescribedBy = [describedBy, error ? errorId : ''].filter(Boolean).join(' ') || undefined

  const step = useCallback((direction) => {
    if (disabled) return
    onChange(stepSelectValue(value, input, direction))
  }, [disabled, input, onChange, value])

  useEffect(() => {
    if (!open) return
    setHighlightedIndex(getSelectSpinIndex(value, input))
  }, [open, value, input])

  const selectedValues = useMemo(() => {
    const stringValue = value === null || value === undefined ? '' : String(value)
    return new Set(stringValue ? [stringValue] : [])
  }, [value])

  const handleSelect = useCallback((nextValue) => {
    onChange(nextValue)
    close()
  }, [close, onChange])

  const handleComboboxKeyDown = useCallback((event) => {
    if (disabled) return

    if (open) {
      if (event.key === 'ArrowDown') {
        event.preventDefault()
        event.stopPropagation()
        setHighlightedIndex((current) => Math.min(current + 1, input.options.length - 1))
        return
      }

      if (event.key === 'ArrowUp') {
        event.preventDefault()
        event.stopPropagation()
        setHighlightedIndex((current) => Math.max(current - 1, 0))
        return
      }

      if (event.key === 'Home') {
        event.preventDefault()
        event.stopPropagation()
        setHighlightedIndex(0)
        return
      }

      if (event.key === 'End') {
        event.preventDefault()
        event.stopPropagation()
        setHighlightedIndex(Math.max(input.options.length - 1, 0))
        return
      }

      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault()
        event.stopPropagation()
        const option = input.options[highlightedIndex]
        if (option) handleSelect(option.value)
        return
      }

      return
    }

    if (event.key === 'ArrowDown' || event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      event.stopPropagation()
      toggle()
      return
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault()
      event.stopPropagation()
      close()
    }
  }, [close, disabled, handleSelect, highlightedIndex, input.options, open, toggle])

  return (
    <>
      <div
        ref={rootRef}
        className={[
          'dialogue-input-picker',
          error ? 'dialogue-input-picker--invalid' : '',
          open ? 'is-open' : '',
        ]
          .filter(Boolean)
          .join(' ')}
        data-dialogue-dropdown-open={open ? 'true' : undefined}
      >
        <div
          id={controlId}
          className="dialogue-input-stepper dialogue-input-stepper--picker"
          data-dialogue-focus-option
          data-option-key={optionKey}
          tabIndex={disabled ? -1 : 0}
          aria-disabled={disabled || undefined}
          role="combobox"
          aria-expanded={open}
          aria-haspopup="listbox"
          aria-controls={listId}
          aria-label={input.label}
          aria-invalid={error ? true : undefined}
          aria-describedby={ariaDescribedBy}
          onKeyDown={handleComboboxKeyDown}
        >
          <button
            type="button"
            className="dialogue-input-stepper-btn"
            disabled={disabled || input.options.length <= 1}
            aria-label={formatInputLocale(resolvedInputLocales.previous_aria, { label: input.label })}
            onClick={() => step(-1)}
          >
            ‹
          </button>

          <button
            type="button"
            className="dialogue-input-stepper-trigger"
            disabled={disabled}
            aria-label={formatInputLocale(resolvedInputLocales.open_options_aria, { label: input.label })}
            onClick={toggle}
          >
            <span className="dialogue-input-stepper-value">{displayValue}</span>
            <ChevronDownIcon className={open ? 'is-open' : ''} />
          </button>

          <button
            type="button"
            className="dialogue-input-stepper-btn"
            disabled={disabled || input.options.length <= 1}
            aria-label={formatInputLocale(resolvedInputLocales.next_aria, { label: input.label })}
            onClick={() => step(1)}
          >
            ›
          </button>
        </div>

        <DialogueInputDropdown
          id={listId}
          open={open}
          options={input.options}
          selectedValues={selectedValues}
          highlightedIndex={highlightedIndex}
          onHighlight={setHighlightedIndex}
          onSelect={handleSelect}
        />
      </div>
      {arrowHint}
      {errorMessage}
    </>
  )
}

export default memo(DialogueSelectInput)
