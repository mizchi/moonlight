// SVG Rendering - @model.Element → DomNode への変換
// Luna の create_element_ns を使用

///|
/// XML エスケープ
fn escape_xml(s : String) -> String {
  s
    .replace(old="&", new="&amp;")
    .replace(old="<", new="&lt;")
    .replace(old=">", new="&gt;")
    .replace(old="\"", new="&quot;")
}

///|
/// SVG 要素に属性を設定（FFI）- 動的更新用
extern "js" fn set_svg_attr_ffi(el : @js.Any, name : String, value : String) =
  #| (el, name, value) => el.setAttribute(name, value)

///|
/// SVG 要素にイベントリスナーを追加（FFI）- 動的イベント用
extern "js" fn add_event_listener_ffi(
  el : @js.Any,
  event : String,
  handler : (@js.Any) -> Unit,
) =
  #| (el, event, handler) => el.addEventListener(event, handler)

///|
/// SVG 要素に子要素を追加（FFI）
extern "js" fn append_child_ffi(parent : @js.Any, child : @js.Any) =
  #| (parent, child) => parent.appendChild(child)

///|
/// SVG 要素を作成（Luna の create_element_ns を使用）
fn create_svg_element(
  tag : String,
  attrs : Array[(String, String)],
  handlers : Array[(String, (@js.Any) -> Unit)],
) -> @js.Any {
  // 属性を AttrValue に変換
  let luna_attrs : Array[(String, @element.AttrValue)] = []
  for attr in attrs {
    luna_attrs.push((attr.0, @element.Static(attr.1)))
  }
  // ハンドラを追加
  for handler in handlers {
    luna_attrs.push((handler.0, @element.Handler(handler.1)))
  }
  // Luna の create_element_ns で作成し、@js.Any に変換
  let node = @element.create_element_ns(@element.svg_ns, tag, luna_attrs, [])
  node.to_dom().as_any()
}

///|
/// 数値を文字列に変換
fn num_str(value : Double) -> String {
  value.to_string()
}

///|
/// スタイル属性を配列に追加
fn add_style_attrs(attrs : Array[(String, String)], style : @model.Style) -> Unit {
  if style.fill is Some(v) {
    attrs.push(("fill", v))
  } else {
    attrs.push(("fill", "none"))
  }
  if style.stroke is Some(v) {
    attrs.push(("stroke", v))
  }
  if style.stroke_width is Some(v) {
    attrs.push(("stroke-width", num_str(v)))
  }
  if style.opacity is Some(v) {
    attrs.push(("opacity", num_str(v)))
  }
  if style.stroke_dasharray is Some(v) {
    attrs.push(("stroke-dasharray", v))
  }
}

///|
/// 矢印マーカー属性を追加（Line 用）
fn add_marker_attrs(attrs : Array[(String, String)], style : @model.Style, stroke_color : String) -> Unit {
  // 色に基づいたマーカー ID を使用
  let color_suffix = stroke_color.replace(old="#", new="")
  if style.marker_start is Some(@model.Arrow) {
    attrs.push(("marker-start", "url(#arrow-start-\{color_suffix})"))
  }
  if style.marker_end is Some(@model.Arrow) {
    attrs.push(("marker-end", "url(#arrow-end-\{color_suffix})"))
  }
}

///|
/// 要素を SVG ノードに変換
/// parent: テキスト子要素の場合、親要素を渡すと中央に配置
pub fn render_element(
  el : @model.Element,
  is_selected : Bool,
  parent~ : @model.Element? = None,
) -> @js.Any {
  let attrs : Array[(String, String)] = []
  // data-id 属性（イベント処理用）
  attrs.push(("data-id", el.id))
  let style = el.style
  let _ = is_selected // Line以外では未使用（Lineは別途ハイライト処理）
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      attrs.push(("x", num_str(el.x)))
      attrs.push(("y", num_str(el.y)))
      attrs.push(("width", num_str(w)))
      attrs.push(("height", num_str(h)))
      if rx is Some(v) {
        attrs.push(("rx", num_str(v)))
      }
      if ry is Some(v) {
        attrs.push(("ry", num_str(v)))
      }
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_element("rect", attrs, [])
    }
    @model.Circle(r) => {
      attrs.push(("cx", num_str(el.x)))
      attrs.push(("cy", num_str(el.y)))
      attrs.push(("r", num_str(r)))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_element("circle", attrs, [])
    }
    @model.Ellipse(rx, ry) => {
      attrs.push(("cx", num_str(el.x)))
      attrs.push(("cy", num_str(el.y)))
      attrs.push(("rx", num_str(rx)))
      attrs.push(("ry", num_str(ry)))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_element("ellipse", attrs, [])
    }
    @model.Line(x2, y2) => {
      // グループ要素でラップ（ヒットエリア + 線）
      let group = create_svg_element(
        "g",
        [("data-id", el.id), ("data-element-type", "line"), ("cursor", "move")],
        [],
      )
      // 透明なヒットエリア（クリックしやすくするため、24px幅）
      let hit_attrs : Array[(String, String)] = [
        ("data-id", el.id),
        ("x1", num_str(el.x)),
        ("y1", num_str(el.y)),
        ("x2", num_str(x2)),
        ("y2", num_str(y2)),
        ("stroke", "transparent"),
        ("stroke-width", "24"),
      ]
      let hit_area = create_svg_element("line", hit_attrs, [])
      append_child_ffi(group, hit_area)
      // 選択時はハイライト用の線を追加（矢印サイズに影響しないよう別の線として描画）
      if is_selected {
        let highlight_attrs : Array[(String, String)] = [
          ("x1", num_str(el.x)),
          ("y1", num_str(el.y)),
          ("x2", num_str(x2)),
          ("y2", num_str(y2)),
          ("stroke", "rgba(0, 102, 255, 0.3)"),
          ("stroke-width", num_str(el.style.stroke_width.unwrap_or(1.0) + 6.0)),
          ("stroke-linecap", "round"),
          ("pointer-events", "none"),
        ]
        let highlight_el = create_svg_element("line", highlight_attrs, [])
        append_child_ffi(group, highlight_el)
      }
      // 実際の線（元のスタイルをそのまま使用、矢印サイズが変わらないように）
      let line_attrs : Array[(String, String)] = [
        ("x1", num_str(el.x)),
        ("y1", num_str(el.y)),
        ("x2", num_str(x2)),
        ("y2", num_str(y2)),
        ("pointer-events", "none"),
      ]
      add_style_attrs(line_attrs, el.style)
      // 矢印マーカーを追加
      let stroke_color = el.style.stroke.unwrap_or("#000000")
      add_marker_attrs(line_attrs, el.style, stroke_color)
      if el.transform is Some(t) {
        line_attrs.push(("transform", t))
      }
      let line_el = create_svg_element("line", line_attrs, [])
      append_child_ffi(group, line_el)
      group
    }
    @model.Polyline(points) => {
      let points_str = points.map(fn(p) { "\{p.x},\{p.y}" }).join(" ")
      attrs.push(("points", points_str))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_element("polyline", attrs, [])
    }
    @model.Path(d) => {
      attrs.push(("d", d))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_element("path", attrs, [])
    }
    @model.Text(content, font_size) => {
      let size = font_size.unwrap_or(16.0)
      // 親要素がある場合は親の中央に配置
      let (text_x, text_y) = match parent {
        Some(p) => {
          let bbox = p.bounding_box()
          (bbox.x + bbox.width / 2.0, bbox.y + bbox.height / 2.0)
        }
        None => (el.x, el.y)
      }
      // グループ要素でラップ（ヒットエリア + テキスト）
      let group = create_svg_element(
        "g",
        [("data-id", el.id), ("data-element-type", "text"), ("cursor", "move")],
        [],
      )
      // ヒットエリアのサイズを計算（単一行の場合は split を省略）
      let (hit_width, hit_height) = if content.contains("\n") {
        let lines : Array[String] = content
          .split("\n")
          .map(fn(sv) { sv.to_string() })
          .collect()
        let line_count = lines.length()
        let line_height = size * 1.2
        let total_height = line_count.to_double() * line_height
        let max_line_len = lines.fold(init=0, fn(acc, line) {
          let len = line.iter().count()
          if len > acc { len } else { acc }
        })
        let estimated_width = max_line_len.to_double() * size * 0.6
        let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
        let h = if total_height < 24.0 { 24.0 } else { total_height }
        (w, h)
      } else {
        // 単一行: 文字数から幅を推定
        let char_count = content.iter().count()
        let estimated_width = char_count.to_double() * size * 0.6
        let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
        (w, size * 1.2)
      }
      // 透明なヒットエリア
      let hit_attrs : Array[(String, String)] = [
        ("data-id", el.id),
        ("x", num_str(text_x - hit_width / 2.0)),
        ("y", num_str(text_y - hit_height / 2.0)),
        ("width", num_str(hit_width)),
        ("height", num_str(hit_height)),
        ("fill", "transparent"),
      ]
      let hit_area = create_svg_element("rect", hit_attrs, [])
      append_child_ffi(group, hit_area)
      // テキスト要素
      attrs.push(("x", num_str(text_x)))
      attrs.push(("y", num_str(text_y)))
      attrs.push(("font-size", num_str(size)))
      attrs.push(("text-anchor", "middle"))
      attrs.push(("dominant-baseline", "middle"))
      attrs.push(("pointer-events", "none"))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      let text_el = create_svg_element("text", attrs, [])
      set_multiline_text_ffi(text_el, content, text_x, size)
      append_child_ffi(group, text_el)
      group
    }
  }
}

///|
/// SVG コンテナを作成（イベントハンドラ付き）
pub fn render_svg_container(
  width : Int,
  height : Int,
  on_mousedown : (@js.Any) -> Unit,
  on_mousemove : (@js.Any) -> Unit,
  on_mouseup : (@js.Any) -> Unit,
  on_contextmenu : (@js.Any) -> Unit,
  children : Array[@js.Any],
) -> @js.Any {
  render_svg_container_with_viewport(
    width,
    height,
    @model.Viewport::default(),
    on_mousedown,
    on_mousemove,
    on_mouseup,
    on_contextmenu,
    fn(_) {  },
    children,
  )
}

///|
/// 矢印マーカーを作成（シンプルな三角形）
fn create_arrow_marker(id : String, color : String, is_start : Bool) -> @js.Any {
  // 矢印マーカー（stroke-width: 1 でも見やすいサイズ）
  let marker_attrs : Array[(String, String)] = [
    ("id", id),
    ("markerWidth", "10"),
    ("markerHeight", "10"),
    ("refX", if is_start { "0" } else { "10" }),
    ("refY", "5"),
    ("orient", "auto"),
    ("markerUnits", "strokeWidth"),
  ]
  let marker = create_svg_element("marker", marker_attrs, [])
  // シンプルな三角形パス
  let path_d = if is_start { "M10,0 L0,5 L10,10" } else { "M0,0 L10,5 L0,10" }
  let path_attrs : Array[(String, String)] = [
    ("d", path_d),
    ("fill", color),
  ]
  let path = create_svg_element("path", path_attrs, [])
  append_child_ffi(marker, path)
  marker
}

///|
/// SVG 定義（マーカー）を作成
pub fn create_arrow_defs() -> @js.Any {
  let defs = create_svg_element("defs", [], [])
  // よく使う色のマーカーを事前定義
  let colors = [
    "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff",
    "#ffff00", "#ff00ff", "#00ffff", "#808080", "#c0c0c0",
  ]
  for color in colors {
    let suffix = color.replace(old="#", new="")
    let start_marker = create_arrow_marker("arrow-start-\{suffix}", color, true)
    let end_marker = create_arrow_marker("arrow-end-\{suffix}", color, false)
    append_child_ffi(defs, start_marker)
    append_child_ffi(defs, end_marker)
  }
  defs
}

///|
/// SVG コンテナを作成（ビューポート対応）
pub fn render_svg_container_with_viewport(
  width : Int,
  height : Int,
  viewport : @model.Viewport,
  on_mousedown : (@js.Any) -> Unit,
  on_mousemove : (@js.Any) -> Unit,
  on_mouseup : (@js.Any) -> Unit,
  on_contextmenu : (@js.Any) -> Unit,
  on_wheel : (@js.Any) -> Unit,
  children : Array[@js.Any],
) -> @js.Any {
  // viewBox をビューポートに基づいて計算
  let vb_width = width.to_double() / viewport.zoom
  let vb_height = height.to_double() / viewport.zoom
  let vb_x = viewport.scroll_x
  let vb_y = viewport.scroll_y
  let attrs : Array[(String, String)] = [
    ("width", width.to_string()),
    ("height", height.to_string()),
    ("viewBox", "\{vb_x} \{vb_y} \{vb_width} \{vb_height}"),
    ("style", "border: 1px solid #ccc; background: #fafafa; user-select: none; --ml-stroke: #000000; --ml-fill: transparent; --ml-text: #000000;"),
  ]
  let handlers : Array[(String, (@js.Any) -> Unit)] = [
    ("mousedown", on_mousedown),
    ("mousemove", on_mousemove),
    ("mouseup", on_mouseup),
    ("contextmenu", on_contextmenu),
    ("wheel", on_wheel),
  ]
  let svg = create_svg_element("svg", attrs, handlers)
  // 矢印マーカーの defs を追加
  let defs = create_arrow_defs()
  append_child_ffi(svg, defs)
  for child in children {
    append_child_ffi(svg, child)
  }
  svg
}

///|
/// SVG を DomNode にラップ
pub fn svg_to_dom_node(svg : @js.Any) -> @element.DomNode {
  let node : @js_dom.Node = svg.cast()
  @element.dom_node(node)
}

///|
/// 要素を SVG 文字列に変換（エクスポート用）
pub fn element_to_svg_string(el : @model.Element) -> String {
  let style = el.style
  let style_attrs = StringBuilder::new()
  if style.fill is Some(v) {
    style_attrs.write_string(" fill=\"\{v}\"")
  } else {
    style_attrs.write_string(" fill=\"none\"")
  }
  if style.stroke is Some(v) {
    style_attrs.write_string(" stroke=\"\{v}\"")
  }
  if style.stroke_width is Some(v) {
    style_attrs.write_string(" stroke-width=\"\{v}\"")
  }
  if style.opacity is Some(v) {
    style_attrs.write_string(" opacity=\"\{v}\"")
  }
  let style_str = style_attrs.to_string()
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rx_attr = if rx is Some(v) { " rx=\"\{v}\"" } else { "" }
      let ry_attr = if ry is Some(v) { " ry=\"\{v}\"" } else { "" }
      "<rect x=\"\{el.x}\" y=\"\{el.y}\" width=\"\{w}\" height=\"\{h}\"\{rx_attr}\{ry_attr}\{style_str}/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{el.x}\" cy=\"\{el.y}\" r=\"\{r}\"\{style_str}/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{el.x}\" cy=\"\{el.y}\" rx=\"\{rx}\" ry=\"\{ry}\"\{style_str}/>"
    @model.Line(x2, y2) =>
      "<line x1=\"\{el.x}\" y1=\"\{el.y}\" x2=\"\{x2}\" y2=\"\{y2}\"\{style_str}/>"
    @model.Polyline(points) => {
      let points_str = points.map(fn(p) { "\{p.x},\{p.y}" }).join(" ")
      "<polyline points=\"\{points_str}\"\{style_str}/>"
    }
    @model.Path(d) => "<path d=\"\{d}\"\{style_str}/>"
    @model.Text(content, font_size) => {
      let size = font_size.unwrap_or(16.0)
      let fs_attr = " font-size=\"\{size}\""
      if content.contains("\n") {
        // 複数行テキストは tspan で出力
        let lines : Array[String] = content.split("\n").map(fn(sv) { sv.to_string() }).collect()
        let line_height = size * 1.2
        let total_height = (lines.length() - 1).to_double() * line_height
        let start_offset = -total_height / 2.0
        let tspans : Array[String] = []
        for i, line in lines {
          let dy = if i == 0 { start_offset } else { line_height }
          let escaped = escape_xml(line)
          let x_val = el.x
          tspans.push(
            "<tspan x=\"\{x_val}\" dy=\"\{dy}\">\{escaped}</tspan>",
          )
        }
        let tspan_str = tspans.join("")
        "<text x=\"\{el.x}\" y=\"\{el.y}\"\{fs_attr}\{style_str}>\{tspan_str}</text>"
      } else {
        let escaped = escape_xml(content)
        "<text x=\"\{el.x}\" y=\"\{el.y}\"\{fs_attr}\{style_str}>\{escaped}</text>"
      }
    }
  }
}

///|
/// 全要素を SVG 文字列に変換
pub fn elements_to_svg(
  elements : Array[@model.Element],
  width : Int,
  height : Int,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}\" height=\"\{height}\" viewBox=\"0 0 \{width} \{height}\">\n",
  )
  for el in elements {
    sb.write_string("  ")
    sb.write_string(element_to_svg_string(el))
    sb.write_string("\n")
  }
  sb.write_string("</svg>")
  sb.to_string()
}

///|
/// グリッド線を描画
pub fn render_grid(
  width : Int,
  height : Int,
  grid_size : Int,
  viewport : @model.Viewport,
) -> Array[@js.Any] {
  let lines : Array[@js.Any] = []
  let size = grid_size.to_double()
  // viewBox の範囲を計算
  let vb_width = width.to_double() / viewport.zoom
  let vb_height = height.to_double() / viewport.zoom
  let start_x = viewport.scroll_x
  let start_y = viewport.scroll_y
  let end_x = start_x + vb_width
  let end_y = start_y + vb_height
  // グリッドの開始位置を計算（グリッドにスナップ）
  let grid_start_x = (start_x / size).floor() * size
  let grid_start_y = (start_y / size).floor() * size
  // 縦線
  let mut x = grid_start_x
  while x <= end_x {
    let attrs : Array[(String, String)] = [
      ("x1", x.to_string()),
      ("y1", start_y.to_string()),
      ("x2", x.to_string()),
      ("y2", end_y.to_string()),
      ("stroke", "#e0e0e0"),
      ("stroke-width", "0.5"),
    ]
    lines.push(create_svg_element("line", attrs, []))
    x = x + size
  }
  // 横線
  let mut y = grid_start_y
  while y <= end_y {
    let attrs : Array[(String, String)] = [
      ("x1", start_x.to_string()),
      ("y1", y.to_string()),
      ("x2", end_x.to_string()),
      ("y2", y.to_string()),
      ("stroke", "#e0e0e0"),
      ("stroke-width", "0.5"),
    ]
    lines.push(create_svg_element("line", attrs, []))
    y = y + size
  }
  lines
}

///|
/// リサイズハンドルのサイズ
let handle_size : Double = 8.0

///|
/// リサイズハンドルを描画
pub fn render_resize_handles(el : @model.Element) -> Array[@js.Any] {
  let half = handle_size / 2.0
  let handles : Array[@js.Any] = []
  // Line の場合は始点と終点にハンドルを表示
  match el.shape {
    @model.Line(x2, y2) => {
      let positions = [
        ("line-start", el.x, el.y, "move"),
        ("line-end", x2, y2, "move"),
      ]
      let hit_radius = 12.0 // ヒットエリア（大きめ）
      let visible_radius = 5.0 // 通常表示サイズ
      let hover_radius = 10.0 // ホバー時サイズ
      for pos in positions {
        let (handle_id, cx, cy, cursor) = pos
        // グループ要素を作成
        let group = create_svg_element("g", [("class", "line-handle-group")], [])
        // 透明なヒットエリア（大きめ）
        let hit_area_attrs : Array[(String, String)] = [
          ("cx", num_str(cx)),
          ("cy", num_str(cy)),
          ("r", num_str(hit_radius)),
          ("fill", "transparent"),
          ("cursor", cursor),
          ("data-handle", handle_id),
          ("data-element-id", el.id),
        ]
        let hit_area = create_svg_element("circle", hit_area_attrs, [])
        // 可視のハンドル（CSSでホバー効果）
        let visible_attrs : Array[(String, String)] = [
          ("cx", num_str(cx)),
          ("cy", num_str(cy)),
          ("r", num_str(visible_radius)),
          ("fill", "#0066ff"),
          ("stroke", "#ffffff"),
          ("stroke-width", "2"),
          ("pointer-events", "none"),
          ("class", "line-handle-visible"),
          ("style", "transition: r 0.15s ease, fill 0.15s ease;"),
        ]
        let visible_circle = create_svg_element("circle", visible_attrs, [])
        // ホバー時に可視ハンドルを拡大するイベント
        add_event_listener_ffi(hit_area, "mouseenter", fn(_e) {
          set_svg_attr_ffi(visible_circle, "r", num_str(hover_radius))
          set_svg_attr_ffi(visible_circle, "fill", "#0088ff")
        })
        add_event_listener_ffi(hit_area, "mouseleave", fn(_e) {
          set_svg_attr_ffi(visible_circle, "r", num_str(visible_radius))
          set_svg_attr_ffi(visible_circle, "fill", "#0066ff")
        })
        append_child_ffi(group, hit_area)
        append_child_ffi(group, visible_circle)
        handles.push(group)
      }
    }
    _ => {
      // その他の形状は四隅のハンドル
      let bbox = el.bounding_box()
      let positions = [
        ("nw", bbox.x - half, bbox.y - half, "nwse-resize"),
        ("ne", bbox.x + bbox.width - half, bbox.y - half, "nesw-resize"),
        ("sw", bbox.x - half, bbox.y + bbox.height - half, "nesw-resize"),
        ("se", bbox.x + bbox.width - half, bbox.y + bbox.height - half, "nwse-resize"),
      ]
      for pos in positions {
        let (handle_id, hx, hy, cursor) = pos
        let attrs : Array[(String, String)] = [
          ("data-handle", handle_id),
          ("data-element-id", el.id),
          ("x", num_str(hx)),
          ("y", num_str(hy)),
          ("width", num_str(handle_size)),
          ("height", num_str(handle_size)),
          ("fill", "#0066ff"),
          ("stroke", "#ffffff"),
          ("stroke-width", "1"),
          ("cursor", cursor),
        ]
        handles.push(create_svg_element("rect", attrs, []))
      }
    }
  }
  handles
}

///|
/// 矩形選択ボックスを描画
pub fn render_selection_box(box_state : @model.BoxSelectState) -> @js.Any {
  let bbox = box_state.to_bbox()
  let attrs : Array[(String, String)] = [
    ("x", num_str(bbox.x)),
    ("y", num_str(bbox.y)),
    ("width", num_str(bbox.width)),
    ("height", num_str(bbox.height)),
    ("fill", "rgba(0, 102, 255, 0.1)"),
    ("stroke", "#0066ff"),
    ("stroke-width", "1"),
    ("stroke-dasharray", "4,2"),
    ("pointer-events", "none"),
  ]
  create_svg_element("rect", attrs, [])
}

///|
/// 接続ポイントのハイライトを描画（スナップ先）
pub fn render_connection_highlight(point : @model.Point) -> @js.Any {
  // 接続ポイントを強調表示する円
  let attrs : Array[(String, String)] = [
    ("cx", num_str(point.x)),
    ("cy", num_str(point.y)),
    ("r", "10"),
    ("fill", "rgba(0, 200, 100, 0.4)"),
    ("stroke", "#00c864"),
    ("stroke-width", "2"),
    ("pointer-events", "none"),
  ]
  create_svg_element("circle", attrs, [])
}

///|
/// 選択中の図形のアンカーポイントを描画（ドラッグでライン生成用）
pub fn render_element_anchors(el : @model.Element) -> Array[@js.Any] {
  let result : Array[@js.Any] = []
  // Line にはアンカーを表示しない
  if el.shape is @model.Line(_, _) {
    return result
  }
  // 全アンカーポイントを描画（中心と四隅以外）
  for anchor_data in el.get_all_anchors() {
    let (anchor, point) = anchor_data
    // 中心点はスキップ（ドラッグやダブルクリックと干渉するため）
    // 四隅はリサイズハンドルと重なるためスキップ
    if anchor == @model.Center ||
       anchor == @model.TopLeft ||
       anchor == @model.TopRight ||
       anchor == @model.BottomLeft ||
       anchor == @model.BottomRight {
      continue
    }
    let anchor_name = match anchor {
      @model.Center => "center"
      @model.Top => "top"
      @model.Bottom => "bottom"
      @model.Left => "left"
      @model.Right => "right"
      @model.TopLeft => "top-left"
      @model.TopRight => "top-right"
      @model.BottomLeft => "bottom-left"
      @model.BottomRight => "bottom-right"
    }
    let attrs : Array[(String, String)] = [
      ("cx", num_str(point.x)),
      ("cy", num_str(point.y)),
      ("r", "6"),
      ("fill", "rgba(100, 100, 255, 0.3)"),
      ("stroke", "#6666ff"),
      ("stroke-width", "1.5"),
      ("cursor", "crosshair"),
      ("data-anchor", anchor_name),
      ("data-element-id", el.id),
    ]
    result.push(create_svg_element("circle", attrs, []))
  }
  result
}

///|
/// 全てのアンカーポイントを描画（ドラッグ中の可視化用）
pub fn render_all_anchor_points(elements : Array[@model.Element], exclude_id : String) -> Array[@js.Any] {
  let result : Array[@js.Any] = []
  for el in elements {
    // 除外する要素はスキップ
    if el.id == exclude_id {
      continue
    }
    // Line 要素はスキップ（Line には接続しない）
    if el.shape is @model.Line(_, _) {
      continue
    }
    // 子要素はスキップ
    if el.parent_id is Some(_) {
      continue
    }
    // 全アンカーポイントを描画
    for anchor_data in el.get_all_anchors() {
      let (_, point) = anchor_data
      let attrs : Array[(String, String)] = [
        ("cx", num_str(point.x)),
        ("cy", num_str(point.y)),
        ("r", "4"),
        ("fill", "rgba(0, 102, 255, 0.3)"),
        ("stroke", "#0066ff"),
        ("stroke-width", "1"),
        ("pointer-events", "none"),
      ]
      result.push(create_svg_element("circle", attrs, []))
    }
  }
  result
}

// =============================================================================
// Luna VNode ベースのレンダリング（差分更新対応）
// =============================================================================

///|
/// SVG ノードを作成（Luna の create_element_ns を使用、DomNode を返す）
fn create_svg_node(
  tag : String,
  attrs : Array[(String, String)],
  handlers : Array[(String, (@js.Any) -> Unit)],
  children : Array[@element.DomNode],
) -> @element.DomNode {
  let luna_attrs : Array[(String, @element.AttrValue)] = []
  for attr in attrs {
    luna_attrs.push((attr.0, @element.Static(attr.1)))
  }
  for handler in handlers {
    luna_attrs.push((handler.0, @element.Handler(handler.1)))
  }
  @element.create_element_ns(@element.svg_ns, tag, luna_attrs, children)
}

///|
/// 要素を DomNode に変換（Luna VNode ベース）
pub fn render_element_node(
  el : @model.Element,
  is_selected : Bool,
  parent~ : @model.Element? = None,
) -> @element.DomNode {
  let attrs : Array[(String, String)] = []
  attrs.push(("data-id", el.id))
  let style = el.style
  let _ = is_selected
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      attrs.push(("x", num_str(el.x)))
      attrs.push(("y", num_str(el.y)))
      attrs.push(("width", num_str(w)))
      attrs.push(("height", num_str(h)))
      if rx is Some(v) {
        attrs.push(("rx", num_str(v)))
      }
      if ry is Some(v) {
        attrs.push(("ry", num_str(v)))
      }
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_node("rect", attrs, [], [])
    }
    @model.Circle(r) => {
      attrs.push(("cx", num_str(el.x)))
      attrs.push(("cy", num_str(el.y)))
      attrs.push(("r", num_str(r)))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_node("circle", attrs, [], [])
    }
    @model.Ellipse(rx, ry) => {
      attrs.push(("cx", num_str(el.x)))
      attrs.push(("cy", num_str(el.y)))
      attrs.push(("rx", num_str(rx)))
      attrs.push(("ry", num_str(ry)))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_node("ellipse", attrs, [], [])
    }
    @model.Line(x2, y2) => {
      // 透明なヒットエリア
      let hit_attrs : Array[(String, String)] = [
        ("data-id", el.id),
        ("x1", num_str(el.x)),
        ("y1", num_str(el.y)),
        ("x2", num_str(x2)),
        ("y2", num_str(y2)),
        ("stroke", "transparent"),
        ("stroke-width", "24"),
      ]
      let hit_area = create_svg_node("line", hit_attrs, [], [])
      // 子要素を収集
      let children : Array[@element.DomNode] = [hit_area]
      // 選択時はハイライト
      if is_selected {
        let highlight_attrs : Array[(String, String)] = [
          ("x1", num_str(el.x)),
          ("y1", num_str(el.y)),
          ("x2", num_str(x2)),
          ("y2", num_str(y2)),
          ("stroke", "rgba(0, 102, 255, 0.3)"),
          ("stroke-width", num_str(el.style.stroke_width.unwrap_or(1.0) + 6.0)),
          ("stroke-linecap", "round"),
          ("pointer-events", "none"),
        ]
        children.push(create_svg_node("line", highlight_attrs, [], []))
      }
      // 実際の線
      let line_attrs : Array[(String, String)] = [
        ("x1", num_str(el.x)),
        ("y1", num_str(el.y)),
        ("x2", num_str(x2)),
        ("y2", num_str(y2)),
        ("pointer-events", "none"),
      ]
      add_style_attrs(line_attrs, el.style)
      let stroke_color = el.style.stroke.unwrap_or("#000000")
      add_marker_attrs(line_attrs, el.style, stroke_color)
      if el.transform is Some(t) {
        line_attrs.push(("transform", t))
      }
      children.push(create_svg_node("line", line_attrs, [], []))
      // グループ
      create_svg_node(
        "g",
        [("data-id", el.id), ("data-element-type", "line"), ("cursor", "move")],
        [],
        children,
      )
    }
    @model.Polyline(points) => {
      let points_str = points.map(fn(p) { "\{p.x},\{p.y}" }).join(" ")
      attrs.push(("points", points_str))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_node("polyline", attrs, [], [])
    }
    @model.Path(d) => {
      attrs.push(("d", d))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_node("path", attrs, [], [])
    }
    @model.Text(content, font_size) => {
      let size = font_size.unwrap_or(16.0)
      let (text_x, text_y) = match parent {
        Some(p) => {
          let bbox = p.bounding_box()
          (bbox.x + bbox.width / 2.0, bbox.y + bbox.height / 2.0)
        }
        None => (el.x, el.y)
      }
      // ヒットエリアサイズ計算
      let (hit_width, hit_height) = if content.contains("\n") {
        let lines : Array[String] = content
          .split("\n")
          .map(fn(sv) { sv.to_string() })
          .collect()
        let line_count = lines.length()
        let line_height = size * 1.2
        let total_height = line_count.to_double() * line_height
        let max_line_len = lines.fold(init=0, fn(acc, line) {
          let len = line.iter().count()
          if len > acc { len } else { acc }
        })
        let estimated_width = max_line_len.to_double() * size * 0.6
        let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
        let h = if total_height < 24.0 { 24.0 } else { total_height }
        (w, h)
      } else {
        let char_count = content.iter().count()
        let estimated_width = char_count.to_double() * size * 0.6
        let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
        (w, size * 1.2)
      }
      // ヒットエリア
      let hit_attrs : Array[(String, String)] = [
        ("data-id", el.id),
        ("x", num_str(text_x - hit_width / 2.0)),
        ("y", num_str(text_y - hit_height / 2.0)),
        ("width", num_str(hit_width)),
        ("height", num_str(hit_height)),
        ("fill", "transparent"),
      ]
      let hit_area = create_svg_node("rect", hit_attrs, [], [])
      // テキスト要素（FFI で複数行テキストを設定するため、ref callback を使用）
      attrs.push(("x", num_str(text_x)))
      attrs.push(("y", num_str(text_y)))
      attrs.push(("font-size", num_str(size)))
      attrs.push(("text-anchor", "middle"))
      attrs.push(("dominant-baseline", "middle"))
      attrs.push(("pointer-events", "none"))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      // テキスト内容を設定するために __ref callback を使用
      let luna_attrs : Array[(String, @element.AttrValue)] = []
      for attr in attrs {
        luna_attrs.push((attr.0, @element.Static(attr.1)))
      }
      // __ref で DOM 要素にアクセスしてテキストを設定
      luna_attrs.push(("__ref", @element.Handler(fn(text_el) {
        set_multiline_text_ffi(text_el, content, text_x, size)
      })))
      let text_node = @element.create_element_ns(
        @element.svg_ns,
        "text",
        luna_attrs,
        [],
      )
      // グループ
      create_svg_node(
        "g",
        [("data-id", el.id), ("data-element-type", "text"), ("cursor", "move")],
        [],
        [hit_area, text_node],
      )
    }
  }
}

///|
/// 矢印マーカーを DomNode として作成
fn create_arrow_marker_node(id : String, color : String, is_start : Bool) -> @element.DomNode {
  let path_d = if is_start { "M10,0 L0,5 L10,10" } else { "M0,0 L10,5 L0,10" }
  let path = create_svg_node("path", [("d", path_d), ("fill", color)], [], [])
  create_svg_node(
    "marker",
    [
      ("id", id),
      ("markerWidth", "10"),
      ("markerHeight", "10"),
      ("refX", if is_start { "0" } else { "10" }),
      ("refY", "5"),
      ("orient", "auto"),
      ("markerUnits", "strokeWidth"),
    ],
    [],
    [path],
  )
}

///|
/// SVG defs を DomNode として作成
pub fn create_arrow_defs_node() -> @element.DomNode {
  let colors = [
    "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff",
    "#ffff00", "#ff00ff", "#00ffff", "#808080", "#c0c0c0",
  ]
  let markers : Array[@element.DomNode] = []
  for color in colors {
    let suffix = color.replace(old="#", new="")
    markers.push(create_arrow_marker_node("arrow-start-\{suffix}", color, true))
    markers.push(create_arrow_marker_node("arrow-end-\{suffix}", color, false))
  }
  create_svg_node("defs", [], [], markers)
}

///|
/// グリッド線を DomNode として作成
pub fn render_grid_nodes(
  width : Int,
  height : Int,
  grid_size : Int,
  viewport : @model.Viewport,
) -> Array[@element.DomNode] {
  let lines : Array[@element.DomNode] = []
  let size = grid_size.to_double()
  let vb_width = width.to_double() / viewport.zoom
  let vb_height = height.to_double() / viewport.zoom
  let start_x = viewport.scroll_x
  let start_y = viewport.scroll_y
  let end_x = start_x + vb_width
  let end_y = start_y + vb_height
  let grid_start_x = (start_x / size).floor() * size
  let grid_start_y = (start_y / size).floor() * size
  // 縦線
  let mut x = grid_start_x
  while x <= end_x {
    lines.push(create_svg_node("line", [
      ("x1", x.to_string()),
      ("y1", start_y.to_string()),
      ("x2", x.to_string()),
      ("y2", end_y.to_string()),
      ("stroke", "#e0e0e0"),
      ("stroke-width", "0.5"),
    ], [], []))
    x = x + size
  }
  // 横線
  let mut y = grid_start_y
  while y <= end_y {
    lines.push(create_svg_node("line", [
      ("x1", start_x.to_string()),
      ("y1", y.to_string()),
      ("x2", end_x.to_string()),
      ("y2", y.to_string()),
      ("stroke", "#e0e0e0"),
      ("stroke-width", "0.5"),
    ], [], []))
    y = y + size
  }
  lines
}

///|
/// リサイズハンドルを DomNode として作成
pub fn render_resize_handles_nodes(el : @model.Element) -> Array[@element.DomNode] {
  let half = handle_size / 2.0
  let handles : Array[@element.DomNode] = []
  match el.shape {
    @model.Line(x2, y2) => {
      let positions = [
        ("line-start", el.x, el.y),
        ("line-end", x2, y2),
      ]
      for pos in positions {
        let (handle_id, cx, cy) = pos
        // ヒットエリア
        let hit_area = create_svg_node("circle", [
          ("cx", num_str(cx)),
          ("cy", num_str(cy)),
          ("r", "12"),
          ("fill", "transparent"),
          ("cursor", "move"),
          ("data-handle", handle_id),
          ("data-element-id", el.id),
        ], [], [])
        // 可視ハンドル
        let visible = create_svg_node("circle", [
          ("cx", num_str(cx)),
          ("cy", num_str(cy)),
          ("r", "5"),
          ("fill", "#0066ff"),
          ("stroke", "#ffffff"),
          ("stroke-width", "2"),
          ("pointer-events", "none"),
        ], [], [])
        handles.push(create_svg_node("g", [("class", "line-handle-group")], [], [hit_area, visible]))
      }
    }
    _ => {
      let bbox = el.bounding_box()
      let positions = [
        ("nw", bbox.x - half, bbox.y - half, "nwse-resize"),
        ("ne", bbox.x + bbox.width - half, bbox.y - half, "nesw-resize"),
        ("sw", bbox.x - half, bbox.y + bbox.height - half, "nesw-resize"),
        ("se", bbox.x + bbox.width - half, bbox.y + bbox.height - half, "nwse-resize"),
      ]
      for pos in positions {
        let (handle_id, hx, hy, cursor) = pos
        handles.push(create_svg_node("rect", [
          ("data-handle", handle_id),
          ("data-element-id", el.id),
          ("x", num_str(hx)),
          ("y", num_str(hy)),
          ("width", num_str(handle_size)),
          ("height", num_str(handle_size)),
          ("fill", "#0066ff"),
          ("stroke", "#ffffff"),
          ("stroke-width", "1"),
          ("cursor", cursor),
        ], [], []))
      }
    }
  }
  handles
}

///|
/// アンカーポイントを DomNode として作成
pub fn render_element_anchors_nodes(el : @model.Element) -> Array[@element.DomNode] {
  let result : Array[@element.DomNode] = []
  if el.shape is @model.Line(_, _) {
    return result
  }
  for anchor_data in el.get_all_anchors() {
    let (anchor, point) = anchor_data
    if anchor == @model.Center ||
       anchor == @model.TopLeft ||
       anchor == @model.TopRight ||
       anchor == @model.BottomLeft ||
       anchor == @model.BottomRight {
      continue
    }
    let anchor_name = match anchor {
      @model.Center => "center"
      @model.Top => "top"
      @model.Bottom => "bottom"
      @model.Left => "left"
      @model.Right => "right"
      @model.TopLeft => "top-left"
      @model.TopRight => "top-right"
      @model.BottomLeft => "bottom-left"
      @model.BottomRight => "bottom-right"
    }
    result.push(create_svg_node("circle", [
      ("cx", num_str(point.x)),
      ("cy", num_str(point.y)),
      ("r", "6"),
      ("fill", "rgba(100, 100, 255, 0.3)"),
      ("stroke", "#6666ff"),
      ("stroke-width", "1.5"),
      ("cursor", "crosshair"),
      ("data-anchor", anchor_name),
      ("data-element-id", el.id),
    ], [], []))
  }
  result
}

///|
/// 矩形選択ボックスを DomNode として作成
pub fn render_selection_box_node(box_state : @model.BoxSelectState) -> @element.DomNode {
  let bbox = box_state.to_bbox()
  create_svg_node("rect", [
    ("x", num_str(bbox.x)),
    ("y", num_str(bbox.y)),
    ("width", num_str(bbox.width)),
    ("height", num_str(bbox.height)),
    ("fill", "rgba(0, 102, 255, 0.1)"),
    ("stroke", "#0066ff"),
    ("stroke-width", "1"),
    ("stroke-dasharray", "4,2"),
    ("pointer-events", "none"),
  ], [], [])
}

///|
/// 接続ポイントハイライトを DomNode として作成
pub fn render_connection_highlight_node(point : @model.Point) -> @element.DomNode {
  create_svg_node("circle", [
    ("cx", num_str(point.x)),
    ("cy", num_str(point.y)),
    ("r", "10"),
    ("fill", "rgba(0, 200, 100, 0.4)"),
    ("stroke", "#00c864"),
    ("stroke-width", "2"),
    ("pointer-events", "none"),
  ], [], [])
}

// =============================================================================
// Luna VNode + Dynamic 属性による差分更新（for_each 用）
// =============================================================================

///|
/// グリッド線を VNode として描画
pub fn render_grid_vnode(state : EditorState) -> @element.DomNode {
  let children : Array[@element.DomNode] = []
  let grid_size = state.grid_size.get()
  let viewport = state.viewport.get()
  let size = grid_size.to_double()
  // viewBox の範囲を計算
  let vb_width = canvas_width.to_double() / viewport.zoom
  let vb_height = canvas_height.to_double() / viewport.zoom
  let start_x = viewport.scroll_x
  let start_y = viewport.scroll_y
  let end_x = start_x + vb_width
  let end_y = start_y + vb_height
  // グリッドの開始位置を計算
  let grid_start_x = (start_x / size).floor() * size
  let grid_start_y = (start_y / size).floor() * size
  // 縦線
  let mut x = grid_start_x
  while x <= end_x {
    children.push(create_svg_node("line", [
      ("x1", x.to_string()),
      ("y1", start_y.to_string()),
      ("x2", x.to_string()),
      ("y2", end_y.to_string()),
      ("stroke", "#e0e0e0"),
      ("stroke-width", "0.5"),
    ], [], []))
    x = x + size
  }
  // 横線
  let mut y = grid_start_y
  while y <= end_y {
    children.push(create_svg_node("line", [
      ("x1", start_x.to_string()),
      ("y1", y.to_string()),
      ("x2", end_x.to_string()),
      ("y2", y.to_string()),
      ("stroke", "#e0e0e0"),
      ("stroke-width", "0.5"),
    ], [], []))
    y = y + size
  }
  @element.fragment(children)
}

///|
/// 要素を VNode として描画（Effect で直接 DOM 更新）
pub fn render_element_vnode(state : EditorState, id : String) -> @element.DomNode {
  // 現在の要素を取得（初期値）
  guard state.find_element(id) is Some(el) else {
    return @element.fragment([])
  }

  // 要素の種類に応じて Effect ベースの VNode を作成
  // テキスト編集中の visibility 制御は Effect 内で行う
  render_element_with_effect(state, id, el)
}

///|
/// Effect で直接 DOM を更新する要素レンダリング
fn render_element_with_effect(
  state : EditorState,
  id : String,
  initial_el : @model.Element,
) -> @element.DomNode {
  // DOM 要素への参照
  let el_ref : Ref[@js.Any?] = { val: None }

  // Effect で Signal 変更時に直接 DOM を更新
  // 位置・サイズの変更を全て反映
  let _ = @luna.effect(fn() {
    let elements = state.elements.get()
    guard el_ref.val is Some(dom_el) else { return }

    // 現在の要素を検索
    let current_el : @model.Element? = {
      let mut found : @model.Element? = None
      for e in elements {
        if e.id == id {
          found = Some(e)
          break
        }
      }
      found
    }
    guard current_el is Some(el) else { return }

    // 要素の属性を更新（位置・サイズ両方）
    update_element_attrs(dom_el, el)
  })

  // テキスト編集状態の変化を監視して visibility を制御
  let _ = @luna.effect(fn() {
    let text_edit = state.text_edit.get()
    guard el_ref.val is Some(dom_el) else { return }

    // テキスト編集中かどうかをチェック
    let is_editing = match text_edit {
      Some(edit_state) => edit_state.editing_id == Some(id)
      None => false
    }

    // 編集中は非表示、それ以外は表示
    if is_editing {
      set_svg_attr_ffi(dom_el, "visibility", "hidden")
    } else {
      set_svg_attr_ffi(dom_el, "visibility", "visible")
    }
  })

  // 初期 VNode を作成（__ref で DOM 参照を取得）
  create_element_vnode_with_ref(initial_el, el_ref)
}

///|
/// 要素の属性を直接 DOM 更新（位置・サイズ両方）
fn update_element_attrs(dom_el : @js.Any, el : @model.Element) -> Unit {
  match el.shape {
    @model.Rect(w, h, _, _) => {
      set_svg_attr_ffi(dom_el, "x", num_str(el.x))
      set_svg_attr_ffi(dom_el, "y", num_str(el.y))
      set_svg_attr_ffi(dom_el, "width", num_str(w))
      set_svg_attr_ffi(dom_el, "height", num_str(h))
    }
    @model.Circle(r) => {
      set_svg_attr_ffi(dom_el, "cx", num_str(el.x))
      set_svg_attr_ffi(dom_el, "cy", num_str(el.y))
      set_svg_attr_ffi(dom_el, "r", num_str(r))
    }
    @model.Ellipse(rx, ry) => {
      set_svg_attr_ffi(dom_el, "cx", num_str(el.x))
      set_svg_attr_ffi(dom_el, "cy", num_str(el.y))
      set_svg_attr_ffi(dom_el, "rx", num_str(rx))
      set_svg_attr_ffi(dom_el, "ry", num_str(ry))
    }
    @model.Line(x2, y2) => {
      // Line はグループ内の子要素を更新
      update_line_children(dom_el, el.x, el.y, x2, y2)
    }
    @model.Text(content, font_size) => {
      // Text はグループ内の子要素を更新
      let size = font_size.unwrap_or(16.0)
      update_text_children(dom_el, el.x, el.y, content, size)
    }
    _ => ()
  }
}

///|
/// Line グループの子要素を更新
extern "js" fn update_line_children(
  group : @js.Any,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) =
  #| (group, x1, y1, x2, y2) => {
  #|   const children = group.children;
  #|   for (let i = 0; i < children.length; i++) {
  #|     const child = children[i];
  #|     if (child.tagName === 'line') {
  #|       child.setAttribute('x1', x1);
  #|       child.setAttribute('y1', y1);
  #|       child.setAttribute('x2', x2);
  #|       child.setAttribute('y2', y2);
  #|     }
  #|   }
  #| }

///|
/// Text グループの子要素を更新
extern "js" fn update_text_children(
  group : @js.Any,
  x : Double,
  y : Double,
  content : String,
  font_size : Double,
) =
  #| (group, x, y, content, fontSize) => {
  #|   const children = group.children;
  #|   // ヒットエリアのサイズを計算
  #|   const lines = content.split('\n');
  #|   const lineCount = lines.length;
  #|   const lineHeight = fontSize * 1.2;
  #|   const totalHeight = lineCount * lineHeight;
  #|   const maxLineLen = lines.reduce((max, line) => Math.max(max, line.length), 0);
  #|   const estimatedWidth = maxLineLen * fontSize * 0.6;
  #|   const hitWidth = Math.max(estimatedWidth, 40);
  #|   const hitHeight = Math.max(totalHeight, 24);
  #|   for (let i = 0; i < children.length; i++) {
  #|     const child = children[i];
  #|     if (child.tagName === 'rect') {
  #|       // ヒットエリア
  #|       child.setAttribute('x', x - hitWidth / 2);
  #|       child.setAttribute('y', y - hitHeight / 2);
  #|       child.setAttribute('width', hitWidth);
  #|       child.setAttribute('height', hitHeight);
  #|     } else if (child.tagName === 'text') {
  #|       // テキスト要素
  #|       child.setAttribute('x', x);
  #|       child.setAttribute('y', y);
  #|     }
  #|   }
  #| }

///|
/// __ref 付きの VNode を作成
fn create_element_vnode_with_ref(
  el : @model.Element,
  el_ref : Ref[@js.Any?],
) -> @element.DomNode {
  let attrs : Array[(String, String)] = []
  attrs.push(("data-id", el.id))

  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      attrs.push(("x", num_str(el.x)))
      attrs.push(("y", num_str(el.y)))
      attrs.push(("width", num_str(w)))
      attrs.push(("height", num_str(h)))
      if rx is Some(v) { attrs.push(("rx", num_str(v))) }
      if ry is Some(v) { attrs.push(("ry", num_str(v))) }
      add_style_attrs(attrs, el.style)
      attrs.push(("cursor", "move"))
      create_svg_node_with_ref("rect", attrs, el_ref)
    }
    @model.Circle(r) => {
      attrs.push(("cx", num_str(el.x)))
      attrs.push(("cy", num_str(el.y)))
      attrs.push(("r", num_str(r)))
      add_style_attrs(attrs, el.style)
      attrs.push(("cursor", "move"))
      create_svg_node_with_ref("circle", attrs, el_ref)
    }
    @model.Ellipse(rx, ry) => {
      attrs.push(("cx", num_str(el.x)))
      attrs.push(("cy", num_str(el.y)))
      attrs.push(("rx", num_str(rx)))
      attrs.push(("ry", num_str(ry)))
      add_style_attrs(attrs, el.style)
      attrs.push(("cursor", "move"))
      create_svg_node_with_ref("ellipse", attrs, el_ref)
    }
    @model.Line(x2, y2) => {
      // Line はグループで __ref を取得
      create_line_vnode_with_ref(el, x2, y2, el_ref)
    }
    @model.Text(content, font_size) => {
      // Text はグループで __ref を取得
      create_text_vnode_with_ref(el, content, font_size, el_ref)
    }
    _ => {
      // 他の形状は既存の静的レンダリング
      render_element_node(el, false, parent=None)
    }
  }
}

///|
/// Line 用の __ref 付き VNode を作成
fn create_line_vnode_with_ref(
  el : @model.Element,
  x2 : Double,
  y2 : Double,
  el_ref : Ref[@js.Any?],
) -> @element.DomNode {
  // 子要素を作成
  let children : Array[@element.DomNode] = []

  // 透明なヒットエリア
  let hit_attrs : Array[(String, String)] = [
    ("data-id", el.id),
    ("x1", num_str(el.x)),
    ("y1", num_str(el.y)),
    ("x2", num_str(x2)),
    ("y2", num_str(y2)),
    ("stroke", "transparent"),
    ("stroke-width", "24"),
  ]
  children.push(create_svg_node("line", hit_attrs, [], []))

  // 実際の線
  let line_attrs : Array[(String, String)] = [
    ("x1", num_str(el.x)),
    ("y1", num_str(el.y)),
    ("x2", num_str(x2)),
    ("y2", num_str(y2)),
    ("pointer-events", "none"),
  ]
  add_style_attrs(line_attrs, el.style)
  let stroke_color = el.style.stroke.unwrap_or("#000000")
  add_marker_attrs(line_attrs, el.style, stroke_color)
  children.push(create_svg_node("line", line_attrs, [], []))

  // グループを作成（__ref 付き）
  let group_attrs : Array[(String, @element.AttrValue)] = [
    ("data-id", @element.Static(el.id)),
    ("data-element-type", @element.Static("line")),
    ("cursor", @element.Static("move")),
    ("__ref", @element.Handler(fn(dom) { el_ref.val = Some(dom) })),
  ]
  @element.create_element_ns(@element.svg_ns, "g", group_attrs, children)
}

///|
/// Text 用の __ref 付き VNode を作成
fn create_text_vnode_with_ref(
  el : @model.Element,
  content : String,
  font_size : Double?,
  el_ref : Ref[@js.Any?],
) -> @element.DomNode {
  let size = font_size.unwrap_or(16.0)
  let text_x = el.x
  let text_y = el.y

  // ヒットエリアサイズ計算
  let (hit_width, hit_height) = if content.contains("\n") {
    let lines : Array[String] = content
      .split("\n")
      .map(fn(sv) { sv.to_string() })
      .collect()
    let line_count = lines.length()
    let line_height = size * 1.2
    let total_height = line_count.to_double() * line_height
    let max_line_len = lines.fold(init=0, fn(acc, line) {
      let len = line.iter().count()
      if len > acc { len } else { acc }
    })
    let estimated_width = max_line_len.to_double() * size * 0.6
    let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
    let h = if total_height < 24.0 { 24.0 } else { total_height }
    (w, h)
  } else {
    let char_count = content.iter().count()
    let estimated_width = char_count.to_double() * size * 0.6
    let w = if estimated_width < 40.0 { 40.0 } else { estimated_width }
    (w, size * 1.2)
  }

  // 子要素を作成
  let children : Array[@element.DomNode] = []

  // ヒットエリア
  let hit_attrs : Array[(String, String)] = [
    ("data-id", el.id),
    ("x", num_str(text_x - hit_width / 2.0)),
    ("y", num_str(text_y - hit_height / 2.0)),
    ("width", num_str(hit_width)),
    ("height", num_str(hit_height)),
    ("fill", "transparent"),
  ]
  children.push(create_svg_node("rect", hit_attrs, [], []))

  // テキスト要素
  let text_attrs : Array[(String, String)] = [
    ("x", num_str(text_x)),
    ("y", num_str(text_y)),
    ("font-size", num_str(size)),
    ("text-anchor", "middle"),
    ("dominant-baseline", "middle"),
    ("pointer-events", "none"),
  ]
  add_style_attrs(text_attrs, el.style)

  // テキスト内容を設定するために __ref callback を使用
  let text_luna_attrs : Array[(String, @element.AttrValue)] = []
  for attr in text_attrs {
    text_luna_attrs.push((attr.0, @element.Static(attr.1)))
  }
  text_luna_attrs.push(("__ref", @element.Handler(fn(text_el) {
    set_multiline_text_ffi(text_el, content, text_x, size)
  })))
  let text_node = @element.create_element_ns(
    @element.svg_ns,
    "text",
    text_luna_attrs,
    [],
  )
  children.push(text_node)

  // グループを作成（__ref 付き）
  let group_attrs : Array[(String, @element.AttrValue)] = [
    ("data-id", @element.Static(el.id)),
    ("data-element-type", @element.Static("text")),
    ("cursor", @element.Static("move")),
    ("__ref", @element.Handler(fn(dom) { el_ref.val = Some(dom) })),
  ]
  @element.create_element_ns(@element.svg_ns, "g", group_attrs, children)
}

///|
/// __ref 付き SVG ノードを作成
fn create_svg_node_with_ref(
  tag : String,
  attrs : Array[(String, String)],
  el_ref : Ref[@js.Any?],
) -> @element.DomNode {
  let luna_attrs : Array[(String, @element.AttrValue)] = []
  for attr in attrs {
    luna_attrs.push((attr.0, @element.Static(attr.1)))
  }
  // __ref で DOM 参照を取得
  luna_attrs.push(("__ref", @element.Handler(fn(dom) {
    el_ref.val = Some(dom)
  })))
  @element.create_element_ns(@element.svg_ns, tag, luna_attrs, [])
}

///|
/// 選択オーバーレイ（ハンドル・アンカー）を描画（Effect ベース）
pub fn render_selection_overlay(state : EditorState) -> @element.DomNode {
  // コンテナへの参照
  let container_ref : Ref[@js.Any?] = { val: None }

  // Effect で選択要素の変更を監視して再描画
  let _ = @luna.effect(fn() {
    let elements = state.elements.get()
    let selected_ids = state.selected_ids.get()

    guard container_ref.val is Some(container) else { return }

    // コンテナをクリア
    clear_children_ffi(container)

    // 選択された要素のオーバーレイを描画
    for sel_id in selected_ids {
      // elements から直接検索（Effect 依存関係を正しく追跡）
      let found_el : @model.Element? = {
        let mut result : @model.Element? = None
        for e in elements {
          if e.id == sel_id {
            result = Some(e)
            break
          }
        }
        result
      }
      if found_el is Some(el) {
        // アンカーポイント
        let anchors = render_element_anchors(el)
        for anchor in anchors {
          append_child_ffi(container, anchor)
        }
        // リサイズハンドル（単一選択の場合のみ）
        if selected_ids.length() == 1 {
          let handles = render_resize_handles(el)
          for handle in handles {
            append_child_ffi(container, handle)
          }
        }
      }
    }
  })

  // コンテナグループを作成
  let attrs : Array[(String, @element.AttrValue)] = [
    ("class", @element.Static("selection-overlay")),
    ("__ref", @element.Handler(fn(el) { container_ref.val = Some(el) })),
  ]
  @element.create_element_ns(@element.svg_ns, "g", attrs, [])
}

///|
/// 矩形選択ボックスを VNode として描画（Effect ベース）
pub fn render_box_select_vnode(state : EditorState) -> @element.DomNode {
  let rect_ref : Ref[@js.Any?] = { val: None }

  let _ = @luna.effect(fn() {
    let box_state = state.box_select.get()
    guard rect_ref.val is Some(rect) else { return }
    guard box_state is Some(bs) else { return }

    let bbox = bs.to_bbox()
    set_svg_attr_ffi(rect, "x", num_str(bbox.x))
    set_svg_attr_ffi(rect, "y", num_str(bbox.y))
    set_svg_attr_ffi(rect, "width", num_str(bbox.width))
    set_svg_attr_ffi(rect, "height", num_str(bbox.height))
  })

  // 初期値で rect を作成
  let initial_box = state.box_select.get()
  let (x, y, w, h) = match initial_box {
    Some(bs) => {
      let bbox = bs.to_bbox()
      (bbox.x, bbox.y, bbox.width, bbox.height)
    }
    None => (0.0, 0.0, 0.0, 0.0)
  }

  let attrs : Array[(String, @element.AttrValue)] = [
    ("x", @element.Static(num_str(x))),
    ("y", @element.Static(num_str(y))),
    ("width", @element.Static(num_str(w))),
    ("height", @element.Static(num_str(h))),
    ("fill", @element.Static("rgba(0, 102, 255, 0.1)")),
    ("stroke", @element.Static("#0066ff")),
    ("stroke-width", @element.Static("1")),
    ("stroke-dasharray", @element.Static("4,2")),
    ("pointer-events", @element.Static("none")),
    ("__ref", @element.Handler(fn(el) { rect_ref.val = Some(el) })),
  ]
  @element.create_element_ns(@element.svg_ns, "rect", attrs, [])
}

///|
/// 全アンカーポイントを VNode として描画（ライン編集中、Effect ベース）
pub fn render_all_anchors_vnode(state : EditorState) -> @element.DomNode {
  let container_ref : Ref[@js.Any?] = { val: None }

  let _ = @luna.effect(fn() {
    let elements = state.elements.get()
    let resize_state = state.resize_state.get()
    guard container_ref.val is Some(container) else { return }
    guard resize_state is Some(resize) else { return }

    // コンテナをクリア
    clear_children_ffi(container)

    for el in elements {
      // 編集中の要素はスキップ
      if el.id == resize.element_id {
        continue
      }
      // Line はスキップ
      if el.shape is @model.Line(_, _) {
        continue
      }
      // 子要素はスキップ
      if el.parent_id is Some(_) {
        continue
      }
      // アンカーポイント
      let anchors = render_all_anchor_points([el], resize.element_id)
      for anchor in anchors {
        append_child_ffi(container, anchor)
      }
    }
  })

  let attrs : Array[(String, @element.AttrValue)] = [
    ("class", @element.Static("all-anchors")),
    ("__ref", @element.Handler(fn(el) { container_ref.val = Some(el) })),
  ]
  @element.create_element_ns(@element.svg_ns, "g", attrs, [])
}

///|
/// 接続ハイライトを VNode として描画（Effect ベース）
pub fn render_connection_highlight_vnode(state : EditorState) -> @element.DomNode {
  let circle_ref : Ref[@js.Any?] = { val: None }

  let _ = @luna.effect(fn() {
    let pending = state.pending_connection.get()
    guard circle_ref.val is Some(circle) else { return }
    guard pending is Some(p) else { return }

    set_svg_attr_ffi(circle, "cx", num_str(p.point.x))
    set_svg_attr_ffi(circle, "cy", num_str(p.point.y))
  })

  // 初期値で circle を作成
  let initial = state.pending_connection.get()
  let (cx, cy) = match initial {
    Some(p) => (p.point.x, p.point.y)
    None => (0.0, 0.0)
  }

  let attrs : Array[(String, @element.AttrValue)] = [
    ("cx", @element.Static(num_str(cx))),
    ("cy", @element.Static(num_str(cy))),
    ("r", @element.Static("10")),
    ("fill", @element.Static("rgba(0, 200, 100, 0.4)")),
    ("stroke", @element.Static("#00c864")),
    ("stroke-width", @element.Static("2")),
    ("pointer-events", @element.Static("none")),
    ("__ref", @element.Handler(fn(el) { circle_ref.val = Some(el) })),
  ]
  @element.create_element_ns(@element.svg_ns, "circle", attrs, [])
}
