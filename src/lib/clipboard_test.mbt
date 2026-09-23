// copy_selection の知らせのテスト

///|
fn clipboard_test_state() -> @core.EditorState {
  let state = @core.EditorState::new(800, 600)
  let shape = @model.Element::new(
    "shape",
    10.0,
    10.0,
    @model.Rect(80.0, 40.0, None, None),
  )
  let label = @model.Element::new(
    "label",
    50.0,
    30.0,
    @model.Text("Hi", Some(14.0)),
  ).with_parent("shape")
  let other = @model.Element::new("other", 200.0, 10.0, @model.Circle(20.0))
  state.elements.set([shape, label, other])
  state
}

///|
/// 出ている知らせの文言（出ていなければ空文字）
fn clipboard_test_notice(state : @core.EditorState) -> String {
  match state.notice.get() {
    Some(n) => n.message
    None => ""
  }
}

///|
test "copy_selection: 写した図形の数を知らせる（ラベルは数えない）" {
  let state = clipboard_test_state()
  state.selected_ids.set(["shape"])
  @lib.copy_selection(state)
  inspect(clipboard_test_notice(state), content="Copied 1 element")
  state.selected_ids.set(["shape", "other"])
  @lib.copy_selection(state)
  inspect(clipboard_test_notice(state), content="Copied 2 elements")
}

///|
test "copy_selection: 何も選んでいなければ知らせない" {
  let state = clipboard_test_state()
  @lib.copy_selection(state)
  inspect(clipboard_test_notice(state), content="")
}
