/**
 * @mizchi/moonlight/headless — build and read drawings without a browser
 */

/** One shape in the scene */
export interface SceneElement {
  /** Identifier, as written in the scenario or minted on import (`el-1`, …) */
  id: string;
  /** "rect" | "circle" | "ellipse" | "line" | "polyline" | "path" | "text" */
  shape: string;
  x: number;
  y: number;
  /** Line only: the far end */
  x2?: number;
  y2?: number;
  bbox: { x: number; y: number; width: number; height: number };
}

/** A line end attached to a shape */
export interface SceneJoint {
  /** id of the line */
  line: string;
  endpoint: 'start' | 'end';
  /** id of the shape it is attached to */
  target: string;
  /** "left" | "right" | "top" | "bottom" | "center" */
  anchor: string;
  /** where that anchor currently is */
  x: number;
  y: number;
}

/** Everything the model knows about a scene */
export interface SceneState {
  ok: true;
  /** the scene before the scenario's inputs were played, when there was one */
  initialSvg?: string;
  svg: string;
  /** a sentence per shape and per connection — what an AI should read first */
  description: string;
  /** claims about the drawing that can be checked against a rendering */
  claims: string[];
  /** connections that no longer hold; empty means the drawing is consistent */
  violations: string[];
  elements: SceneElement[];
  joints: SceneJoint[];
  selection: string[];
}

export interface SceneOptions {
  /** canvas width, default 640 */
  width?: number;
  /** canvas height, default 420 */
  height?: number;
}

/**
 * A drawing being built.
 *
 * It keeps the scenario you have written (and the SVG it started from, if any)
 * and runs it through the model on every question, so the same input always
 * gives the same drawing.
 */
export declare class Scene {
  /**
   * Add scenario lines. Throws on a syntax error, naming the line, and leaves
   * the scene as it was.
   */
  apply(scenario: string): Scene;
  /** The drawing as a Moonlight SVG */
  toSvg(): string;
  /** What is in the drawing, in words */
  describe(): string;
  elements(): SceneElement[];
  joints(): SceneJoint[];
  /** Connections that no longer hold; empty means consistent */
  violations(): string[];
  claims(): string[];
  /** Everything at once */
  inspect(): SceneState;
}

/** Start an empty drawing */
export declare function createScene(options?: SceneOptions): Scene;

/**
 * Read an existing Moonlight SVG and keep editing it.
 *
 * Needs a DOMParser: on Node it borrows one from happy-dom, so this call is
 * async. Everything after it is synchronous.
 */
export declare function loadSvg(svg: string, options?: SceneOptions): Promise<Scene>;

/** Read an SVG and report what is in it, without keeping a scene around */
export declare function describeSvg(svg: string, options?: SceneOptions): Promise<SceneState>;

/**
 * Rasterise an SVG. Needs playwright installed; throws saying so if it is not.
 */
export declare function toPng(
  svg: string,
  options?: { scale?: number; background?: string },
): Promise<Uint8Array>;

export declare const DEFAULT_WIDTH: number;
export declare const DEFAULT_HEIGHT: number;
