import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { fetchNui } from './fetch.jsx'
import { trapFocus } from './dialogue-a11y'
import './design-system/index.css'
import './task-group-menu.css'

const DEFAULT_LOCALES = {
  menuBrand: 'Newbs Bridge',
  menuTitle: 'Task Groups',
  close: 'Close',
  tabBrowse: 'Browse',
  tabCreate: 'Create',
  tabManage: 'Manage',
  joinWithCode: 'Join with code',
  joinCodeHint: 'Enter the numeric group code.',
  noPublicGroups: 'No public groups right now.',
  join: 'Join',
  createTitle: 'Create a task group',
  createHint: 'You become the leader. Members can be invited nearby.',
  groupName: 'Group name',
  groupNamePlaceholder: 'Heist crew, race lobby…',
  maxPlayers: 'Max players',
  publicGroup: 'List publicly in browse',
  createGroup: 'Create group',
  copyJoinCode: 'Copy join code',
  kick: 'Kick',
  disbandGroup: 'Disband group',
  leaveGroup: 'Leave group',
  inviteNearby: 'Invite nearby player',
  leader: 'Leader',
  you: 'You',
  memberCount: '{current}/{max} members',
  joinCodeCopyFailed: 'Could not copy join code.',
}

function normalizeLocales(value) {
  if (!value || typeof value !== 'object') return DEFAULT_LOCALES

  return {
    ...DEFAULT_LOCALES,
    ...Object.fromEntries(
      Object.entries(DEFAULT_LOCALES).map(([key]) => [
        key,
        typeof value[key] === 'string' ? value[key] : DEFAULT_LOCALES[key],
      ]),
    ),
  }
}

function formatLocale(template, ...args) {
  if (typeof template !== 'string') return ''
  let index = 0
  return template.replace(/\{[^}]+\}/g, () => {
    const value = args[index]
    index += 1
    return value == null ? '' : String(value)
  })
}

function getRootElement() {
  return document.getElementById('root')
}

function shouldHideRoot() {
  return !document.querySelector('.dialogue-container.is-open')
    && !document.querySelector('.prop-placer--visible')
    && !document.querySelector('.gizmo-panel--visible')
    && !document.querySelector('.zone-creator--visible')
    && !document.querySelector('.dui-creator--visible')
    && !document.querySelector('.task-group-menu')
    && !document.querySelector('.task-hud--visible')
}

function applyActionResult(result, setGroups, setMyGroup, notify) {
  if (!result || typeof result !== 'object') return

  if (result.message) {
    notify(result.message, result.success !== false)
  }

  if (Array.isArray(result.groups)) {
    setGroups(result.groups)
  }

  if ('myGroup' in result) {
    setMyGroup(result.myGroup ?? null)
  }
}

export default function TaskGroupMenu() {
  const [open, setOpen] = useState(false)
  const [tab, setTab] = useState('browse')
  const [locales, setLocales] = useState(DEFAULT_LOCALES)
  const [config, setConfig] = useState({})
  const [groups, setGroups] = useState([])
  const [myGroup, setMyGroup] = useState(null)
  const [myServerId, setMyServerId] = useState(0)
  const [toast, setToast] = useState(null)
  const [joinCode, setJoinCode] = useState('')
  const [createForm, setCreateForm] = useState({
    name: '',
    maxplayers: 4,
    public: false,
  })
  const [inviteCandidates, setInviteCandidates] = useState([])
  const shellRef = useRef(null)
  const closeButtonRef = useRef(null)
  const previousFocusRef = useRef(null)

  const notify = useCallback((message, success = true) => {
    if (!message) return
    setToast({ message, success })
    window.setTimeout(() => setToast(null), 3200)
  }, [])

  const closeMenu = useCallback(() => {
    setOpen(false)
    fetchNui('taskGroupMenu:close').catch(() => undefined)
    if (shouldHideRoot()) {
      getRootElement()?.classList.add('hidden')
    }
  }, [])

  const openMenu = useCallback((payload) => {
    getRootElement()?.classList.remove('hidden')
    setLocales(normalizeLocales(payload?.locales))
    setConfig(payload?.config ?? {})
    setGroups(Array.isArray(payload?.groups) ? payload.groups : [])
    setMyGroup(payload?.myGroup ?? null)
    setMyServerId(Number(payload?.myServerId) || 0)
    setTab(payload?.myGroup ? 'manage' : 'browse')
    setCreateForm((current) => ({
      ...current,
      maxplayers: payload?.config?.defaultMaxPlayers ?? current.maxplayers,
    }))
    setOpen(true)
  }, [])

  useEffect(() => {
    const onMessage = (event) => {
      const payload = event.data
      if (!payload?.action) return

      if (payload.action === 'taskGroupMenu:open') {
        openMenu(payload.data)
        return
      }

      if (payload.action === 'taskGroupMenu:close') {
        setOpen(false)
        if (shouldHideRoot()) {
          getRootElement()?.classList.add('hidden')
        }
        return
      }

      if (payload.action === 'taskGroupMenu:refresh' && payload.data) {
        if (Array.isArray(payload.data.groups)) setGroups(payload.data.groups)
        if ('myGroup' in payload.data) setMyGroup(payload.data.myGroup ?? null)
      }
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [openMenu])

  useEffect(() => {
    if (!open) return undefined

    const onKeyDown = (event) => {
      if (event.key === 'Escape') {
        closeMenu()
        return
      }

      const tabs = shellRef.current
        ? Array.from(shellRef.current.querySelectorAll('[role="tab"]'))
        : []
      const focusedTabIndex = tabs.indexOf(event.target)
      if (focusedTabIndex !== -1 && (event.key === 'ArrowRight' || event.key === 'ArrowLeft')) {
        event.preventDefault()
        const step = event.key === 'ArrowRight' ? 1 : -1
        const nextTab = tabs[(focusedTabIndex + step + tabs.length) % tabs.length]
        nextTab.click()
        nextTab.focus()
        return
      }

      trapFocus(shellRef.current, event)
    }

    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [closeMenu, open])

  useEffect(() => {
    if (!open) return undefined

    previousFocusRef.current = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null

    const frame = window.requestAnimationFrame(() => {
      closeButtonRef.current?.focus({
        preventScroll: true,
        focusVisible: false,
      })
    })

    return () => {
      window.cancelAnimationFrame(frame)
      if (previousFocusRef.current instanceof HTMLElement) {
        previousFocusRef.current.focus()
      }
      previousFocusRef.current = null
    }
  }, [open])

  const isLeader = useMemo(() => {
    if (!myGroup) return false
    return Number(myGroup.leader) === Number(myServerId)
  }, [myGroup, myServerId])

  const runAction = useCallback(async (event, data) => {
    const result = await fetchNui(event, data)
    applyActionResult(result, setGroups, setMyGroup, notify)
    if (result?.success && result?.myGroup) setTab('manage')
    return result
  }, [notify])

  const loadInviteCandidates = useCallback(async () => {
    const result = await fetchNui('taskGroupMenu:getNearbyCandidates')
    setInviteCandidates(Array.isArray(result?.candidates) ? result.candidates : [])
  }, [])

  if (!open) return null

  return (
    <>
      <div className="task-group-menu">
        <div
          ref={shellRef}
          className="task-group-menu__shell"
          role="dialog"
          aria-modal="true"
          aria-labelledby="task-group-menu-title"
        >
          <div className="task-group-menu__header">
            <div>
              <p className="task-group-menu__brand">{locales.menuBrand}</p>
              <h2 id="task-group-menu-title" className="task-group-menu__title">{locales.menuTitle}</h2>
            </div>
            <button
              ref={closeButtonRef}
              type="button"
              className="task-group-menu__btn task-group-menu__btn--compact task-group-menu__btn--ghost"
              onClick={closeMenu}
            >
              {locales.close}
            </button>
          </div>

          <div className="task-group-menu__tabs" role="tablist" aria-label={locales.menuTitle}>
            {[
              { id: 'browse', label: locales.tabBrowse },
              { id: 'create', label: locales.tabCreate },
              ...(myGroup ? [{ id: 'manage', label: locales.tabManage }] : []),
            ].map((entry) => (
              <button
                key={entry.id}
                type="button"
                role="tab"
                id={`task-group-tab-${entry.id}`}
                aria-selected={tab === entry.id}
                aria-controls="task-group-panel"
                className={`task-group-menu__tab ${tab === entry.id ? 'task-group-menu__tab--active' : ''}`}
                onClick={() => setTab(entry.id)}
              >
                {entry.label}
              </button>
            ))}
          </div>

          <div
            className="task-group-menu__body"
            role="tabpanel"
            id="task-group-panel"
            aria-labelledby={`task-group-tab-${tab}`}
          >
            {tab === 'browse' && (
              <div className="task-group-menu__stack">
                <div className="task-group-menu__card">
                  <label className="task-group-menu__label" htmlFor="join-code">{locales.joinWithCode}</label>
                  <input
                    id="join-code"
                    className="dialogue-input-native"
                    value={joinCode}
                    onChange={(event) => setJoinCode(event.target.value.replace(/\D/g, '').slice(0, config.joinCodeLength || 6))}
                    placeholder={locales.joinCodeHint}
                  />
                  <button
                    type="button"
                    className="task-group-menu__btn task-group-menu__btn--info task-group-menu__btn--block task-group-menu__card--action"
                    onClick={() => runAction('taskGroupMenu:joinByCode', { joinCode })}
                  >
                    {locales.join}
                  </button>
                </div>

                {groups.length === 0 ? (
                  <div className="task-group-menu__empty">{locales.noPublicGroups}</div>
                ) : groups.map((group) => (
                  <div key={group.id} className="task-group-menu__card task-group-menu__row">
                    <div className="task-group-menu__grow">
                      <div className="task-group-menu__member-name">{group.name}</div>
                      <div className="task-group-menu__member-meta">
                        {formatLocale(locales.memberCount, group.players?.length ?? 0, group.maxPlayers)}
                      </div>
                    </div>
                    <button
                      type="button"
                      className="task-group-menu__btn task-group-menu__btn--info task-group-menu__btn--compact"
                      onClick={() => runAction('taskGroupMenu:joinGroup', { groupId: group.id })}
                    >
                      {locales.join}
                    </button>
                  </div>
                ))}
              </div>
            )}

            {tab === 'create' && (
              <div className="task-group-menu__stack">
                <div>
                  <h3 className="task-group-menu__title">{locales.createTitle}</h3>
                  <p className="task-group-menu__subtitle">{locales.createHint}</p>
                </div>
                <label className="task-group-menu__label" htmlFor="group-name">{locales.groupName}</label>
                <input
                  id="group-name"
                  className="dialogue-input-native"
                  value={createForm.name}
                  maxLength={config.maxNameLength || 32}
                  placeholder={locales.groupNamePlaceholder}
                  onChange={(event) => setCreateForm({ ...createForm, name: event.target.value })}
                />
                <label className="task-group-menu__label" htmlFor="group-max">{locales.maxPlayers}</label>
                <input
                  id="group-max"
                  type="number"
                  className="dialogue-input-native"
                  min={config.minMaxPlayers || 2}
                  max={config.maxMaxPlayers || 8}
                  value={createForm.maxplayers}
                  onChange={(event) => setCreateForm({ ...createForm, maxplayers: Number(event.target.value) || 4 })}
                />
                <label className="dialogue-input-checkbox">
                  <input
                    id="group-public"
                    type="checkbox"
                    className="dialogue-input-checkbox-control"
                    checked={createForm.public}
                    onChange={(event) => setCreateForm({ ...createForm, public: event.target.checked })}
                  />
                  <span className="dialogue-input-checkbox-label">{locales.publicGroup}</span>
                </label>
                <button
                  type="button"
                  className="task-group-menu__btn task-group-menu__btn--info task-group-menu__btn--block"
                  onClick={() => runAction('taskGroupMenu:createGroup', createForm)}
                >
                  {locales.createGroup}
                </button>
              </div>
            )}

            {tab === 'manage' && myGroup && (
              <div className="task-group-menu__stack">
                <div className="task-group-menu__card">
                  <div className="task-group-menu__member-name">{myGroup.name}</div>
                  <div className="task-group-menu__member-meta">
                    {formatLocale(locales.memberCount, myGroup.players?.length ?? 0, myGroup.maxPlayers)}
                  </div>
                </div>

                {myGroup.joinCode && (
                  <button
                    type="button"
                    className="task-group-menu__btn task-group-menu__btn--info task-group-menu__btn--block"
                    onClick={() => runAction('taskGroupMenu:copyJoinCode', { joinCode: myGroup.joinCode })}
                  >
                    {locales.copyJoinCode}
                  </button>
                )}

                {(myGroup.players ?? []).map((player) => {
                  const isSelf = Number(player.serverId) === Number(myServerId)
                  return (
                    <div key={player.serverId} className="task-group-menu__member">
                      <div>
                        <div className="task-group-menu__member-name">
                          {player.name}
                          {player.leader ? ` · ${locales.leader}` : ''}
                          {isSelf ? ` · ${locales.you}` : ''}
                        </div>
                        <div className="task-group-menu__member-meta">ID {player.serverId}</div>
                      </div>
                      {isLeader && !isSelf && (
                        <button
                          type="button"
                          className="task-group-menu__btn task-group-menu__btn--danger task-group-menu__btn--compact"
                          onClick={() => runAction('taskGroupMenu:kickMember', { targetId: player.serverId })}
                        >
                          {locales.kick}
                        </button>
                      )}
                    </div>
                  )
                })}

                {isLeader && (
                  <>
                    <button
                      type="button"
                      className="task-group-menu__btn task-group-menu__btn--block"
                      onClick={loadInviteCandidates}
                    >
                      {locales.inviteNearby}
                    </button>
                    {inviteCandidates.map((candidate) => (
                      <div key={candidate.serverId} className="task-group-menu__member">
                        <div>
                          <div className="task-group-menu__member-name">{candidate.name}</div>
                          <div className="task-group-menu__member-meta">ID {candidate.serverId}</div>
                        </div>
                        <button
                          type="button"
                          className="task-group-menu__btn task-group-menu__btn--info task-group-menu__btn--compact"
                          onClick={() => runAction('taskGroupMenu:inviteMember', { targetId: candidate.serverId })}
                        >
                          {locales.join}
                        </button>
                      </div>
                    ))}
                    <button
                      type="button"
                      className="task-group-menu__btn task-group-menu__btn--danger task-group-menu__btn--block"
                      onClick={() => runAction('taskGroupMenu:disbandGroup')}
                    >
                      {locales.disbandGroup}
                    </button>
                  </>
                )}

                {!isLeader && (
                  <button
                    type="button"
                    className="task-group-menu__btn task-group-menu__btn--ghost task-group-menu__btn--block"
                    onClick={() => runAction('taskGroupMenu:leaveGroup')}
                  >
                    {locales.leaveGroup}
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {toast && (
        <div
          className={`task-group-menu__toast ${toast.success ? 'task-group-menu__toast--info' : 'task-group-menu__toast--error'}`}
          role="status"
          aria-live="polite"
          aria-atomic="true"
        >
          {toast.message}
        </div>
      )}
    </>
  )
}
