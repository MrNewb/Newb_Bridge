import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { fetchNui } from './fetch.jsx'
import { trapFocus } from './dialogue-a11y'
import { hideRootIfIdle, showRoot } from './nui-visibility'
import { showNotify } from './notify-utils'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

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
    showNotify({
      description: message,
      type: success ? 'inform' : 'error',
      duration: 3200,
    })
  }, [])

  const closeMenu = useCallback(() => {
    setOpen(false)
    fetchNui('taskGroupMenu:close').catch(() => undefined)
    hideRootIfIdle()
  }, [])

  const openMenu = useCallback((payload) => {
    showRoot()
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
        hideRootIfIdle()
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

  useEffect(() => {
    if (tab === 'manage' && !myGroup) setTab('browse')
  }, [tab, myGroup])

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

  const resolvedTab = tab === 'manage' && !myGroup ? 'browse' : tab

  if (!open) return null

  return (
    <div className="task-group-menu task-group-menu--visible pointer-events-auto fixed inset-0 z-40 flex items-center justify-center select-none">
      <div
        ref={shellRef}
        className="flex max-h-[min(720px,calc(100vh-48px))] w-[min(560px,calc(100vw-32px))] flex-col overflow-hidden rounded-lg border border-solid border-border bg-background shadow-toast"
        role="dialog"
        aria-modal="true"
        aria-labelledby="task-group-menu-title"
      >
        <div className="flex items-start justify-between gap-3 border-b border-border p-4">
          <div>
            <p className="m-0 text-sm text-muted-foreground">{locales.menuBrand}</p>
            <h2 id="task-group-menu-title" className="mt-1 text-lg font-semibold leading-none tracking-tight text-foreground">
              {locales.menuTitle}
            </h2>
          </div>
          <Button ref={closeButtonRef} variant="ghost" size="sm" onClick={closeMenu}>
            {locales.close}
          </Button>
        </div>

        <Tabs value={resolvedTab} onValueChange={setTab} className="min-h-0 flex-1">
          <TabsList className="mx-4 mt-2 w-[calc(100%-2rem)]" aria-label={locales.menuTitle}>
            <TabsTrigger value="browse">{locales.tabBrowse}</TabsTrigger>
            <TabsTrigger value="create">{locales.tabCreate}</TabsTrigger>
            {myGroup ? <TabsTrigger value="manage">{locales.tabManage}</TabsTrigger> : null}
          </TabsList>

          <TabsContent value="browse" className="flex flex-col gap-3">
            <div className="rounded-md bg-card px-4 py-4">
              <Label htmlFor="join-code">{locales.joinWithCode}</Label>
              <Input
                id="join-code"
                value={joinCode}
                onChange={(event) => setJoinCode(event.target.value.replace(/\D/g, '').slice(0, config.joinCodeLength || 6))}
                placeholder={locales.joinCodeHint}
              />
              <Button
                variant="default"
                size="block"
                className="mt-3"
                onClick={() => runAction('taskGroupMenu:joinByCode', { joinCode })}
              >
                {locales.join}
              </Button>
            </div>

            {groups.length === 0 ? (
              <div className="rounded-md bg-muted px-4 py-8 text-center text-sm text-muted-foreground">
                {locales.noPublicGroups}
              </div>
            ) : groups.map((group) => (
              <div key={group.id} className="flex items-center gap-3 rounded-md bg-card px-4 py-4">
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium leading-snug text-foreground">{group.name}</div>
                  <div className="mt-1 text-xs leading-snug text-muted-foreground">
                    {formatLocale(locales.memberCount, group.players?.length ?? 0, group.maxPlayers)}
                  </div>
                </div>
                <Button
                  variant="default"
                  size="sm"
                  onClick={() => runAction('taskGroupMenu:joinGroup', { groupId: group.id })}
                >
                  {locales.join}
                </Button>
              </div>
            ))}
          </TabsContent>

          <TabsContent value="create" className="flex flex-col gap-3">
            <div>
              <h3 className="m-0 text-lg font-semibold leading-none tracking-tight text-foreground">{locales.createTitle}</h3>
              <p className="mt-1.5 text-sm text-muted-foreground">{locales.createHint}</p>
            </div>
            <Label htmlFor="group-name">{locales.groupName}</Label>
            <Input
              id="group-name"
              value={createForm.name}
              maxLength={config.maxNameLength || 32}
              placeholder={locales.groupNamePlaceholder}
              onChange={(event) => setCreateForm({ ...createForm, name: event.target.value })}
            />
            <Label htmlFor="group-max">{locales.maxPlayers}</Label>
            <Input
              id="group-max"
              type="number"
              min={config.minMaxPlayers || 2}
              max={config.maxMaxPlayers || 8}
              value={createForm.maxplayers}
              onChange={(event) => setCreateForm({ ...createForm, maxplayers: Number(event.target.value) || 4 })}
            />
            <label className="flex cursor-pointer items-center gap-2">
              <Checkbox
                id="group-public"
                checked={createForm.public}
                onCheckedChange={(checked) => setCreateForm({ ...createForm, public: checked === true })}
              />
              <span className="text-sm text-foreground">{locales.publicGroup}</span>
            </label>
            <Button variant="default" size="block" onClick={() => runAction('taskGroupMenu:createGroup', createForm)}>
              {locales.createGroup}
            </Button>
          </TabsContent>

          {myGroup ? (
            <TabsContent value="manage" className="flex flex-col gap-3">
              <div className="rounded-md bg-card px-4 py-4">
                <div className="text-sm font-medium leading-snug text-foreground">{myGroup.name}</div>
                <div className="mt-1 text-xs leading-snug text-muted-foreground">
                  {formatLocale(locales.memberCount, myGroup.players?.length ?? 0, myGroup.maxPlayers)}
                </div>
              </div>

              {myGroup.joinCode ? (
                <Button
                  variant="default"
                  size="block"
                  onClick={() => runAction('taskGroupMenu:copyJoinCode', { joinCode: myGroup.joinCode })}
                >
                  {locales.copyJoinCode}
                </Button>
              ) : null}

              {(myGroup.players ?? []).map((player) => {
                const isSelf = Number(player.serverId) === Number(myServerId)
                return (
                  <div key={player.serverId} className="flex items-center justify-between gap-3 rounded-md bg-muted px-3 py-2.5">
                    <div>
                      <div className="text-sm font-medium leading-snug text-foreground">
                        {player.name}
                        {player.leader ? ` · ${locales.leader}` : ''}
                        {isSelf ? ` · ${locales.you}` : ''}
                      </div>
                      <div className="mt-1 text-xs leading-snug text-muted-foreground">ID {player.serverId}</div>
                    </div>
                    {isLeader && !isSelf ? (
                      <Button
                        variant="destructive"
                        size="sm"
                        onClick={() => runAction('taskGroupMenu:kickMember', { targetId: player.serverId })}
                      >
                        {locales.kick}
                      </Button>
                    ) : null}
                  </div>
                )
              })}

              {isLeader ? (
                <>
                  <Button variant="secondary" size="block" onClick={loadInviteCandidates}>
                    {locales.inviteNearby}
                  </Button>
                  {inviteCandidates.map((candidate) => (
                    <div key={candidate.serverId} className="flex items-center justify-between gap-3 rounded-md bg-muted px-3 py-2.5">
                      <div>
                        <div className="text-sm font-medium leading-snug text-foreground">{candidate.name}</div>
                        <div className="mt-1 text-xs leading-snug text-muted-foreground">ID {candidate.serverId}</div>
                      </div>
                      <Button
                        variant="default"
                        size="sm"
                        onClick={() => runAction('taskGroupMenu:inviteMember', { targetId: candidate.serverId })}
                      >
                        {locales.join}
                      </Button>
                    </div>
                  ))}
                  <Button variant="destructive" size="block" onClick={() => runAction('taskGroupMenu:disbandGroup')}>
                    {locales.disbandGroup}
                  </Button>
                </>
              ) : (
                <Button variant="ghost" size="block" onClick={() => runAction('taskGroupMenu:leaveGroup')}>
                  {locales.leaveGroup}
                </Button>
              )}
            </TabsContent>
          ) : null}
        </Tabs>
      </div>
    </div>
  )
}
