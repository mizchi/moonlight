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
        embed: resolve(__dirname, 'examples/embed.html'),
        webcomponent: resolve(__dirname, 'examples/webcomponent.html'),
        preview: resolve(__dirname, 'examples/preview.html'),
        'free_draw': resolve(__dirname, 'examples/free_draw.html'),
        viewer: resolve(__dirname, 'examples/viewer.html'),
      },
    },
  },
});
