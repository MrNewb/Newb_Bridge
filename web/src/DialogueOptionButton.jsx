import { memo } from 'react'
import ChevronRightIcon from './design-system/ChevronRightIcon'
import DialogueInputControl from './design-system/DialogueInputControl'
import InlineMetadata from './design-system/InlineMetadata'
import ProgressBar from './design-system/ProgressBar'
import DialogueIcon from './DialogueIcon'
import DialogueImage from './design-system/DialogueImage'
import { isImageUrl } from './design-system/image-utils.js'
import { usesArrowStepping, formatInputLocale } from './design-system/input-utils.js'
import DialogueMarkdown from './dialogue-markdown'

function OptionIcon({ option }) {
  if (option.image) {
    return <DialogueImage src={option.image} variant="option" alt="" />
  }

  if (option.iconImage) {
    return <DialogueImage src={option.iconImage} variant="icon" alt="" />
  }

  const iconName = option.icon || option.input?.icon
  if (!iconName) return null

  if (isImageUrl(iconName)) {
    return <DialogueImage src={iconName} variant="icon" alt="" />
  }

  return (
    <span
      className={[
        'dialogue-button-icon',
        option.iconAnimation ? `dialogue-button-icon--${option.iconAnimation}` : '',
      ]
        .filter(Boolean)
        .join(' ')}
      style={option.iconColor ? { color: option.iconColor } : undefined}
      aria-hidden="true"
    >
      <DialogueIcon name={iconName} />
    </span>
  )
}

function DialogueOptionButton({
  option,
  index,
  isPending,
  isGloballyDisabled,
  inputValue,
  inputError,
  onInputChange,
  onSelect,
  inputLocales,
}) {
  const isDisabled = option.disabled || isGloballyDisabled
  const showArrow = option.arrow
  const hasProgress = option.progress !== null && option.progress !== undefined
  const hasInput = Boolean(option.input)
  const isActionInput = hasInput && option.isInputAction
  const descriptionId = option.description
    ? `dialogue-option-desc-${option.key}`
    : option.input?.description
      ? `dialogue-option-input-desc-${option.key}`
      : undefined
  const progressId = hasProgress ? `dialogue-option-progress-${option.key}` : undefined
  const inputControlId = hasInput ? `dialogue-option-input-${option.key}` : undefined
  const inputErrorId = inputError ? `dialogue-option-input-error-${option.key}` : undefined
  const inputStepHintId = hasInput && usesArrowStepping(option.input)
    ? `dialogue-option-input-step-hint-${option.key}`
    : undefined
  const describedBy = [descriptionId, progressId, inputStepHintId, inputErrorId]
    .filter(Boolean)
    .join(' ') || undefined

  const className = [
    'dialogue-button',
    `dialogue-button--${option.type}`,
    hasInput ? 'dialogue-button--input' : '',
    isActionInput ? 'dialogue-button--action' : '',
    option.input?.required ? 'dialogue-button--input-required' : '',
    option.readOnly ? 'dialogue-button--readonly' : '',
    option.disabled ? 'dialogue-button--disabled' : '',
    isPending ? 'dialogue-button--pending' : '',
    option.description || option.input?.description ? 'dialogue-button--with-description' : '',
    hasProgress ? 'dialogue-button--with-progress' : '',
    option.metadata?.length ? 'dialogue-button--with-metadata' : '',
  ]
    .filter(Boolean)
    .join(' ')

  const displayDescription = option.description || option.input?.description

  const content = (
    <div className="dialogue-button-main">
      <OptionIcon option={option} />
      <div className="dialogue-button-copy">
        <span className="dialogue-button-title">
          <DialogueMarkdown text={option.title} />
        </span>
        {displayDescription && (
          <span id={descriptionId} className="dialogue-button-description">
            <DialogueMarkdown text={displayDescription} />
          </span>
        )}
        {hasInput && (
          <div
            className="dialogue-button-input-host"
            onClick={(event) => event.stopPropagation()}
            onKeyDown={(event) => event.stopPropagation()}
          >
            <DialogueInputControl
              input={option.input}
              value={inputValue}
              controlId={inputControlId}
              optionKey={option.optionKey}
              describedBy={describedBy}
              stepHintId={inputStepHintId}
              error={inputError}
              errorId={inputErrorId}
              inputLocales={inputLocales}
              onChange={(nextValue) => onInputChange(option.optionKey, nextValue, option.input)}
            />
          </div>
        )}
        <InlineMetadata metadata={option.metadata} optionKey={option.key} locales={inputLocales} />
        <ProgressBar
          id={progressId}
          value={option.progress}
          colorScheme={option.colorScheme}
          label={hasProgress
            ? formatInputLocale(
              option.title ? inputLocales?.progress_named : inputLocales?.progress_complete,
              { label: option.title, value: option.progress },
            )
            : undefined}
        />
      </div>
      {showArrow && (
        <span className="dialogue-button-arrow" aria-hidden="true">
          <ChevronRightIcon />
        </span>
      )}
    </div>
  )

  if (option.readOnly || (hasInput && !isActionInput)) {
    return (
      <div
        className={className}
        style={{ '--i': Math.min(index, 19) }}
        aria-disabled={option.readOnly || option.input?.disabled ? 'true' : undefined}
        aria-describedby={describedBy}
      >
        {content}
      </div>
    )
  }

  return (
    <button
      type="button"
      className={className}
      disabled={isDisabled}
      aria-busy={isPending}
      aria-describedby={describedBy}
      data-dialogue-focus-option
      data-option-key={option.optionKey}
      style={{ '--i': Math.min(index, 19) }}
      onClick={() => onSelect(option)}
    >
      {content}
    </button>
  )
}

export default memo(DialogueOptionButton)
