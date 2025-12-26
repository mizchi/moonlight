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
