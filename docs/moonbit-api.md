# Moonlight MoonBit API

API documentation for using Moonlight from MoonBit.

## Package Structure

```
mizchi/moonlight
├── core      # EditorState, Signal management
├── model     # Pure data types and computation functions
├── lib       # UI logic (DOM dependent)
├── embed     # JavaScript integration entry point
├── entries/
│   └── viewer/  # Lightweight SVG generation (no editor features)
└── luna_testing # VNode test helpers
```

## Basic Types

### Point

2D coordinate point.

```moonbit
pub(all) struct Point {
  x : Double
  y : Double
}
```

### ShapeType

Shape types.

```moonbit
pub(all) enum ShapeType {
  Rect(Double, Double, Double?, Double?)  // width, height, rx?, ry?
  Circle(Double)                           // radius
  Ellipse(Double, Double)                  // rx, ry
  Line(Double, Double)                     // end_x, end_y (start is Element.x, y)
  Polyline(Array[Point])                   // polyline
  Path(String, Double, Double, Double, Double)  // d, start_x, start_y, end_x, end_y
  Text(String, Double?)                    // content, font_size?
}
```

### Style

Element style.

```moonbit
pub(all) struct Style {
  fill : String?           // fill color
  stroke : String?         // stroke color
  stroke_width : Double?   // stroke width
  opacity : Double?        // opacity
  stroke_dasharray : String?  // dash pattern
  marker_start : ArrowType?   // start marker
  marker_end : ArrowType?     // end marker
  font_family : String?    // font family
}
```

### Element

Shape element.

```moonbit
pub(all) struct Element {
  id : String              // unique identifier
  x : Double               // X coordinate
  y : Double               // Y coordinate
  shape : ShapeType        // shape type
  style : Style            // style
  transform : String?      // SVG transform attribute
  parent_id : String?      // parent element ID (for child elements)
  connections : LineConnections?  // line connection info
}
```

### Anchor

Connection point positions.

```moonbit
pub(all) enum Anchor {
  Center
  Top
  Bottom
  Left
  Right
  TopLeft
  TopRight
  BottomLeft
  BottomRight
  LineStart   // line start point
  LineEnd     // line end point
}
```

## EditorState

Editor state management. Signal-based reactive state.

### Creation

```moonbit
// Basic creation
let state = @core.EditorState::new(800, 600)

// Create with mode
let state = @core.EditorState::new_with_mode(800, 600, @core.Embedded)
```

### Element Operations

```moonbit
// Add element
state.add_element(element)

// Find element
let el : Element? = state.find_element("element-id")

// Update element
state.update_element("element-id", fn(el) {
  { ..el, x: 100.0, y: 100.0 }
})

// Generic update helper
state.update_element_by_id("element-id", fn(el) {
  { ..el, style: { ..el.style, fill: Some("#ff0000") } }
})

// Move element (connected lines auto-update)
state.move_element("element-id", 200.0, 150.0)
```

### Selection Operations

```moonbit
// Single selection
state.select(Some("element-id"))

// Multiple selection
state.select_multiple(["id1", "id2", "id3"])

// Add to selection
state.add_to_selection("element-id")

// Remove from selection
state.remove_from_selection("element-id")

// Select all
state.select_all()

// Check if selected
let is_sel : Bool = state.is_selected("element-id")

// Get selected ID
let selected_id : String? = state.get_selected_id()
```

### Hit Testing

```moonbit
// Find element at coordinates
let hit_id : String? = state.hit_test(100.0, 200.0)
```

### Theme

```moonbit
// Get theme
let theme : @model.Theme = state.get_theme()

// Light theme
let light = @model.Theme::light()

// Dark theme
let dark = @model.Theme::dark()
```

## Element Operations

### Creation

```moonbit
// Basic creation
let rect = @model.Element::new(
  "rect-1",
  100.0,  // x
  100.0,  // y
  @model.Rect(80.0, 60.0, None, None),
  @model.Style::default(),
)

// With parent element
let text = rect.with_parent("parent-id")

// With style
let styled = rect.with_style({ ..@model.Style::default(), fill: Some("#ff0000") })
```

### Bounding Box

```moonbit
let bbox : @model.BoundingBox = element.bounding_box()
// bbox.x, bbox.y, bbox.width, bbox.height
```

### Hit Testing

```moonbit
let hit : Bool = element.hit_test(@model.Point::new(50.0, 50.0))
```

### Anchor Points

```moonbit
// Get specific anchor position
let point : Point = element.get_anchor_point(@model.Center)

// Get all anchors
let anchors : Array[(Anchor, Point)] = element.get_all_anchors()

// Find nearest anchor
let nearest : (Anchor, Point, Double)? = element.find_nearest_anchor(
  @model.Point::new(100.0, 100.0),
  20.0,  // threshold
)
```

## JavaScript Integration

### EditorOptions

Options passed from JavaScript.

```moonbit
pub(all) struct EditorOptions {
  width : Int?           // canvas width
  height : Int?          // canvas height
  gridsnap : Bool        // grid snap
  theme : String?        // "light" | "dark"
  zoom : Double?         // initial zoom
  is_readonly : Bool     // read-only mode
  toolbar_visible : Bool // toolbar visibility
  initial_svg : String?  // initial SVG
  show_help_button : Bool // help button visibility
  github_url : String?   // GitHub link URL (optional)
}
```

### JavaScript API

```javascript
// Create editor
const handle = MoonlightEditor.create(container, {
  width: 800,
  height: 600,
  theme: 'light',
  initialSvg: '<svg>...</svg>',
  githubUrl: 'https://github.com/user/repo' // optional
});

// === Basic API ===
handle.exportSvg();        // Get SVG
handle.importSvg(svg);     // Import SVG
handle.clear();            // Clear
handle.destroy();          // Destroy
handle.hasFocus();         // Focus state

// === Selection API ===
handle.select(['id1', 'id2']);  // Select elements
handle.selectAll();             // Select all
handle.deselect();              // Deselect
handle.getSelectedIds();        // Get selected IDs

// === Focus API ===
handle.focus();            // Focus
handle.blur();             // Blur

// === Element API ===
handle.getElements();           // Get all elements
handle.getElementById('id');    // Get element by ID
handle.deleteElements(['id']);  // Delete elements

// === Mode API ===
handle.setMode('select');       // Set mode ('select' | 'freedraw')
handle.getMode();               // Get current mode

// === Read-only API ===
handle.setReadonly(true);       // Set read-only
handle.isReadonly();            // Check read-only
```

### Event Subscriptions

```javascript
// Change event
const unsub = handle.onChange(() => {
  console.log('Content changed');
});
unsub(); // Unsubscribe

// Selection event
handle.onSelect((ids) => {
  console.log('Selected:', ids);
});

// Deselection event
handle.onDeselect(() => {
  console.log('Deselected');
});

// Focus events
handle.onFocus(() => {
  console.log('Editor focused');
});

handle.onBlur(() => {
  console.log('Editor blurred');
});

// Mode change event
handle.onModeChange((mode) => {
  console.log('Mode:', mode);
});

// Element add/delete events
handle.onElementAdd((id) => {
  console.log('Added:', id);
});

handle.onElementDelete((id) => {
  console.log('Deleted:', id);
});
```

### WYSIWYG Integration Example

```javascript
// TipTap/ProseMirror NodeView usage
const editor = MoonlightEditor.create(container, {
  width: 400,
  height: 300,
  readonly: false,
});

// Sync content changes to parent editor
editor.onChange(() => {
  updateNodeAttributes({ svg: editor.exportSvg() });
});

// Focus control
editor.onFocus(() => {
  // Disable parent editor focus
  parentEditor.setEditable(false);
});

editor.onBlur(() => {
  parentEditor.setEditable(true);
});
```

## Testing Helpers

The `luna_testing` package enables VNode unit testing.

```moonbit
// VNode queries
let tag : String? = get_tag(node)
let text : String = get_all_text(node)
let found : Node? = find_by_tag(node, "button")

// Assertions
assert_tag(node, "div")
assert_text_contains(node, "Hello")
assert_has_element(node, "button")

// Signal tracking
let tracker = track_signal(sig)
sig.set(1)
sig.set(2)
assert_tracked_values(tracker, [0, 1, 2])
```

See `src/luna_testing/README.md` for details.

## Model Layer Pure Functions

The `@model` package contains DOM-independent pure functions.

### Element Movement

```moonbit
// Move element and update all relations (pure function)
let updated : Array[Element] = @model.move_element_with_relations(
  elements,
  "element-id",
  new_x,
  new_y,
)
```

### Resize

```moonbit
// Resize element and update related elements
let updated : Array[Element] = @model.resize_element_with_relations(
  elements,
  "element-id",
  new_shape,
)
```

### Validation

```moonbit
// Validate elements
let result : ValidationResult = @model.validate_elements(elements)
let capability : ElementCapability = @model.get_element_capability(result, "id")
let issues : Array[ValidationIssue] = @model.get_element_issues(result, "id")
```

### Topology

```moonbit
// Build connection graph
let graph : ConnectionGraph = @model.build_connection_graph(elements)

// Get neighboring elements
let neighbors : Array[String] = graph.get_neighbors("element-id")

// Find shortest path
let path : ShortestPath? = graph.find_shortest_path("from", "to", elements)
```

## Viewer Package (Lightweight SVG Generation)

The `@viewer` package provides DOM-independent pure SVG generation.
Use when editor features are not needed (minimizes bundle size).

### Element Creation

```moonbit
// Rectangle
let rect = @viewer.rect("rect-1", 100.0, 100.0, 80.0, 60.0, @viewer.default_style())

// Circle
let circle = @viewer.circle("circle-1", 200.0, 150.0, 40.0, @viewer.default_style())

// Line
let line = @viewer.line("line-1", 50.0, 50.0, 150.0, 100.0, @viewer.line_style("#333", 2.0))

// Text
let text = @viewer.text("text-1", 100.0, 200.0, "Hello", 16.0, @viewer.default_style())
```

### Style Creation

```moonbit
// Default style (white fill, black stroke)
let style = @viewer.default_style()

// Fill style
let filled = @viewer.fill_style("#4CAF50", "#2E7D32")

// Line style
let stroked = @viewer.line_style("#333333", 2.0)
```

### SVG Generation

```moonbit
// Convert to standard SVG string
let svg : String = @viewer.to_svg(elements, 400, 300)

// With background color
let svg_with_bg : String = @viewer.to_svg_with_options(elements, 400, 300, "#ffffff")

// Moonlight format (with re-editable metadata)
let moonlight_svg : String = @viewer.to_moonlight_svg(elements, 400, 300, "#ffffff")

// Convert single element to SVG string
let el_svg : String = @viewer.element_to_svg(element)
```

### Usage Example

```moonbit
fn generate_diagram() -> String {
  let elements = [
    @viewer.rect("box1", 50.0, 50.0, 100.0, 60.0, @viewer.fill_style("#E3F2FD", "#1976D2")),
    @viewer.rect("box2", 200.0, 50.0, 100.0, 60.0, @viewer.fill_style("#E8F5E9", "#388E3C")),
    @viewer.line("arrow", 150.0, 80.0, 200.0, 80.0, @viewer.line_style("#333", 2.0)),
    @viewer.text("label1", 65.0, 85.0, "Start", 14.0, @viewer.default_style()),
    @viewer.text("label2", 220.0, 85.0, "End", 14.0, @viewer.default_style()),
  ]
  @viewer.to_svg(elements, 350, 150)
}
```
