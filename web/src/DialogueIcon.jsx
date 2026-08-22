import { memo, useSyncExternalStore } from 'react'
import FallbackIcon from './FallbackIcon'
import { getIconVersion, loadSolidIcon, subscribeToIcons } from './icons'

function DialogueIcon({ name }) {
  // The icon pack loads on demand; re-render once it resolves.
  useSyncExternalStore(subscribeToIcons, getIconVersion, getIconVersion)

  const iconDef = loadSolidIcon(name)

  if (!iconDef?.icon) {
    return <FallbackIcon />
  }

  const [width, height, , , path] = iconDef.icon

  return (
    <svg
      aria-hidden="true"
      className="dialogue-icon-svg dialogue-icon-svg--visible"
      viewBox={`0 0 ${width} ${height}`}
      width="1em"
      height="1em"
      focusable="false"
    >
      <path fill="currentColor" d={path} />
    </svg>
  )
}

export default memo(DialogueIcon)
