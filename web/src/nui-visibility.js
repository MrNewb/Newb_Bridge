export function getRootElement() {
  return document.getElementById('root')
}

export function isInteractiveUiOpen() {
  return Boolean(
    document.querySelector('.dialogue-container.is-open')
    || document.querySelector('.prop-placer--visible')
    || document.querySelector('.gizmo-panel--visible')
    || document.querySelector('.zone-creator--visible')
    || document.querySelector('.dui-creator--visible')
    || document.querySelector('.task-group-menu--visible')
    || document.querySelector('.task-hud--visible'),
  )
}

export function showRoot() {
  getRootElement()?.classList.remove('hidden')
}

export function hideRootIfIdle() {
  requestAnimationFrame(() => {
    if (!isInteractiveUiOpen()) {
      getRootElement()?.classList.add('hidden')
    }
  })
}
