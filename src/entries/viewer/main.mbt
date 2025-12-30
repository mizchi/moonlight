// Moonlight Viewer Entry Point
// 最小構成: model + render のみ
// SVG 文字列を生成するための純粋関数を提供

// =============================================================================
// 型のリエクスポート
// =============================================================================

///|
pub type Element = @model.Element

///|
pub type Style = @model.Style

///|
pub type ShapeType = @model.ShapeType

///|
pub type Point = @model.Point

// =============================================================================
// 要素作成ヘルパー
// =============================================================================

///|
/// 矩形要素を作成
pub fn rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Rect(width, height, None, None),
    style,
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// 円要素を作成
pub fn circle(
  id : String,
  cx : Double,
  cy : Double,
  r : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x: cx,
    y: cy,
    shape: @model.Circle(r),
    style,
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// 線要素を作成
pub fn line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x: x1,
    y: y1,
    shape: @model.Line(x2, y2),
    style,
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// テキスト要素を作成
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
  font_size : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Text(content, Some(font_size)),
    style,
    transform: None,
    parent_id: None,
    connections: None,
  }
}

// =============================================================================
// スタイル作成ヘルパー
// =============================================================================

///|
/// デフォルトスタイルを作成
pub fn default_style() -> @model.Style {
  {
    fill: Some("#ffffff"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// 塗りつぶしスタイルを作成
pub fn fill_style(fill : String, stroke : String) -> @model.Style {
  {
    fill: Some(fill),
    stroke: Some(stroke),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// 線スタイルを作成
pub fn line_style(stroke : String, stroke_width : Double) -> @model.Style {
  {
    fill: None,
    stroke: Some(stroke),
    stroke_width: Some(stroke_width),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

// =============================================================================
// SVG 生成
// =============================================================================

///|
/// 要素配列を標準 SVG 文字列に変換
pub fn to_svg(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
) -> String {
  @render.elements_to_svg(elements, width, height)
}

///|
/// 要素配列を SVG 文字列に変換（オプション付き）
pub fn to_svg_with_options(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
  bg_color : String,
) -> String {
  @render.elements_to_svg_with_options(elements, width, height, bg_color)
}

///|
/// 要素配列を Moonlight SVG 文字列に変換（再編集可能）
pub fn to_moonlight_svg(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
  bg_color : String,
) -> String {
  @render.elements_to_moonlight_svg(elements, width, height, bg_color)
}

///|
/// 単一要素を SVG 文字列に変換
pub fn element_to_svg(el : @model.Element) -> String {
  @render.element_to_svg_string(el)
}
