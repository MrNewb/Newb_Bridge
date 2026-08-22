import { lazy, Suspense, useEffect, useState } from 'react'

const PropPlacer = lazy(() => import('./PropPlacer.jsx'))
const GizmoPanel = lazy(() => import('./GizmoPanel.jsx'))
const ZoneCreatorPanel = lazy(() => import('./ZoneCreatorPanel.jsx'))
const DuiCreatorPanel = lazy(() => import('./DuiCreatorPanel.jsx'))

export default function PlacementOverlays() {
  const [ready, setReady] = useState(false)

  useEffect(() => {
    const activate = () => setReady(true)

    window.addEventListener('placement:open', activate)
    return () => window.removeEventListener('placement:open', activate)
  }, [])

  if (!ready) return null

  return (
    <Suspense fallback={null}>
      <PropPlacer />
      <GizmoPanel />
      <ZoneCreatorPanel />
      <DuiCreatorPanel />
    </Suspense>
  )
}
