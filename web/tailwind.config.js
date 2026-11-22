import { readFileSync } from 'node:fs'

// The colours live in src/design-system/tokens.css. Tailwind reads them from there, so a colour is changed in one place.
const tokenCss = readFileSync(new URL('./src/design-system/tokens.css', import.meta.url), 'utf8')

function token(name) {
  const match = tokenCss.match(new RegExp('--' + name + ':\\s*(#[0-9a-fA-F]{3,8})\\s*;'))
  if (!match) throw new Error('tokens.css has no colour token --' + name)
  return match[1]
}

/** @type {import('tailwindcss').Config} */
export default {
  corePlugins: {
    preflight: false,
  },
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        border: token('border'),
        input: token('input'),
        ring: token('ring'),
        background: token('background'),
        foreground: token('foreground'),
        primary: { DEFAULT: token('primary'), foreground: token('primary-foreground'), hover: token('primary-hover') },
        secondary: { DEFAULT: token('secondary'), foreground: token('secondary-foreground') },
        muted: { DEFAULT: token('muted'), foreground: token('muted-foreground') },
        accent: { DEFAULT: token('accent'), foreground: token('accent-foreground') },
        destructive: {
          DEFAULT: token('destructive'),
          foreground: token('destructive-foreground'),
          fill: token('destructive-fill'),
          hover: token('destructive-hover'),
        },
        card: { DEFAULT: token('card'), foreground: token('card-foreground') },
        popover: { DEFAULT: token('popover'), foreground: token('popover-foreground') },
        success: { DEFAULT: token('success'), foreground: token('success-foreground') },
        warning: { DEFAULT: token('warning'), foreground: token('warning-foreground') },
        info: { DEFAULT: token('info'), foreground: token('info-foreground'), fill: token('info-fill') },
        zinc: Object.fromEntries([50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950].map((step) => [step, token('zinc-' + step)])),
      },
      borderRadius: {
        lg: '0.5rem',
        md: 'calc(0.5rem - 2px)',
        sm: 'calc(0.5rem - 4px)',
        xs: '2px',
        full: '999px',
      },
      fontFamily: {
        sans: ['Selawik', 'sans-serif'],
        mono: ['Selawik', 'sans-serif'],
      },
      fontSize: {
        meta: ['0.875rem', { lineHeight: '1.35' }],
        icon: ['0.95rem', { lineHeight: '1.35' }],
      },
      transitionDuration: {
        120: '120ms',
      },
      boxShadow: {
        toast: '0 10px 15px -3px rgba(0, 0, 0, 0.5), 0 4px 6px -4px rgba(0, 0, 0, 0.4)',
        float: '0 10px 15px -3px rgba(0, 0, 0, 0.5), 0 4px 6px -4px rgba(0, 0, 0, 0.4)',
      },
      zIndex: {
        toast: '40',
      },
    },
  },
  plugins: [],
}
