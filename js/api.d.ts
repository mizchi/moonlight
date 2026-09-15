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

export interface EditorElement {
  id: string;
  x: number;
  y: number;
}

/** Unsubscribe from an event registered with one of the `on*` methods */
export type Unsubscribe = () => void;

export interface EditorHandle {
  /** Export current drawing as SVG string */
  exportSvg(): string;
  /**
   * Import an SVG string into the editor, replacing its contents.
   * Element ids are regenerated so they cannot collide; connections and
   * parent links are remapped to match.
   */
  importSvg(svg: string): void;
  /** Clear all elements */
  clear(): void;
  /** Destroy editor and cleanup */
  destroy(): void;
  /** Check if editor has focus */
  hasFocus(): boolean;

  /** Select one element or several; replaces the current selection */
  select(ids: string | string[]): void;
  /** Select every element */
  selectAll(): void;
  /** Clear the selection */
  deselect(): void;
  /** Ids of the currently selected elements */
  getSelectedIds(): string[];

  /** Give the editor keyboard focus */
  focus(): void;
  /** Take keyboard focus away from the editor */
  blur(): void;

  /** Every element currently on the canvas */
  getElements(): EditorElement[];
  /** One element by id, or null when there is none */
  getElementById(id: string): EditorElement | null;
  /** Delete one element or several */
  deleteElements(ids: string | string[]): void;

  /** Switch between the select tool and free drawing */
  setMode(mode: "select" | "freedraw"): void;
  getMode(): "select" | "freedraw";

  /** Turn editing off (the drawing stays visible) */
  setReadonly(value: boolean): void;
  isReadonly(): boolean;

  onChange(callback: () => void): Unsubscribe;
  onSelect(callback: (ids: string[]) => void): Unsubscribe;
  onDeselect(callback: () => void): Unsubscribe;
  onFocus(callback: () => void): Unsubscribe;
  onBlur(callback: () => void): Unsubscribe;
  onModeChange(callback: (mode: string) => void): Unsubscribe;
  onElementAdd(callback: (id: string) => void): Unsubscribe;
  onElementDelete(callback: (id: string) => void): Unsubscribe;
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
