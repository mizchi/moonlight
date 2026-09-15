import { defineConfig } from 'vite';
import moonbit from 'vite-plugin-moonbit';
import { resolve } from 'node:path';

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
        main: resolve(import.meta.dirname, 'index.html'),
        embed: resolve(import.meta.dirname, 'examples/embed.html'),
        webcomponent: resolve(import.meta.dirname, 'examples/webcomponent.html'),
        preview: resolve(import.meta.dirname, 'examples/preview.html'),
        'free_draw': resolve(import.meta.dirname, 'examples/free_draw.html'),
        viewer: resolve(import.meta.dirname, 'examples/viewer.html'),
        'api-demo': resolve(import.meta.dirname, 'examples/api-demo.html'),
        help: resolve(import.meta.dirname, 'docs/help.html'),
      },
    },
  },
});
