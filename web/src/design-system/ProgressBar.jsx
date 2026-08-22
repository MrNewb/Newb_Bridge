import { memo } from 'react'

function ProgressBar({ value, colorScheme, id, label }) {
  if (value === null || value === undefined) return null

  return (
    <div
      id={id}
      className="dialogue-button-progress"
      role="progressbar"
      aria-valuenow={value}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={label || undefined}
    >
      <div
        className="dialogue-button-progress-fill"
        data-color-scheme={colorScheme || undefined}
        style={{ '--progress-scale': value / 100 }}
      />
    </div>
  )
}

export default memo(ProgressBar)
