// WebComponent エディタモジュール - 遅延読み込み用
// shell (component.js) から動的 import される重量級モジュール
//
// 使用方法:
// const module = await import('./moonlight-editor.editor.js');
// const handle = module.createEditor(container, options);

///|
/// ES Module export として createEditor を登録
extern "js" fn register_create_editor(
  create_fn : (@js.Any, @js.Any) -> @js.Any,
) =
  #| (createFn) => {
  #|   // ES module 用のグローバル参照（rolldown が export に変換）
  #|   globalThis.__moonlightEditorModule = {
  #|     createEditor: createFn
  #|   };
  #| }

///|
/// エディタを作成（JavaScript から呼び出される）
fn create_editor_internal(container : @js.Any, options_js : @js.Any) -> @js.Any {
  let options = @editor.EmbedOptions::from_js(options_js)
  @editor.create_js_editor(container, options)
}

///|
/// メイン関数
fn main {
  register_create_editor(create_editor_internal)
}
