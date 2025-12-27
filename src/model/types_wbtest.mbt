// lib/types.mbt のユニットテスト

// ============================================================
// Point のテスト
// ============================================================

test "Point equality" {
  let p1 : Point = { x: 10.0, y: 20.0 }
  let p2 : Point = { x: 10.0, y: 20.0 }
  let p3 : Point = { x: 10.0, y: 30.0 }
  assert_eq(p1, p2)
  assert_true(p1 != p3)
}

// ============================================================
// BoundingBox のテスト
// ============================================================

test "BoundingBox::contains - point inside" {
  let bbox : BoundingBox = { x: 100.0, y: 100.0, width: 50.0, height: 50.0 }
  let p : Point = { x: 125.0, y: 125.0 }
  assert_true(bbox.contains(p))
}

test "BoundingBox::contains - point on edge" {
  let bbox : BoundingBox = { x: 100.0, y: 100.0, width: 50.0, height: 50.0 }
  // 左端
  assert_true(bbox.contains({ x: 100.0, y: 125.0 }))
  // 右端
  assert_true(bbox.contains({ x: 150.0, y: 125.0 }))
  // 上端
  assert_true(bbox.contains({ x: 125.0, y: 100.0 }))
  // 下端
  assert_true(bbox.contains({ x: 125.0, y: 150.0 }))
}

test "BoundingBox::contains - point outside" {
  let bbox : BoundingBox = { x: 100.0, y: 100.0, width: 50.0, height: 50.0 }
  // 左外
  assert_false(bbox.contains({ x: 99.0, y: 125.0 }))
  // 右外
  assert_false(bbox.contains({ x: 151.0, y: 125.0 }))
  // 上外
  assert_false(bbox.contains({ x: 125.0, y: 99.0 }))
  // 下外
  assert_false(bbox.contains({ x: 125.0, y: 151.0 }))
}

// ============================================================
// Viewport のテスト
// ============================================================

test "Viewport::default" {
  let vp = Viewport::default()
  assert_eq(vp.scroll_x, 0.0)
  assert_eq(vp.scroll_y, 0.0)
  assert_eq(vp.zoom, 1.0)
}

test "Viewport::screen_to_scene - no scroll, no zoom" {
  let vp = Viewport::default()
  let scene = vp.screen_to_scene(100.0, 200.0)
  assert_eq(scene.x, 100.0)
  assert_eq(scene.y, 200.0)
}

test "Viewport::screen_to_scene - with scroll" {
  let vp : Viewport = { scroll_x: 50.0, scroll_y: 100.0, zoom: 1.0 }
  let scene = vp.screen_to_scene(100.0, 200.0)
  assert_eq(scene.x, 150.0) // 100 + 50
  assert_eq(scene.y, 300.0) // 200 + 100
}

test "Viewport::screen_to_scene - with zoom" {
  let vp : Viewport = { scroll_x: 0.0, scroll_y: 0.0, zoom: 2.0 }
  let scene = vp.screen_to_scene(100.0, 200.0)
  assert_eq(scene.x, 50.0) // 100 / 2
  assert_eq(scene.y, 100.0) // 200 / 2
}

test "Viewport::scene_to_screen - no scroll, no zoom" {
  let vp = Viewport::default()
  let screen = vp.scene_to_screen(100.0, 200.0)
  assert_eq(screen.x, 100.0)
  assert_eq(screen.y, 200.0)
}

test "Viewport::scene_to_screen - with scroll" {
  let vp : Viewport = { scroll_x: 50.0, scroll_y: 100.0, zoom: 1.0 }
  let screen = vp.scene_to_screen(150.0, 300.0)
  assert_eq(screen.x, 100.0) // (150 - 50) * 1
  assert_eq(screen.y, 200.0) // (300 - 100) * 1
}

test "Viewport::scene_to_screen - with zoom" {
  let vp : Viewport = { scroll_x: 0.0, scroll_y: 0.0, zoom: 2.0 }
  let screen = vp.scene_to_screen(50.0, 100.0)
  assert_eq(screen.x, 100.0) // 50 * 2
  assert_eq(screen.y, 200.0) // 100 * 2
}

test "Viewport roundtrip - screen -> scene -> screen" {
  let vp : Viewport = { scroll_x: 30.0, scroll_y: 40.0, zoom: 1.5 }
  let original_x = 120.0
  let original_y = 180.0
  let scene = vp.screen_to_scene(original_x, original_y)
  let back_to_screen = vp.scene_to_screen(scene.x, scene.y)
  // 浮動小数点の誤差を許容
  assert_true((back_to_screen.x - original_x).abs() < 0.001)
  assert_true((back_to_screen.y - original_y).abs() < 0.001)
}

// ============================================================
// リサイズ計算のテスト
// ============================================================

test "calc_rect_resize - SE handle (expand)" {
  let result = calc_rect_resize(
    100.0, 100.0, // start x, y
    80.0, 60.0,   // start w, h
    20.0, 10.0,   // dx, dy
    SE,           // handle
    10.0,         // min_size
  )
  // SE は右下なので、x, y は変わらず、w, h だけ増加
  assert_eq(result.x, 100.0)
  assert_eq(result.y, 100.0)
  assert_eq(result.width, 100.0) // 80 + 20
  assert_eq(result.height, 70.0) // 60 + 10
}

test "calc_rect_resize - NW handle (shrink)" {
  let result = calc_rect_resize(
    100.0, 100.0, // start x, y
    80.0, 60.0,   // start w, h
    20.0, 10.0,   // dx, dy (move right/down = shrink)
    NW,           // handle
    10.0,         // min_size
  )
  // NW は左上なので、x, y が移動、w, h が縮小
  assert_eq(result.x, 120.0) // 100 + 20
  assert_eq(result.y, 110.0) // 100 + 10
  assert_eq(result.width, 60.0) // 80 - 20
  assert_eq(result.height, 50.0) // 60 - 10
}

test "calc_rect_resize - minimum size enforcement" {
  let result = calc_rect_resize(
    100.0, 100.0, // start x, y
    80.0, 60.0,   // start w, h
    -100.0, -100.0, // dx, dy (try to make negative)
    SE,           // handle
    10.0,         // min_size
  )
  // 最小サイズが保証される
  assert_eq(result.width, 10.0)
  assert_eq(result.height, 10.0)
}

test "calc_rect_resize - NE handle" {
  let result = calc_rect_resize(
    100.0, 100.0, // start x, y
    80.0, 60.0,   // start w, h
    30.0, 20.0,   // dx, dy
    NE,           // handle
    10.0,         // min_size
  )
  // NE は右上なので、x は変わらず、y は下に移動、w は増加、h は縮小
  assert_eq(result.x, 100.0)
  assert_eq(result.y, 120.0) // 100 + 20
  assert_eq(result.width, 110.0) // 80 + 30
  assert_eq(result.height, 40.0) // 60 - 20
}

test "calc_rect_resize - SW handle" {
  let result = calc_rect_resize(
    100.0, 100.0, // start x, y
    80.0, 60.0,   // start w, h
    30.0, 20.0,   // dx, dy
    SW,           // handle
    10.0,         // min_size
  )
  // SW は左下なので、x は右に移動、y は変わらず、w は縮小、h は増加
  assert_eq(result.x, 130.0) // 100 + 30
  assert_eq(result.y, 100.0)
  assert_eq(result.width, 50.0) // 80 - 30
  assert_eq(result.height, 80.0) // 60 + 20
}

test "calc_circle_resize - SE expand" {
  let new_r = calc_circle_resize(50.0, 20.0, 20.0, SE, 5.0)
  // SE: (dx + dy) / 2 = 20
  assert_eq(new_r, 70.0) // 50 + 20
}

test "calc_circle_resize - NW shrink" {
  let new_r = calc_circle_resize(50.0, 20.0, 20.0, NW, 5.0)
  // NW: -(dx + dy) / 2 = -20
  assert_eq(new_r, 30.0) // 50 - 20
}

test "calc_circle_resize - minimum radius enforcement" {
  let new_r = calc_circle_resize(50.0, 100.0, 100.0, NW, 5.0)
  // 最小半径が保証される
  assert_eq(new_r, 5.0)
}

test "calc_circle_resize - NE" {
  let new_r = calc_circle_resize(50.0, 20.0, -10.0, NE, 5.0)
  // NE: (dx - dy) / 2 = (20 - (-10)) / 2 = 15
  assert_eq(new_r, 65.0) // 50 + 15
}

test "calc_circle_resize - SW" {
  let new_r = calc_circle_resize(50.0, -10.0, 20.0, SW, 5.0)
  // SW: (-dx + dy) / 2 = (10 + 20) / 2 = 15
  assert_eq(new_r, 65.0) // 50 + 15
}

// ============================================================
// calc_drag_position tests
// ============================================================

test "calc_drag_position - basic" {
  let pos = calc_drag_position(10.0, 20.0, 100.0, 150.0)
  assert_eq(pos.x, 90.0) // 100 - 10
  assert_eq(pos.y, 130.0) // 150 - 20
}

test "calc_drag_position - zero offset" {
  let pos = calc_drag_position(0.0, 0.0, 50.0, 75.0)
  assert_eq(pos.x, 50.0)
  assert_eq(pos.y, 75.0)
}

test "calc_drag_position - negative result" {
  let pos = calc_drag_position(100.0, 100.0, 50.0, 50.0)
  assert_eq(pos.x, -50.0) // 50 - 100
  assert_eq(pos.y, -50.0) // 50 - 100
}

// ============================================================
// find_element_at tests
// ============================================================

test "find_element_at - empty array" {
  let elements : Array[Element] = []
  let result = find_element_at(elements, { x: 100.0, y: 100.0 })
  assert_eq(result, None)
}

test "find_element_at - hit single element" {
  let elements = [
    Element::new("el-1", 50.0, 50.0, Rect(100.0, 100.0, None, None)),
  ]
  let result = find_element_at(elements, { x: 75.0, y: 75.0 })
  assert_true(result is Some(_))
  assert_eq(result.unwrap().id, "el-1")
}

test "find_element_at - miss" {
  let elements = [
    Element::new("el-1", 50.0, 50.0, Rect(100.0, 100.0, None, None)),
  ]
  let result = find_element_at(elements, { x: 200.0, y: 200.0 })
  assert_eq(result, None)
}

test "find_element_at - returns topmost element" {
  // 後ろの要素が上に表示される
  let elements = [
    Element::new("el-1", 50.0, 50.0, Rect(100.0, 100.0, None, None)),
    Element::new("el-2", 75.0, 75.0, Rect(100.0, 100.0, None, None)),
  ]
  // (100, 100) は両方の要素にヒットするが、el-2（後ろ）が返される
  let result = find_element_at(elements, { x: 100.0, y: 100.0 })
  assert_true(result is Some(_))
  assert_eq(result.unwrap().id, "el-2")
}

test "find_element_at - circle hit test" {
  let elements = [
    Element::new("circle-1", 100.0, 100.0, Circle(50.0)),
  ]
  // 円の中心付近
  let result = find_element_at(elements, { x: 100.0, y: 100.0 })
  assert_true(result is Some(_))
  assert_eq(result.unwrap().id, "circle-1")
}

// ============================================================
// DragState, ContextMenu, ResizeState construction tests
// ============================================================

test "DragState - construction" {
  let state : DragState = {
    element_id: "el-1",
    start_x: 100.0,
    start_y: 200.0,
    offset_x: 10.0,
    offset_y: 20.0,
    start_shape: None,
    start_connections: None,
    connected_start_positions: [],
  }
  assert_eq(state.element_id, "el-1")
  assert_eq(state.start_x, 100.0)
}

test "ContextMenu - construction" {
  let menu : ContextMenu = {
    x: 150.0,
    y: 250.0,
    scene_x: 100.0,
    scene_y: 200.0,
    target_id: Some("el-2"),
  }
  assert_eq(menu.x, 150.0)
  assert_eq(menu.scene_x, 100.0)
  assert_eq(menu.target_id, Some("el-2"))
}

test "ResizeState - construction" {
  let state : ResizeState = {
    element_id: "el-1",
    handle: SE,
    start_x: 100.0,
    start_y: 100.0,
    start_shape: Rect(80.0, 60.0, None, None),
    mouse_start_x: 180.0,
    mouse_start_y: 160.0,
  }
  assert_eq(state.element_id, "el-1")
  assert_eq(state.handle, SE)
}

// ============================================================
// Anchor and Connection tests
// ============================================================

test "parse_anchor - valid anchors" {
  assert_eq(parse_anchor("center"), Some(Center))
  assert_eq(parse_anchor("top"), Some(Top))
  assert_eq(parse_anchor("bottom"), Some(Bottom))
  assert_eq(parse_anchor("left"), Some(Left))
  assert_eq(parse_anchor("right"), Some(Right))
  assert_eq(parse_anchor("top-left"), Some(TopLeft))
  assert_eq(parse_anchor("top-right"), Some(TopRight))
  assert_eq(parse_anchor("bottom-left"), Some(BottomLeft))
  assert_eq(parse_anchor("bottom-right"), Some(BottomRight))
}

test "parse_anchor - invalid anchor" {
  assert_eq(parse_anchor("invalid"), None)
  assert_eq(parse_anchor(""), None)
}

test "LineConnections::none" {
  let conns = LineConnections::none()
  assert_eq(conns.start, None)
  assert_eq(conns.end, None)
}

test "Connection - construction" {
  let conn : Connection = { element_id: "el-1", anchor: Top }
  assert_eq(conn.element_id, "el-1")
  assert_eq(conn.anchor, Top)
}

// ============================================================
// Element anchor tests
// ============================================================

test "Element::get_anchor_point - Rect center" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let point = el.get_anchor_point(Center)
  assert_eq(point.x, 140.0) // 100 + 80/2
  assert_eq(point.y, 130.0) // 100 + 60/2
}

test "Element::get_anchor_point - Rect edges" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  // Top
  let top = el.get_anchor_point(Top)
  assert_eq(top.x, 140.0) // center x
  assert_eq(top.y, 100.0) // top edge
  // Bottom
  let bottom = el.get_anchor_point(Bottom)
  assert_eq(bottom.x, 140.0)
  assert_eq(bottom.y, 160.0) // 100 + 60
  // Left
  let left = el.get_anchor_point(Left)
  assert_eq(left.x, 100.0)
  assert_eq(left.y, 130.0)
  // Right
  let right = el.get_anchor_point(Right)
  assert_eq(right.x, 180.0) // 100 + 80
  assert_eq(right.y, 130.0)
}

test "Element::get_anchor_point - Rect corners" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  assert_eq(el.get_anchor_point(TopLeft), { x: 100.0, y: 100.0 })
  assert_eq(el.get_anchor_point(TopRight), { x: 180.0, y: 100.0 })
  assert_eq(el.get_anchor_point(BottomLeft), { x: 100.0, y: 160.0 })
  assert_eq(el.get_anchor_point(BottomRight), { x: 180.0, y: 160.0 })
}

test "Element::get_anchor_point - Circle" {
  let el = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  // Circle center is at (100, 100), bbox is (50, 50, 100, 100)
  let center = el.get_anchor_point(Center)
  assert_eq(center.x, 100.0)
  assert_eq(center.y, 100.0)
  let top = el.get_anchor_point(Top)
  assert_eq(top.x, 100.0)
  assert_eq(top.y, 50.0) // 100 - 50
}

test "Element::get_all_anchors" {
  let el = Element::new("el-1", 0.0, 0.0, Rect(100.0, 100.0, None, None))
  let anchors = el.get_all_anchors()
  assert_eq(anchors.length(), 9)
  // Check that all anchors are present
  let has_center = anchors.iter().any(fn(a) { a.0 == Center })
  let has_top = anchors.iter().any(fn(a) { a.0 == Top })
  assert_true(has_center)
  assert_true(has_top)
}

test "Element::find_nearest_anchor - within threshold" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  // Point close to top anchor (140, 100)
  let result = el.find_nearest_anchor({ x: 142.0, y: 102.0 }, 10.0)
  assert_true(result is Some(_))
  let (anchor, _, _) = result.unwrap()
  assert_eq(anchor, Top)
}

test "Element::find_nearest_anchor - outside threshold" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  // Point far from any anchor
  let result = el.find_nearest_anchor({ x: 140.0, y: 130.0 }, 5.0) // Center is at 140, 130
  // Center should be within threshold
  assert_true(result is Some(_))
  // But a point far away should not match
  let result2 = el.find_nearest_anchor({ x: 200.0, y: 200.0 }, 10.0)
  assert_eq(result2, None)
}

// ============================================================
// BoundingBox intersection tests
// ============================================================

test "BoundingBox::intersects - overlapping" {
  let a : BoundingBox = { x: 0.0, y: 0.0, width: 100.0, height: 100.0 }
  let b : BoundingBox = { x: 50.0, y: 50.0, width: 100.0, height: 100.0 }
  assert_true(a.intersects(b))
  assert_true(b.intersects(a))
}

test "BoundingBox::intersects - touching edges" {
  let a : BoundingBox = { x: 0.0, y: 0.0, width: 100.0, height: 100.0 }
  let b : BoundingBox = { x: 100.0, y: 0.0, width: 100.0, height: 100.0 }
  assert_true(a.intersects(b)) // touching is intersecting
}

test "BoundingBox::intersects - not intersecting" {
  let a : BoundingBox = { x: 0.0, y: 0.0, width: 100.0, height: 100.0 }
  let b : BoundingBox = { x: 200.0, y: 200.0, width: 100.0, height: 100.0 }
  assert_false(a.intersects(b))
}

test "BoundingBox::intersects - one inside other" {
  let a : BoundingBox = { x: 0.0, y: 0.0, width: 100.0, height: 100.0 }
  let b : BoundingBox = { x: 25.0, y: 25.0, width: 50.0, height: 50.0 }
  assert_true(a.intersects(b))
  assert_true(b.intersects(a))
}

// ============================================================
// BoxSelectState tests
// ============================================================

test "BoxSelectState::to_bbox - normal direction" {
  let state : BoxSelectState = {
    start_x: 10.0,
    start_y: 20.0,
    current_x: 100.0,
    current_y: 80.0,
  }
  let bbox = state.to_bbox()
  assert_eq(bbox.x, 10.0)
  assert_eq(bbox.y, 20.0)
  assert_eq(bbox.width, 90.0) // 100 - 10
  assert_eq(bbox.height, 60.0) // 80 - 20
}

test "BoxSelectState::to_bbox - reversed direction" {
  // Dragging from bottom-right to top-left
  let state : BoxSelectState = {
    start_x: 100.0,
    start_y: 80.0,
    current_x: 10.0,
    current_y: 20.0,
  }
  let bbox = state.to_bbox()
  assert_eq(bbox.x, 10.0)
  assert_eq(bbox.y, 20.0)
  assert_eq(bbox.width, 90.0)
  assert_eq(bbox.height, 60.0)
}

// ============================================================
// find_elements_in_box tests
// ============================================================

test "find_elements_in_box - select all" {
  let elements = [
    Element::new("el-1", 50.0, 50.0, Rect(40.0, 40.0, None, None)),
    Element::new("el-2", 100.0, 100.0, Rect(40.0, 40.0, None, None)),
  ]
  let box_bbox : BoundingBox = { x: 0.0, y: 0.0, width: 200.0, height: 200.0 }
  let result = find_elements_in_box(elements, box_bbox)
  assert_eq(result.length(), 2)
}

test "find_elements_in_box - select partial" {
  let elements = [
    Element::new("el-1", 50.0, 50.0, Rect(40.0, 40.0, None, None)),
    Element::new("el-2", 200.0, 200.0, Rect(40.0, 40.0, None, None)),
  ]
  let box_bbox : BoundingBox = { x: 0.0, y: 0.0, width: 100.0, height: 100.0 }
  let result = find_elements_in_box(elements, box_bbox)
  assert_eq(result.length(), 1)
  assert_eq(result[0].id, "el-1")
}

test "find_elements_in_box - exclude children" {
  let parent = Element::new("parent", 50.0, 50.0, Rect(100.0, 100.0, None, None))
  let child = Element::new("child", 60.0, 60.0, Text("Hello", Some(16.0))).with_parent("parent")
  let elements = [parent, child]
  let box_bbox : BoundingBox = { x: 0.0, y: 0.0, width: 200.0, height: 200.0 }
  let result = find_elements_in_box(elements, box_bbox)
  // Only parent should be selected, not child
  assert_eq(result.length(), 1)
  assert_eq(result[0].id, "parent")
}

// ============================================================
// snap_to_grid tests
// ============================================================

test "snap_to_grid - disabled" {
  let (x, y) = snap_to_grid(33.0, 47.0, 20, false)
  assert_eq(x, 33.0)
  assert_eq(y, 47.0)
}

test "snap_to_grid - enabled" {
  let (x, y) = snap_to_grid(33.0, 47.0, 20, true)
  assert_eq(x, 40.0) // rounds to nearest 20
  assert_eq(y, 40.0) // rounds to nearest 20
}

test "snap_to_grid - exact" {
  let (x, y) = snap_to_grid(40.0, 60.0, 20, true)
  assert_eq(x, 40.0)
  assert_eq(y, 60.0)
}

// ============================================================
// format_shape tests
// ============================================================

test "format_shape - Rect" {
  let result = format_shape(Rect(80.0, 60.0, None, None))
  assert_eq(result, "Rect(80×60)")
}

test "format_shape - Circle" {
  let result = format_shape(Circle(50.0))
  assert_eq(result, "Circle(r=50)")
}

test "format_shape - Ellipse" {
  let result = format_shape(Ellipse(40.0, 30.0))
  assert_eq(result, "Ellipse(40×30)")
}

test "format_shape - Line" {
  let result = format_shape(Line(150.0, 100.0))
  assert_eq(result, "Line(→150,100)")
}

test "format_shape - Text" {
  let result = format_shape(Text("Hello", Some(16.0)))
  assert_eq(result, "Text(\"Hello\")")
}

// ============================================================
// parse_handle_position tests
// ============================================================

test "parse_handle_position - valid handles" {
  assert_eq(parse_handle_position("nw"), NW)
  assert_eq(parse_handle_position("ne"), NE)
  assert_eq(parse_handle_position("sw"), SW)
  assert_eq(parse_handle_position("se"), SE)
  assert_eq(parse_handle_position("line-start"), LineStart)
  assert_eq(parse_handle_position("line-end"), LineEnd)
}

test "parse_handle_position - invalid defaults to SE" {
  assert_eq(parse_handle_position("invalid"), SE)
  assert_eq(parse_handle_position(""), SE)
}

// ============================================================
// Style tests
// ============================================================

test "Style::default" {
  let style = Style::default()
  assert_eq(style.fill, None)
  assert_eq(style.stroke, Some("#000000"))
  assert_eq(style.stroke_width, Some(1.0))
  assert_eq(style.opacity, None)
}

// ============================================================
// Element construction tests
// ============================================================

test "Element::new" {
  let el = Element::new("el-1", 100.0, 200.0, Circle(50.0))
  assert_eq(el.id, "el-1")
  assert_eq(el.x, 100.0)
  assert_eq(el.y, 200.0)
  assert_true(el.shape == Circle(50.0))
  assert_eq(el.parent_id, None)
  assert_eq(el.connections, None)
}

test "Element::with_parent" {
  let el = Element::new("child", 10.0, 10.0, Text("Hello", None)).with_parent("parent")
  assert_eq(el.parent_id, Some("parent"))
}

test "Element::with_style" {
  let style : Style = {
    fill: Some("#ff0000"),
    stroke: Some("#00ff00"),
    stroke_width: Some(3.0),
    opacity: Some(0.5),
    stroke_dasharray: Some("5,5"),
    marker_start: Some(Arrow),
    marker_end: Some(Arrow),
  }
  let el = Element::new("el-1", 0.0, 0.0, Circle(10.0)).with_style(style)
  assert_eq(el.style.fill, Some("#ff0000"))
  assert_eq(el.style.opacity, Some(0.5))
  assert_eq(el.style.stroke_dasharray, Some("5,5"))
  assert_eq(el.style.marker_start, Some(Arrow))
}

// ============================================================
// Element bounding_box tests for various shapes
// ============================================================

test "Element::bounding_box - Circle" {
  let el = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 50.0) // 100 - 50
  assert_eq(bbox.y, 50.0)
  assert_eq(bbox.width, 100.0) // 50 * 2
  assert_eq(bbox.height, 100.0)
}

test "Element::bounding_box - Ellipse" {
  let el = Element::new("el-1", 100.0, 100.0, Ellipse(40.0, 30.0))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 60.0) // 100 - 40
  assert_eq(bbox.y, 70.0) // 100 - 30
  assert_eq(bbox.width, 80.0) // 40 * 2
  assert_eq(bbox.height, 60.0) // 30 * 2
}

test "Element::bounding_box - Line" {
  let el = Element::new("el-1", 50.0, 100.0, Line(150.0, 50.0))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 50.0) // min(50, 150)
  assert_eq(bbox.y, 50.0) // min(100, 50)
  assert_eq(bbox.width, 100.0) // 150 - 50
  assert_eq(bbox.height, 50.0) // 100 - 50
}

test "Element::bounding_box - Text" {
  let el = Element::new("el-1", 100.0, 100.0, Text("Hi", Some(20.0)))
  let bbox = el.bounding_box()
  // Text bbox is centered at (100, 100)
  assert_true(bbox.x < 100.0)
  assert_true(bbox.y < 100.0)
  assert_eq(bbox.height, 20.0) // font_size
}

// ============================================================
// MultiDragState and TextEditState tests
// ============================================================

test "MultiDragState - construction" {
  let state : MultiDragState = {
    element_ids: ["el-1", "el-2"],
    start_positions: [("el-1", 100.0, 100.0), ("el-2", 200.0, 200.0)],
    line_endpoints: [],
    mouse_start_x: 150.0,
    mouse_start_y: 150.0,
  }
  assert_eq(state.element_ids.length(), 2)
  assert_eq(state.start_positions.length(), 2)
}

test "TextEditState - construction" {
  let state : TextEditState = {
    parent_id: "parent",
    x: 100.0,
    y: 100.0,
    editing_id: Some("text-1"),
    initial_text: "Hello",
  }
  assert_eq(state.parent_id, "parent")
  assert_eq(state.editing_id, Some("text-1"))
  assert_eq(state.initial_text, "Hello")
}

// ============================================================
// Element::hit_test tests
// ============================================================

test "Element::hit_test - point inside rect" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  assert_true(el.hit_test({ x: 120.0, y: 120.0 }))
}

test "Element::hit_test - point outside rect" {
  let el = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  assert_false(el.hit_test({ x: 50.0, y: 50.0 }))
}

test "Element::hit_test - point inside circle" {
  let el = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  // Circle bbox is (50, 50, 100, 100)
  assert_true(el.hit_test({ x: 100.0, y: 100.0 }))
  assert_true(el.hit_test({ x: 60.0, y: 100.0 }))
}

test "Element::hit_test - point outside circle" {
  let el = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  // Circle bbox is (50, 50, 100, 100)
  assert_false(el.hit_test({ x: 160.0, y: 160.0 }))
}

// ============================================================
// Style comparison tests
// ============================================================

test "Style equality - same styles" {
  let style1 : Style = {
    fill: Some("#ff0000"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: Some(0.8),
    stroke_dasharray: Some("5,5"),
    marker_start: Some(Arrow),
    marker_end: None,
  }
  let style2 : Style = {
    fill: Some("#ff0000"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: Some(0.8),
    stroke_dasharray: Some("5,5"),
    marker_start: Some(Arrow),
    marker_end: None,
  }
  assert_eq(style1, style2)
}

test "Style equality - different fill" {
  let style1 = Style::default()
  let style2 = { ..Style::default(), fill: Some("#ff0000") }
  assert_true(style1 != style2)
}

test "Style equality - different stroke_dasharray" {
  let style1 = Style::default()
  let style2 = { ..Style::default(), stroke_dasharray: Some("5,5") }
  assert_true(style1 != style2)
}

test "Style equality - different marker" {
  let style1 = Style::default()
  let style2 = { ..Style::default(), marker_end: Some(Arrow) }
  assert_true(style1 != style2)
}

// ============================================================
// ArrowType tests
// ============================================================

test "ArrowType equality" {
  assert_eq(Arrow, Arrow)
  assert_eq(NoArrow, NoArrow)
  assert_true(Arrow != NoArrow)
}

// ============================================================
// Anchor tests
// ============================================================

test "Anchor equality" {
  assert_eq(Center, Center)
  assert_eq(Top, Top)
  assert_true(Center != Top)
  assert_true(TopLeft != BottomRight)
}

// ============================================================
// Line bounding box edge cases
// ============================================================

test "Element::bounding_box - Line reversed direction" {
  // Line from (150, 50) to (50, 100) - end point is to the left and below start
  let el = Element::new("el-1", 150.0, 50.0, Line(50.0, 100.0))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 50.0) // min(150, 50)
  assert_eq(bbox.y, 50.0) // min(50, 100)
  assert_eq(bbox.width, 100.0) // 150 - 50
  assert_eq(bbox.height, 50.0) // 100 - 50
}

test "Element::bounding_box - horizontal Line" {
  let el = Element::new("el-1", 50.0, 100.0, Line(150.0, 100.0))
  let bbox = el.bounding_box()
  assert_eq(bbox.y, 100.0)
  assert_eq(bbox.height, 0.0) // same y
}

test "Element::bounding_box - vertical Line" {
  let el = Element::new("el-1", 100.0, 50.0, Line(100.0, 150.0))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 100.0)
  assert_eq(bbox.width, 0.0) // same x
}

// ============================================================
// Polyline bounding box tests
// ============================================================

test "Element::bounding_box - Polyline empty" {
  let el = Element::new("el-1", 100.0, 100.0, Polyline([]))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 100.0)
  assert_eq(bbox.y, 100.0)
  assert_eq(bbox.width, 0.0)
  assert_eq(bbox.height, 0.0)
}

test "Element::bounding_box - Polyline with points" {
  let points : Array[Point] = [
    { x: 50.0, y: 50.0 },
    { x: 150.0, y: 50.0 },
    { x: 100.0, y: 150.0 },
  ]
  let el = Element::new("el-1", 100.0, 100.0, Polyline(points))
  let bbox = el.bounding_box()
  assert_eq(bbox.x, 50.0) // min of all x
  assert_eq(bbox.y, 50.0) // min of all y
  assert_eq(bbox.width, 100.0) // 150 - 50
  assert_eq(bbox.height, 100.0) // 150 - 50
}

// ============================================================
// LineConnections::get_connected_ids tests
// ============================================================

test "LineConnections::get_connected_ids - no connections" {
  let conns = LineConnections::none()
  let ids = conns.get_connected_ids()
  assert_eq(ids.length(), 0)
}

test "LineConnections::get_connected_ids - start only" {
  let conns : LineConnections = {
    start: Some({ element_id: "rect-1", anchor: Top }),
    end: None,
  }
  let ids = conns.get_connected_ids()
  assert_eq(ids.length(), 1)
  assert_eq(ids[0], "rect-1")
}

test "LineConnections::get_connected_ids - end only" {
  let conns : LineConnections = {
    start: None,
    end: Some({ element_id: "rect-2", anchor: Bottom }),
  }
  let ids = conns.get_connected_ids()
  assert_eq(ids.length(), 1)
  assert_eq(ids[0], "rect-2")
}

test "LineConnections::get_connected_ids - both ends different" {
  let conns : LineConnections = {
    start: Some({ element_id: "rect-1", anchor: Top }),
    end: Some({ element_id: "rect-2", anchor: Bottom }),
  }
  let ids = conns.get_connected_ids()
  assert_eq(ids.length(), 2)
  assert_true(ids.contains("rect-1"))
  assert_true(ids.contains("rect-2"))
}

test "LineConnections::get_connected_ids - both ends same element" {
  let conns : LineConnections = {
    start: Some({ element_id: "rect-1", anchor: Top }),
    end: Some({ element_id: "rect-1", anchor: Bottom }),
  }
  let ids = conns.get_connected_ids()
  // 同じ要素への接続は重複を除去
  assert_eq(ids.length(), 1)
  assert_eq(ids[0], "rect-1")
}

// ============================================================
// calc_connected_line_updates tests
// ============================================================

test "calc_connected_line_updates - no connected lines" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let line = Element::new("line-1", 50.0, 50.0, Line(200.0, 200.0))
  // 接続情報なし
  let updates = calc_connected_line_updates("rect-1", 150.0, 150.0, [line], [rect, line])
  assert_eq(updates.length(), 0)
}

test "calc_connected_line_updates - line connected at start" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let line_conns : LineConnections = {
    start: Some({ element_id: "rect-1", anchor: Right }),
    end: None,
  }
  let line = { ..Element::new("line-1", 180.0, 130.0, Line(300.0, 200.0)), connections: Some(line_conns) }
  // rect-1 を (100, 100) → (200, 200) に移動
  // Right アンカーは bbox.x + bbox.width, bbox.y + bbox.height/2
  // 移動後の rect の bbox は x=200, y=200, w=80, h=60
  // Right アンカーは (280, 230)
  let updates = calc_connected_line_updates("rect-1", 200.0, 200.0, [line], [rect, line])
  assert_eq(updates.length(), 1)
  assert_eq(updates[0].line_id, "line-1")
  assert_eq(updates[0].new_x, 280.0) // 200 + 80
  assert_eq(updates[0].new_y, 230.0) // 200 + 60/2
  assert_eq(updates[0].new_x2, 300.0) // 終点は変わらない
  assert_eq(updates[0].new_y2, 200.0)
}

test "calc_connected_line_updates - line connected at end" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let line_conns : LineConnections = {
    start: None,
    end: Some({ element_id: "rect-1", anchor: Center }),
  }
  let line = { ..Element::new("line-1", 50.0, 50.0, Line(140.0, 130.0)), connections: Some(line_conns) }
  // rect-1 を移動、Center アンカーは x + w/2, y + h/2
  let updates = calc_connected_line_updates("rect-1", 200.0, 200.0, [line], [rect, line])
  assert_eq(updates.length(), 1)
  assert_eq(updates[0].new_x, 50.0) // 始点は変わらない
  assert_eq(updates[0].new_y, 50.0)
  assert_eq(updates[0].new_x2, 240.0) // 200 + 80/2
  assert_eq(updates[0].new_y2, 230.0) // 200 + 60/2
}

test "calc_connected_line_updates - line connected at both ends to same element" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let line_conns : LineConnections = {
    start: Some({ element_id: "rect-1", anchor: Top }),
    end: Some({ element_id: "rect-1", anchor: Bottom }),
  }
  let line = { ..Element::new("line-1", 140.0, 100.0, Line(140.0, 160.0)), connections: Some(line_conns) }
  // rect-1 を移動
  let updates = calc_connected_line_updates("rect-1", 200.0, 200.0, [line], [rect, line])
  assert_eq(updates.length(), 1)
  // Top: (x + w/2, y) = (240, 200)
  assert_eq(updates[0].new_x, 240.0)
  assert_eq(updates[0].new_y, 200.0)
  // Bottom: (x + w/2, y + h) = (240, 260)
  assert_eq(updates[0].new_x2, 240.0)
  assert_eq(updates[0].new_y2, 260.0)
}

// ============================================================
// calc_child_positions tests
// ============================================================

test "calc_child_positions - no children" {
  let parent = Element::new("parent", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let results = calc_child_positions("parent", 50.0, 30.0, [parent])
  assert_eq(results.length(), 0)
}

test "calc_child_positions - with children" {
  let parent = Element::new("parent", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let child1 = Element::new("child-1", 110.0, 110.0, Text("A", None)).with_parent("parent")
  let child2 = Element::new("child-2", 120.0, 120.0, Text("B", None)).with_parent("parent")
  let other = Element::new("other", 200.0, 200.0, Circle(20.0))
  let results = calc_child_positions("parent", 50.0, 30.0, [parent, child1, child2, other])
  assert_eq(results.length(), 2)
  // child-1: (110 + 50, 110 + 30) = (160, 140)
  assert_true(results.iter().any(fn(r) { r.child_id == "child-1" && r.new_x == 160.0 && r.new_y == 140.0 }))
  // child-2: (120 + 50, 120 + 30) = (170, 150)
  assert_true(results.iter().any(fn(r) { r.child_id == "child-2" && r.new_x == 170.0 && r.new_y == 150.0 }))
}

// ============================================================
// apply_element_move tests
// ============================================================

test "apply_element_move - simple move" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let elements = [rect]
  let result = apply_element_move(elements, "rect-1", 200.0, 150.0)
  assert_eq(result.length(), 1)
  assert_eq(result[0].x, 200.0)
  assert_eq(result[0].y, 150.0)
}

test "apply_element_move - with children" {
  let parent = Element::new("parent", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let child = Element::new("child", 110.0, 110.0, Text("A", None)).with_parent("parent")
  let elements = [parent, child]
  // 親を (100, 100) → (200, 200) に移動 (dx=100, dy=100)
  let result = apply_element_move(elements, "parent", 200.0, 200.0)
  assert_eq(result.length(), 2)
  // 親の位置
  let result_parent = result[0]
  assert_eq(result_parent.x, 200.0)
  assert_eq(result_parent.y, 200.0)
  // 子も同じ差分で移動
  let result_child = result[1]
  assert_eq(result_child.x, 210.0) // 110 + 100
  assert_eq(result_child.y, 210.0) // 110 + 100
}

test "apply_element_move - with connected line" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let line_conns : LineConnections = {
    start: Some({ element_id: "rect-1", anchor: Right }),
    end: None,
  }
  // Right アンカー初期位置: (180, 130)
  let line = { ..Element::new("line-1", 180.0, 130.0, Line(300.0, 200.0)), connections: Some(line_conns) }
  let elements = [rect, line]
  // rect を (100, 100) → (200, 200) に移動
  let result = apply_element_move(elements, "rect-1", 200.0, 200.0)
  assert_eq(result.length(), 2)
  // rect の位置
  assert_eq(result[0].x, 200.0)
  assert_eq(result[0].y, 200.0)
  // line の始点が Right アンカー (280, 230) に更新
  assert_eq(result[1].x, 280.0)
  assert_eq(result[1].y, 230.0)
  // 終点は変わらない
  guard result[1].shape is Line(x2, y2)
  assert_eq(x2, 300.0)
  assert_eq(y2, 200.0)
}

test "apply_element_move - element not found" {
  let rect = Element::new("rect-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let elements = [rect]
  // 存在しない要素を移動しようとしても、配列は変更されない
  let result = apply_element_move(elements, "nonexistent", 200.0, 200.0)
  assert_eq(result.length(), 1)
  assert_eq(result[0].x, 100.0)
  assert_eq(result[0].y, 100.0)
}
