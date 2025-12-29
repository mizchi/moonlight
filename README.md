# Moonlight

A lightweight SVG editor built with MoonBit and the Luna reactive UI library. Inspired by Excalidraw, Moonlight provides a simple yet powerful interface for creating and editing vector graphics.

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

### 4. CDN Distribution

Load the Web Component directly from a CDN (Cloudflare Workers):

```html
<script type="module" src="https://moonlight.mizchi.workers.dev/moonlight-editor.component.js"></script>

<moonlight-editor width="800" height="600"></moonlight-editor>
```

#### Self-hosting with Cloudflare Workers

1. Build the library:
   ```bash
   pnpm build:lib
   ```

2. Deploy to Cloudflare Workers:
   ```bash
   pnpm deploy
   ```

3. The worker serves files with CORS headers enabled, allowing cross-origin usage.

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
