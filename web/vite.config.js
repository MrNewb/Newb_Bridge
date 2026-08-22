import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: './',
  plugins: [react()],
  build: {
    outDir: 'build',
    target: 'es2020',
    modulePreload: {
      polyfill: false,
    },
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('@fortawesome/free-brands-svg-icons')) return 'icons-brands'
          if (id.includes('@fortawesome/free-regular-svg-icons')) return 'icons-regular'
          if (
            id.includes('@fortawesome/free-solid-svg-icons')
            || id.includes('@fortawesome/fontawesome-svg-core')
          ) {
            return 'icons-solid'
          }
        },
      },
    },
  },
})
