import { memo, useEffect, useRef } from 'react'

function DialogueInputDropdown({
  id,
  open,
  options,
  selectedValues,
  highlightedIndex,
  onHighlight,
  onSelect,
  multiple = false,
  getOptionDisabled,
}) {
  const listRef = useRef(null)

  useEffect(() => {
    if (!open || highlightedIndex < 0) return
    const item = listRef.current?.children?.[highlightedIndex]
    item?.scrollIntoView?.({ block: 'nearest' })
  }, [open, highlightedIndex])

  if (!open) return null

  return (
    <ul
      ref={listRef}
      id={id}
      className={[
        'dialogue-input-dropdown',
        multiple ? 'dialogue-input-dropdown--multi' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      role="listbox"
      aria-multiselectable={multiple || undefined}
    >
      {options.map((option, index) => {
        const isSelected = selectedValues.has(option.value)
        const isDisabled = getOptionDisabled?.(option, isSelected) === true
        const isHighlighted = index === highlightedIndex

        return (
          <li
            key={option.value}
            role="option"
            aria-selected={isSelected}
            aria-disabled={isDisabled || undefined}
            className={[
              'dialogue-input-dropdown-option',
              isSelected ? 'is-selected' : '',
              isHighlighted ? 'is-highlighted' : '',
              isDisabled ? 'is-disabled' : '',
            ]
              .filter(Boolean)
              .join(' ')}
            onMouseEnter={() => onHighlight(index)}
            onMouseDown={(event) => event.preventDefault()}
            onClick={() => {
              if (isDisabled) return
              onSelect(option.value, index)
            }}
          >
            <span className="dialogue-input-dropdown-check" aria-hidden="true">
              {isSelected ? (
                <svg viewBox="0 0 448 512" width="12" height="12">
                  <path
                    fill="currentColor"
                    d="M438.6 105.4c12.5 12.5 12.5 32.8 0 45.3l-256 256c-12.5 12.5-32.8 12.5-45.3 0l-128-128c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0L160 338.7 393.4 105.4c12.5-12.5 32.8-12.5 45.3 0z"
                  />
                </svg>
              ) : null}
            </span>
            <span className="dialogue-input-dropdown-copy">
              <span className="dialogue-input-dropdown-label">{option.label}</span>
              {option.description && (
                <span className="dialogue-input-dropdown-description">{option.description}</span>
              )}
            </span>
          </li>
        )
      })}
    </ul>
  )
}

export default memo(DialogueInputDropdown)
