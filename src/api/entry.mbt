// ESM API for moonlight editor
// Usage:
//   import { createEditor } from '@mizchi/moonlight';
//   const editor = createEditor(container, { width: 800, height: 600 });

///|
/// Create editor instance
/// Returns handle object with methods: exportSvg, importSvg, clear, destroy, hasFocus, onChange
pub fn createEditor(container : @js.Any, options : @js.Any) -> @js.Any {
  let opts = @editor.EmbedOptions::from_js(options)
  @editor.create_js_editor(container, opts)
}

///|
fn main {
  // Entry point - exports are handled by moon.pkg.json link config
}
