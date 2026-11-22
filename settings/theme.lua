-- Server colour palette shared by every Newb UI.
--
-- Each value becomes a CSS variable (`--newb-<token-in-kebab-case>`) that Newb resources read for their
-- backgrounds, text, buttons and status colours. Change a value here, restart Newb_Bridge, then restart
-- (or reopen) the resources using it. Leave a token out and each resource keeps its own built-in colour.
--
-- Colours are `#rgb` / `#rrggbb`. Tokens marked (any) may also be `rgb()` / `rgba()`.
-- Resources still look different from each other (layout, shape, density); only colour is shared.
--
-- Hover, soft (tinted background) and border variants are worked out from the main colour for
-- primary, accent, success, warning, danger, info and close. To set one yourself, add it as its own
-- token, e.g. `successSoft = 'rgba(34, 197, 94, 0.2)'`.

---@class NewbTheme
Config.Theme = {
    -- Surfaces
    background = '#0a0a0a',       -- page / panel canvas
    surface = '#171717',          -- cards and sections
    surfaceRaised = '#262626',    -- inputs, controls, chips
    surfaceHover = '#333333',     -- hovered controls
    menu = '#1c1c1c',             -- dropdowns and popovers
    overlay = 'rgba(0, 0, 0, 0.55)', -- (any) scrim behind modals

    -- Lines
    border = 'rgba(255, 255, 255, 0.1)',       -- (any)
    borderStrong = 'rgba(255, 255, 255, 0.15)', -- (any) inputs and emphasis

    -- Text
    text = '#fafafa',
    textSecondary = '#d4d4d4',
    textMuted = '#a1a1a1',
    textInverse = '#171717',      -- text on a light button

    -- Brand
    primary = '#e5e5e5',          -- main button fill
    primaryContrast = '#171717',  -- text on the primary fill
    accent = '#3b82f6',           -- icons, selection, focus highlights
    accentText = '#60a5fa',       -- accent used as text or icon colour

    -- Status
    success = '#22c55e',
    successText = '#4ade80',
    onSuccess = '#052e16',        -- text on a success fill
    warning = '#f59e0b',
    warningText = '#fbbf24',
    onWarning = '#1c1004',        -- text on a warning fill
    danger = '#ef4444',           -- errors
    dangerText = '#f87171',
    info = '#3b82f6',
    infoText = '#60a5fa',

    -- Exit / close button
    close = '#dc2626',

    -- Shape and type (any CSS value)
    radius = '0.625rem',
    font = 'Selawik, sans-serif',
}
