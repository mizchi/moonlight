// delete_selected の親子関係削除ロジックのテスト

// ============================================================
// テスト用ヘルパー関数
// ============================================================

///|
fn test_make_rect(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> @model.Element {
  @model.Element::new(id, x, y, @model.Rect(w, h, None, None))
}

///|
fn test_make_text_with_parent(
  id : String,
  x : Double,
  y : Double,
  content : String,
  parent_id : String,
) -> @model.Element {
  { ..@model.Element::new(id, x, y, @model.Text(content, None)), parent_id: Some(parent_id) }
}

// ============================================================
// delete_selected テスト
// ============================================================

///|
test "delete_selected: 単一要素の削除" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  state.selected_ids.set(["rect1"])
  state.delete_selected()
  inspect(state.elements.get().length(), content="0")
}

///|
test "delete_selected: 親要素を削除すると子要素も削除される" {
  let state = EditorState::new(800, 600)
  let parent = test_make_rect("parent", 100.0, 100.0, 100.0, 50.0)
  let child = test_make_text_with_parent("child", 150.0, 125.0, "Hello", "parent")
  state.elements.set([parent, child])
  state.selected_ids.set(["parent"])
  state.delete_selected()
  // 親と子の両方が削除される
  inspect(state.elements.get().length(), content="0")
}

///|
test "delete_selected: 子要素を削除すると親要素も削除される" {
  let state = EditorState::new(800, 600)
  let parent = test_make_rect("parent", 100.0, 100.0, 100.0, 50.0)
  let child = test_make_text_with_parent("child", 150.0, 125.0, "Hello", "parent")
  state.elements.set([parent, child])
  state.selected_ids.set(["child"])
  state.delete_selected()
  // 子を削除すると親も削除される
  inspect(state.elements.get().length(), content="0")
}

///|
test "delete_selected: 複数の子を持つ親を削除すると全ての子が削除される" {
  let state = EditorState::new(800, 600)
  let parent = test_make_rect("parent", 100.0, 100.0, 100.0, 50.0)
  let child1 = test_make_text_with_parent("child1", 120.0, 125.0, "A", "parent")
  let child2 = test_make_text_with_parent("child2", 160.0, 125.0, "B", "parent")
  state.elements.set([parent, child1, child2])
  state.selected_ids.set(["parent"])
  state.delete_selected()
  // 親と全ての子が削除される
  inspect(state.elements.get().length(), content="0")
}

///|
test "delete_selected: 1つの子を削除すると親と他の子も削除される" {
  let state = EditorState::new(800, 600)
  let parent = test_make_rect("parent", 100.0, 100.0, 100.0, 50.0)
  let child1 = test_make_text_with_parent("child1", 120.0, 125.0, "A", "parent")
  let child2 = test_make_text_with_parent("child2", 160.0, 125.0, "B", "parent")
  state.elements.set([parent, child1, child2])
  state.selected_ids.set(["child1"])
  state.delete_selected()
  // 子1を削除すると、親と子2も削除される
  inspect(state.elements.get().length(), content="0")
}

///|
test "delete_selected: 親を持たない要素の削除は他に影響しない" {
  let state = EditorState::new(800, 600)
  let rect1 = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  let rect2 = test_make_rect("rect2", 200.0, 100.0, 50.0, 50.0)
  state.elements.set([rect1, rect2])
  state.selected_ids.set(["rect1"])
  state.delete_selected()
  // rect1だけが削除され、rect2は残る
  inspect(state.elements.get().length(), content="1")
  inspect(state.elements.get()[0].id, content="rect2")
}

///|
test "delete_selected: 複数の独立した要素を同時に削除" {
  let state = EditorState::new(800, 600)
  let rect1 = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  let rect2 = test_make_rect("rect2", 200.0, 100.0, 50.0, 50.0)
  let rect3 = test_make_rect("rect3", 300.0, 100.0, 50.0, 50.0)
  state.elements.set([rect1, rect2, rect3])
  state.selected_ids.set(["rect1", "rect3"])
  state.delete_selected()
  // rect1とrect3が削除され、rect2だけ残る
  inspect(state.elements.get().length(), content="1")
  inspect(state.elements.get()[0].id, content="rect2")
}

///|
test "delete_selected: 親子セットと独立要素を同時に削除" {
  let state = EditorState::new(800, 600)
  let parent = test_make_rect("parent", 100.0, 100.0, 100.0, 50.0)
  let child = test_make_text_with_parent("child", 150.0, 125.0, "Hello", "parent")
  let independent = test_make_rect("independent", 300.0, 100.0, 50.0, 50.0)
  state.elements.set([parent, child, independent])
  state.selected_ids.set(["parent", "independent"])
  state.delete_selected()
  // 全て削除される
  inspect(state.elements.get().length(), content="0")
}
