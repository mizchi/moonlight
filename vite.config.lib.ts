// WebComponent をライブラリとしてビルドする設定
import { defineConfig } from 'vite';
import moonbit from 'vite-plugin-moonbit';
import { resolve } from 'path';

export default defineConfig({
  plugins: [
    moonbit({
      watch: false,
      showLogs: true,
    })
  ],
  build: {
    outDir: 'dist-lib',
    lib: {
      entry: resolve(__dirname, 'webcomponent.ts'),
      name: 'MoonlightEditor',
      fileName: 'moonlight-editor',
      formats: ['es', 'iife'],
    },
    rollupOptions: {
      output: {
        // IIFE 形式で単一ファイルに
        inlineDynamicImports: true,
      },
    },
    minify: true, // esbuild を使用
  },
});
