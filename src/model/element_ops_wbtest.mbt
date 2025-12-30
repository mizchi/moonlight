// element_ops - 単体テスト

///|
test "move_element_with_relations - updates child elements" {
  // 親要素（Rect）を作成
  let parent : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 子要素（Text）を作成 - 親の中央に配置
  let child : Element = {
    id: "text-1",
    x: 140.0, // 100 + 80/2 = 140
    y: 130.0, // 100 + 60/2 = 130
    shape: Text("Hello", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("rect-1"),
    connections: None,
  }
  let elements = [parent, child]

  // 親要素を移動
  let result = move_element_with_relations(elements, "rect-1", 200.0, 200.0)

  // 親要素の位置を確認
  let moved_parent = result[0]
  assert_eq(moved_parent.x, 200.0)
  assert_eq(moved_parent.y, 200.0)
  // 子要素も同じ差分で移動していることを確認
  // dx = 200 - 100 = 100, dy = 200 - 100 = 100
  let moved_child = result[1]
  assert_eq(moved_child.x, 240.0) // 140 + 100 = 240
  assert_eq(moved_child.y, 230.0) // 130 + 100 = 230
}

///|
test "move_element_with_relations - updates connected lines" {
  // ターゲット要素（Rect）を作成
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 接続されたLine（終点がRectのLeftアンカーに接続）
  let line : Element = {
    id: "line-1",
    x: 50.0,
    y: 130.0,
    shape: Line(100.0, 130.0), // 終点 (100, 130) = Rect の Left アンカー
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: Some({
      start: None,
      end: Some({ element_id: "rect-1", anchor: Left }),
    }),
  }
  let elements = [rect, line]

  // Rectを移動
  let result = move_element_with_relations(elements, "rect-1", 200.0, 150.0)
  let moved_rect = result[0]
  let moved_line = result[1]
  // Rectの新しい位置
  assert_eq(moved_rect.x, 200.0)
  assert_eq(moved_rect.y, 150.0)
  // Lineの終点がRectのLeftアンカーを追従していることを確認
  // 新しいRectのLeft アンカー = (200, 150 + 30) = (200, 180)
  guard moved_line.shape is Line(x2, y2)
  assert_eq(x2, 200.0)
  assert_eq(y2, 180.0)
}

///|
test "move_element_with_relations - updates both child and connected lines" {
  // ターゲット要素（Rect）を作成
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 子要素（Text）を作成 - 親の中央に配置
  let child : Element = {
    id: "text-1",
    x: 140.0, // 100 + 80/2 = 140
    y: 130.0, // 100 + 60/2 = 130
    shape: Text("JS", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("rect-1"),
    connections: None,
  }
  // 接続されたLine（終点がRectのLeftアンカーに接続）
  let line : Element = {
    id: "line-1",
    x: 50.0,
    y: 130.0,
    shape: Line(100.0, 130.0), // 終点 = Rect の Left アンカー
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: Some({
      start: None,
      end: Some({ element_id: "rect-1", anchor: Left }),
    }),
  }
  let elements = [rect, child, line]

  // Rectを移動
  let result = move_element_with_relations(elements, "rect-1", 200.0, 200.0)
  let moved_rect = result[0]
  let moved_child = result[1]
  let moved_line = result[2]

  // Rectの新しい位置
  assert_eq(moved_rect.x, 200.0)
  assert_eq(moved_rect.y, 200.0)

  // 子要素も同じ差分で移動
  // dx = 100, dy = 100
  assert_eq(moved_child.x, 240.0) // 140 + 100 = 240
  assert_eq(moved_child.y, 230.0) // 130 + 100 = 230

  // Lineの終点がRectのLeftアンカーを追従
  // 新しいRectのLeft アンカー = (200, 200 + 30) = (200, 230)
  guard moved_line.shape is Line(x2, y2)
  assert_eq(x2, 200.0)
  assert_eq(y2, 230.0)
}

///|
test "resize_element_with_relations - centers child elements" {
  // 親要素（Rect）
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 子要素（Text）- 親の中央に配置
  let child : Element = {
    id: "text-1",
    x: 140.0,
    y: 130.0,
    shape: Text("JS", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("rect-1"),
    connections: None,
  }
  let elements = [rect, child]

  // Rect を大きくリサイズ
  let new_shape = Rect(120.0, 100.0, None, None)
  let result = resize_element_with_relations(elements, "rect-1", new_shape)
  let resized_rect = result[0]
  let moved_child = result[1]

  // 新しい形状
  guard resized_rect.shape is Rect(w, h, _, _)
  assert_eq(w, 120.0)
  assert_eq(h, 100.0)

  // 子要素が新しい中央に配置されている
  // 新しい中央 = (100 + 60, 100 + 50) = (160, 150)
  assert_eq(moved_child.x, 160.0)
  assert_eq(moved_child.y, 150.0)
}

///|
test "resize_element_with_relations - updates connected lines" {
  // ターゲット要素（Rect）
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 接続されたLine（終点がRectのLeftアンカーに接続）
  let line : Element = {
    id: "line-1",
    x: 50.0,
    y: 130.0,
    shape: Line(100.0, 130.0), // 終点 = Rect の Left アンカー (100, 130)
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: Some({
      start: None,
      end: Some({ element_id: "rect-1", anchor: Left }),
    }),
  }
  let elements = [rect, line]

  // Rect を高さを変更
  let new_shape = Rect(80.0, 100.0, None, None) // 高さを 60 -> 100 に
  let result = resize_element_with_relations(elements, "rect-1", new_shape)
  let resized_rect = result[0]
  let moved_line = result[1]

  // 新しい形状
  guard resized_rect.shape is Rect(_, h, _, _)
  assert_eq(h, 100.0)

  // Lineの終点が新しいLeftアンカーを追従
  // 新しいLeft アンカー = (100, 100 + 50) = (100, 150)
  guard moved_line.shape is Line(x2, y2)
  assert_eq(x2, 100.0)
  assert_eq(y2, 150.0)
}

// ============================================================
// Edge Cases
// ============================================================

///|
test "move_element_with_relations - element not found returns unchanged" {
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  let elements = [rect]

  // 存在しない要素を移動
  let result = move_element_with_relations(elements, "nonexistent", 200.0, 200.0)

  // 元の配列がそのまま返される
  assert_eq(result.length(), 1)
  assert_eq(result[0].x, 100.0)
  assert_eq(result[0].y, 100.0)
}

///|
test "move_element_with_relations - line without connections" {
  // 接続なしのLine
  let line : Element = {
    id: "line-1",
    x: 0.0,
    y: 0.0,
    shape: Line(100.0, 100.0),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  let elements = [line]

  // Lineを移動
  let result = move_element_with_relations(elements, "line-1", 50.0, 50.0)

  // 単純に移動される
  assert_eq(result[0].x, 50.0)
  assert_eq(result[0].y, 50.0)
  guard result[0].shape is Line(x2, y2)
  assert_eq(x2, 150.0) // 100 + 50
  assert_eq(y2, 150.0) // 100 + 50
}

///|
test "move_element_with_relations - circle with children" {
  // 親要素（Circle）
  let circle : Element = {
    id: "circle-1",
    x: 100.0,
    y: 100.0,
    shape: Circle(50.0),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 子要素（Text）
  let child : Element = {
    id: "text-1",
    x: 100.0, // 円の中心
    y: 100.0,
    shape: Text("OK", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("circle-1"),
    connections: None,
  }
  let elements = [circle, child]

  // Circleを移動
  let result = move_element_with_relations(elements, "circle-1", 200.0, 150.0)

  // dx = 100, dy = 50
  assert_eq(result[0].x, 200.0)
  assert_eq(result[0].y, 150.0)
  assert_eq(result[1].x, 200.0) // 100 + 100
  assert_eq(result[1].y, 150.0) // 100 + 50
}

///|
test "move_element_with_relations - multiple children" {
  // 親要素
  let parent : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 複数の子要素
  let child1 : Element = {
    id: "text-1",
    x: 120.0,
    y: 110.0,
    shape: Text("A", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("rect-1"),
    connections: None,
  }
  let child2 : Element = {
    id: "text-2",
    x: 150.0,
    y: 140.0,
    shape: Text("B", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("rect-1"),
    connections: None,
  }
  let elements = [parent, child1, child2]

  // 親を移動
  let result = move_element_with_relations(elements, "rect-1", 200.0, 200.0)

  // dx = 100, dy = 100
  assert_eq(result[1].x, 220.0) // 120 + 100
  assert_eq(result[1].y, 210.0) // 110 + 100
  assert_eq(result[2].x, 250.0) // 150 + 100
  assert_eq(result[2].y, 240.0) // 140 + 100
}

///|
test "move_element_with_relations - line connected at both ends" {
  // 2つのRect
  let rect1 : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  let rect2 : Element = {
    id: "rect-2",
    x: 300.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 両端が接続されたLine
  let line : Element = {
    id: "line-1",
    x: 180.0, // rect1.right
    y: 130.0,
    shape: Line(300.0, 130.0), // rect2.left
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: Some({
      start: Some({ element_id: "rect-1", anchor: Right }),
      end: Some({ element_id: "rect-2", anchor: Left }),
    }),
  }
  let elements = [rect1, rect2, line]

  // rect1を移動
  let result = move_element_with_relations(elements, "rect-1", 100.0, 200.0)

  // Lineの始点がrect1のRightアンカーを追従
  // 新しいRight アンカー = (100 + 80, 200 + 30) = (180, 230)
  let moved_line = result[2]
  assert_eq(moved_line.x, 180.0)
  assert_eq(moved_line.y, 230.0)
  // 終点は変わらない（rect2は移動していない）
  guard moved_line.shape is Line(x2, y2)
  assert_eq(x2, 300.0)
  assert_eq(y2, 130.0)
}

///|
test "resize_element_with_relations - element not found returns unchanged" {
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  let elements = [rect]

  // 存在しない要素をリサイズ
  let new_shape = Rect(120.0, 100.0, None, None)
  let result = resize_element_with_relations(elements, "nonexistent", new_shape)

  // 元の配列がそのまま返される
  assert_eq(result.length(), 1)
  guard result[0].shape is Rect(w, h, _, _)
  assert_eq(w, 80.0)
  assert_eq(h, 60.0)
}

///|
test "resize_element_with_relations - circle resize" {
  let circle : Element = {
    id: "circle-1",
    x: 100.0,
    y: 100.0,
    shape: Circle(50.0),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  let child : Element = {
    id: "text-1",
    x: 100.0,
    y: 100.0,
    shape: Text("OK", Some(16.0)),
    style: Style::default(),
    transform: None,
    parent_id: Some("circle-1"),
    connections: None,
  }
  let elements = [circle, child]

  // Circle を大きくリサイズ
  let new_shape = Circle(80.0)
  let result = resize_element_with_relations(elements, "circle-1", new_shape)

  // 新しい形状
  guard result[0].shape is Circle(r)
  assert_eq(r, 80.0)

  // 子要素が新しい中央に配置
  // 円の中心は (100, 100) のまま
  assert_eq(result[1].x, 100.0)
  assert_eq(result[1].y, 100.0)
}

///|
test "resize_element_with_relations - connected line at start" {
  let rect : Element = {
    id: "rect-1",
    x: 100.0,
    y: 100.0,
    shape: Rect(80.0, 60.0, None, None),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
  // 始点がRectに接続されたLine
  let line : Element = {
    id: "line-1",
    x: 180.0, // rect.right
    y: 130.0,
    shape: Line(300.0, 200.0),
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: Some({
      start: Some({ element_id: "rect-1", anchor: Right }),
      end: None,
    }),
  }
  let elements = [rect, line]

  // Rectの幅を変更
  let new_shape = Rect(120.0, 60.0, None, None)
  let result = resize_element_with_relations(elements, "rect-1", new_shape)

  // Lineの始点が新しいRightアンカーを追従
  // 新しいRight アンカー = (100 + 120, 100 + 30) = (220, 130)
  let moved_line = result[1]
  assert_eq(moved_line.x, 220.0)
  assert_eq(moved_line.y, 130.0)
}
