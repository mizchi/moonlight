// SVG 文字列生成 - 純粋関数
// DOM に依存しない、Element → String 変換

// =============================================================================
// スタイル属性ヘルパー
// =============================================================================

///|
/// スタイルを属性配列に変換
pub fn style_to_attrs(style : @model.Style) -> Array[(String, String)] {
  let attrs : Array[(String, String)] = []
  match style.fill {
    Some(v) => attrs.push(("fill", v))
    None => attrs.push(("fill", "none"))
  }
  if style.stroke is Some(v) {
    attrs.push(("stroke", v))
  }
  if style.stroke_width is Some(v) {
    attrs.push(("stroke-width", @model.num_str(v)))
  }
  if style.opacity is Some(v) {
    attrs.push(("opacity", @model.num_str(v)))
  }
  if style.stroke_dasharray is Some(v) {
    attrs.push(("stroke-dasharray", v))
  }
  attrs
}

///|
/// スタイル属性を配列に追加（mutable版）
pub fn add_style_attrs(
  attrs : Array[(String, String)],
  style : @model.Style,
) -> Unit {
  for attr in style_to_attrs(style) {
    attrs.push(attr)
  }
}

///|
/// 矢印マーカー属性を追加
pub fn add_marker_attrs(
  attrs : Array[(String, String)],
  style : @model.Style,
) -> Unit {
  if style.marker_start is Some(@model.Arrow) {
    attrs.push(("marker-start", "url(#arrow-start-context)"))
  }
  if style.marker_end is Some(@model.Arrow) {
    attrs.push(("marker-end", "url(#arrow-end-context)"))
  }
}

// =============================================================================
// 要素 → SVG 文字列変換
// =============================================================================

///|
/// 要素を SVG 文字列に変換
pub fn element_to_svg_string(el : @model.Element) -> String {
  element_to_svg_string_with_parent(el, None)
}

///|
/// 要素を SVG 文字列に変換（親の stroke 色を考慮）
pub fn element_to_svg_string_with_parent(
  el : @model.Element,
  parent_stroke : String?,
) -> String {
  let style = el.style
  let fill = style.fill.unwrap_or("none")
  let stroke = style.stroke.unwrap_or("#000000")
  let stroke_width = style.stroke_width.unwrap_or(1.0)
  let opacity_attr = match style.opacity {
    Some(v) => " opacity=\"\{@model.num_str(v)}\""
    None => ""
  }
  let dasharray_attr = match style.stroke_dasharray {
    Some(v) => " stroke-dasharray=\"\{v}\""
    None => ""
  }
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rx_attr = match rx {
        Some(v) => " rx=\"\{@model.num_str(v)}\""
        None => ""
      }
      let ry_attr = match ry {
        Some(v) => " ry=\"\{@model.num_str(v)}\""
        None => ""
      }
      "<rect x=\"\{@model.num_str(el.x)}\" y=\"\{@model.num_str(el.y)}\" width=\"\{@model.num_str(w)}\" height=\"\{@model.num_str(h)}\"\{rx_attr}\{ry_attr} fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"\{opacity_attr}\{dasharray_attr}/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{@model.num_str(el.x)}\" cy=\"\{@model.num_str(el.y)}\" r=\"\{@model.num_str(r)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"\{opacity_attr}\{dasharray_attr}/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{@model.num_str(el.x)}\" cy=\"\{@model.num_str(el.y)}\" rx=\"\{@model.num_str(rx)}\" ry=\"\{@model.num_str(ry)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"\{opacity_attr}\{dasharray_attr}/>"
    @model.Line(x2, y2) => {
      let marker_start = match style.marker_start {
        Some(@model.Arrow) => " marker-start=\"url(#arrow-start-context)\""
        _ => ""
      }
      let marker_end = match style.marker_end {
        Some(@model.Arrow) => " marker-end=\"url(#arrow-end-context)\""
        _ => ""
      }
      "<line x1=\"\{@model.num_str(el.x)}\" y1=\"\{@model.num_str(el.y)}\" x2=\"\{@model.num_str(x2)}\" y2=\"\{@model.num_str(y2)}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"\{opacity_attr}\{dasharray_attr}\{marker_start}\{marker_end}/>"
    }
    @model.Text(content, font_size) => {
      let fs = font_size.unwrap_or(16.0)
      let text_fill = @model.get_text_fill_color(el.style, parent_stroke)
      let font_family_attr = match el.style.font_family {
        Some(ff) => " font-family=\"\{ff}\""
        None => ""
      }
      "<text x=\"\{@model.num_str(el.x)}\" y=\"\{@model.num_str(el.y)}\" fill=\"\{text_fill}\" font-size=\"\{@model.num_str(fs)}\"\{font_family_attr} text-anchor=\"middle\" dominant-baseline=\"middle\">\{@model.escape_xml(content)}</text>"
    }
    @model.Polyline(points) => {
      let points_str = points
        .map(fn(p) { "\{@model.num_str(p.x)},\{@model.num_str(p.y)}" })
        .join(" ")
      "<polyline points=\"\{points_str}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"\{opacity_attr}\{dasharray_attr}/>"
    }
    @model.Path(d, _, _, _, _) =>
      "<path d=\"\{d}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"\{opacity_attr}\{dasharray_attr}/>"
  }
}

// =============================================================================
// 矢印マーカー定義
// =============================================================================

///|
/// 矢印マーカーの SVG defs を生成
pub fn generate_arrow_defs() -> String {
  let mut defs = "<defs>\n"
  // 始点用矢印（context-stroke で参照元の色を継承）
  defs = defs +
    "  <marker id=\"arrow-start-context\" markerWidth=\"10\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto\" markerUnits=\"strokeWidth\">\n"
  defs = defs + "    <path d=\"M10,0 L0,5 L10,10\" fill=\"context-stroke\"/>\n"
  defs = defs + "  </marker>\n"
  // 終点用矢印
  defs = defs +
    "  <marker id=\"arrow-end-context\" markerWidth=\"10\" markerHeight=\"10\" refX=\"10\" refY=\"5\" orient=\"auto\" markerUnits=\"strokeWidth\">\n"
  defs = defs + "    <path d=\"M0,0 L10,5 L0,10\" fill=\"context-stroke\"/>\n"
  defs = defs + "  </marker>\n"
  defs = defs + "</defs>"
  defs
}

// =============================================================================
// 標準 SVG エクスポート
// =============================================================================

///|
/// 要素配列を標準 SVG 文字列にエクスポート
pub fn elements_to_svg(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
) -> String {
  elements_to_svg_with_options(elements, width, height, "#ffffff")
}

///|
/// 要素を描画順にソート（親要素を先、子要素を後に）
/// 子要素（Text等）が親要素（Line等）の上に描画されるようにする
pub fn sort_elements_for_render(
  elements : Array[@model.Element],
) -> Array[@model.Element] {
  // 親要素（parent_id が None）を先に、子要素を後に
  let parents : Array[@model.Element] = []
  let children : Array[@model.Element] = []
  for el in elements {
    if el.parent_id is None {
      parents.push(el)
    } else {
      children.push(el)
    }
  }
  // 親の後に子を追加（子は親の描画後に描画される = 上に表示）
  parents.append(children)
  parents
}

///|
/// 要素配列を標準 SVG 文字列にエクスポート（オプション付き）
pub fn elements_to_svg_with_options(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
  bg_color : String,
) -> String {
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{width} \{height}\" width=\"\{width}\" height=\"\{height}\">\n"
  // 矢印マーカーが必要かチェック
  let needs_arrows = elements.iter().any(fn(el) {
    el.style.marker_start is Some(_) || el.style.marker_end is Some(_)
  })
  if needs_arrows {
    svg = svg + "  " + generate_arrow_defs().replace(old="\n", new="\n  ") + "\n"
  }
  // 背景
  svg = svg + "  <rect width=\"100%\" height=\"100%\" fill=\"\{bg_color}\"/>\n"
  // 要素（子要素が親要素の上に描画されるようソート）
  let sorted = sort_elements_for_render(elements)
  for el in sorted {
    let parent_stroke = @model.get_parent_stroke(elements, el.parent_id)
    svg = svg +
      "  " +
      element_to_svg_string_with_parent(el, parent_stroke) +
      "\n"
  }
  svg = svg + "</svg>"
  svg
}
