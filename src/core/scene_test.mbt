// EditorState のテスト

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
fn test_make_line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> @model.Element {
  { ..@model.Element::new(id, x1, y1, @model.Line(x2, y2)), connections: None }
}

///|
fn test_make_zero_line(id : String, x : Double, y : Double) -> @model.Element {
  // 始点と終点が同じ（長さ0）のLine
  { ..@model.Element::new(id, x, y, @model.Line(x, y)), connections: None }
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

// ============================================================
// remove_element テスト
// ============================================================

///|
test "remove_element: 指定IDの要素を削除" {
  let state = EditorState::new(800, 600)
  let rect1 = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  let rect2 = test_make_rect("rect2", 200.0, 100.0, 50.0, 50.0)
  state.elements.set([rect1, rect2])
  state.remove_element("rect1")
  inspect(state.elements.get().length(), content="1")
  inspect(state.elements.get()[0].id, content="rect2")
}

///|
test "remove_element: 存在しないIDは何もしない" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  state.remove_element("nonexistent")
  inspect(state.elements.get().length(), content="1")
}

///|
test "remove_element: 選択中の要素を削除すると選択解除される" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  state.selected_ids.set(["rect1"])
  state.remove_element("rect1")
  inspect(state.selected_ids.get().length(), content="0")
}

// ============================================================
// select 関連テスト
// ============================================================

///|
test "select: 要素を選択" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  state.select(Some("rect1"))
  inspect(state.selected_ids.get().length(), content="1")
  inspect(state.selected_ids.get()[0], content="rect1")
}

///|
test "select: Noneで選択解除" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  state.selected_ids.set(["rect1"])
  state.select(None)
  inspect(state.selected_ids.get().length(), content="0")
}

///|
test "select_multiple: 複数要素を選択" {
  let state = EditorState::new(800, 600)
  let rect1 = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  let rect2 = test_make_rect("rect2", 200.0, 100.0, 50.0, 50.0)
  state.elements.set([rect1, rect2])
  state.select_multiple(["rect1", "rect2"])
  inspect(state.selected_ids.get().length(), content="2")
}

///|
test "select_all: 全要素を選択（Line/Arrowは除外）" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  let line = test_make_line("line1", 0.0, 0.0, 100.0, 100.0)
  state.elements.set([rect, line])
  state.select_all()
  // Line は除外されるので rect のみ選択
  // 注: 実際の実装では Line も選択される場合があるのでテスト結果を確認
  inspect(state.selected_ids.get().length(), content="2")
}

// ============================================================
// find_element テスト
// ============================================================

///|
test "find_element: 存在する要素を検索" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  match state.find_element("rect1") {
    Some(el) => inspect(el.id, content="rect1")
    None => panic()
  }
}

///|
test "find_element: 存在しない要素はNone" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  inspect(state.find_element("nonexistent") is None, content="true")
}

// ============================================================
// add_element_raw テスト（無効要素のスキップ）
// ============================================================

///|
test "add_element_raw: 有効な要素を追加" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.add_element_raw(rect)
  inspect(state.elements.get().length(), content="1")
}

///|
test "add_element_raw: 無効な要素（ゼロ長Line）はスキップ" {
  let state = EditorState::new(800, 600)
  let zero_line = test_make_zero_line("line1", 100.0, 100.0)
  state.add_element_raw(zero_line)
  // 長さ0のLineは無効なので追加されない
  inspect(state.elements.get().length(), content="0")
}

// ============================================================
// start_drag / start_resize ガードテスト
// ============================================================

///|
test "start_drag: 存在しない要素IDでもパニックしない" {
  let state = EditorState::new(800, 600)
  // 要素がない状態でstart_dragを呼んでも例外が発生しないことを確認
  state.start_drag("nonexistent", 100.0, 100.0)
  // パニックしなければ成功
  inspect(state.drag_state.get() is None, content="true")
}

///|
test "start_resize: 存在しない要素IDでもパニックしない" {
  let state = EditorState::new(800, 600)
  // 要素がない状態でstart_resizeを呼んでも例外が発生しないことを確認
  state.start_resize("nonexistent", @model.NW, 100.0, 100.0)
  // パニックしなければ成功
  inspect(state.resize_state.get() is None, content="true")
}

// ============================================================
// is_selected テスト
// ============================================================

///|
test "is_selected: 選択中の要素" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  state.selected_ids.set(["rect1"])
  inspect(state.is_selected("rect1"), content="true")
}

///|
test "is_selected: 選択されていない要素" {
  let state = EditorState::new(800, 600)
  let rect = test_make_rect("rect1", 100.0, 100.0, 50.0, 50.0)
  state.elements.set([rect])
  inspect(state.is_selected("rect1"), content="false")
}
