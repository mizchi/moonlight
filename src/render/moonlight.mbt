// Moonlight SVG フォーマット生成
// data-* 属性を含む、再編集可能な SVG 出力

// =============================================================================
// ヘルパー関数
// =============================================================================

///|
/// 接続情報を文字列に変換 (format: "element-id:anchor")
fn connection_to_string(conn : @model.Connection) -> String {
  let anchor_str = @model.anchor_to_string(conn.anchor)
  "\{conn.element_id}:\{anchor_str}"
}

///|
/// Moonlight 用矢印マーカー定義を生成
fn generate_moonlight_arrow_defs() -> String {
  let sb = StringBuilder::new()
  sb.write_string("  <defs>\n")
  // 始点矢印
  sb.write_string(
    "    <marker id=\"arrow-start\" markerWidth=\"10\" markerHeight=\"10\" refX=\"0\" refY=\"3\" orient=\"auto-start-reverse\">\n",
  )
  sb.write_string(
    "      <path d=\"M0,0 L0,6 L9,3 z\" fill=\"currentColor\"/>\n",
  )
  sb.write_string("    </marker>\n")
  // 終点矢印
  sb.write_string(
    "    <marker id=\"arrow-end\" markerWidth=\"10\" markerHeight=\"10\" refX=\"9\" refY=\"3\" orient=\"auto\">\n",
  )
  sb.write_string(
    "      <path d=\"M0,0 L0,6 L9,3 z\" fill=\"currentColor\"/>\n",
  )
  sb.write_string("    </marker>\n")
  sb.write_string("  </defs>\n")
  sb.to_string()
}

// =============================================================================
// 要素 → Moonlight SVG 文字列変換
// =============================================================================

///|
/// 要素を Moonlight SVG 文字列に変換（メタデータ付き）
pub fn element_to_moonlight_svg(el : @model.Element) -> String {
  element_to_moonlight_svg_with_parent(el, None)
}

///|
/// 要素を Moonlight SVG 文字列に変換（親の stroke 色を考慮）
pub fn element_to_moonlight_svg_with_parent(
  el : @model.Element,
  parent_stroke : String?,
) -> String {
  let style = el.style
  let attrs = StringBuilder::new()
  // メタデータ属性
  attrs.write_string(" data-id=\"\{el.id}\"")
  if el.parent_id is Some(pid) {
    attrs.write_string(" data-parent-id=\"\{pid}\"")
  }
  // 接続情報
  if el.connections is Some(conns) {
    if conns.start is Some(start_conn) {
      attrs.write_string(
        " data-connection-start=\"\{connection_to_string(start_conn)}\"",
      )
    }
    if conns.end is Some(end_conn) {
      attrs.write_string(
        " data-connection-end=\"\{connection_to_string(end_conn)}\"",
      )
    }
  }
  // transform
  if el.transform is Some(t) {
    attrs.write_string(" transform=\"\{t}\"")
  }
  // スタイル属性（テキスト以外）
  let is_text = el.shape is @model.Text(_, _)
  if is_text {
    // テキストの場合、親があれば親の stroke を使用
    let text_fill = @model.get_text_fill_color(style, parent_stroke)
    attrs.write_string(" fill=\"\{text_fill}\"")
  } else if style.fill is Some(v) {
    attrs.write_string(" fill=\"\{v}\"")
  } else {
    attrs.write_string(" fill=\"none\"")
  }
  if style.stroke is Some(v) {
    attrs.write_string(" stroke=\"\{v}\"")
  }
  if style.stroke_width is Some(v) {
    attrs.write_string(" stroke-width=\"\{v}\"")
  }
  if style.opacity is Some(v) {
    attrs.write_string(" opacity=\"\{v}\"")
  }
  if style.stroke_dasharray is Some(v) {
    attrs.write_string(" stroke-dasharray=\"\{v}\"")
  }
  // マーカー属性
  if style.marker_start is Some(@model.Arrow) {
    attrs.write_string(" marker-start=\"url(#arrow-start)\"")
  }
  if style.marker_end is Some(@model.Arrow) {
    attrs.write_string(" marker-end=\"url(#arrow-end)\"")
  }
  let attrs_str = attrs.to_string()
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rx_attr = if rx is Some(v) { " rx=\"\{v}\"" } else { "" }
      let ry_attr = if ry is Some(v) { " ry=\"\{v}\"" } else { "" }
      "<rect x=\"\{el.x}\" y=\"\{el.y}\" width=\"\{w}\" height=\"\{h}\"\{rx_attr}\{ry_attr}\{attrs_str}/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{el.x}\" cy=\"\{el.y}\" r=\"\{r}\"\{attrs_str}/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{el.x}\" cy=\"\{el.y}\" rx=\"\{rx}\" ry=\"\{ry}\"\{attrs_str}/>"
    @model.Line(x2, y2) =>
      "<line x1=\"\{el.x}\" y1=\"\{el.y}\" x2=\"\{x2}\" y2=\"\{y2}\"\{attrs_str}/>"
    @model.Polyline(points) => {
      let points_str = points.map(fn(p) { "\{p.x},\{p.y}" }).join(" ")
      "<polyline points=\"\{points_str}\"\{attrs_str}/>"
    }
    @model.Path(d, _, _, _, _) => "<path d=\"\{d}\"\{attrs_str}/>"
    @model.Text(content, font_size) => {
      let size = font_size.unwrap_or(16.0)
      let fs_attr = " font-size=\"\{size}\""
      if content.contains("\n") {
        let lines : Array[String] = content
          .split("\n")
          .map(fn(sv) { sv.to_string() })
          .collect()
        let line_height = size * 1.2
        let total_height = (lines.length() - 1).to_double() * line_height
        let start_offset = -total_height / 2.0
        let tspans : Array[String] = []
        for i, line in lines {
          let dy = if i == 0 { start_offset } else { line_height }
          let escaped = @model.escape_xml(line)
          let x_val = el.x
          tspans.push("<tspan x=\"\{x_val}\" dy=\"\{dy}\">\{escaped}</tspan>")
        }
        let tspan_str = tspans.join("")
        "<text x=\"\{el.x}\" y=\"\{el.y}\"\{fs_attr}\{attrs_str}>\{tspan_str}</text>"
      } else {
        let escaped = @model.escape_xml(content)
        "<text x=\"\{el.x}\" y=\"\{el.y}\"\{fs_attr}\{attrs_str}>\{escaped}</text>"
      }
    }
  }
}

// =============================================================================
// Moonlight SVG エクスポート
// =============================================================================

///|
/// 全要素を Moonlight SVG 形式で出力
pub fn elements_to_moonlight_svg(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
  bg_color : String,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}\" height=\"\{height}\" viewBox=\"0 0 \{width} \{height}\" data-moonlight=\"1.0\">\n",
  )
  // 矢印定義
  sb.write_string(generate_moonlight_arrow_defs())
  // 背景
  if bg_color != "transparent" {
    sb.write_string(
      "  <rect width=\"100%\" height=\"100%\" fill=\"\{bg_color}\"/>\n",
    )
  }
  // 要素（子要素が親要素の上に描画されるようソート）
  let sorted = @model.sort_elements_for_render(elements)
  for el in sorted {
    // 子テキスト要素の場合、親の stroke 色を取得
    let parent_stroke = @model.get_parent_stroke(elements, el.parent_id)
    sb.write_string("  ")
    sb.write_string(element_to_moonlight_svg_with_parent(el, parent_stroke))
    sb.write_string("\n")
  }
  sb.write_string("</svg>")
  sb.to_string()
}

///|
/// デフォルト背景色（白）で Moonlight SVG を出力
pub fn elements_to_moonlight_svg_default(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
) -> String {
  elements_to_moonlight_svg(elements, width, height, "#ffffff")
}
