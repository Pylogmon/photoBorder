import { readdirSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const isHarmony = mode === 'harmony'

  return {
    base: './',
    define: {
      __HARMONY_RAWFILE__: JSON.stringify(isHarmony),
    },
    plugins: [react(), cameraLogoSvgVirtualModule(isHarmony), isHarmony && harmonyRawfileHtml()],
    build: isHarmony
      ? {
          outDir: 'harmony/entry/src/main/resources/rawfile',
          modulePreload: false,
          cssCodeSplit: false,
          rollupOptions: {
            output: {
              format: 'iife',
              inlineDynamicImports: true,
            },
          },
        }
      : undefined,
  }
})

function cameraLogoSvgVirtualModule(includeLogos: boolean): Plugin {
  const virtualModuleId = 'virtual:camera-logo-svgs'
  const resolvedVirtualModuleId = `\0${virtualModuleId}`

  return {
    name: 'camera-logo-svg-virtual-module',
    resolveId(id: string) {
      if (id === virtualModuleId) return resolvedVirtualModuleId
    },
    load(id: string) {
      if (id !== resolvedVirtualModuleId) return
      if (!includeLogos) return 'export const cameraLogoSvgs = {}'

      const logoDirectory = resolve(import.meta.dirname, 'public/camera-logos')
      const logos = Object.fromEntries(
        readdirSync(logoDirectory)
          .filter((fileName) => fileName.toLowerCase().endsWith('.svg'))
          .map((fileName) => [fileName, readFileSync(resolve(logoDirectory, fileName), 'utf8')]),
      )

      return `export const cameraLogoSvgs = ${JSON.stringify(logos)}`
    },
  }
}

function harmonyRawfileHtml() {
  return {
    name: 'harmony-rawfile-html',
    transformIndexHtml(html: string) {
      return html
        .replace(/\s*<link rel="manifest"[^>]*>\n?/g, '')
        .replace(/\s*crossorigin(?:="[^"]*")?/g, '')
        .replace(/<script type="module"([^>]*)>/g, '<script defer$1>')
    },
  }
}
