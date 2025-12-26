// Command - Undo/Redo のためのコマンドパターン実装

///|
/// 操作コマンド（各操作の実行と取り消しを表現）
pub enum Command {
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
pub struct History {
  undo_stack : Array[Command]
  redo_stack : Array[Command]
}

///|
/// 履歴を作成
pub fn History::new() -> History {
  { undo_stack: [], redo_stack: [] }
}

///|
/// コマンドを実行して履歴に追加
pub fn History::execute(
  self : History,
  state : EditorState,
  command : Command,
) -> Unit {
  // コマンドを実行
  command.apply(state)
  // Undo スタックに追加
  self.undo_stack.push(command)
  // Redo スタックをクリア（新しい操作後は Redo できない）
  self.redo_stack.clear()
}

///|
/// Undo（取り消し）
pub fn History::undo(self : History, state : EditorState) -> Bool {
  guard self.undo_stack.pop() is Some(command)
  // 逆操作を実行
  command.unapply(state)
  // Redo スタックに追加
  self.redo_stack.push(command)
  true
}

///|
/// Redo（やり直し）
pub fn History::redo(self : History, state : EditorState) -> Bool {
  guard self.redo_stack.pop() is Some(command)
  // 操作を再実行
  command.apply(state)
  // Undo スタックに追加
  self.undo_stack.push(command)
  true
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

///|
/// コマンドを適用（実行）
fn Command::apply(self : Command, state : EditorState) -> Unit {
  match self {
    AddElement(element) => state.add_element_raw(element)
    RemoveElement(element) => state.remove_element_raw(element.id)
    MoveElement(id, _, _, to_x, to_y) => state.move_element_raw(id, to_x, to_y)
    ResizeElement(id, _, new_shape) => state.update_shape_raw(id, new_shape)
  }
}

///|
/// コマンドを取り消し（逆操作）
fn Command::unapply(self : Command, state : EditorState) -> Unit {
  match self {
    AddElement(element) => state.remove_element_raw(element.id)
    RemoveElement(element) => state.add_element_raw(element)
    MoveElement(id, from_x, from_y, _, _) =>
      state.move_element_raw(id, from_x, from_y)
    ResizeElement(id, old_shape, _) => state.update_shape_raw(id, old_shape)
  }
}
