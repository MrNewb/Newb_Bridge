import { memo } from 'react'
import FallbackIcon from './FallbackIcon'
import { iconClassName } from './icon-utils'

const knownGlyphs = new Map()

// The Font Awesome stylesheet defines a glyph for every icon name it knows. A name it does not know has no ::before content,
// which is how a mistyped icon is told apart from a real one without shipping a list of names.
function hasGlyph(className) {
  const known = knownGlyphs.get(className)
  if (known !== undefined) return known

  const probe = document.createElement('i')
  probe.className = className
  probe.style.cssText = 'position:absolute;visibility:hidden'
  document.body.appendChild(probe)
  const content = getComputedStyle(probe, '::before').content
  probe.remove()

  const found = Boolean(content) && content !== 'none' && content !== 'normal' && content !== '""'
  knownGlyphs.set(className, found)
  return found
}

function DialogueIcon({ name }) {
  const className = iconClassName(name)

  if (!className || !hasGlyph(className)) {
    return <FallbackIcon />
  }

  return <i aria-hidden="true" className={`${className} dialogue-icon-font`} />
}

export default memo(DialogueIcon)
