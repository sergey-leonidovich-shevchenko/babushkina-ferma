import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: './',
  build: { target: 'es2022', sourcemap: false, outDir: process.env.WIKI_BUILD_OUT || 'dist' },
  server: {
    host: '127.0.0.1',
    port: 4173,
    strictPort: true,
    proxy: {
      '/__wiki': {
        target: process.env.WIKI_API_URL ?? 'http://127.0.0.1:4174',
        changeOrigin: false,
      },
    },
  },
})
