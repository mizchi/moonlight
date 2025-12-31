// Moonlight Editor - TypeScript Type Definitions

/**
 * Editor options for creating an embedded editor
 */
export interface EditorOptions {
  /** Canvas width in pixels */
  width?: number;
  /** Canvas height in pixels */
  height?: number;
  /** Enable grid snapping */
  gridsnap?: boolean;
  /** Theme mode */
  theme?: 'light' | 'dark';
  /** Initial zoom level (1.0 = 100%) */
  zoom?: number;
  /** Enable read-only mode */
  readonly?: boolean;
  /** Show toolbar */
  toolbarVisible?: boolean;
  /** Initial SVG content */
  initialSvg?: string;
  /** Show help button (default: true) */
  showHelpButton?: boolean;
}

/**
 * Element information returned by getElements
 */
export interface ElementInfo {
  id: string;
  x: number;
  y: number;
  shape: unknown;
  style: unknown;
  transform?: string;
  parent_id?: string;
  connections?: unknown;
}

/**
 * Tool mode for the editor
 */
export type ToolMode = 'select' | 'freedraw';

/**
 * Unsubscribe function returned by event subscriptions
 */
export type Unsubscribe = () => void;

/**
 * Editor handle for controlling the embedded editor
 */
export interface EditorHandle {
  // === Existing API ===
  /** Export the current content as SVG string */
  exportSvg(): string;
  /** Import SVG content into the editor */
  importSvg(svg: string): void;
  /** Clear all elements from the editor */
  clear(): void;
  /** Destroy the editor and clean up resources */
  destroy(): void;
  /** Check if the editor has focus */
  hasFocus(): boolean;

  // === Selection API ===
  /** Select elements by IDs */
  select(ids: string[]): void;
  /** Select all elements */
  selectAll(): void;
  /** Deselect all elements */
  deselect(): void;
  /** Get currently selected element IDs */
  getSelectedIds(): string[];

  // === Focus API ===
  /** Focus the editor */
  focus(): void;
  /** Blur the editor */
  blur(): void;

  // === Element API ===
  /** Get all elements */
  getElements(): ElementInfo[];
  /** Get an element by ID */
  getElementById(id: string): ElementInfo | null;
  /** Delete elements by IDs */
  deleteElements(ids: string[]): void;

  // === Mode API ===
  /** Set the tool mode */
  setMode(mode: ToolMode): void;
  /** Get the current tool mode */
  getMode(): ToolMode;

  // === Readonly API ===
  /** Set readonly mode */
  setReadonly(readonly: boolean): void;
  /** Check if readonly mode is enabled */
  isReadonly(): boolean;

  // === Event Subscriptions ===
  /** Subscribe to change events. Returns unsubscribe function. */
  onChange(callback: () => void): Unsubscribe;
  /** Subscribe to selection events. Returns unsubscribe function. */
  onSelect(callback: (ids: string[]) => void): Unsubscribe;
  /** Subscribe to deselection events. Returns unsubscribe function. */
  onDeselect(callback: () => void): Unsubscribe;
  /** Subscribe to focus events. Returns unsubscribe function. */
  onFocus(callback: () => void): Unsubscribe;
  /** Subscribe to blur events. Returns unsubscribe function. */
  onBlur(callback: () => void): Unsubscribe;
  /** Subscribe to mode change events. Returns unsubscribe function. */
  onModeChange(callback: (mode: ToolMode) => void): Unsubscribe;
  /** Subscribe to element add events. Returns unsubscribe function. */
  onElementAdd(callback: (id: string) => void): Unsubscribe;
  /** Subscribe to element delete events. Returns unsubscribe function. */
  onElementDelete(callback: (id: string) => void): Unsubscribe;
}

/**
 * MoonlightEditor API for creating embedded editors
 */
export interface MoonlightEditorAPI {
  /** Create a new editor instance */
  create(container: HTMLElement, options?: EditorOptions): EditorHandle;
}

/**
 * Preview options
 */
export interface PreviewOptions {
  /** Preview width in pixels */
  width?: number;
  /** Preview height in pixels */
  height?: number;
}

/**
 * Preview handle for controlling the preview mode
 */
export interface PreviewHandle {
  /** Open the editor modal */
  openEditor(): void;
  /** Close the editor modal */
  closeEditor(): void;
  /** Check if the editor modal is open */
  isOpen(): boolean;
  /** Get the current SVG content */
  getSvg(): string;
  /** Set the SVG content */
  setSvg(svg: string): void;
}

/**
 * MoonlightPreview API for creating preview instances
 */
export interface MoonlightPreviewAPI {
  /** Create a new preview instance */
  create(container: HTMLElement, svg: string, options?: PreviewOptions): PreviewHandle;
}

// Global declarations
declare global {
  interface Window {
    MoonlightEditor: MoonlightEditorAPI;
    MoonlightPreview: MoonlightPreviewAPI;
  }

  interface HTMLElementTagNameMap {
    'moonlight-editor': HTMLMoonlightEditorElement;
  }
}

/**
 * Moonlight Editor custom element
 */
export interface HTMLMoonlightEditorElement extends HTMLElement {
  /** Shadow root of the element */
  readonly shadowRoot: ShadowRoot;
  /** Export SVG content */
  exportSvg(): string;
  /** Import SVG content */
  importSvg(svg: string): void;
  /** Clear the editor */
  clear(): void;
}

/**
 * Observed attributes for moonlight-editor element
 */
export type MoonlightEditorAttribute =
  | 'width'
  | 'height'
  | 'gridsnap'
  | 'theme'
  | 'zoom'
  | 'readonly'
  | 'toolbar-visible';

export {};
