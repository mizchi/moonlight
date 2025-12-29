// rolldown config for WebComponent IIFE bundle
import { defineConfig } from 'rolldown';

export default defineConfig({
  input: 'target/js/release/build/webcomponent/webcomponent.js',
  output: {
    file: 'dist/moonlight-editor.component.js',
    format: 'iife',
    name: 'MoonlightEditor',
    minify: true,
  },
});
