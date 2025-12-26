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
  let attrs : Array[(String, String)] = [
    ("width", width.to_string()),
    ("height", height.to_string()),
    ("viewBox", "0 0 \{width} \{height}"),
    ("style", "border: 1px solid #ccc; background: #fafafa; user-select: none;"),
  ]
  let handlers : Array[(String, (@js.Any) -> Unit)] = [
    ("mousedown", on_mousedown),
    ("mousemove", on_mousemove),
    ("mouseup", on_mouseup),
    ("contextmenu", on_contextmenu),
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
/// リサイズハンドルのサイズ
let handle_size : Double = 8.0

///|
/// リサイズハンドルを描画
pub fn render_resize_handles(el : @model.Element) -> Array[@js.Any] {
  let bbox = el.bounding_box()
  let half = handle_size / 2.0
  let handles : Array[@js.Any] = []
  // 四隅のハンドル位置
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
  handles
}
