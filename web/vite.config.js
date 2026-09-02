import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const rootDir = fileURLToPath(new URL('.', import.meta.url))

export default defineConfig({
  base: './',
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(rootDir, 'src'),
    },
  },
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
