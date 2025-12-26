// Command - EditorState に依存する操作
// 型定義は @model.Command, @model.History を使用

///|
/// コマンドを実行して履歴に追加
pub fn execute_command(
  history : @model.History,
  state : EditorState,
  command : @model.Command,
) -> Unit {
  // コマンドを実行
  apply_command(command, state)
  // Undo スタックに追加
  history.undo_stack.push(command)
  // Redo スタックをクリア（新しい操作後は Redo できない）
  history.redo_stack.clear()
}

///|
/// Undo（取り消し）
pub fn undo_command(history : @model.History, state : EditorState) -> Bool {
  guard history.undo_stack.pop() is Some(command)
  // 逆操作を実行
  unapply_command(command, state)
  // Redo スタックに追加
  history.redo_stack.push(command)
  true
}

///|
/// Redo（やり直し）
pub fn redo_command(history : @model.History, state : EditorState) -> Bool {
  guard history.redo_stack.pop() is Some(command)
  // 操作を再実行
  apply_command(command, state)
  // Undo スタックに追加
  history.undo_stack.push(command)
  true
}

///|
/// コマンドを適用（実行）
fn apply_command(command : @model.Command, state : EditorState) -> Unit {
  match command {
    @model.AddElement(element) => state.add_element_raw(element)
    @model.RemoveElement(element) => state.remove_element_raw(element.id)
    @model.MoveElement(id, _, _, to_x, to_y) => state.move_element_raw(id, to_x, to_y)
    @model.ResizeElement(id, _, new_shape) => state.update_shape_raw(id, new_shape)
  }
}

///|
/// コマンドを取り消し（逆操作）
fn unapply_command(command : @model.Command, state : EditorState) -> Unit {
  match command {
    @model.AddElement(element) => state.remove_element_raw(element.id)
    @model.RemoveElement(element) => state.add_element_raw(element)
    @model.MoveElement(id, from_x, from_y, _, _) =>
      state.move_element_raw(id, from_x, from_y)
    @model.ResizeElement(id, old_shape, _) => state.update_shape_raw(id, old_shape)
  }
}
