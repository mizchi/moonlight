// Command - Undo/Redo のためのコマンドパターン実装
// 純粋なデータ構造のみ（apply/unapply は EditorState に依存するため src に残す）

///|
/// 操作コマンド（各操作の実行と取り消しを表現）
pub(all) enum Command {
  /// 要素を追加
  AddElement(Element)
  /// 要素を削除
  RemoveElement(Element)
  /// 要素を移動 (id, from_x, from_y, to_x, to_y)
  MoveElement(String, Double, Double, Double, Double)
  /// 要素をリサイズ (id, old_shape, new_shape)
  ResizeElement(String, ShapeType, ShapeType)
} derive(Show, Eq)

///|
/// 履歴管理
pub(all) struct History {
  undo_stack : Array[Command]
  redo_stack : Array[Command]
}

///|
/// 履歴を作成
pub fn History::new() -> History {
  { undo_stack: [], redo_stack: [] }
}

///|
/// Undo 可能かどうか
pub fn History::can_undo(self : History) -> Bool {
  self.undo_stack.length() > 0
}

///|
/// Redo 可能かどうか
pub fn History::can_redo(self : History) -> Bool {
  self.redo_stack.length() > 0
}
