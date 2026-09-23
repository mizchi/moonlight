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
  let sb = StringBuilder()
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
  serialize_element(el, parent_stroke, Moonlight)
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
  let sb = StringBuilder()
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
