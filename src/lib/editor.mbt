// 共通ライブラリ - エディタ作成ロジック
// FFI関数とレンダリング関数は render.mbt から使用

///|
/// プレビューハンドルを作成
pub extern "js" fn create_preview_handle(
  open_fn : () -> Unit,
  close_fn : () -> Unit,
  is_open_fn : () -> Bool,
  get_svg_fn : () -> String,
  set_svg_fn : (String) -> Unit,
) -> @js.Any =
  #| (open, close, isOpen, getSvg, setSvg) => ({
  #|   openEditor: open,
  #|   closeEditor: close,
  #|   isOpen: isOpen,
  #|   getSvg: getSvg,
  #|   setSvg: setSvg
  #| })

// SimpleEditorState は @core.EditorState の型エイリアス

///|
pub type SimpleEditorState = @core.EditorState

// ============================================================
// ヘルパー関数（単一選択用）
// ============================================================

// get_selected_id は @core.EditorState のメソッドとして定義
// state.get_selected_id() を使用

///|
/// 選択を設定（単一選択として）
pub fn set_selected_id(state : @core.EditorState, id : String?) -> Unit {
  match id {
    Some(i) => state.selected_ids.set([i])
    None => state.selected_ids.set([])
  }
}
