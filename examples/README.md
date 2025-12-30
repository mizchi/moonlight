# Moonlight Examples

This directory contains various examples demonstrating different ways to use the Moonlight SVG editor.

## Examples Overview

### [embed.html](./embed.html)
**Basic Embedding** - The simplest way to embed Moonlight in your web page.

```javascript
const editor = MoonlightEmbed.create(container, {
  width: 600,
  height: 400,
  theme: 'light',
  gridsnap: true
});
```

### [webcomponent.html](./webcomponent.html)
**Web Component** - Use Moonlight as a custom HTML element.

```html
<moonlight-editor
  width="600"
  height="400"
  theme="dark"
  gridsnap>
</moonlight-editor>
```

### [preview.html](./preview.html)
**Preview Mode** - Read-only preview with modal editor popup. Click to edit.

```javascript
const preview = MoonlightPreview.create(container, {
  width: 300,
  height: 200,
  clickToEdit: true
});
```

### [embed-demo.html](./embed-demo.html)
**Embed Demo** - Interactive demo showing embed API features.

### [free_draw.html](./free_draw.html)
**Free Draw** - Experimental freehand drawing with bezier curve approximation.

### [viewer.html](./viewer.html)
**SVG Viewer** - Minimal read-only SVG viewer component.

## Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | number | container width | Canvas width in pixels |
| `height` | number | container height | Canvas height in pixels |
| `theme` | 'light' \| 'dark' | 'light' | Color theme |
| `gridsnap` | boolean | false | Enable grid snapping |
| `readonly` | boolean | false | Read-only mode |
| `toolbarVisible` | boolean | true | Show toolbar |
| `initialSvg` | string | - | Initial SVG content |
| `showHelpButton` | boolean | true | Show help button |

## API Methods

### MoonlightEmbed

```javascript
const editor = MoonlightEmbed.create(container, options);

// Export current content as SVG
const svg = editor.exportSvg();

// Import SVG content
editor.importSvg(svgString);

// Clear all elements
editor.clear();

// Destroy editor instance
editor.destroy();

// Check if editor has focus
const focused = editor.hasFocus();
```

### MoonlightPreview

```javascript
const preview = MoonlightPreview.create(container, options);

// Open modal editor
preview.open();
```

## Running Examples

```bash
# Start development server
pnpm dev

# Open in browser
# http://localhost:5173/examples/embed.html
```
