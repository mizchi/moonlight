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
    outDir: 'dist',
    emptyOutDir: false, // 他のビルド成果物を消さない
    lib: {
      entry: resolve(__dirname, 'webcomponent.ts'),
      name: 'MoonlightEditor',
      fileName: 'moonlight-editor.component',
      formats: ['es'],
    },
    rollupOptions: {
      output: {
        inlineDynamicImports: true,
      },
    },
    minify: true,
  },
});
