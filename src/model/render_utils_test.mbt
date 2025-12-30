// Moonlight - Rendering Utilities Tests

// ============================================================
// テキストヒットエリア計算テスト
// ============================================================

///|
test "calc_text_hit_area: single line short text" {
  let (w, h) = calc_text_hit_area("Hi", 16.0)
  // 2文字 * 16 * 0.55 = 17.6 → min_width = 32.0 適用
  inspect(w >= 32.0, content="true")
  // 高さは font_size * 1.2 = 19.2
  inspect(h, content="19.2")
}

///|
test "calc_text_hit_area: single line normal text" {
  let (w, h) = calc_text_hit_area("Hello World", 16.0)
  // 11文字 * 16 * 0.55 = 96.8
  inspect(w > 90.0 && w < 100.0, content="true")
  inspect(h, content="19.2")
}

///|
test "calc_text_hit_area: multiline text" {
  let content = "Line 1\nLine 2\nLine 3"
  let (w, h) = calc_text_hit_area(content, 16.0)
  // 3行 * 16 * 1.2 = 57.6
  inspect(h > 55.0 && h < 60.0, content="true")
  // 最長行 "Line 1" = 6文字
  inspect(w > 50.0, content="true")
}

///|
test "calc_text_hit_area: empty text" {
  let (w, h) = calc_text_hit_area("", 16.0)
  // 0文字 → min_width 適用
  inspect(w, content="32")
  inspect(h, content="19.2")
}

///|
test "calc_text_bounds: centered positioning" {
  let bbox = calc_text_bounds("Test", 100.0, 100.0, 16.0)
  // 幅と高さが計算される
  inspect(bbox.width > 0.0, content="true")
  inspect(bbox.height > 0.0, content="true")
  // 中央揃えなので x, y は元の位置からオフセット
  inspect(bbox.x < 100.0, content="true")
  inspect(bbox.y < 100.0, content="true")
}

// ============================================================
// スタイル属性変換テスト
// ============================================================

///|
test "style_to_svg_attrs: default style" {
  let style = Style::default()
  let attrs = style_to_svg_attrs(style)
  // fill: none がデフォルト
  inspect(attrs.contains(("fill", "none")), content="true")
}

///|
test "style_to_svg_attrs: with fill and stroke" {
  let style : Style = {
    fill: Some("#ff0000"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let attrs = style_to_svg_attrs(style)
  inspect(attrs.contains(("fill", "#ff0000")), content="true")
  inspect(attrs.contains(("stroke", "#000000")), content="true")
  inspect(attrs.contains(("stroke-width", "2")), content="true")
}

///|
test "style_to_svg_attrs: with dasharray" {
  let style : Style = {
    fill: None,
    stroke: Some("#333"),
    stroke_width: Some(1.0),
    opacity: Some(0.5),
    stroke_dasharray: Some("5,5"),
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let attrs = style_to_svg_attrs(style)
  inspect(attrs.contains(("stroke-dasharray", "5,5")), content="true")
  inspect(attrs.contains(("opacity", "0.5")), content="true")
}

///|
test "get_marker_attrs: with arrows" {
  let style : Style = {
    fill: None,
    stroke: None,
    stroke_width: None,
    opacity: None,
    stroke_dasharray: None,
    marker_start: Some(Arrow),
    marker_end: Some(Arrow),
    font_family: None,
  }
  let attrs = get_marker_attrs(style)
  inspect(attrs.length(), content="2")
  inspect(
    attrs.contains(("marker-start", "url(#arrow-start-context)")),
    content="true",
  )
  inspect(
    attrs.contains(("marker-end", "url(#arrow-end-context)")),
    content="true",
  )
}

///|
test "get_marker_attrs: no arrows" {
  let style = Style::default()
  let attrs = get_marker_attrs(style)
  inspect(attrs.length(), content="0")
}

// ============================================================
// 要素更新テスト
// ============================================================

///|
test "update_element_position: basic move" {
  let el = test_make_rect("el1", 10.0, 20.0, 100.0, 50.0)
  let updated = update_element_position(el, 50.0, 60.0)
  inspect(updated.x, content="50")
  inspect(updated.y, content="60")
  // IDは変わらない
  inspect(updated.id, content="el1")
}

///|
test "update_line_endpoint: update start" {
  let el = test_make_line("line1", 0.0, 0.0, 100.0, 100.0)
  let updated = update_line_endpoint(el, "start", 10.0, 20.0)
  inspect(updated.x, content="10")
  inspect(updated.y, content="20")
  // 終点は変わらない
  match updated.shape {
    Line(x2, y2) => {
      inspect(x2, content="100")
      inspect(y2, content="100")
    }
    _ => fail("Expected Line shape")
  }
}

///|
test "update_line_endpoint: update end" {
  let el = test_make_line("line1", 0.0, 0.0, 100.0, 100.0)
  let updated = update_line_endpoint(el, "end", 200.0, 150.0)
  // 始点は変わらない
  inspect(updated.x, content="0")
  inspect(updated.y, content="0")
  // 終点が更新される
  match updated.shape {
    Line(x2, y2) => {
      inspect(x2, content="200")
      inspect(y2, content="150")
    }
    _ => fail("Expected Line shape")
  }
}

///|
test "update_element_in_array: updates matching element" {
  let elements = [
    test_make_rect("el1", 0.0, 0.0, 50.0, 50.0),
    test_make_rect("el2", 100.0, 100.0, 50.0, 50.0),
  ]
  let updated = update_element_in_array(elements, "el1", fn(el) {
    update_element_position(el, 25.0, 25.0)
  })
  inspect(updated[0].x, content="25")
  inspect(updated[0].y, content="25")
  // el2 は変わらない
  inspect(updated[1].x, content="100")
  inspect(updated[1].y, content="100")
}

// ============================================================
// 座標計算テスト
// ============================================================

///|
test "calc_distance: horizontal" {
  let d = calc_distance(0.0, 0.0, 3.0, 0.0)
  inspect(d, content="3")
}

///|
test "calc_distance: vertical" {
  let d = calc_distance(0.0, 0.0, 0.0, 4.0)
  inspect(d, content="4")
}

///|
test "calc_distance: diagonal (3-4-5 triangle)" {
  let d = calc_distance(0.0, 0.0, 3.0, 4.0)
  inspect(d, content="5")
}

///|
test "point_in_circle: inside" {
  let inside = point_in_circle(5.0, 5.0, 5.0, 5.0, 10.0)
  inspect(inside, content="true")
}

///|
test "point_in_circle: on edge" {
  let on_edge = point_in_circle(15.0, 5.0, 5.0, 5.0, 10.0)
  inspect(on_edge, content="true")
}

///|
test "point_in_circle: outside" {
  let outside = point_in_circle(20.0, 5.0, 5.0, 5.0, 10.0)
  inspect(outside, content="false")
}

///|
test "point_in_rect: inside" {
  let inside = point_in_rect(15.0, 15.0, 10.0, 10.0, 20.0, 20.0)
  inspect(inside, content="true")
}

///|
test "point_in_rect: on corner" {
  let on_corner = point_in_rect(10.0, 10.0, 10.0, 10.0, 20.0, 20.0)
  inspect(on_corner, content="true")
}

///|
test "point_in_rect: outside" {
  let outside = point_in_rect(5.0, 5.0, 10.0, 10.0, 20.0, 20.0)
  inspect(outside, content="false")
}

///|
test "point_to_line_distance: perpendicular" {
  // 水平線 (0,0) -> (10,0) に対して (5,5) からの距離
  let d = point_to_line_distance(5.0, 5.0, 0.0, 0.0, 10.0, 0.0)
  inspect(d, content="5")
}

///|
test "point_to_line_distance: to endpoint" {
  // 線分の外側の点から最寄りの端点への距離
  let d = point_to_line_distance(15.0, 0.0, 0.0, 0.0, 10.0, 0.0)
  inspect(d, content="5")
}

///|
test "point_to_line_distance: point line" {
  // 線分が点の場合（始点と終点が同じ）
  let d = point_to_line_distance(3.0, 4.0, 0.0, 0.0, 0.0, 0.0)
  inspect(d, content="5")
}
