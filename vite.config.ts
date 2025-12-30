import { defineConfig } from 'vite';
import moonbit from 'vite-plugin-moonbit';
import { resolve } from 'path';

export default defineConfig({
  plugins: [
    moonbit({
      watch: true,
      showLogs: true,
    })
  ],
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        embed: resolve(__dirname, 'embed.html'),
        webcomponent: resolve(__dirname, 'webcomponent.html'),
        preview: resolve(__dirname, 'preview.html'),
        'free_draw': resolve(__dirname, 'free_draw.html'),
        viewer: resolve(__dirname, 'viewer.html'),
      },
    },
  },
});
