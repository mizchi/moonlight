/**
 * @mizchi/moonlight - ESM API
 * 
 * Lightweight SVG editor like Excalidraw
 */

import { createEditor as _createEditor } from "../_build/js/release/build/api/api.js";

/**
 * Create a new Moonlight editor instance
 * @param {HTMLElement} container - DOM element to mount the editor
 * @param {import('./api').EditorOptions} [options] - Editor configuration
 * @returns {import('./api').EditorHandle} Editor handle
 */
export function createEditor(container, options = {}) {
  // Convert options to MoonBit format
  const opts = {
    width: options.width ?? 400,
    height: options.height ?? 300,
    doc_width: options.docWidth ?? options.width ?? 400,
    doc_height: options.docHeight ?? options.height ?? 300,
    zoom: options.zoom ?? 1.0,
    theme: options.theme ?? "light",
    is_readonly: options.readonly ?? false,
    initial_svg: options.initialSvg ?? null,
  };
  
  return _createEditor(container, opts);
}
