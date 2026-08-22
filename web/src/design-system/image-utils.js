const IMAGE_EXTENSION_PATTERN = /\.(png|webp|jpg|jpeg|gif|svg|bmp|avif)(\?.*)?$/i

export function isImageUrl(value) {
  if (!value || typeof value !== 'string') return false

  const trimmed = value.trim()
  if (!trimmed) return false

  if (
    trimmed.startsWith('http://') ||
    trimmed.startsWith('https://') ||
    trimmed.startsWith('nui://') ||
    trimmed.startsWith('cfx-nui://')
  ) {
    return true
  }

  return IMAGE_EXTENSION_PATTERN.test(trimmed)
}

export function normalizeImageSource(value) {
  if (!isImageUrl(value)) return null
  return value.trim()
}
