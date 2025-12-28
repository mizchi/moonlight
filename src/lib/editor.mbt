// 共通ライブラリ - エディタ作成ロジック

///|
/// SVG 要素に属性を設定（FFI）
pub extern "js" fn set_svg_attr(el : @js.Any, name : String, value : String) =
  #| (el, name, value) => el.setAttribute(name, value)

///|
/// SVG 要素を作成（createElementNS）
pub extern "js" fn create_svg_element_ns(tag : String) -> @js.Any =
  #| (tag) => document.createElementNS('http://www.w3.org/2000/svg', tag)

///|
/// 子要素を追加
pub extern "js" fn append_child(parent : @js.Any, child : @js.Any) =
  #| (parent, child) => parent.appendChild(child)

///|
/// innerHTML を設定
pub extern "js" fn set_inner_html(el : @js.Any, html : String) =
  #| (el, html) => el.innerHTML = html

///|
/// 要素のスタイルを設定
pub extern "js" fn set_style(el : @js.Any, style : String) =
  #| (el, style) => el.style.cssText = style

///|
/// null を返す
extern "js" fn js_null() -> @js.Any =
  #| () => null

///|
/// コンテナをクリア
pub extern "js" fn clear_container_ffi(container : @js.Any) =
  #| (container) => { container.innerHTML = ''; }

///|
/// エディタハンドルを作成
pub extern "js" fn create_editor_handle(
  export_svg_fn : () -> String,
  import_svg_fn : (String) -> Unit,
  clear_fn : () -> Unit,
  destroy_fn : () -> Unit,
  has_focus_fn : () -> Bool,
) -> @js.Any =
  #| (exportSvg, importSvg, clear, destroy, hasFocus) => ({
  #|   _changeCallbacks: [],
  #|   exportSvg: exportSvg,
  #|   importSvg: importSvg,
  #|   clear: clear,
  #|   destroy: destroy,
  #|   hasFocus: hasFocus,
  #|   onChange: function(callback) { this._changeCallbacks.push(callback); }
  #| })

///|
/// プレビューハンドルを作成
pub extern "js" fn create_preview_handle(
  open_fn : () -> Unit,
  close_fn : () -> Unit,
  is_open_fn : () -> Bool,
  get_svg_fn : () -> String,
  set_svg_fn : (String) -> Unit,
) -> @js.Any =
  #| (open, close, isOpen, getSvg, setSvg) => ({
  #|   openEditor: open,
  #|   closeEditor: close,
  #|   isOpen: isOpen,
  #|   getSvg: getSvg,
  #|   setSvg: setSvg
  #| })

///|
/// 数値を文字列に変換（小数点以下2桁）
fn num_to_str(n : Double) -> String {
  let rounded = (n * 100.0).round() / 100.0
  rounded.to_string()
}

///|
/// 簡易エディタ状態
pub struct SimpleEditorState {
  width : Int
  height : Int
  elements : @luna.Signal[Array[@model.Element]]
  selected_id : @luna.Signal[String?]
  theme_mode : @luna.Signal[@model.ThemeMode]
  has_focus : @luna.Signal[Bool]
  is_readonly : @luna.Signal[Bool]
  show_toolbar : @luna.Signal[Bool]
  mut svg_el : @js.Any // SVG 要素への参照
  mut container_el : @js.Any // コンテナへの参照
}

///|
/// 簡易エディタ状態を作成
pub fn SimpleEditorState::new(
  width : Int,
  height : Int,
  options : EditorOptions,
) -> SimpleEditorState {
  {
    width,
    height,
    elements: @luna.signal([]),
    selected_id: @luna.signal(None),
    theme_mode: @luna.signal(parse_theme(options.theme)),
    has_focus: @luna.signal(false),
    is_readonly: @luna.signal(options.is_readonly),
    show_toolbar: @luna.signal(options.toolbar_visible),
    svg_el: js_null(),
    container_el: js_null(),
  }
}

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
    _ => ""
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
    svg = svg + "  " + element_to_svg_string(el) + "\n"
  }
  svg = svg + "</svg>"
  svg
}

///|
/// 要素を DOM SVG 要素として描画
fn render_element_to_dom(el : @model.Element) -> @js.Any {
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
      ellipse
    }
    @model.Line(x2, y2) => {
      let line = create_svg_element_ns("line")
      set_svg_attr(line, "x1", num_to_str(el.x))
      set_svg_attr(line, "y1", num_to_str(el.y))
      set_svg_attr(line, "x2", num_to_str(x2))
      set_svg_attr(line, "y2", num_to_str(y2))
      set_svg_attr(line, "stroke", stroke)
      set_svg_attr(line, "stroke-width", num_to_str(stroke_width))
      set_svg_attr(line, "data-id", el.id)
      line
    }
    @model.Text(content, font_size) => {
      let text = create_svg_element_ns("text")
      set_svg_attr(text, "x", num_to_str(el.x))
      set_svg_attr(text, "y", num_to_str(el.y))
      set_svg_attr(text, "fill", fill)
      set_svg_attr(text, "font-size", num_to_str(font_size.unwrap_or(16.0)))
      set_inner_html(text, content)
      set_svg_attr(text, "data-id", el.id)
      text
    }
    _ => create_svg_element_ns("g") // 空のグループを返す
  }
}

///|
/// SVG を再描画
pub fn redraw_svg(state : SimpleEditorState) -> Unit {
  let svg = state.svg_el
  // 既存の子要素をクリア（背景rect以外）
  clear_svg_elements_ffi(svg)
  // 背景を追加
  let bg = create_svg_element_ns("rect")
  set_svg_attr(bg, "width", "100%")
  set_svg_attr(bg, "height", "100%")
  let bg_color = match state.theme_mode.get() {
    @model.Dark => "#1a1a2e"
    @model.Light => "#ffffff"
  }
  set_svg_attr(bg, "fill", bg_color)
  append_child(svg, bg)
  // 要素を描画
  for el in state.elements.get() {
    let dom_el = render_element_to_dom(el)
    append_child(svg, dom_el)
  }
}

///|
/// SVG 要素の子要素をクリア
extern "js" fn clear_svg_elements_ffi(svg : @js.Any) =
  #| (svg) => { while (svg.firstChild) svg.removeChild(svg.firstChild); }

///|
/// SVG コンテナを作成して初期化
pub fn create_svg_container(
  state : SimpleEditorState,
  container : @js.Any,
) -> @js.Any {
  let width = state.width
  let height = state.height
  // SVG 要素を作成
  let svg = create_svg_element_ns("svg")
  set_svg_attr(svg, "viewBox", "0 0 \{width} \{height}")
  set_svg_attr(svg, "width", width.to_string())
  set_svg_attr(svg, "height", height.to_string())
  set_style(svg, "display: block; max-width: 100%; height: auto;")
  // コンテナに追加
  append_child(container, svg)
  // 状態に参照を保存
  state.svg_el = svg
  state.container_el = container
  // 初期描画
  redraw_svg(state)
  svg
}

///|
/// 簡易 SVG パーサー（基本的な図形のみ）
pub fn parse_simple_svg(
  svg_string : String,
  new_id : () -> String,
) -> Array[@model.Element] {
  let elements : Array[@model.Element] = []
  // 非常に簡易的なパーサー（実際のプロダクションでは DOM パーサーを使用すべき）
  // rect, circle, ellipse, line, text を検出
  parse_svg_rects(svg_string, elements, new_id)
  parse_svg_circles(svg_string, elements, new_id)
  elements
}

///|
/// SVG から rect 要素をパース（簡易版）
fn parse_svg_rects(
  _svg : String,
  _elements : Array[@model.Element],
  _new_id : () -> String,
) -> Unit {
  // 簡易実装：実際のプロダクションでは正規表現または DOM パーサーを使用
  // ここでは省略
}

///|
/// SVG から circle 要素をパース（簡易版）
fn parse_svg_circles(
  _svg : String,
  _elements : Array[@model.Element],
  _new_id : () -> String,
) -> Unit {
  // 簡易実装
}

///|
/// サンプル図形を追加
pub fn add_sample_elements(state : SimpleEditorState) -> Unit {
  let elements : Array[@model.Element] = [
    {
      id: "sample-rect",
      x: 50.0,
      y: 50.0,
      shape: @model.Rect(100.0, 60.0, None, None),
      style: {
        fill: Some("#4CAF50"),
        stroke: Some("#2E7D32"),
        stroke_width: Some(2.0),
        opacity: None,
        stroke_dasharray: None,
        marker_start: None,
        marker_end: None,
      },
      transform: None,
      parent_id: None,
      connections: None,
    },
    {
      id: "sample-circle",
      x: 250.0,
      y: 100.0,
      shape: @model.Circle(40.0),
      style: {
        fill: Some("#2196F3"),
        stroke: Some("#1565C0"),
        stroke_width: Some(2.0),
        opacity: None,
        stroke_dasharray: None,
        marker_start: None,
        marker_end: None,
      },
      transform: None,
      parent_id: None,
      connections: None,
    },
  ]
  state.elements.set(elements)
}
