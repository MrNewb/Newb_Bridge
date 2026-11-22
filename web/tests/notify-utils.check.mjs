// Run with: npm test. These used to run when the bundle loaded; they live here so a failure can never take the UI down.
import { normalizeNotify } from '../src/notify-utils.js'

let failures = 0
function fail(name) {
  failures += 1
  console.error('FAIL', name)
}

const stringPayload = normalizeNotify('Saved')
if (!stringPayload || stringPayload.type !== 'inform' || stringPayload.description !== 'Saved') {
  fail('notify string payload')
}

const infoAlias = normalizeNotify({ type: 'info', description: 'Hello' })
if (!infoAlias || infoAlias.type !== 'inform' || infoAlias.position !== 'top-right') {
  fail('notify info alias')
}

const customPayload = normalizeNotify({
  id: 12,
  type: 'success',
  title: 'Notification title',
  description: 'Notification description',
  showDuration: false,
  position: 'top',
  icon: ['fas', 'ban'],
  image: 'ox_inventory/web/images/lockpick.png',
  iconColor: '#C53030',
  iconAnimation: 'spin',
  alignIcon: 'top',
  style: {
    backgroundColor: '#141517',
    color: '#C1C2C5',
    '.description': { color: '#909296' },
  },
})
if (
  !customPayload
  || customPayload.id !== '12'
  || customPayload.showDuration !== false
  || customPayload.icon !== 'fas ban'
  || customPayload.image !== 'nui://ox_inventory/web/images/lockpick.png'
  || customPayload.iconColor !== '#C53030'
  || customPayload.alignIcon !== 'top'
  || customPayload.style?.backgroundColor !== '#141517'
  || customPayload.descriptionStyle?.color !== '#909296'
) {
  fail('notify ox_lib custom payload')
}

const darkClamp = normalizeNotify({
  description: 'Saved',
  style: { backgroundColor: '#09090b', color: '#333333' },
})
if (!darkClamp || darkClamp.style?.color !== '#fafafa') {
  fail('notify contrast clamp dark')
}

const lightClamp = normalizeNotify({
  description: 'Saved',
  style: { backgroundColor: '#fafafa', color: '#eeeeee' },
})
if (!lightClamp || lightClamp.style?.color !== '#09090b') {
  fail('notify contrast clamp light')
}

if (failures) process.exit(1)
console.log('notify-utils checks passed')
