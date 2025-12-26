// Moonlight - 軽量 SVG エディタ

///|
using @element {div, h1, p, button, text, text_dyn, events}

///|
/// キャンバスサイズ
let canvas_width : Int = 800

///|
let canvas_height : Int = 600

///|
/// ID カウンター（Signal で管理）
fn create_id_counter() -> @luna.Signal[Int] {
  @luna.signal(0)
}

///|
/// SVG コンテナの参照を保持（FFI）
extern "js" fn clear_children_ffi(el : @js.Any) =
  #| (el) => { while (el.firstChild) el.removeChild(el.firstChild); }

///|
fn main {
  guard @js_dom.document().getElementById("app") is Some(el)
  @element.render(el |> @element.DomElement::from_dom, editor_app())
}

///|
fn editor_app() -> @element.DomNode {
  // ID カウンター
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }

  // エディタ状態を初期化
  let state = EditorState::new(canvas_width, canvas_height)

  // サンプルの図形を追加
  let rect1 = Element::new(
    new_id(),
    100.0,
    100.0,
    Rect(120.0, 80.0, None, None),
  ).with_style({
    fill: Some("#4a90d9"),
    stroke: Some("#2c5282"),
    stroke_width: Some(2.0),
    opacity: None,
  })
  let rect2 = Element::new(
    new_id(),
    300.0,
    200.0,
    Rect(100.0, 100.0, Some(10.0), Some(10.0)),
  ).with_style({
    fill: Some("#48bb78"),
    stroke: Some("#276749"),
    stroke_width: Some(2.0),
    opacity: None,
  })
  let circle1 = Element::new(new_id(), 500.0, 150.0, Circle(50.0)).with_style({
    fill: Some("#ed8936"),
    stroke: Some("#c05621"),
    stroke_width: Some(2.0),
    opacity: None,
  })
  state.add_element(rect1)
  state.add_element(rect2)
  state.add_element(circle1)

  // SVG コンテナへの参照
  let svg_ref : Ref[@js.Any?] = { val: None }

  // マウスイベントハンドラ
  let on_mousedown : (@js.Any) -> Unit = fn(e) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let target = e._get("target")
    let data_id_raw = target._get("dataset")._get("id")
    let data_id : String? = if @js.is_nullish(data_id_raw) {
      None
    } else {
      Some(data_id_raw.cast())
    }

    // SVG 要素の座標を取得
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let svg_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let svg_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    if data_id is Some(id) {
      // 要素をクリック - 選択してドラッグ開始
      state.select(Some(id))
      state.start_drag(id, svg_x, svg_y)
    } else {
      // 空白をクリック - 選択解除
      state.select(None)
    }
  }
  let on_mousemove : (@js.Any) -> Unit = fn(e) {
    if state.is_dragging() {
      let mouse_event : @js_dom.MouseEvent = e.cast()
      let svg = e._get("currentTarget")
      let rect = svg._call("getBoundingClientRect", [])
      let svg_x = mouse_event.clientX - (rect._get("left").cast() : Double)
      let svg_y = mouse_event.clientY - (rect._get("top").cast() : Double)
      state.drag_move(svg_x, svg_y)
    }
  }
  let on_mouseup : (@js.Any) -> Unit = fn(_e) { state.end_drag() }

  // 初期 SVG を作成（effect より先に作成）
  let initial_children : Array[@js.Any] = []
  let elements = state.elements.get()
  let selected = state.selected_id.get()
  for el in elements {
    initial_children.push(render_element(el, Some(el.id) == selected))
  }
  let svg = render_svg_container(
    canvas_width,
    canvas_height,
    on_mousedown,
    on_mousemove,
    on_mouseup,
    initial_children,
  )
  svg_ref.val = Some(svg)

  // SVG を再描画する関数
  let redraw_svg = fn() {
    // svg_ref が None の場合は何もしない
    match svg_ref.val {
      None => ()
      Some(svg) => {
        clear_children_ffi(svg)
        let elements = state.elements.get()
        let selected = state.selected_id.get()
        for el in elements {
          let child = render_element(el, Some(el.id) == selected)
          append_child_ffi(svg, child)
        }
      }
    }
  }

  // 初回フラグ（effect は作成直後に一度実行されるのでスキップ）
  let is_first_run : Ref[Bool] = { val: true }

  // Signal の変更を監視して再描画
  let _ = @luna.effect(fn() {
    // Signal を読み取って依存関係を登録
    let _ = state.elements.get()
    let _ = state.selected_id.get()
    // 初回はスキップ（既に初期レンダリング済み）
    if is_first_run.val {
      is_first_run.val = false
      return
    }
    redraw_svg()
  })

  // UI
  div([
    h1([text("Moonlight SVG Editor")]),
    p([
      text_dyn(fn() {
        match state.selected_id.get() {
          Some(id) => "Selected: \{id}"
          None => "Click a shape to select"
        }
      }),
    ]),
    // SVG キャンバス
    svg_to_dom_node(svg),
    // ボタン
    div(style="margin-top: 10px;", [
      button(
        on=events().click(fn(_) {
          let current = id_counter.get()
          let new_rect = Element::new(
            new_id(),
            150.0 + current.to_double() * 20.0,
            150.0 + current.to_double() * 20.0,
            Rect(80.0, 60.0, None, None),
          ).with_style({
            fill: Some("#9f7aea"),
            stroke: Some("#6b46c1"),
            stroke_width: Some(2.0),
            opacity: None,
          })
          state.add_element(new_rect)
        }),
        [text("Add Rectangle")],
      ),
      button(
        on=events().click(fn(_) {
          let current = id_counter.get()
          let new_circle = Element::new(
            new_id(),
            200.0 + current.to_double() * 20.0,
            200.0 + current.to_double() * 20.0,
            Circle(40.0),
          ).with_style({
            fill: Some("#f56565"),
            stroke: Some("#c53030"),
            stroke_width: Some(2.0),
            opacity: None,
          })
          state.add_element(new_circle)
        }),
        [text("Add Circle")],
      ),
    ]),
  ])
}
