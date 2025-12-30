// Moonlight - Rendering Utilities (Pure Functions)
// SVG レンダリング用の純粋関数群

// ============================================================
// テキストサイズ計算
// ============================================================

///|
/// テキストヒットエリアのサイズを計算
/// 文字数とフォントサイズからヒットエリアの幅と高さを推定する
pub fn calc_text_hit_area(
  content : String,
  font_size : Double,
) -> (Double, Double) {
  // 文字幅係数（等幅フォント想定、実際のフォントにより異なる）
  let char_width_ratio = 0.55
  let line_height_ratio = 1.2
  let min_width = font_size * 2.0
  let min_height = 24.0
  if content.contains("\n") {
    // 複数行: 各行の長さを計算
    let lines : Array[String] = content
      .split("\n")
      .map(fn(sv) { sv.to_string() })
      .collect()
    let line_count = lines.length()
    let line_height = font_size * line_height_ratio
    let total_height = line_count.to_double() * line_height

    // 最長行の文字数を取得
    let max_line_len = lines.fold(init=0, fn(acc, line) {
      let len = line.iter().count()
      if len > acc {
        len
      } else {
        acc
      }
    })
    let estimated_width = max_line_len.to_double() *
      font_size *
      char_width_ratio
    let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
    let h = if total_height < min_height { min_height } else { total_height }
    (w, h)
  } else {
    // 単一行: 文字数から幅を推定
    let char_count = content.iter().count()
    let estimated_width = char_count.to_double() * font_size * char_width_ratio
    let w = if estimated_width < min_width {
      min_width
    } else {
      estimated_width
    }
    (w, font_size * line_height_ratio)
  }
}

///|
/// テキストのバウンディングボックスを計算
/// 中央揃えを考慮した位置とサイズを返す
pub fn calc_text_bounds(
  content : String,
  x : Double,
  y : Double,
  font_size : Double,
) -> BoundingBox {
  let (width, height) = calc_text_hit_area(content, font_size)
  // テキストは中央揃えなので、位置を調整
  { x: x - width / 2.0, y: y - height / 2.0, width, height }
}

// ============================================================
// スタイル属性変換
// ============================================================

///|
/// スタイルをSVG属性のリストに変換
pub fn style_to_svg_attrs(style : Style) -> Array[(String, String)] {
  let attrs : Array[(String, String)] = []

  // fill
  match style.fill {
    Some(v) => attrs.push(("fill", v))
    None => attrs.push(("fill", "none"))
  }

  // stroke
  if style.stroke is Some(v) {
    attrs.push(("stroke", v))
  }

  // stroke-width
  if style.stroke_width is Some(v) {
    attrs.push(("stroke-width", num_str(v)))
  }

  // opacity
  if style.opacity is Some(v) {
    attrs.push(("opacity", num_str(v)))
  }

  // stroke-dasharray
  if style.stroke_dasharray is Some(v) {
    attrs.push(("stroke-dasharray", v))
  }
  attrs
}

///|
/// 矢印マーカー属性を取得
pub fn get_marker_attrs(style : Style) -> Array[(String, String)] {
  let attrs : Array[(String, String)] = []
  if style.marker_start is Some(Arrow) {
    attrs.push(("marker-start", "url(#arrow-start-context)"))
  }
  if style.marker_end is Some(Arrow) {
    attrs.push(("marker-end", "url(#arrow-end-context)"))
  }
  attrs
}

// ============================================================
// 要素更新の純粋関数
// ============================================================

///|
/// 要素の位置を更新した新しい要素を返す
pub fn update_element_position(
  el : Element,
  new_x : Double,
  new_y : Double,
) -> Element {
  { ..el, x: new_x, y: new_y }
}

///|
/// ラインの端点を更新した新しい要素を返す
pub fn update_line_endpoint(
  el : Element,
  endpoint : String,
  new_x : Double,
  new_y : Double,
) -> Element {
  match el.shape {
    Line(_, _) =>
      if endpoint == "start" {
        // 始点を更新
        { ..el, x: new_x, y: new_y }
      } else {
        // 終点を更新
        { ..el, shape: Line(new_x, new_y) }
      }
    _ => el // Line 以外は変更しない
  }
}

///|
/// 要素配列から指定IDの要素を更新
pub fn update_element_in_array(
  elements : Array[Element],
  id : String,
  updater : (Element) -> Element,
) -> Array[Element] {
  elements
  .iter()
  .map(fn(el) { if el.id == id { updater(el) } else { el } })
  .collect()
}

///|
/// 複数の要素を一括更新
pub fn update_elements_in_array(
  elements : Array[Element],
  updates : Array[(String, (Element) -> Element)],
) -> Array[Element] {
  let update_map : Map[String, (Element) -> Element] = {}
  for pair in updates {
    let (id, updater) = pair
    update_map[id] = updater
  }
  elements
  .iter()
  .map(fn(el) {
    match update_map.get(el.id) {
      Some(updater) => updater(el)
      None => el
    }
  })
  .collect()
}

// ============================================================
// 座標計算ユーティリティ
// ============================================================

///|
/// 2点間の距離を計算
pub fn calc_distance(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Double {
  let dx = x2 - x1
  let dy = y2 - y1
  (dx * dx + dy * dy).sqrt()
}

///|
/// 点が円内にあるかチェック
pub fn point_in_circle(
  px : Double,
  py : Double,
  cx : Double,
  cy : Double,
  radius : Double,
) -> Bool {
  calc_distance(px, py, cx, cy) <= radius
}

///|
/// 点が矩形内にあるかチェック
pub fn point_in_rect(
  px : Double,
  py : Double,
  rx : Double,
  ry : Double,
  width : Double,
  height : Double,
) -> Bool {
  px >= rx && px <= rx + width && py >= ry && py <= ry + height
}

///|
/// 線分と点の最短距離を計算
pub fn point_to_line_distance(
  px : Double,
  py : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Double {
  let dx = x2 - x1
  let dy = y2 - y1
  let len_sq = dx * dx + dy * dy
  if len_sq == 0.0 {
    // 線分が点の場合
    return calc_distance(px, py, x1, y1)
  }

  // 線分上の最近点のパラメータ t を計算
  let t = ((px - x1) * dx + (py - y1) * dy) / len_sq
  let t_clamped = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }

  // 最近点の座標
  let nearest_x = x1 + t_clamped * dx
  let nearest_y = y1 + t_clamped * dy
  calc_distance(px, py, nearest_x, nearest_y)
}
