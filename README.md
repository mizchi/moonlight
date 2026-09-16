# Moonlight

A lightweight SVG editor built with MoonBit and the Luna reactive UI library. Inspired by Excalidraw, Moonlight provides a simple yet powerful interface for creating and editing vector graphics.

## Demo

**Live Demo**: https://moonlight.mizchi.workers.dev

Try the editor directly in your browser. No installation required.

## Features

- **SVG-native**: Works directly with SVG elements (rect, circle, ellipse, line, text)
- **Multiple modes**: Full editor, embeddable widget, and Web Component
- **Reactive UI**: Built on Luna's signal-based reactivity
- **Undo/Redo**: Full command history support
- **Grid snapping**: Optional snap-to-grid for precise alignment
- **Connected lines**: Lines can connect to element anchor points and follow when moved
- **Dark/Light themes**: Toggle between dark and light modes
- **Import/Export**: Save and load SVG files

## Getting Started

### Prerequisites

- [MoonBit](https://www.moonbitlang.com/) toolchain
- Node.js 18+
- pnpm

### Installation

```bash
git clone <repository-url>
cd moonlight
pnpm install
```

### Development

```bash
# Start development server
pnpm dev

# Type checking
moon check

# Format code
moon fmt

# Build for production
pnpm build
```

### Access the Editor

- **Full Editor**: http://localhost:5173/
- **Embed Mode**: http://localhost:5173/embed.html
- **Web Component**: http://localhost:5173/webcomponent.html

## User Guide

### Tools

| Tool | Shortcut | Description |
|------|----------|-------------|
| Select | `V` or `1` | Select and move elements |
| Rectangle | `R` or `2` | Draw rectangles |
| Circle | `C` or `3` | Draw circles/ellipses |
| Line | `L` or `4` | Draw lines and arrows |
| Text | `T` or `5` | Add text elements |

### Keyboard Shortcuts

#### General
| Shortcut | Action |
|----------|--------|
| `Ctrl+Z` / `Cmd+Z` | Undo |
| `Ctrl+Shift+Z` / `Cmd+Shift+Z` | Redo |
| `Ctrl+Y` / `Cmd+Y` | Redo (alternative) |
| `Delete` / `Backspace` | Delete selected element |
| `Escape` | Deselect / Cancel operation |

#### Navigation
| Shortcut | Action |
|----------|--------|
| `Arrow Keys` | Move selected element (5px) |
| `Shift + Arrow Keys` | Move selected element (1px, precise) |
| `Ctrl + Arrow Keys` | Move selected element (10px, fast) |

#### Element Operations
| Shortcut | Action |
|----------|--------|
| `Ctrl+D` / `Cmd+D` | Duplicate selected element |
| `[` | Send backward |
| `]` | Bring forward |
| `Ctrl+[` / `Cmd+[` | Send to back |
| `Ctrl+]` / `Cmd+]` | Bring to front |

#### View
| Shortcut | Action |
|----------|--------|
| `G` | Toggle grid visibility |
| `Ctrl+G` / `Cmd+G` | Toggle grid snapping |

### Mouse Operations

- **Click**: Select element
- **Click + Drag**: Move element or draw new shape
- **Click on canvas**: Deselect all
- **Right-click**: Context menu (delete, duplicate, layer ordering)

### Working with Lines

Lines can be connected to other elements:

1. Select the Line tool (`L`)
2. Click near an element's anchor point (edges or center)
3. Drag to another element's anchor point
4. The line will automatically follow when connected elements are moved

### Detail Panel

The right sidebar shows properties of the selected element:

- **Position**: X/Y coordinates (editable)
- **Size**: Width/Height or radius (editable)
- **Style**: Fill color, stroke color, stroke width
- **Line markers**: Add arrows to line endpoints

### Themes

Toggle between light and dark themes using the theme button in the toolbar.

## Usage Modes

### 1. Full Editor Mode

The standalone editor with all features enabled.

```html
<script type="module" src="./main.ts"></script>
```

### 2. Embed Mode

Embed the editor in your application using JavaScript:

```html
<script type="module" src="./embed.ts"></script>
<div id="editor-container"></div>
<script>
  const editor = MoonlightEditor.create(
    document.getElementById('editor-container'),
    {
      width: 800,
      height: 600,
      theme: 'light',  // or 'dark'
      readonly: false
    }
  );

  // API
  const svg = editor.exportSvg();
  editor.importSvg(svgString);
  editor.clear();
  editor.hasFocus();
</script>
```

### 3. Web Component Mode

Use as a custom HTML element:

```html
<script type="module" src="./webcomponent.ts"></script>

<moonlight-editor
  width="800"
  height="600"
  theme="light">
</moonlight-editor>

<script>
  const editor = document.querySelector('moonlight-editor');

  // API (same as embed mode)
  const svg = editor.exportSvg();
  editor.importSvg(svgString);
  editor.clear();
  editor.hasFocus();
</script>
```

#### Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `width` | number | 400 | Canvas width in pixels |
| `height` | number | 300 | Canvas height in pixels |
| `theme` | string | "light" | Theme: "light" or "dark" |
| `readonly` | boolean | false | Disable editing |

### 4. CDN Distribution (Copy & Paste)

Embed the editor in any HTML page with just 2 lines:

#### Minimal Example

```html
<moonlight-editor width="800" height="600"></moonlight-editor>
<script src="https://moonlight.mizchi.workers.dev/moonlight-editor.component.js" async></script>
```

#### With Initial SVG (using template)

```html
<moonlight-editor width="800" height="500">
  <template>
    <svg viewBox="0 0 800 500">
      <rect x="100" y="100" width="120" height="80" fill="#4CAF50" stroke="#2E7D32" stroke-width="2"/>
      <circle cx="400" cy="200" r="50" fill="#2196F3" stroke="#1565C0" stroke-width="2"/>
      <text x="300" y="350" font-size="24" fill="#333">Hello Moonlight!</text>
    </svg>
  </template>
</moonlight-editor>
<script src="https://moonlight.mizchi.workers.dev/moonlight-editor.component.js" async></script>
```

#### With API Usage

```html
<button onclick="alert(editor.exportSvg())">Export SVG</button>
<button onclick="editor.clear()">Clear</button>

<moonlight-editor id="editor" width="800" height="600" theme="dark"></moonlight-editor>

<script src="https://moonlight.mizchi.workers.dev/moonlight-editor.component.js" async></script>
<script>
  const editor = document.getElementById('editor');
  // editor.exportSvg()    - Get SVG string
  // editor.importSvg(svg) - Load SVG
  // editor.clear()        - Clear canvas
  // editor.hasFocus()     - Check focus state
</script>
```

#### Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `width` | 400 | Canvas width (px) |
| `height` | 300 | Canvas height (px) |
| `theme` | "light" | "light" or "dark" |
| `readonly` | - | Add to disable editing |

#### Self-hosting with Cloudflare Workers

```bash
pnpm build:all   # Build component
pnpm deploy      # Deploy to Workers
```

The worker serves files with CORS headers, enabling cross-origin usage.

## API Reference

### Editor Handle

Both embed and web component modes return an editor handle with these methods:

```typescript
interface EditorHandle {
  // Export current canvas as SVG string
  exportSvg(): string;

  // Import SVG string to canvas.
  // Returns false when nothing could be imported (the string did not parse, or
  // it held no shape the editor understands); the current drawing is kept.
  importSvg(svg: string): boolean;

  // Clear all elements
  clear(): void;

  // Check if editor has focus
  hasFocus(): boolean;

  // Register change callback
  onChange(callback: () => void): void;
}
```

## Architecture

```
src/
├── main.mbt          # Editor assembly (library; the entry point lives in entries/app)
├── ui.mbt            # UI components (sidebar, toolbar)
├── render.mbt        # SVG rendering
├── model/            # Pure calculation — no signals, no DOM
│   ├── types.mbt     # Data models (Element, Style, etc.)
│   ├── command.mbt   # Undo/Redo commands
│   └── element_ops.mbt # Pure element operations
├── interaction/      # Semantic interaction model — what a gesture means
│   ├── types.mbt     # Scene, Target, Input, Gesture, Session
│   ├── joints.mbt    # Joints between line endpoints and shape anchors
│   ├── resize.mbt    # Resize geometry per shape × handle
│   ├── session.mbt   # The gesture state machine (a pure reducer)
│   └── dsl.mbt       # Scenario DSL shared by unit and visual tests
├── core/
│   └── scene.mbt     # Editor state (signals) over the pure layers
├── lib/              # Shared library code
├── entries/
│   ├── app/          # Full editor entry point
│   └── model-js/     # The interaction model, exported to JS for tests
├── embed/            # Embed mode entry point
├── webcomponent/     # Web Component entry point
└── preview/          # Preview mode
```

The three layers are kept apart on purpose: `model` and `interaction` know
nothing about signals or the DOM, so the rules for dragging, resizing and
joining shapes can be tested without a browser — and the editor delegates to
them rather than keeping its own copy. See
[docs/interaction-model.md](./docs/interaction-model.md).

## Testing

```bash
just test-unit        # MoonBit unit tests, including the interaction model
just test             # Playwright end-to-end suite
just visual-model     # Semantic prediction vs. a real mouse gesture
just vlm-integrity    # vlmkit reference-free gate over 3 viewports (needs `just dev`)
just vlm-snapshot     # vlmkit visual snapshots (needs `just dev`)
just vrt              # Screenshot regression against stored baselines
```

Visual-model tests state a scenario once and check it three ways: what the
semantic model predicts, what the editor actually does under a real pointer
gesture, and what the rendered picture shows. The last of those uses
[@mizchi/vlmkit](https://github.com/mizchi/vlmkit)'s natural-language
assertions, which need something that can look at a screenshot and judge a
sentence about it. `e2e/vlm-reviewer.ts` will use, in order:

| Reviewer | Needs |
|---|---|
| `anthropic` / `openrouter` / `gemini` | `ANTHROPIC_API_KEY` / `OPENROUTER_API_KEY` / `GEMINI_API_KEY` |
| `claude-cli` | the `claude` CLI on `PATH`, already signed in — no key |

Name one explicitly with `VLMKIT_REVIEWER`; pick the judging model with
`VLMKIT_MODEL`. With none of them available the assertions skip with a clear
reason, and everything else in the suite runs key-free.

One assertion in that file is a negative control: it hands the reviewer a claim
the picture plainly contradicts and requires it to be rejected. A reviewer that
answered "pass" to everything would turn the other assertions green without
looking, so the positive results only mean something alongside it.

## Tech Stack

- **MoonBit**: Systems programming language that compiles to WebAssembly/JavaScript
- **Luna**: Signal-based reactive UI library for MoonBit
- **Vite**: Build tool with hot module replacement
- **vite-plugin-moonbit**: Vite plugin for MoonBit integration

## License

MIT
