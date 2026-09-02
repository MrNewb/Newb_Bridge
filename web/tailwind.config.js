/** @type {import('tailwindcss').Config} */
export default {
  corePlugins: {
    preflight: false,
  },
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        border: '#3f3f46',
        input: '#3f3f46',
        ring: '#d4d4d8',
        background: '#09090b',
        foreground: '#fafafa',
        primary: {
          DEFAULT: '#fafafa',
          foreground: '#18181b',
          hover: '#e4e4e7',
        },
        secondary: {
          DEFAULT: '#27272a',
          foreground: '#fafafa',
        },
        muted: {
          DEFAULT: '#27272a',
          foreground: '#a1a1aa',
        },
        accent: {
          DEFAULT: '#27272a',
          foreground: '#fafafa',
        },
        destructive: {
          DEFAULT: '#ef4444',
          foreground: '#fafafa',
          hover: '#dc2626',
        },
        card: {
          DEFAULT: '#18181b',
          foreground: '#fafafa',
        },
        popover: {
          DEFAULT: '#18181b',
          foreground: '#fafafa',
        },
        success: {
          DEFAULT: '#22c55e',
          foreground: '#052e16',
        },
        warning: {
          DEFAULT: '#eab308',
          foreground: '#422006',
        },
        info: {
          DEFAULT: '#3b82f6',
          foreground: '#eff6ff',
        },
        zinc: {
          50: '#fafafa',
          100: '#f4f4f5',
          200: '#e4e4e7',
          300: '#d4d4d8',
          400: '#a1a1aa',
          500: '#71717a',
          600: '#52525b',
          700: '#3f3f46',
          800: '#27272a',
          900: '#18181b',
          950: '#09090b',
        },
      },
      borderRadius: {
        lg: '0.5rem',
        md: 'calc(0.5rem - 2px)',
        sm: 'calc(0.5rem - 4px)',
        xs: '2px',
        full: '999px',
      },
      fontFamily: {
        sans: ['ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        meta: ['0.875rem', { lineHeight: '1.35' }],
        icon: ['0.95rem', { lineHeight: '1.35' }],
        kbd: ['11px', { lineHeight: '1' }],
        'kbd-badge': ['0.625rem', { lineHeight: '1' }],
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
