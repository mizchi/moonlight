// rolldown config for WebComponent chunk splitting
// 1. component.js (shell): カスタム要素登録 + プレビュー + Edit ボタン (~5KB)
// 2. editor.js (heavy): エディタ本体、動的 import される (~150KB)
import { defineConfig } from 'rolldown';

export default defineConfig([
  // Shell: 軽量なカスタム要素登録
  {
    input: 'target/js/release/build/webcomponent/webcomponent.js',
    output: {
      file: 'dist/moonlight-editor.component.js',
      format: 'iife',
      name: 'MoonlightEditorShell',
      minify: true,
    },
  },
  // Editor: 重量級エディタモジュール（ESM で動的 import 用）
  {
    input: 'target/js/release/build/webcomponent-editor/webcomponent-editor.js',
    output: {
      file: 'dist/moonlight-editor.editor.js',
      format: 'esm',
      minify: true,
      // グローバルから ES module export を生成
      footer: 'export const createEditor = globalThis.__moonlightEditorModule.createEditor;',
    },
  },
]);
