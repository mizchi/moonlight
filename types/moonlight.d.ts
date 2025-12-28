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
}

/**
 * Editor handle for controlling the embedded editor
 */
export interface EditorHandle {
  /** Export the current content as SVG string */
  exportSvg(): string;
  /** Import SVG content into the editor */
  importSvg(svg: string): void;
  /** Clear all elements from the editor */
  clear(): void;
  /** Destroy the editor and clean up resources */
  destroy(): void;
  /** Subscribe to change events */
  onChange(callback: (elements: any[]) => void): void;
  /** Check if the editor has focus */
  hasFocus(): boolean;
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
