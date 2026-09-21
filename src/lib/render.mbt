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
/// 要素を SVG DOM 要素として描画（親のストローク色を考慮）
/// parent_stroke: 親要素のストローク色（テキスト要素の場合に使用）
pub fn render_element_to_svg_with_parent(
  el : @model.Element,
  is_selected : Bool,
  parent_stroke : String?,
) -> @js.Any {
  let style = el.style
  let fill = style.fill.unwrap_or("none")
  let stroke = style.stroke.unwrap_or("#000000")
  let stroke_width = style.stroke_width.unwrap_or(1.0)
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rect = create_svg_element_ns("rect")
      set_svg_attr(rect, "x", @model.num_str(el.x))
      set_svg_attr(rect, "y", @model.num_str(el.y))
      set_svg_attr(rect, "width", @model.num_str(w))
      set_svg_attr(rect, "height", @model.num_str(h))
      if rx is Some(v) {
        set_svg_attr(rect, "rx", @model.num_str(v))
      }
      if ry is Some(v) {
        set_svg_attr(rect, "ry", @model.num_str(v))
      }
      set_svg_attr(rect, "fill", fill)
      set_svg_attr(rect, "stroke", stroke)
      set_svg_attr(rect, "stroke-width", @model.num_str(stroke_width))
      set_svg_attr(rect, "data-id", el.id)
      set_svg_attr(rect, "cursor", "move")
      rect
    }
    @model.Circle(r) => {
      let circle = create_svg_element_ns("circle")
      set_svg_attr(circle, "cx", @model.num_str(el.x))
      set_svg_attr(circle, "cy", @model.num_str(el.y))
      set_svg_attr(circle, "r", @model.num_str(r))
      set_svg_attr(circle, "fill", fill)
      set_svg_attr(circle, "stroke", stroke)
      set_svg_attr(circle, "stroke-width", @model.num_str(stroke_width))
      set_svg_attr(circle, "data-id", el.id)
      set_svg_attr(circle, "cursor", "move")
      circle
    }
    @model.Ellipse(rx, ry) => {
      let ellipse = create_svg_element_ns("ellipse")
      set_svg_attr(ellipse, "cx", @model.num_str(el.x))
      set_svg_attr(ellipse, "cy", @model.num_str(el.y))
      set_svg_attr(ellipse, "rx", @model.num_str(rx))
      set_svg_attr(ellipse, "ry", @model.num_str(ry))
      set_svg_attr(ellipse, "fill", fill)
      set_svg_attr(ellipse, "stroke", stroke)
      set_svg_attr(ellipse, "stroke-width", @model.num_str(stroke_width))
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
      set_svg_attr(hit_area, "x1", @model.num_str(el.x))
      set_svg_attr(hit_area, "y1", @model.num_str(el.y))
      set_svg_attr(hit_area, "x2", @model.num_str(x2))
      set_svg_attr(hit_area, "y2", @model.num_str(y2))
      set_svg_attr(hit_area, "stroke", "transparent")
      set_svg_attr(hit_area, "stroke-width", "24")
      append_child(group, hit_area)
      // 選択時はハイライト線を追加
      if is_selected {
        let highlight = create_svg_element_ns("line")
        set_svg_attr(highlight, "x1", @model.num_str(el.x))
        set_svg_attr(highlight, "y1", @model.num_str(el.y))
        set_svg_attr(highlight, "x2", @model.num_str(x2))
        set_svg_attr(highlight, "y2", @model.num_str(y2))
        set_svg_attr(highlight, "stroke", "rgba(0, 102, 255, 0.3)")
        set_svg_attr(
          highlight,
          "stroke-width",
          @model.num_str(stroke_width + 6.0),
        )
        set_svg_attr(highlight, "stroke-linecap", "round")
        set_svg_attr(highlight, "pointer-events", "none")
        append_child(group, highlight)
      }
      // 実際の線
      let line = create_svg_element_ns("line")
      set_svg_attr(line, "x1", @model.num_str(el.x))
      set_svg_attr(line, "y1", @model.num_str(el.y))
      set_svg_attr(line, "x2", @model.num_str(x2))
      set_svg_attr(line, "y2", @model.num_str(y2))
      set_svg_attr(line, "stroke", stroke)
      set_svg_attr(line, "stroke-width", @model.num_str(stroke_width))
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
      set_svg_attr(text, "x", @model.num_str(el.x))
      set_svg_attr(text, "y", @model.num_str(el.y))
      // 親要素がある場合、テキスト色は親の stroke に揃える（Excalidraw 仕様）
      let text_fill = @model.get_text_fill_color(el.style, parent_stroke)
      set_svg_attr(text, "fill", text_fill)
      set_svg_attr(text, "font-size", @model.num_str(font_size.unwrap_or(16.0)))
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
        .map(fn(p) { "\{@model.num_str(p.x)},\{@model.num_str(p.y)}" })
        .join(" ")
      set_svg_attr(polyline, "points", points_str)
      set_svg_attr(polyline, "fill", fill)
      set_svg_attr(polyline, "stroke", stroke)
      set_svg_attr(polyline, "stroke-width", @model.num_str(stroke_width))
      set_svg_attr(polyline, "data-id", el.id)
      set_svg_attr(polyline, "cursor", "move")
      polyline
    }
    @model.Path(d, _, _, _, _) => {
      let path = create_svg_element_ns("path")
      set_svg_attr(path, "d", d)
      set_svg_attr(path, "fill", fill)
      set_svg_attr(path, "stroke", stroke)
      set_svg_attr(path, "stroke-width", @model.num_str(stroke_width))
      set_svg_attr(path, "data-id", el.id)
      set_svg_attr(path, "cursor", "move")
      path
    }
  }
}

// =============================================================================
// 選択枠・アンカーポイント描画
// =============================================================================

// =============================================================================
// 要素の境界計算
// =============================================================================

// =============================================================================
// アンカーポイント位置計算
// =============================================================================

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
        Some(v) => " rx=\"\{@model.num_str(v)}\""
        None => ""
      }
      let ry_attr = match ry {
        Some(v) => " ry=\"\{@model.num_str(v)}\""
        None => ""
      }
      "<rect x=\"\{@model.num_str(el.x)}\" y=\"\{@model.num_str(el.y)}\" width=\"\{@model.num_str(w)}\" height=\"\{@model.num_str(h)}\"\{rx_attr}\{ry_attr} fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{@model.num_str(el.x)}\" cy=\"\{@model.num_str(el.y)}\" r=\"\{@model.num_str(r)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{@model.num_str(el.x)}\" cy=\"\{@model.num_str(el.y)}\" rx=\"\{@model.num_str(rx)}\" ry=\"\{@model.num_str(ry)}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"/>"
    @model.Line(x2, y2) =>
      "<line x1=\"\{@model.num_str(el.x)}\" y1=\"\{@model.num_str(el.y)}\" x2=\"\{@model.num_str(x2)}\" y2=\"\{@model.num_str(y2)}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"/>"
    @model.Text(content, font_size) => {
      let fs = font_size.unwrap_or(16.0)
      "<text x=\"\{@model.num_str(el.x)}\" y=\"\{@model.num_str(el.y)}\" fill=\"\{fill}\" font-size=\"\{@model.num_str(fs)}\">\{content}</text>"
    }
    @model.Polyline(points) => {
      let points_str = points
        .map(fn(p) { "\{@model.num_str(p.x)},\{@model.num_str(p.y)}" })
        .join(" ")
      "<polyline points=\"\{points_str}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"/>"
    }
    @model.Path(d, _, _, _, _) =>
      "<path d=\"\{d}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{@model.num_str(stroke_width)}\"/>"
  }
}

// =============================================================================
// プレビュー線描画（アンカードラッグ時）
// =============================================================================

///|
/// フリードロープレビューを描画
pub fn draw_free_draw_preview(
  svg : @js.Any,
  points : Array[@model.Point],
) -> Unit {
  if points.length() < 2 {
    remove_free_draw_preview(svg)
    return
  }
  let points_str = points.map(fn(p) { "\{p.x},\{p.y}" }).join(" ")
  draw_free_draw_preview_ffi(svg, points_str)
}

///|
extern "js" fn draw_free_draw_preview_ffi(svg : @js.Any, points_str : String) =
  #| (svg, pointsStr) => {
  #|   let existing = svg.querySelector('.free-draw-preview');
  #|   if (!existing) {
  #|     existing = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
  #|     existing.setAttribute('class', 'free-draw-preview');
  #|     existing.setAttribute('fill', 'none');
  #|     existing.setAttribute('stroke', '#888');
  #|     existing.setAttribute('stroke-width', '1');
  #|     existing.setAttribute('stroke-linecap', 'round');
  #|     existing.setAttribute('stroke-linejoin', 'round');
  #|     existing.setAttribute('stroke-dasharray', '4 2');
  #|     existing.setAttribute('opacity', '0.6');
  #|     existing.setAttribute('pointer-events', 'none');
  #|     svg.appendChild(existing);
  #|   }
  #|   existing.setAttribute('points', pointsStr);
  #| }

///|
/// フリードロープレビューを削除
pub extern "js" fn remove_free_draw_preview(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelector('.free-draw-preview');
  #|   if (existing) existing.remove();
  #| }
