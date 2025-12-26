// SVG Rendering - @model.Element → DomNode への変換

///|
/// SVG namespace URI
let svg_ns : String = "http://www.w3.org/2000/svg"

///|
/// SVG 要素を createElementNS で作成（FFI）
extern "js" fn create_svg_element_ffi(
  tag : String,
  ns : String,
) -> @js.Any =
  #| (tag, ns) => document.createElementNS(ns, tag)

///|
/// SVG 要素に属性を設定（FFI）
extern "js" fn set_svg_attr_ffi(el : @js.Any, name : String, value : String) =
  #| (el, name, value) => el.setAttribute(name, value)

///|
/// SVG 要素にイベントリスナーを追加（FFI）
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
/// SVG 要素を作成
fn create_svg_element(
  tag : String,
  attrs : Array[(String, String)],
  handlers : Array[(String, (@js.Any) -> Unit)],
) -> @js.Any {
  let el = create_svg_element_ffi(tag, svg_ns)
  for attr in attrs {
    set_svg_attr_ffi(el, attr.0, attr.1)
  }
  for handler in handlers {
    add_event_listener_ffi(el, handler.0, handler.1)
  }
  el
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
}

///|
/// 要素を SVG ノードに変換
pub fn render_element(el : @model.Element, is_selected : Bool) -> @js.Any {
  let attrs : Array[(String, String)] = []
  // data-id 属性（イベント処理用）
  attrs.push(("data-id", el.id))
  // 選択状態のスタイル
  let style = if is_selected {
    {
      ..el.style,
      stroke: Some("#0066ff"),
      stroke_width: Some(el.style.stroke_width.unwrap_or(1.0) + 1.0),
    }
  } else {
    el.style
  }
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
      attrs.push(("x1", num_str(el.x)))
      attrs.push(("y1", num_str(el.y)))
      attrs.push(("x2", num_str(x2)))
      attrs.push(("y2", num_str(y2)))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      create_svg_element("line", attrs, [])
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
      attrs.push(("x", num_str(el.x)))
      attrs.push(("y", num_str(el.y)))
      if font_size is Some(size) {
        attrs.push(("font-size", num_str(size)))
      }
      // テキストを中央寄せ
      attrs.push(("text-anchor", "middle"))
      attrs.push(("dominant-baseline", "middle"))
      add_style_attrs(attrs, style)
      if el.transform is Some(t) {
        attrs.push(("transform", t))
      }
      attrs.push(("cursor", "move"))
      let text_el = create_svg_element("text", attrs, [])
      set_text_content_ffi(text_el, content)
      text_el
    }
  }
}

///|
/// テキストコンテンツを設定（FFI）
extern "js" fn set_text_content_ffi(el : @js.Any, content : String) =
  #| (el, content) => el.textContent = content

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
    ("style", "border: 1px solid #ccc; background: #fafafa; user-select: none;"),
  ]
  let handlers : Array[(String, (@js.Any) -> Unit)] = [
    ("mousedown", on_mousedown),
    ("mousemove", on_mousemove),
    ("mouseup", on_mouseup),
    ("contextmenu", on_contextmenu),
    ("wheel", on_wheel),
  ]
  let svg = create_svg_element("svg", attrs, handlers)
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
      let fs_attr = if font_size is Some(size) {
        " font-size=\"\{size}\""
      } else {
        ""
      }
      "<text x=\"\{el.x}\" y=\"\{el.y}\"\{fs_attr}\{style_str}>\{content}</text>"
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
        ("line-start", el.x - half, el.y - half, "move"),
        ("line-end", x2 - half, y2 - half, "move"),
      ]
      for pos in positions {
        let (handle_id, hx, hy, cursor) = pos
        // 円形のハンドルを使用
        let attrs : Array[(String, String)] = [
          ("data-handle", handle_id),
          ("data-element-id", el.id),
          ("cx", num_str(hx + half)),
          ("cy", num_str(hy + half)),
          ("r", num_str(half)),
          ("fill", "#0066ff"),
          ("stroke", "#ffffff"),
          ("stroke-width", "1"),
          ("cursor", cursor),
        ]
        handles.push(create_svg_element("circle", attrs, []))
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
