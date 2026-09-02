import React from 'react'
import ReactDOM from 'react-dom/client'
import Dialogue from './dialogue.jsx'
import PlacementOverlays from './PlacementOverlays.jsx'
import TaskGroupMenu from './TaskGroupMenu.jsx'
import TaskHud from './TaskHud.jsx'
import NotifyToaster from './components/NotifyToaster.jsx'
import { installPlacementMessageBuffer } from './placement-message-buffer'
import './index.css'
import './cef.css'
import './components/notify.css'

installPlacementMessageBuffer()

const root = document.getElementById('root')
const notifyRoot = document.getElementById('notify-root')

ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <Dialogue />
    <PlacementOverlays />
    <TaskGroupMenu />
    <TaskHud />
  </React.StrictMode>,
)

if (notifyRoot) {
  ReactDOM.createRoot(notifyRoot).render(
    <React.StrictMode>
      <NotifyToaster />
    </React.StrictMode>,
  )
}

root.classList.add('hidden')
