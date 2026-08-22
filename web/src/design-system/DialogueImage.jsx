import { memo, useState } from 'react'

function DialogueImage({ src, variant = 'icon', className = '', alt = '' }) {
  const [loaded, setLoaded] = useState(false)
  const [failed, setFailed] = useState(false)

  if (!src || failed) return null

  return (
    <span
      className={['dialogue-image-wrap', `dialogue-image-wrap--${variant}`, className]
        .filter(Boolean)
        .join(' ')}
    >
      {!loaded && <span className="dialogue-image-skeleton" aria-hidden="true" />}
      <img
        className={[
          'dialogue-image',
          `dialogue-image--${variant}`,
          loaded ? 'is-loaded' : '',
        ]
          .filter(Boolean)
          .join(' ')}
        src={src}
        alt={alt}
        aria-hidden={alt ? undefined : true}
        loading="lazy"
        decoding="async"
        onLoad={() => setLoaded(true)}
        onError={() => setFailed(true)}
      />
    </span>
  )
}

export default memo(DialogueImage)
