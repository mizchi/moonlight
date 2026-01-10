/**
 * Moonlight Editor - TypeScript Type Definitions
 */

export interface EditorOptions {
  /** Canvas width in pixels */
  width?: number;
  /** Canvas height in pixels */
  height?: number;
  /** Document width (viewBox) */
  docWidth?: number;
  /** Document height (viewBox) */
  docHeight?: number;
  /** Initial zoom level */
  zoom?: number;
  /** Theme: "light" or "dark" */
  theme?: "light" | "dark";
  /** Read-only mode */
  readonly?: boolean;
  /** Initial SVG content */
  initialSvg?: string;
}

export interface EditorHandle {
  /** Export current drawing as SVG string */
  exportSvg(): string;
  /** Import SVG string into editor */
  importSvg(svg: string): void;
  /** Clear all elements */
  clear(): void;
  /** Destroy editor and cleanup */
  destroy(): void;
  /** Check if editor has focus */
  hasFocus(): boolean;
  /** Register change callback */
  onChange(callback: () => void): void;
}

/**
 * Create a new Moonlight editor instance
 * @param container - DOM element to mount the editor
 * @param options - Editor configuration options
 * @returns Editor handle with control methods
 * 
 * @example
 * ```typescript
 * import { createEditor } from '@mizchi/moonlight';
 * 
 * const editor = createEditor(document.getElementById('container'), {
 *   width: 800,
 *   height: 600,
 *   theme: 'dark',
 * });
 * 
 * editor.onChange(() => {
 *   console.log('Editor changed:', editor.exportSvg());
 * });
 * ```
 */
export function createEditor(
  container: HTMLElement,
  options?: EditorOptions
): EditorHandle;
