// Moonlight Static Editor Entry Point
// model + render + import
// SVG の読み込み・編集・出力が可能（インタラクティブ UI なし）

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
// SVG インポート
// =============================================================================

///|
/// SVG 文字列をパースして Element 配列を返す
pub fn import_svg(
  svg_str : String,
  new_id : () -> String,
) -> Array[@model.Element] {
  @import.import_svg_elements(svg_str, new_id)
}

///|
/// シンプルな ID 生成器を作成
pub fn create_id_generator() -> () -> String {
  let counter : Ref[Int] = { val: 0 }
  fn() {
    counter.val = counter.val + 1
    "el-\{counter.val}"
  }
}

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
/// 角丸矩形要素を作成
pub fn rounded_rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Rect(width, height, Some(rx), Some(ry)),
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
/// 楕円要素を作成
pub fn ellipse(
  id : String,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x: cx,
    y: cy,
    shape: @model.Ellipse(rx, ry),
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

///|
/// パス要素を作成
pub fn path(
  id : String,
  d : String,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  style : @model.Style,
) -> @model.Element {
  {
    id,
    x: 0.0,
    y: 0.0,
    shape: @model.Path(d, start_x, start_y, end_x, end_y),
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
pub fn stroke_style(stroke : String, stroke_width : Double) -> @model.Style {
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

///|
/// 破線スタイルを作成
pub fn dashed_style(
  stroke : String,
  stroke_width : Double,
  dasharray : String,
) -> @model.Style {
  {
    fill: None,
    stroke: Some(stroke),
    stroke_width: Some(stroke_width),
    opacity: None,
    stroke_dasharray: Some(dasharray),
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

// =============================================================================
// 要素操作
// =============================================================================

///|
/// 要素を移動
pub fn move_element(
  el : @model.Element,
  dx : Double,
  dy : Double,
) -> @model.Element {
  { ..el, x: el.x + dx, y: el.y + dy }
}

///|
/// 要素のスタイルを更新
pub fn update_style(
  el : @model.Element,
  style : @model.Style,
) -> @model.Element {
  { ..el, style, }
}

///|
/// 要素を ID で検索
pub fn find_by_id(
  elements : Array[@model.Element],
  id : String,
) -> @model.Element? {
  for el in elements {
    if el.id == id {
      return Some(el)
    }
  }
  None
}

///|
/// 要素を更新
pub fn update_by_id(
  elements : Array[@model.Element],
  id : String,
  updater : (@model.Element) -> @model.Element,
) -> Array[@model.Element] {
  elements.map(fn(el) { if el.id == id { updater(el) } else { el } })
}

///|
/// 要素を削除
pub fn remove_by_id(
  elements : Array[@model.Element],
  id : String,
) -> Array[@model.Element] {
  elements.filter(fn(el) { el.id != id })
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
