import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  base: '/bsnutri/',
  plugins: [react(), tailwindcss()],
  test: { environment: 'jsdom', setupFiles: './src/test/setup.ts' },
})
