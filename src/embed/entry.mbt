// 埋め込みモード - エントリポイント
// JavaScript から MoonlightEditor.create() で呼び出される

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
/// ID カウンター
let id_counter : Ref[Int] = { val: 0 }

///|
/// 新しい ID を生成
fn new_id() -> String {
  id_counter.val = id_counter.val + 1
  "el-\{id_counter.val}"
}

///|
/// エディタを作成（JavaScript から呼び出される）
fn create_editor_internal(container : @js.Any, options_js : @js.Any) -> @js.Any {
  let options = @lib.EditorOptions::from_js(options_js)
  // 共通セットアップロジックを使用
  let result = @lib.setup_editor(container, options, new_id)
  result.handle
}

///|
/// メイン関数（JavaScript から自動的に呼ばれる）
fn main {
  // グローバルに MoonlightEditor.create を登録
  register_create_editor(create_editor_internal)
}
