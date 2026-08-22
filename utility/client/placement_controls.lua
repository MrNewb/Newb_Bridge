-- Shared GTA control IDs for the placement UIs (placer, gizmo, zone creator,
-- DUI). Keyboard hints in the NUI panels need to stay aligned with these.
local controls = {
    place = 38, -- E (INPUT_PICKUP)
    cancel = 194, -- Backspace / frontend back
    returnMenu = 74, -- H — optional alternate cancel / return to admin UI
    scrollUp = 15,
    scrollDown = 14,
    rotateLeft = 174, -- Arrow left
    rotateRight = 175, -- Arrow right
    pedRaise = 172, -- Arrow up
    pedLower = 173, -- Arrow down
    undo = 20, -- Z (INPUT_MULTIPLAYER_INFO) — undo last multi placement
    animClear = 73, -- X (INPUT_VEH_DUCK)
    previewModeToggle = 37, -- Tab — switch what the arrow keys adjust (height, model, animation)
    gizmoToggle = 47, -- G — open transform gizmo on the preview
    gizmoSnap = 19, -- Left Alt (INPUT_CHARACTER_WHEEL) — snap gizmo entity to ground
    modifierCoarse = 21, -- Left Shift — coarser scroll step
    modifierFine = 19, -- Left Alt — finer scroll step
    cancelGraceMs = 400,
    frontendCancel = { 194, 200, 202, 177 },
}

-- swallows frontend cancel/back for as long as isActive returns true, so the
-- input that opened a placement session can't immediately close it
function controls.blockCancelWhile(isActive)
    CreateThread(function()
        while isActive() do
            for i = 1, #controls.frontendCancel do
                DisableControlAction(0, controls.frontendCancel[i], true)
            end
            Wait(0)
        end
    end)
end

return controls
