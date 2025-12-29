// 埋め込みモード - エントリポイント
// JavaScript から MoonlightEditor.create() で呼び出される
// フルモードと同じコードを使用

///|
/// JavaScript グローバルに createEditor を登録
extern "js" fn register_create_editor(
  create_fn : (@js.Any, @js.Any) -> @js.Any,
) =
  #| (createFn) => {
  #|   globalThis.MoonlightEditor = {
  #|     create: createFn
  #|   };
  #| }

///|
/// エディタを作成（JavaScript から呼び出される）
fn create_editor_internal(container : @js.Any, options_js : @js.Any) -> @js.Any {
  let options = @editor.EmbedOptions::from_js(options_js)
  @editor.create_js_editor(container, options)
}

///|
/// メイン関数（JavaScript から自動的に呼ばれる）
fn main {
  // グローバルに MoonlightEditor.create を登録
  register_create_editor(create_editor_internal)
}
