// SVG 文字列生成 - 純粋関数
// DOM に依存しない、Element → String 変換

// =============================================================================
// スタイル属性ヘルパー
// =============================================================================

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
  serialize_element(el, parent_stroke, Plain)
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
/// 要素配列を標準 SVG 文字列にエクスポート（オプション付き）
pub fn elements_to_svg_with_options(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
  bg_color : String,
) -> String {
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{width} \{height}\" width=\"\{width}\" height=\"\{height}\">\n"
  // 矢印マーカーが必要かチェック
  let needs_arrows = elements
    .iter()
    .any(fn(el) {
      el.style.marker_start is Some(_) || el.style.marker_end is Some(_)
    })
  if needs_arrows {
    svg = svg +
      "  " +
      generate_arrow_defs().replace(old="\n", new="\n  ") +
      "\n"
  }
  // 背景
  svg = svg + "  <rect width=\"100%\" height=\"100%\" fill=\"\{bg_color}\"/>\n"
  // 要素（子要素が親要素の上に描画されるようソート）
  let sorted = @model.sort_elements_for_render(elements)
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
