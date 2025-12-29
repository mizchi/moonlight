// 共通レンダリングモジュール
// Preview/Embed/WebComponent で共通のSVGレンダリング関数

// =============================================================================
// FFI 関数
// =============================================================================

///|
/// SVG 要素を作成（createElementNS）
pub extern "js" fn create_svg_element_ns(tag : String) -> @js.Any =
  #| (tag) => document.createElementNS('http://www.w3.org/2000/svg', tag)

///|
/// SVG 要素に属性を設定
pub extern "js" fn set_svg_attr(el : @js.Any, name : String, value : String) =
  #| (el, name, value) => el.setAttribute(name, value)

///|
/// 子要素を追加
pub extern "js" fn append_child(parent : @js.Any, child : @js.Any) =
  #| (parent, child) => parent.appendChild(child)

///|
/// innerHTML を設定
pub extern "js" fn set_inner_html(el : @js.Any, html : String) =
  #| (el, html) => el.innerHTML = html

///|
/// SVG 要素の子要素をクリア
pub extern "js" fn clear_svg_children(svg : @js.Any) =
  #| (svg) => { while (svg.firstChild) svg.removeChild(svg.firstChild); }

// =============================================================================
// 矢印マーカー定義
// =============================================================================

///|
/// 矢印マーカーを作成（シンプルな三角形、context-stroke使用）
fn create_arrow_marker(id : String, is_start : Bool) -> @js.Any {
  let marker = create_svg_element_ns("marker")
  set_svg_attr(marker, "id", id)
  set_svg_attr(marker, "markerWidth", "10")
  set_svg_attr(marker, "markerHeight", "10")
  set_svg_attr(marker, "refX", if is_start { "0" } else { "10" })
  set_svg_attr(marker, "refY", "5")
  set_svg_attr(marker, "orient", "auto")
  set_svg_attr(marker, "markerUnits", "strokeWidth")
  // シンプルな三角形パス - context-stroke で参照元のstrokeを継承
  let path = create_svg_element_ns("path")
  let path_d = if is_start { "M10,0 L0,5 L10,10" } else { "M0,0 L10,5 L0,10" }
  set_svg_attr(path, "d", path_d)
  set_svg_attr(path, "fill", "context-stroke")
  append_child(marker, path)
  marker
}

///|
/// SVG 定義（矢印マーカー）を作成
pub fn create_arrow_defs() -> @js.Any {
  let defs = create_svg_element_ns("defs")
  // context-stroke マーカー（参照元のstrokeを継承）
  let start_context = create_arrow_marker("arrow-start-context", true)
  let end_context = create_arrow_marker("arrow-end-context", false)
  append_child(defs, start_context)
  append_child(defs, end_context)
  defs
}

// =============================================================================
// 数値変換ユーティリティ
// =============================================================================

///|
/// 数値を文字列に変換（小数点以下2桁）
pub fn num_to_str(n : Double) -> String {
  let rounded = (n * 100.0).round() / 100.0
  rounded.to_string()
}

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
    attrs.push(("stroke-width", num_to_str(v)))
  }
  if style.opacity is Some(v) {
    attrs.push(("opacity", num_to_str(v)))
  }
  if style.stroke_dasharray is Some(v) {
    attrs.push(("stroke-dasharray", v))
  }
  attrs
}

///|
/// スタイル属性を配列に追加（mutable版、既存コードとの互換性）
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
// 要素レンダリング（共通ロジック）
// =============================================================================

///|
/// 要素を SVG DOM 要素として描画
/// is_selected: 選択状態（ハイライト用）
pub fn render_element_to_svg(
  el : @model.Element,
  is_selected : Bool,
) -> @js.Any {
  let style = el.style
  let fill = style.fill.unwrap_or("none")
  let stroke = style.stroke.unwrap_or("#000000")
  let stroke_width = style.stroke_width.unwrap_or(1.0)
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rect = create_svg_element_ns("rect")
      set_svg_attr(rect, "x", num_to_str(el.x))
      set_svg_attr(rect, "y", num_to_str(el.y))
      set_svg_attr(rect, "width", num_to_str(w))
      set_svg_attr(rect, "height", num_to_str(h))
      if rx is Some(v) {
        set_svg_attr(rect, "rx", num_to_str(v))
      }
      if ry is Some(v) {
        set_svg_attr(rect, "ry", num_to_str(v))
      }
      set_svg_attr(rect, "fill", fill)
      set_svg_attr(rect, "stroke", stroke)
      set_svg_attr(rect, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(rect, "data-id", el.id)
      set_svg_attr(rect, "cursor", "move")
      rect
    }
    @model.Circle(r) => {
      let circle = create_svg_element_ns("circle")
      set_svg_attr(circle, "cx", num_to_str(el.x))
      set_svg_attr(circle, "cy", num_to_str(el.y))
      set_svg_attr(circle, "r", num_to_str(r))
      set_svg_attr(circle, "fill", fill)
      set_svg_attr(circle, "stroke", stroke)
      set_svg_attr(circle, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(circle, "data-id", el.id)
      set_svg_attr(circle, "cursor", "move")
      circle
    }
    @model.Ellipse(rx, ry) => {
      let ellipse = create_svg_element_ns("ellipse")
      set_svg_attr(ellipse, "cx", num_to_str(el.x))
      set_svg_attr(ellipse, "cy", num_to_str(el.y))
      set_svg_attr(ellipse, "rx", num_to_str(rx))
      set_svg_attr(ellipse, "ry", num_to_str(ry))
      set_svg_attr(ellipse, "fill", fill)
      set_svg_attr(ellipse, "stroke", stroke)
      set_svg_attr(ellipse, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(ellipse, "data-id", el.id)
      set_svg_attr(ellipse, "cursor", "move")
      ellipse
    }
    @model.Line(x2, y2) => {
      // Line要素はグループでラップして、クリック領域を広げる
      let group = create_svg_element_ns("g")
      set_svg_attr(group, "data-id", el.id)
      set_svg_attr(group, "data-element-type", "line")
      set_svg_attr(group, "cursor", "move")
      // 透明なヒットエリア（クリック用、24px幅）
      let hit_area = create_svg_element_ns("line")
      set_svg_attr(hit_area, "x1", num_to_str(el.x))
      set_svg_attr(hit_area, "y1", num_to_str(el.y))
      set_svg_attr(hit_area, "x2", num_to_str(x2))
      set_svg_attr(hit_area, "y2", num_to_str(y2))
      set_svg_attr(hit_area, "stroke", "transparent")
      set_svg_attr(hit_area, "stroke-width", "24")
      append_child(group, hit_area)
      // 選択時はハイライト線を追加
      if is_selected {
        let highlight = create_svg_element_ns("line")
        set_svg_attr(highlight, "x1", num_to_str(el.x))
        set_svg_attr(highlight, "y1", num_to_str(el.y))
        set_svg_attr(highlight, "x2", num_to_str(x2))
        set_svg_attr(highlight, "y2", num_to_str(y2))
        set_svg_attr(highlight, "stroke", "rgba(0, 102, 255, 0.3)")
        set_svg_attr(highlight, "stroke-width", num_to_str(stroke_width + 6.0))
        set_svg_attr(highlight, "stroke-linecap", "round")
        set_svg_attr(highlight, "pointer-events", "none")
        append_child(group, highlight)
      }
      // 実際の線
      let line = create_svg_element_ns("line")
      set_svg_attr(line, "x1", num_to_str(el.x))
      set_svg_attr(line, "y1", num_to_str(el.y))
      set_svg_attr(line, "x2", num_to_str(x2))
      set_svg_attr(line, "y2", num_to_str(y2))
      set_svg_attr(line, "stroke", stroke)
      set_svg_attr(line, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(line, "pointer-events", "none")
      // 矢印マーカー
      if style.marker_start is Some(@model.Arrow) {
        set_svg_attr(line, "marker-start", "url(#arrow-start-context)")
      }
      if style.marker_end is Some(@model.Arrow) {
        set_svg_attr(line, "marker-end", "url(#arrow-end-context)")
      }
      append_child(group, line)
      group
    }
    @model.Text(content, font_size) => {
      let text = create_svg_element_ns("text")
      set_svg_attr(text, "x", num_to_str(el.x))
      set_svg_attr(text, "y", num_to_str(el.y))
      set_svg_attr(text, "fill", fill)
      set_svg_attr(text, "font-size", num_to_str(font_size.unwrap_or(16.0)))
      set_svg_attr(text, "text-anchor", "middle")
      set_svg_attr(text, "dominant-baseline", "middle")
      set_inner_html(text, content)
      set_svg_attr(text, "data-id", el.id)
      set_svg_attr(text, "cursor", "move")
      text
    }
    @model.Polyline(points) => {
      let polyline = create_svg_element_ns("polyline")
      let points_str = points
        .map(fn(p) { "\{num_to_str(p.x)},\{num_to_str(p.y)}" })
        .join(" ")
      set_svg_attr(polyline, "points", points_str)
      set_svg_attr(polyline, "fill", fill)
      set_svg_attr(polyline, "stroke", stroke)
      set_svg_attr(polyline, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(polyline, "data-id", el.id)
      set_svg_attr(polyline, "cursor", "move")
      polyline
    }
    @model.Path(d) => {
      let path = create_svg_element_ns("path")
      set_svg_attr(path, "d", d)
      set_svg_attr(path, "fill", fill)
      set_svg_attr(path, "stroke", stroke)
      set_svg_attr(path, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(path, "data-id", el.id)
      set_svg_attr(path, "cursor", "move")
      path
    }
  }
}

// =============================================================================
// 選択枠・アンカーポイント描画
// =============================================================================

///|
/// 選択枠を描画（低レベルヘルパー）
pub fn create_selection_rect(
  svg : @js.Any,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> @js.Any {
  let rect = create_svg_element_ns("rect")
  set_svg_attr(rect, "class", "selection-rect")
  set_svg_attr(rect, "x", num_to_str(x - 2.0))
  set_svg_attr(rect, "y", num_to_str(y - 2.0))
  set_svg_attr(rect, "width", num_to_str(w + 4.0))
  set_svg_attr(rect, "height", num_to_str(h + 4.0))
  set_svg_attr(rect, "fill", "none")
  set_svg_attr(rect, "stroke", "#0066ff")
  set_svg_attr(rect, "stroke-width", "2")
  set_svg_attr(rect, "stroke-dasharray", "4,2")
  set_svg_attr(rect, "pointer-events", "none")
  append_child(svg, rect)
  rect
}

///|
/// アンカーポイントを描画
pub fn render_anchor_point(
  svg : @js.Any,
  x : Double,
  y : Double,
  element_id : String,
  anchor_type : String,
) -> @js.Any {
  let circle = create_svg_element_ns("circle")
  set_svg_attr(circle, "class", "anchor-point")
  set_svg_attr(circle, "cx", num_to_str(x))
  set_svg_attr(circle, "cy", num_to_str(y))
  set_svg_attr(circle, "r", "6")
  set_svg_attr(circle, "fill", "#0066ff")
  set_svg_attr(circle, "stroke", "#ffffff")
  set_svg_attr(circle, "stroke-width", "2")
  set_svg_attr(circle, "cursor", "crosshair")
  set_svg_attr(circle, "data-anchor", anchor_type)
  set_svg_attr(circle, "data-anchor-element", element_id)
  append_child(svg, circle)
  circle
}

///|
/// リサイズハンドルを描画
pub fn render_resize_handle(
  svg : @js.Any,
  x : Double,
  y : Double,
  handle_type : String,
  element_id : String,
  cursor : String,
) -> @js.Any {
  let rect = create_svg_element_ns("rect")
  let size = 8.0
  set_svg_attr(rect, "class", "resize-handle")
  set_svg_attr(rect, "x", num_to_str(x - size / 2.0))
  set_svg_attr(rect, "y", num_to_str(y - size / 2.0))
  set_svg_attr(rect, "width", num_to_str(size))
  set_svg_attr(rect, "height", num_to_str(size))
  set_svg_attr(rect, "fill", "#0066ff")
  set_svg_attr(rect, "stroke", "#ffffff")
  set_svg_attr(rect, "stroke-width", "1")
  set_svg_attr(rect, "cursor", cursor)
  set_svg_attr(rect, "data-handle", handle_type)
  set_svg_attr(rect, "data-element-id", element_id)
  append_child(svg, rect)
  rect
}

///|
/// Lineのハンドルを描画（円形）
pub fn render_line_handle(
  svg : @js.Any,
  x : Double,
  y : Double,
  handle_type : String,
  element_id : String,
) -> @js.Any {
  let circle = create_svg_element_ns("circle")
  set_svg_attr(circle, "class", "line-handle")
  set_svg_attr(circle, "cx", num_to_str(x))
  set_svg_attr(circle, "cy", num_to_str(y))
  set_svg_attr(circle, "r", "5")
  set_svg_attr(circle, "fill", "#0066ff")
  set_svg_attr(circle, "stroke", "#ffffff")
  set_svg_attr(circle, "stroke-width", "2")
  set_svg_attr(circle, "cursor", "move")
  set_svg_attr(circle, "data-handle", handle_type)
  set_svg_attr(circle, "data-element-id", element_id)
  append_child(svg, circle)
  circle
}

// =============================================================================
// 要素の境界計算
// =============================================================================

///|
/// 要素の境界を取得 (x, y, width, height)
pub fn get_element_bounds(
  el : @model.Element,
) -> (Double, Double, Double, Double) {
  match el.shape {
    @model.Rect(w, h, _, _) => (el.x, el.y, w, h)
    @model.Circle(r) => (el.x - r, el.y - r, r * 2.0, r * 2.0)
    @model.Ellipse(rx, ry) => (el.x - rx, el.y - ry, rx * 2.0, ry * 2.0)
    @model.Line(x2, y2) => {
      let min_x = if el.x < x2 { el.x } else { x2 }
      let min_y = if el.y < y2 { el.y } else { y2 }
      let max_x = if el.x > x2 { el.x } else { x2 }
      let max_y = if el.y > y2 { el.y } else { y2 }
      // 最小幅/高さを保証
      let w = if max_x - min_x < 1.0 { 1.0 } else { max_x - min_x }
      let h = if max_y - min_y < 1.0 { 1.0 } else { max_y - min_y }
      (min_x, min_y, w, h)
    }
    @model.Text(_, font_size) => {
      let size = font_size.unwrap_or(16.0)
      (el.x - 50.0, el.y - size / 2.0, 100.0, size)
    }
    _ => (el.x, el.y, 50.0, 50.0)
  }
}

// =============================================================================
// アンカーポイント位置計算
// =============================================================================

///|
/// 要素のアンカーポイントを取得
pub fn get_element_anchor_points(
  el : @model.Element,
) -> Array[(Double, Double, @core.AnchorType)] {
  match el.shape {
    @model.Rect(w, h, _, _) => {
      let cx = el.x + w / 2.0
      let cy = el.y + h / 2.0
      [
        (cx, el.y, @core.Top),
        (cx, el.y + h, @core.Bottom),
        (el.x, cy, @core.Left),
        (el.x + w, cy, @core.Right),
        (cx, cy, @core.Center),
      ]
    }
    @model.Circle(r) =>
      [
        (el.x, el.y - r, @core.Top),
        (el.x, el.y + r, @core.Bottom),
        (el.x - r, el.y, @core.Left),
        (el.x + r, el.y, @core.Right),
        (el.x, el.y, @core.Center),
      ]
    @model.Ellipse(rx, ry) =>
      [
        (el.x, el.y - ry, @core.Top),
        (el.x, el.y + ry, @core.Bottom),
        (el.x - rx, el.y, @core.Left),
        (el.x + rx, el.y, @core.Right),
        (el.x, el.y, @core.Center),
      ]
    @model.Line(x2, y2) =>
      [
        (el.x, el.y, @core.LineStart),
        (x2, y2, @core.LineEnd),
        ((el.x + x2) / 2.0, (el.y + y2) / 2.0, @core.Center),
      ]
    @model.Text(_, _) => [(el.x, el.y, @core.Center)]
    _ => []
  }
}

// =============================================================================
// SVGエクスポート
// =============================================================================

///|
/// 要素を SVG 文字列に変換
pub fn element_to_svg_string(el : @model.Element) -> String {
  let style = el.style
  let fill = style.fill.unwrap_or("none")
  let stroke = style.stroke.unwrap_or("#000000")
  let stroke_width = style.stroke_width.unwrap_or(1.0)
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rx_attr = match rx {
        Some(v) => " rx=\"\{num_to_str(v)}\""
        None => ""
      }
      let ry_attr = match ry {
        Some(v) => " ry=\"\{num_to_str(v)}\""
        None => ""
      }
      "<rect x=\"\{num_to_str(el.x)}\" y=\"\{num_to_str(el.y)}\" width=\"\{num_to_str(w)}\" height=\"\{num_to_str(h)}\"\{rx_attr}\{ry_attr} fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{num_to_str(el.x)}\" cy=\"\{num_to_str(el.y)}\" r=\"\{num_to_str(r)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{num_to_str(el.x)}\" cy=\"\{num_to_str(el.y)}\" rx=\"\{num_to_str(rx)}\" ry=\"\{num_to_str(ry)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    @model.Line(x2, y2) =>
      "<line x1=\"\{num_to_str(el.x)}\" y1=\"\{num_to_str(el.y)}\" x2=\"\{num_to_str(x2)}\" y2=\"\{num_to_str(y2)}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    @model.Text(content, font_size) => {
      let fs = font_size.unwrap_or(16.0)
      "<text x=\"\{num_to_str(el.x)}\" y=\"\{num_to_str(el.y)}\" fill=\"\{fill}\" font-size=\"\{num_to_str(fs)}\">\{content}</text>"
    }
    @model.Polyline(points) => {
      let points_str = points
        .map(fn(p) { "\{num_to_str(p.x)},\{num_to_str(p.y)}" })
        .join(" ")
      "<polyline points=\"\{points_str}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    }
    @model.Path(d) =>
      "<path d=\"\{d}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
  }
}

///|
/// 要素配列を SVG 文字列にエクスポート
pub fn export_elements_to_svg(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
  bg_color : String,
) -> String {
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{width} \{height}\" width=\"\{width}\" height=\"\{height}\">\n"
  svg = svg + "  <rect width=\"100%\" height=\"100%\" fill=\"\{bg_color}\"/>\n"
  for el in elements {
    // 子テキスト要素の場合、親の stroke 色を取得
    let parent_stroke : String? = match el.parent_id {
      Some(pid) => {
        let parent = elements.iter().find_first(fn(e) { e.id == pid })
        match parent {
          Some(p) => p.style.stroke
          None => None
        }
      }
      None => None
    }
    svg = svg + "  " + element_to_svg_string_with_parent(el, parent_stroke) + "\n"
  }
  svg = svg + "</svg>"
  svg
}

///|
/// 要素を SVG 文字列に変換（親の stroke 色を考慮）
fn element_to_svg_string_with_parent(
  el : @model.Element,
  parent_stroke : String?,
) -> String {
  let style = el.style
  let fill = style.fill.unwrap_or("none")
  let stroke = style.stroke.unwrap_or("#000000")
  let stroke_width = style.stroke_width.unwrap_or(1.0)
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rx_attr = match rx {
        Some(v) => " rx=\"\{num_to_str(v)}\""
        None => ""
      }
      let ry_attr = match ry {
        Some(v) => " ry=\"\{num_to_str(v)}\""
        None => ""
      }
      "<rect x=\"\{num_to_str(el.x)}\" y=\"\{num_to_str(el.y)}\" width=\"\{num_to_str(w)}\" height=\"\{num_to_str(h)}\"\{rx_attr}\{ry_attr} fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{num_to_str(el.x)}\" cy=\"\{num_to_str(el.y)}\" r=\"\{num_to_str(r)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{num_to_str(el.x)}\" cy=\"\{num_to_str(el.y)}\" rx=\"\{num_to_str(rx)}\" ry=\"\{num_to_str(ry)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    @model.Line(x2, y2) =>
      "<line x1=\"\{num_to_str(el.x)}\" y1=\"\{num_to_str(el.y)}\" x2=\"\{num_to_str(x2)}\" y2=\"\{num_to_str(y2)}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    @model.Text(content, font_size) => {
      let fs = font_size.unwrap_or(16.0)
      // 親要素がある場合、テキスト色は親の stroke に揃える（Excalidraw 仕様）
      let text_fill = match parent_stroke {
        Some(s) => s
        None => fill
      }
      "<text x=\"\{num_to_str(el.x)}\" y=\"\{num_to_str(el.y)}\" fill=\"\{text_fill}\" font-size=\"\{num_to_str(fs)}\" text-anchor=\"middle\" dominant-baseline=\"middle\">\{content}</text>"
    }
    @model.Polyline(points) => {
      let points_str = points
        .map(fn(p) { "\{num_to_str(p.x)},\{num_to_str(p.y)}" })
        .join(" ")
      "<polyline points=\"\{points_str}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
    }
    @model.Path(d) =>
      "<path d=\"\{d}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{num_to_str(stroke_width)}\"/>"
  }
}

// =============================================================================
// プレビュー線描画（アンカードラッグ時）
// =============================================================================

///|
/// プレビュー線を描画
pub extern "js" fn draw_preview_line(
  svg : @js.Any,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) =
  #| (svg, x1, y1, x2, y2) => {
  #|   const existing = svg.querySelector('.preview-line');
  #|   if (existing) existing.remove();
  #|   const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
  #|   line.setAttribute('class', 'preview-line');
  #|   line.setAttribute('x1', x1);
  #|   line.setAttribute('y1', y1);
  #|   line.setAttribute('x2', x2);
  #|   line.setAttribute('y2', y2);
  #|   line.setAttribute('stroke', '#0066ff');
  #|   line.setAttribute('stroke-width', '2');
  #|   line.setAttribute('stroke-dasharray', '4,2');
  #|   line.setAttribute('pointer-events', 'none');
  #|   svg.appendChild(line);
  #| }

///|
/// プレビュー線を削除
pub extern "js" fn remove_preview_line(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelector('.preview-line');
  #|   if (existing) existing.remove();
  #| }

///|
/// 選択枠を削除
pub extern "js" fn remove_selection_rect(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelector('.selection-rect');
  #|   if (existing) existing.remove();
  #| }

///|
/// アンカーポイントを削除
pub extern "js" fn remove_anchor_points(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelectorAll('.anchor-point');
  #|   existing.forEach(el => el.remove());
  #| }

///|
/// リサイズハンドルを削除
pub extern "js" fn remove_resize_handles(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelectorAll('.resize-handle, .line-handle');
  #|   existing.forEach(el => el.remove());
  #| }
