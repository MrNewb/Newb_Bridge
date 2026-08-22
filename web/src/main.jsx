import React from 'react'
import ReactDOM from 'react-dom/client'
import Dialogue from './dialogue.jsx'
import PlacementOverlays from './PlacementOverlays.jsx'
import TaskGroupMenu from './TaskGroupMenu.jsx'
import TaskHud from './TaskHud.jsx'
import { installPlacementMessageBuffer } from './placement-message-buffer'
import './index.css'
import './cef.css'

installPlacementMessageBuffer()

const root = document.getElementById('root')
ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <Dialogue />
    <PlacementOverlays />
    <TaskGroupMenu />
    <TaskHud />
  </React.StrictMode>,
)

root.classList.add('hidden')
