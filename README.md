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

  // Import SVG string to canvas
  importSvg(svg: string): void;

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
├── main.mbt          # Full editor entry point
├── ui.mbt            # UI components (sidebar, toolbar)
├── render.mbt        # SVG rendering
├── core/
│   └── scene.mbt     # Editor state management
├── model/
│   ├── types.mbt     # Data models (Element, Style, etc.)
│   ├── command.mbt   # Undo/Redo commands
│   └── element_ops.mbt # Pure element operations
├── lib/              # Shared library code
├── embed/            # Embed mode entry point
├── webcomponent/     # Web Component entry point
└── preview/          # Preview mode
```

## Tech Stack

- **MoonBit**: Systems programming language that compiles to WebAssembly/JavaScript
- **Luna**: Signal-based reactive UI library for MoonBit
- **Vite**: Build tool with hot module replacement
- **vite-plugin-moonbit**: Vite plugin for MoonBit integration

## License

MIT
