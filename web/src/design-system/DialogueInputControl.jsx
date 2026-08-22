import { memo } from 'react'
import DialogueMultiSelectInput from './DialogueMultiSelectInput.jsx'
import DialogueSelectInput from './DialogueSelectInput.jsx'
import {
  formatInputDisplayValue,
  formatNumberFieldValue,
  isNumberDraft,
  normalizeInputLocales,
  sanitizeNumberDraft,
  sanitizeNumberValue,
  sanitizeTextValue,
  stepNumericValue,
  usesArrowStepping,
  formatInputLocale,
} from './input-utils.js'

function DialogueInputControl({
  input,
  value,
  onChange,
  controlId,
  optionKey,
  describedBy,
  error,
  errorId,
  stepHintId,
  inputLocales,
}) {
  if (!input) return null

  const disabled = input.disabled
  const resolvedInputLocales = normalizeInputLocales(inputLocales)
  const displayValue = formatInputDisplayValue(value, input, resolvedInputLocales)
  const ariaDescribedBy = [describedBy, error ? errorId : ''].filter(Boolean).join(' ') || undefined
  const arrowHint = usesArrowStepping(input) && stepHintId ? (
    <span id={stepHintId} className="dialogue-sr-only">
      {resolvedInputLocales.arrow_step_hint}
    </span>
  ) : null

  const errorMessage = error ? (
    <span id={errorId} className="dialogue-input-error" role="alert">
      {error}
    </span>
  ) : null

  const sharedPickerProps = {
    input,
    value,
    onChange,
    controlId,
    optionKey,
    describedBy,
    error,
    errorId,
    stepHintId,
    arrowHint,
    errorMessage,
    inputLocales,
  }

  if (input.type === 'checkbox') {
    return (
      <>
        <label className="dialogue-input-checkbox" htmlFor={controlId}>
          <input
            id={controlId}
            type="checkbox"
            className="dialogue-input-checkbox-control"
            data-dialogue-focus-option
            data-option-key={optionKey}
            checked={Boolean(value)}
            disabled={disabled}
            required={input.required}
            aria-label={input.label}
            aria-invalid={error ? true : undefined}
            aria-describedby={ariaDescribedBy}
            onChange={(event) => onChange(event.target.checked)}
          />
          <span className="dialogue-input-checkbox-label">{input.label}</span>
          <span className="dialogue-input-checkbox-state" aria-hidden="true">
            {displayValue}
          </span>
        </label>
        {arrowHint}
        {errorMessage}
      </>
    )
  }

  if (input.type === 'textarea') {
    return (
      <>
        <textarea
          id={controlId}
          className={['dialogue-input-textarea', error ? 'dialogue-input-native--invalid' : '']
            .filter(Boolean)
            .join(' ')}
          data-dialogue-focus-option
          data-option-key={optionKey}
          value={value ?? ''}
          disabled={disabled}
          required={input.required}
          placeholder={input.placeholder || undefined}
          autoComplete="off"
          rows={input.min ?? 3}
          minLength={input.minLength ?? undefined}
          maxLength={input.maxLength ?? undefined}
          aria-label={input.label}
          aria-invalid={error ? true : undefined}
          aria-describedby={ariaDescribedBy}
          onChange={(event) => onChange(sanitizeTextValue(event.target.value, input))}
        />
        {errorMessage}
      </>
    )
  }

  if (input.type === 'slider') {
    const numericValue = sanitizeNumberValue(value, input)
    return (
      <>
        <div className="dialogue-input-slider">
          <input
            id={controlId}
            type="range"
            className="dialogue-input-slider-control"
            data-dialogue-focus-option
            data-option-key={optionKey}
            value={numericValue}
            disabled={disabled}
            min={input.min ?? undefined}
            max={input.max ?? undefined}
            step={input.step ?? undefined}
            aria-label={input.label}
            aria-invalid={error ? true : undefined}
            aria-describedby={ariaDescribedBy}
            aria-valuetext={displayValue}
            onChange={(event) => onChange(sanitizeNumberValue(event.target.value, input))}
          />
          <span className="dialogue-input-slider-value" aria-hidden="true">{displayValue}</span>
        </div>
        {arrowHint}
        {errorMessage}
      </>
    )
  }

  if (input.type === 'select') {
    return <DialogueSelectInput {...sharedPickerProps} />
  }

  if (input.type === 'multi-select') {
    return <DialogueMultiSelectInput {...sharedPickerProps} />
  }

  if (input.type === 'number') {
    const spinValue = isNumberDraft(value) ? undefined : sanitizeNumberValue(value, input)

    return (
      <>
        <div
          className={[
            'dialogue-input-picker',
            error ? 'dialogue-input-picker--invalid' : '',
          ]
            .filter(Boolean)
            .join(' ')}
        >
          <div
            id={controlId}
            className={['dialogue-input-stepper dialogue-input-stepper--picker', error ? 'dialogue-input-stepper--invalid' : '']
              .filter(Boolean)
              .join(' ')}
            data-dialogue-focus-option
            data-option-key={optionKey}
            tabIndex={disabled ? -1 : 0}
            aria-disabled={disabled || undefined}
            role="spinbutton"
            aria-label={input.label}
            aria-valuemin={input.min ?? undefined}
            aria-valuemax={input.max ?? undefined}
            aria-valuenow={spinValue}
            aria-valuetext={displayValue || input.placeholder || undefined}
            aria-invalid={error ? true : undefined}
            aria-describedby={ariaDescribedBy}
          >
            <button
              type="button"
              className="dialogue-input-stepper-btn"
              disabled={disabled}
              aria-label={formatInputLocale(resolvedInputLocales.decrease_aria, { label: input.label })}
              onClick={() => onChange(stepNumericValue(value, input, -1))}
            >
              ‹
            </button>

            <div className="dialogue-input-stepper-trigger dialogue-input-stepper-trigger--number">
              <input
                type="text"
                inputMode="decimal"
                className="dialogue-input-native dialogue-input-native--number"
                value={formatNumberFieldValue(value)}
                disabled={disabled}
                required={input.required}
                placeholder={input.placeholder || undefined}
                autoComplete="off"
                spellCheck={false}
                aria-label={input.label}
                aria-invalid={error ? true : undefined}
                onChange={(event) => onChange(sanitizeNumberDraft(event.target.value))}
                onBlur={(event) => onChange(sanitizeNumberValue(event.target.value, input))}
              />
            </div>

            <button
              type="button"
              className="dialogue-input-stepper-btn"
              disabled={disabled}
              aria-label={formatInputLocale(resolvedInputLocales.increase_aria, { label: input.label })}
              onClick={() => onChange(stepNumericValue(value, input, 1))}
            >
              ›
            </button>
          </div>
        </div>
        {arrowHint}
        {errorMessage}
      </>
    )
  }

  return (
    <>
      <input
        id={controlId}
        type={input.password ? 'password' : 'text'}
        className={['dialogue-input-native', error ? 'dialogue-input-native--invalid' : '']
          .filter(Boolean)
          .join(' ')}
        data-dialogue-focus-option
        data-option-key={optionKey}
        value={value ?? ''}
        disabled={disabled}
        required={input.required}
        placeholder={input.placeholder || undefined}
        autoComplete="off"
        spellCheck={input.password ? false : undefined}
        minLength={input.minLength ?? undefined}
        maxLength={input.maxLength ?? undefined}
        aria-label={input.label}
        aria-invalid={error ? true : undefined}
        aria-describedby={ariaDescribedBy}
        onChange={(event) => onChange(sanitizeTextValue(event.target.value, input))}
      />
      {errorMessage}
    </>
  )
}

export default memo(DialogueInputControl)
