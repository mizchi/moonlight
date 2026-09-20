///|
/// フリーハンドで描いた軌跡を Path にするところを、ブラウザ無しで確かめる
fn draw_a_stroke(state : @core.EditorState, history : @model.History) -> Unit {
  start_free_draw(state, 10.0, 10.0)
  // ゆるい弧
  for i = 1; i <= 12; i = i + 1 {
    continue_free_draw(
      state,
      10.0 + i.to_double() * 12.0,
      10.0 + i.to_double() * 3.0,
    )
  }
  finish_free_draw(state, fn() { "path-1" }, history~)
}

///|
test "free draw: 描いた軌跡が Path 要素になる" {
  let state = @core.EditorState::new(400, 300)
  state.elements.set([])
  let history = @model.History::new()
  draw_a_stroke(state, history)
  let els = state.elements.get()
  inspect(els.length(), content="1")
  inspect(els[0].id, content="path-1")
  inspect(els[0].shape is @model.Path(_, _, _, _, _), content="true")
}

///|
test "free draw: 描いた線は Ctrl+Z で取り消せる" {
  let state = @core.EditorState::new(400, 300)
  state.elements.set([])
  let history = @model.History::new()
  draw_a_stroke(state, history)
  inspect(state.elements.get().length(), content="1")
  // 描画そのものが履歴に一段積まれていること
  inspect(@core.undo_command(history, state), content="true")
  inspect(state.elements.get().length(), content="0")
  // Redo で戻ること（Path が add_element_raw に弾かれていた頃はここが 0 のまま）
  inspect(@core.redo_command(history, state), content="true")
  inspect(state.elements.get().length(), content="1")
}

///|
test "free draw: 消した線は Undo で戻る" {
  let state = @core.EditorState::new(400, 300)
  state.elements.set([])
  let history = @model.History::new()
  draw_a_stroke(state, history)
  state.selected_ids.set(["path-1"])
  delete_selection(state, history)
  inspect(state.elements.get().length(), content="0")
  inspect(@core.undo_command(history, state), content="true")
  let restored = state.elements.get()
  inspect(restored.length(), content="1")
  inspect(restored[0].id, content="path-1")
}
