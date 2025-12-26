// Moonlight - 軽量 SVG エディタ

///|
using @element {div, h1, p, button, text, text_dyn, events, show}

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

  // 履歴管理
  let history = @model.History::new()

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
  // 初期要素は履歴に記録しない
  state.add_element_raw(rect1)
  state.add_element_raw(rect2)
  state.add_element_raw(circle1)

  // SVG コンテナへの参照
  let svg_ref : Ref[@js.Any?] = { val: None }

  // マウスイベントハンドラ
  let on_mousedown : (@js.Any) -> Unit = fn(e) {
    // コンテキストメニューを閉じる
    state.hide_context_menu()

    let mouse_event : @js_dom.MouseEvent = e.cast()
    let target = e._get("target")
    let dataset = target._get("dataset")

    // リサイズハンドルのクリックをチェック
    let data_handle_raw = dataset._get("handle")
    if not(@js.is_nullish(data_handle_raw)) {
      let handle_str : String = data_handle_raw.cast()
      let element_id_raw = dataset._get("elementId")
      if not(@js.is_nullish(element_id_raw)) {
        let element_id : String = element_id_raw.cast()
        let svg = e._get("currentTarget")
        let rect = svg._call("getBoundingClientRect", [])
        let svg_x = mouse_event.clientX - (rect._get("left").cast() : Double)
        let svg_y = mouse_event.clientY - (rect._get("top").cast() : Double)
        let handle = match handle_str {
          "nw" => @model.NW
          "ne" => @model.NE
          "sw" => @model.SW
          _ => @model.SE
        }
        state.start_resize(element_id, handle, svg_x, svg_y)
        return
      }
    }

    let data_id_raw = dataset._get("id")
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
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let svg_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let svg_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    if state.is_resizing() {
      state.resize_move(svg_x, svg_y)
    } else if state.is_dragging() {
      state.drag_move(svg_x, svg_y)
    }
  }
  let on_mouseup : (@js.Any) -> Unit = fn(_e) {
    // リサイズ終了時にリサイズコマンドを履歴に記録
    if state.resize_state.get() is Some(resize) {
      if state.find_element(resize.element_id) is Some(el) {
        // 実際にリサイズした場合のみ履歴に記録
        if resize.start_shape != el.shape || resize.start_x != el.x || resize.start_y != el.y {
          let cmd = @model.ResizeElement(resize.element_id, resize.start_shape, el.shape)
          // 位置も変わった場合は移動も記録（NW, NE, SW ハンドルの場合）
          if resize.start_x != el.x || resize.start_y != el.y {
            let move_cmd = @model.MoveElement(
              resize.element_id,
              resize.start_x,
              resize.start_y,
              el.x,
              el.y,
            )
            history.undo_stack.push(move_cmd)
          }
          history.undo_stack.push(cmd)
          history.redo_stack.clear()
        }
      }
      state.end_resize()
      return
    }
    // ドラッグ終了時に移動コマンドを履歴に記録
    if state.drag_state.get() is Some(drag) {
      if state.find_element(drag.element_id) is Some(el) {
        // 実際に移動した場合のみ履歴に記録
        if drag.start_x != el.x || drag.start_y != el.y {
          let cmd = @model.MoveElement(drag.element_id, drag.start_x, drag.start_y, el.x, el.y)
          // 履歴に追加（実行はすでにドラッグ中に完了している）
          history.undo_stack.push(cmd)
          history.redo_stack.clear()
        }
      }
    }
    state.end_drag()
  }

  // コンテキストメニューハンドラ
  let on_contextmenu : (@js.Any) -> Unit = fn(e) {
    // デフォルトメニューを無効化
    let _ = e._call("preventDefault", [])
    let mouse_event : @js_dom.MouseEvent = e.cast()

    // クリック対象を取得
    let target = e._get("target")
    let data_id_raw = target._get("dataset")._get("id")
    let target_id : String? = if @js.is_nullish(data_id_raw) {
      None
    } else {
      Some(data_id_raw.cast())
    }

    // 要素上で右クリックした場合は選択
    if target_id is Some(id) {
      state.select(Some(id))
    }

    // メニュー表示
    state.show_context_menu(mouse_event.clientX, mouse_event.clientY, target_id)
  }

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
    on_contextmenu,
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
          let is_selected = Some(el.id) == selected
          let child = render_element(el, is_selected)
          append_child_ffi(svg, child)
        }
        // 選択中の要素のリサイズハンドルを描画
        if selected is Some(id) {
          if state.find_element(id) is Some(el) {
            let handles = render_resize_handles(el)
            for handle in handles {
              append_child_ffi(svg, handle)
            }
          }
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
    // SVG キャンバス（position: relative でコンテキストメニューの基準に）
    div(style="position: relative; display: inline-block;", [
      svg_to_dom_node(svg),
      // コンテキストメニュー
      show(
        fn() { state.context_menu.get() is Some(_) },
        fn() { render_context_menu(state, history) },
      ),
    ]),
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
          execute_command(history, state, @model.AddElement(new_rect))
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
          execute_command(history, state, @model.AddElement(new_circle))
        }),
        [text("Add Circle")],
      ),
      // Undo/Redo ボタン
      button(
        on=events().click(fn(_) { let _ = undo_command(history, state) }),
        [text("Undo")],
      ),
      button(
        on=events().click(fn(_) { let _ = redo_command(history, state) }),
        [text("Redo")],
      ),
    ]),
  ])
}

///|
/// コンテキストメニューをレンダリング
fn render_context_menu(state : EditorState, history : @model.History) -> @element.DomNode {
  guard state.context_menu.get() is Some(menu)
  let style =
    "position: fixed; left: \{menu.x}px; top: \{menu.y}px; background: white; border: 1px solid #ccc; border-radius: 4px; box-shadow: 2px 2px 10px rgba(0,0,0,0.1); min-width: 120px; z-index: 1000;"
  div(
    style~,
    [
      // 要素上でクリックした場合のみ「削除」を表示
      if menu.target_id is Some(id) {
        div(style="padding: 8px 12px; cursor: pointer; hover: #f0f0f0;", [
          button(
            style="width: 100%; text-align: left; background: none; border: none; cursor: pointer; padding: 4px 8px;",
            on=events().click(fn(_) {
              // 削除対象の要素を取得して履歴に記録
              if state.find_element(id) is Some(el) {
                execute_command(history, state, @model.RemoveElement(el))
              }
              state.hide_context_menu()
            }),
            [text("Delete")],
          ),
        ])
      } else {
        // 空白部分を右クリックした場合
        div(style="padding: 8px 12px; color: #999;", [text("No element selected")])
      },
    ],
  )
}
