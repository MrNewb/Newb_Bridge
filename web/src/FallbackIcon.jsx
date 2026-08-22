function FallbackIcon() {
  return (
    <svg
      aria-hidden="true"
      className="dialogue-icon-svg dialogue-icon-svg--fallback dialogue-icon-svg--visible"
      viewBox="0 0 512 512"
      width="1em"
      height="1em"
      focusable="false"
    >
      <path
        fill="currentColor"
        d="M256 512A256 256 0 1 0 256 0a256 256 0 1 0 0 512zM216 336h24V272H216v64zm0-96h24V144H216v96z"
      />
    </svg>
  )
}

export default FallbackIcon
