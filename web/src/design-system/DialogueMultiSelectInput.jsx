import { memo, useCallback, useEffect, useMemo, useState } from 'react'
import ChevronDownIcon from './ChevronDownIcon.jsx'
import DialogueInputDropdown from './DialogueInputDropdown.jsx'
import {
  toggleMultiSelectValue,
  normalizeInputLocales,
  formatInputLocale,
} from './input-utils.js'
import { useDropdown } from './useDropdown.js'

function getSelectedValues(value) {
  return Array.isArray(value) ? value.map(String) : []
}

function DialogueMultiSelectInput({
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
  const selected = getSelectedValues(value)
  const { open, toggle, close, rootRef, listId } = useDropdown(disabled)
  const [highlightedIndex, setHighlightedIndex] = useState(0)

  const ariaDescribedBy = [describedBy, error ? errorId : ''].filter(Boolean).join(' ') || undefined
  const resolvedInputLocales = normalizeInputLocales(inputLocales)
  const placeholder = input.placeholder || resolvedInputLocales.none_selected

  const selectedSet = useMemo(() => new Set(selected), [selected])

  const optionByValue = useMemo(
    () => new Map(input.options.map((option) => [option.value, option])),
    [input.options],
  )

  const isAtMax = typeof input.maxSelectedValues === 'number'
    && selected.length >= input.maxSelectedValues

  const getOptionDisabled = useCallback((_option, isSelected) => (
    isAtMax && !isSelected
  ), [isAtMax])

  useEffect(() => {
    if (!open) return
    const firstSelectedIndex = input.options.findIndex((option) => selectedSet.has(option.value))
    setHighlightedIndex(firstSelectedIndex >= 0 ? firstSelectedIndex : 0)
  }, [open, input.options, selectedSet])

  const toggleValue = useCallback((optionValue) => {
    onChange(toggleMultiSelectValue(value, optionValue, input))
  }, [input, onChange, value])

  const removeValue = useCallback((optionValue) => {
    const current = getSelectedValues(value)
    if (!current.includes(String(optionValue))) return
    onChange(current.filter((entry) => entry !== String(optionValue)))
  }, [onChange, value])

  const handleFieldKeyDown = useCallback((event) => {
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
        if (option) toggleValue(option.value)
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
  }, [close, disabled, highlightedIndex, input.options, open, toggle, toggleValue])

  return (
    <>
      <div
        ref={rootRef}
        className={[
          'dialogue-input-picker dialogue-input-picker--multi',
          error ? 'dialogue-input-picker--invalid' : '',
          open ? 'is-open' : '',
        ]
          .filter(Boolean)
          .join(' ')}
        data-dialogue-dropdown-open={open ? 'true' : undefined}
      >
        <div
          id={controlId}
          className="dialogue-input-multiselect-field"
          data-dialogue-focus-option
          data-option-key={optionKey}
          tabIndex={disabled ? -1 : 0}
          aria-disabled={disabled || undefined}
          role="group"
          aria-label={input.label}
          aria-invalid={error ? true : undefined}
          aria-describedby={ariaDescribedBy}
          onKeyDown={handleFieldKeyDown}
        >
          <div className="dialogue-input-multiselect-chips" aria-live="polite">
            {selected.length === 0 ? (
              <span className="dialogue-input-multiselect-placeholder">{placeholder}</span>
            ) : (
              selected.map((entry) => {
                const option = optionByValue.get(entry)
                const label = option?.label || entry

                return (
                  <button
                    key={entry}
                    type="button"
                    className="dialogue-input-chip"
                    disabled={disabled}
                    aria-label={formatInputLocale(resolvedInputLocales.remove_aria, { label })}
                    onClick={() => removeValue(entry)}
                  >
                    <span className="dialogue-input-chip-label">{label}</span>
                    <span className="dialogue-input-chip-remove" aria-hidden="true">×</span>
                  </button>
                )
              })
            )}
          </div>

          <button
            type="button"
            className="dialogue-input-multiselect-toggle"
            disabled={disabled}
            aria-expanded={open}
            aria-controls={listId}
            aria-label={formatInputLocale(resolvedInputLocales.choose_aria, { label: input.label })}
            onClick={toggle}
          >
            <span className="dialogue-input-multiselect-toggle-label">
              {selected.length
                ? formatInputLocale(resolvedInputLocales.selected_count, { count: selected.length })
                : resolvedInputLocales.choose}
            </span>
            <ChevronDownIcon className={open ? 'is-open' : ''} />
          </button>
        </div>

        {isAtMax && (
          <span className="dialogue-input-multiselect-limit">
            {formatInputLocale(resolvedInputLocales.max_selected, { count: input.maxSelectedValues })}
          </span>
        )}

        <DialogueInputDropdown
          id={listId}
          open={open}
          options={input.options}
          selectedValues={selectedSet}
          highlightedIndex={highlightedIndex}
          onHighlight={setHighlightedIndex}
          onSelect={toggleValue}
          multiple
          getOptionDisabled={getOptionDisabled}
        />
      </div>
      {arrowHint}
      {errorMessage}
    </>
  )
}

export default memo(DialogueMultiSelectInput)
