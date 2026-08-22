import { memo } from 'react'
import ProgressBar from './ProgressBar'
import { formatInputLocale } from './input-utils.js'

function InlineMetadata({ metadata, optionKey, locales }) {
  if (!metadata?.length) return null

  return (
    <div className="dialogue-button-metadata-inline">
      {metadata.map((entry, entryIndex) => (
        <div
          key={`${entry.label}-${entryIndex}`}
          className="dialogue-button-metadata-inline-row"
        >
          <span className="dialogue-button-metadata-label">{entry.label}</span>
          {entry.value !== null && entry.value !== undefined && (
            <span className="dialogue-button-metadata-value">{String(entry.value)}</span>
          )}
          <ProgressBar
            id={
              entry.progress !== null && entry.progress !== undefined
                ? `dialogue-option-meta-progress-${optionKey}-${entryIndex}`
                : undefined
            }
            value={entry.progress}
            colorScheme={entry.colorScheme}
            label={
              entry.progress !== null && entry.progress !== undefined
                ? formatInputLocale(
                  entry.label ? locales?.progress_named : locales?.progress_complete,
                  { label: entry.label, value: entry.progress },
                )
                : undefined
            }
          />
        </div>
      ))}
    </div>
  )
}

export default memo(InlineMetadata)
