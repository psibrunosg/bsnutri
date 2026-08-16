import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: '/bsnutri/',
  plugins: [react()],
  test: {
    // As jornadas de ponta a ponta rodam no Playwright (`npm run test:e2e`).
    exclude: ['node_modules/**', 'dist/**', 'e2e/**'],
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    pool: 'forks',
    fileParallelism: false,
    maxWorkers: 1,
  },
})
