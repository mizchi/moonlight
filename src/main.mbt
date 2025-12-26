// Moonlight - 軽量 SVG エディタ

///|
using @element {div, h1, button, text, text_dyn, events, show, input}

///|
/// キャンバスサイズ
let canvas_width : Int = 400

///|
let canvas_height : Int = 300

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
  let rect1 = @model.Element::new(
    new_id(),
    50.0,
    50.0,
    @model.Rect(80.0, 60.0, None, None),
  ).with_style({
    fill: Some("#4a90d9"),
    stroke: Some("#2c5282"),
    stroke_width: Some(2.0),
    opacity: None,
  })
  let rect2 = @model.Element::new(
    new_id(),
    180.0,
    120.0,
    @model.Rect(70.0, 70.0, Some(8.0), Some(8.0)),
  ).with_style({
    fill: Some("#48bb78"),
    stroke: Some("#276749"),
    stroke_width: Some(2.0),
    opacity: None,
  })
  let circle1 = @model.Element::new(new_id(), 320.0, 80.0, @model.Circle(35.0)).with_style({
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

  // Space キーが押されているか
  let space_pressed : Ref[Bool] = { val: false }

  // Space キーの監視を設定
  let _ = add_keydown_listener(fn(e) {
    let key : String = e._get("key").cast()
    if key == " " {
      space_pressed.val = true
    }
  })
  let _ = add_keyup_listener(fn(e) {
    let key : String = e._get("key").cast()
    if key == " " {
      space_pressed.val = false
      // Space を離したらパン終了
      if state.is_panning.get() {
        state.end_pan()
      }
    }
  })

  // マウス座標をスクリーン座標で取得
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }

  // マウス座標をシーン座標に変換するヘルパー
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }

  // ダブルクリック検出用の状態
  let last_click_time : Ref[Double] = { val: 0.0 }
  let last_click_element : Ref[String] = { val: "" }
  let double_click_threshold : Double = 300.0 // ms

  // ダブルクリック時のテキスト編集開始
  let handle_double_click = fn(element_id : String) {
    guard state.find_element(element_id) is Some(el)
    // 要素のバウンディングボックスの中心を計算
    let bbox = el.bounding_box()
    let center_x = bbox.x + bbox.width / 2.0
    let center_y = bbox.y + bbox.height / 2.0
    // テキスト編集を開始
    state.start_text_edit(element_id, center_x, center_y)
  }

  // テキスト要素の編集開始
  let handle_text_edit = fn(text_id : String) {
    guard state.find_element(text_id) is Some(el)
    guard el.shape is @model.Text(content, _)
    // 親要素IDを取得（必須）
    guard el.parent_id is Some(parent_id)
    // テキスト要素の位置で編集開始
    state.start_text_edit_existing(text_id, parent_id, el.x, el.y, content)
  }

  // テキスト入力を確定
  let commit_text_input = fn(text_content : String) {
    guard state.text_edit.get() is Some(edit_state)
    match edit_state.editing_id {
      Some(text_id) => {
        // 既存テキストの編集
        if text_content == "" {
          // 空文字の場合はテキストを削除
          if state.find_element(text_id) is Some(el) {
            execute_command(history, state, @model.RemoveElement(el))
          }
        } else if text_content != edit_state.initial_text {
          // 内容が変わった場合のみ更新
          state.update_element(text_id, fn(el) {
            match el.shape {
              @model.Text(_, font_size) =>
                { ..el, shape: @model.Text(text_content, font_size) }
              _ => el
            }
          })
        }
      }
      None => {
        // 新規テキストの作成
        if text_content != "" {
          let text_el = @model.Element::new(
            new_id(),
            edit_state.x,
            edit_state.y,
            @model.Text(text_content, Some(16.0)),
          ).with_style({
            fill: Some("#333333"),
            stroke: None,
            stroke_width: None,
            opacity: None,
          }).with_parent(edit_state.parent_id)
          execute_command(history, state, @model.AddElement(text_el))
        }
      }
    }
    state.end_text_edit()
  }

  // マウスイベントハンドラ
  let on_mousedown : (@js.Any) -> Unit = fn(e) {
    // コンテキストメニューを閉じる
    state.hide_context_menu()

    // Space キーが押されていればパンを開始
    if space_pressed.val {
      let (screen_x, screen_y) = get_screen_coords(e)
      state.start_pan(screen_x, screen_y)
      return
    }

    let target = e._get("target")
    let dataset = target._get("dataset")

    // リサイズハンドルのクリックをチェック
    let data_handle_raw = dataset._get("handle")
    if not(@js.is_nullish(data_handle_raw)) {
      let handle_str : String = data_handle_raw.cast()
      let element_id_raw = dataset._get("elementId")
      if not(@js.is_nullish(element_id_raw)) {
        let element_id : String = element_id_raw.cast()
        // viewport 考慮した座標を取得
        let (scene_x, scene_y) = get_scene_coords(e)
        let handle = match handle_str {
          "nw" => @model.NW
          "ne" => @model.NE
          "sw" => @model.SW
          "se" => @model.SE
          "line-start" => @model.LineStart
          "line-end" => @model.LineEnd
          _ => @model.SE
        }
        state.start_resize(element_id, handle, scene_x, scene_y)
        return
      }
    }

    let data_id_raw = dataset._get("id")
    let data_id : String? = if @js.is_nullish(data_id_raw) {
      None
    } else {
      Some(data_id_raw.cast())
    }

    // SVG 要素の座標を取得（viewport 考慮）
    let (scene_x, scene_y) = get_scene_coords(e)
    if data_id is Some(id) {
      // 子要素の場合は親を取得
      let target_id = match state.get_parent_id(id) {
        Some(parent_id) => parent_id
        None => id
      }
      let now = get_current_time()
      let is_child = state.is_child_element(id)
      // テキスト子要素かどうかをチェック
      let is_text_child = if is_child {
        match state.find_element(id) {
          Some(el) => el.shape is @model.Text(_, _)
          None => false
        }
      } else {
        false
      }
      // ダブルクリック判定
      // - 親要素: target_id が一致
      // - テキスト子要素: id（テキスト要素自体）が一致
      let dblclick_target = if is_text_child { id } else { target_id }
      if last_click_element.val == dblclick_target && now - last_click_time.val < double_click_threshold {
        // ダブルクリック検出
        last_click_time.val = 0.0
        last_click_element.val = ""
        state.end_drag()
        if is_text_child {
          // テキスト子要素の場合は編集モード
          handle_text_edit(id)
        } else {
          // 親要素の場合は新規テキスト追加
          handle_double_click(target_id)
        }
        return
      }
      // クリック時間と要素を記録
      last_click_time.val = now
      last_click_element.val = dblclick_target
      // 要素をクリック - 親を選択してドラッグ開始
      state.select(Some(target_id))
      state.start_drag(target_id, scene_x, scene_y)
    } else {
      // 空白をクリック - 選択解除
      state.select(None)
      last_click_time.val = 0.0
      last_click_element.val = ""
    }
  }
  let on_mousemove : (@js.Any) -> Unit = fn(e) {
    // パン中の場合
    if state.is_panning.get() {
      let (screen_x, screen_y) = get_screen_coords(e)
      state.pan_move(screen_x, screen_y)
      return
    }
    let (scene_x, scene_y) = get_scene_coords(e)
    if state.is_resizing() {
      state.resize_move(scene_x, scene_y)
    } else if state.is_dragging() {
      state.drag_move(scene_x, scene_y)
    }
  }
  let on_mouseup : (@js.Any) -> Unit = fn(_e) {
    // パン終了
    if state.is_panning.get() {
      state.end_pan()
      return
    }
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

  // ホイールイベントハンドラ（ズーム）
  let on_wheel : (@js.Any) -> Unit = fn(e) {
    let _ = e._call("preventDefault", [])
    let delta_y : Double = e._get("deltaY").cast()
    if delta_y < 0.0 {
      state.zoom_in()
    } else {
      state.zoom_out()
    }
  }

  // コンテキストメニューハンドラ
  let on_contextmenu : (@js.Any) -> Unit = fn(e) {
    // デフォルトメニューを無効化
    let _ = e._call("preventDefault", [])
    let mouse_event : @js_dom.MouseEvent = e.cast()

    // シーン座標を取得（図形挿入用）
    let (scene_x, scene_y) = get_scene_coords(e)

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

    // メニュー表示（スクリーン座標とシーン座標の両方を渡す）
    state.show_context_menu(
      mouse_event.clientX,
      mouse_event.clientY,
      scene_x,
      scene_y,
      target_id,
    )
  }

  // 初期 SVG を作成（effect より先に作成）
  let initial_children : Array[@js.Any] = []
  let elements = state.elements.get()
  let selected = state.selected_id.get()
  for el in elements {
    initial_children.push(render_element(el, Some(el.id) == selected))
  }
  let svg = render_svg_container_with_viewport(
    canvas_width,
    canvas_height,
    state.viewport.get(),
    on_mousedown,
    on_mousemove,
    on_mouseup,
    on_contextmenu,
    on_wheel,
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
        // グリッド線を描画（有効な場合）
        if state.grid_enabled.get() {
          let grid_lines = render_grid(
            canvas_width,
            canvas_height,
            state.grid_size.get(),
            state.viewport.get(),
          )
          for line in grid_lines {
            append_child_ffi(svg, line)
          }
        }
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
    let _ = state.grid_enabled.get()
    // 初回はスキップ（既に初期レンダリング済み）
    if is_first_run.val {
      is_first_run.val = false
      return
    }
    redraw_svg()
  })

  // Viewport の変更を監視して viewBox を更新
  let viewport_first_run : Ref[Bool] = { val: true }
  let _ = @luna.effect(fn() {
    let vp = state.viewport.get()
    if viewport_first_run.val {
      viewport_first_run.val = false
      return
    }
    if svg_ref.val is Some(svg) {
      let vb_width = canvas_width.to_double() / vp.zoom
      let vb_height = canvas_height.to_double() / vp.zoom
      let viewbox = "\{vp.scroll_x} \{vp.scroll_y} \{vb_width} \{vb_height}"
      update_viewbox_ffi(svg, viewbox)
      // グリッドも再描画
      redraw_svg()
    }
  })

  // キーボードショートカット
  setup_keyboard_shortcuts(state, history, new_id)

  // UI
  div([
    // ヘッダー
    div(style="margin-bottom: 10px;", [
      h1(style="margin: 0 0 8px 0;", [text("Moonlight SVG Editor")]),
      // ツールバー
      div([
        button(
          on=events().click(fn(_) {
            let current = id_counter.get()
            let new_rect = @model.Element::new(
              new_id(),
              150.0 + current.to_double() * 20.0,
              150.0 + current.to_double() * 20.0,
              @model.Rect(80.0, 60.0, None, None),
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
            let new_circle = @model.Element::new(
              new_id(),
              200.0 + current.to_double() * 20.0,
              200.0 + current.to_double() * 20.0,
              @model.Circle(40.0),
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
        button(
          on=events().click(fn(_) {
            let current = id_counter.get()
            let new_ellipse = @model.Element::new(
              new_id(),
              180.0 + current.to_double() * 20.0,
              120.0 + current.to_double() * 20.0,
              @model.Ellipse(60.0, 35.0),
            ).with_style({
              fill: Some("#38b2ac"),
              stroke: Some("#234e52"),
              stroke_width: Some(2.0),
              opacity: None,
            })
            execute_command(history, state, @model.AddElement(new_ellipse))
          }),
          [text("Add Ellipse")],
        ),
        button(
          on=events().click(fn(_) {
            let current = id_counter.get()
            let offset = current.to_double() * 20.0
            let new_line = @model.Element::new(
              new_id(),
              50.0 + offset,
              50.0 + offset,
              @model.Line(150.0 + offset, 100.0 + offset),
            ).with_style({
              fill: None,
              stroke: Some("#805ad5"),
              stroke_width: Some(3.0),
              opacity: None,
            })
            execute_command(history, state, @model.AddElement(new_line))
          }),
          [text("Add Line")],
        ),
        button(
          on=events().click(fn(_) {
            let current = id_counter.get()
            let new_text = @model.Element::new(
              new_id(),
              100.0 + current.to_double() * 20.0,
              200.0 + current.to_double() * 15.0,
              @model.Text("Hello", Some(24.0)),
            ).with_style({
              fill: Some("#2d3748"),
              stroke: None,
              stroke_width: None,
              opacity: None,
            })
            execute_command(history, state, @model.AddElement(new_text))
          }),
          [text("Add Text")],
        ),
        button(
          on=events().click(fn(_) { let _ = undo_command(history, state) }),
          [text("Undo")],
        ),
        button(
          on=events().click(fn(_) { let _ = redo_command(history, state) }),
          [text("Redo")],
        ),
        button(
          style="margin-left: 16px;",
          on=events().click(fn(_) {
            let svg_str = elements_to_svg(
              state.elements.get(),
              canvas_width,
              canvas_height,
            )
            download_file(svg_str, "drawing.svg", "image/svg+xml")
          }),
          [text("Export SVG")],
        ),
        // ズームコントロール
        @element.span(style="margin-left: 16px; display: inline-flex; align-items: center; gap: 4px;", [
          button(
            on=events().click(fn(_) { state.zoom_out() }),
            [text("-")],
          ),
          @element.span(style="min-width: 50px; text-align: center;", [
            text_dyn(fn() {
              let zoom = state.viewport.get().zoom
              "\{(zoom * 100.0).to_int()}%"
            }),
          ]),
          button(
            on=events().click(fn(_) { state.zoom_in() }),
            [text("+")],
          ),
          button(
            style="margin-left: 4px;",
            on=events().click(fn(_) { state.reset_viewport() }),
            [text("Reset")],
          ),
        ]),
        // グリッドスナップ
        @element.span(style="margin-left: 16px;", [
          @element.label(style="display: inline-flex; align-items: center; gap: 4px; cursor: pointer;", [
            input(
              type_="checkbox",
              on=events().change(fn(_) { state.toggle_grid() }),
            ),
            text("Grid Snap"),
          ]),
        ]),
      ]),
    ]),
    // メインエリア（Canvas + Sidebar）
    div(style="display: flex; gap: 16px;", [
      // SVG キャンバス（position: relative でコンテキストメニューの基準に）
      div(style="position: relative;", [
        svg_to_dom_node(svg),
        // コンテキストメニュー
        show(
          fn() { state.context_menu.get() is Some(_) },
          fn() { render_context_menu(state, history, new_id) },
        ),
        // テキスト入力オーバーレイ
        show(
          fn() { state.text_edit.get() is Some(_) },
          fn() { render_text_input(state, commit_text_input) },
        ),
      ]),
      // サイドバー
      render_sidebar(state),
    ]),
  ])
}

///|
/// キーボードショートカットを設定
fn setup_keyboard_shortcuts(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  let handler : (@js.Any) -> Unit = fn(e) {
    let key : String = e._get("key").cast()
    let ctrl_key : Bool = e._get("ctrlKey").cast()
    let meta_key : Bool = e._get("metaKey").cast()
    let is_cmd = ctrl_key || meta_key

    match key {
      // Delete or Backspace: 選択中の要素を削除
      "Delete" | "Backspace" => {
        if state.selected_id.get() is Some(id) {
          if state.find_element(id) is Some(el) {
            execute_command(history, state, @model.RemoveElement(el))
          }
        }
      }
      // Escape: 選択解除
      "Escape" => state.select(None)
      // Ctrl+D or Cmd+D: 複製
      "d" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          if state.selected_id.get() is Some(id) {
            if state.find_element(id) is Some(el) {
              // 新しいIDで複製し、少しオフセット
              let new_el = {
                ..el,
                id: new_id(),
                x: el.x + 20.0,
                y: el.y + 20.0,
              }
              execute_command(history, state, @model.AddElement(new_el))
              state.select(Some(new_el.id))
            }
          }
        }
      // Ctrl+Z or Cmd+Z: Undo
      "z" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let _ = undo_command(history, state)

        }
      // Ctrl+Y or Cmd+Shift+Z: Redo
      "y" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let _ = redo_command(history, state)

        }
      _ => ()
    }
  }
  add_keyboard_listener(handler)
}

///|
/// window に keydown イベントリスナーを追加
extern "js" fn add_keyboard_listener(handler : (@js.Any) -> Unit) =
  #| (handler) => window.addEventListener('keydown', handler)

///|
/// keydown リスナー（別名）
extern "js" fn add_keydown_listener(handler : (@js.Any) -> Unit) =
  #| (handler) => window.addEventListener('keydown', handler)

///|
/// keyup リスナー
extern "js" fn add_keyup_listener(handler : (@js.Any) -> Unit) =
  #| (handler) => window.addEventListener('keyup', handler)

///|
/// SVG の viewBox を更新
extern "js" fn update_viewbox_ffi(svg : @js.Any, viewbox : String) =
  #| (svg, viewbox) => svg.setAttribute('viewBox', viewbox)

///|
/// ファイルをダウンロード
extern "js" fn download_file(content : String, filename : String, mime_type : String) =
  #| (content, filename, mimeType) => {
  #|   const blob = new Blob([content], { type: mimeType });
  #|   const url = URL.createObjectURL(blob);
  #|   const a = document.createElement('a');
  #|   a.href = url;
  #|   a.download = filename;
  #|   document.body.appendChild(a);
  #|   a.click();
  #|   document.body.removeChild(a);
  #|   URL.revokeObjectURL(url);
  #| }

///|
/// 現在時刻を取得（ミリ秒）
extern "js" fn get_current_time() -> Double =
  #| () => performance.now()

///|
/// 指定セレクタの要素にフォーカスを遅延設定（初期値付き）
extern "js" fn schedule_focus_with_value_ffi(selector : String, value : String) -> Int =
  #| (selector, value) => setTimeout(() => { const el = document.querySelector(selector); if (el) { el.value = value; el.focus(); el.select(); } }, 0)

///|
/// サイドバー幅
let sidebar_width : Int = 220

///|
/// サイドバーをレンダリング
fn render_sidebar(state : EditorState) -> @element.DomNode {
  let sidebar_style =
    "width: \{sidebar_width}px; min-height: \{canvas_height}px; border: 1px solid #ccc; border-radius: 4px; background: #fafafa; padding: 12px; box-sizing: border-box;"
  div(
    style=sidebar_style,
    [
      div(style="font-weight: bold; margin-bottom: 12px; border-bottom: 1px solid #ddd; padding-bottom: 8px;", [
        text("Element"),
      ]),
      // 選択中の要素の詳細を表示
      show(
        fn() { state.selected_id.get() is Some(_) },
        fn() { render_element_details(state) },
      ),
      // 選択なしの場合
      show(
        fn() { state.selected_id.get() is None },
        fn() {
          div(style="color: #888; font-size: 14px;", [
            text("Select an element to view details"),
          ])
        },
      ),
    ],
  )
}

///|
/// 入力フィールドのスタイル
let input_style : String = "width: 100%; padding: 4px; border: 1px solid #ccc; border-radius: 3px; font-family: monospace; font-size: 13px; box-sizing: border-box;"

///|
/// カラー入力のスタイル
let color_input_style : String = "width: 60px; height: 24px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer;"

///|
/// 要素の詳細を表示・編集
fn render_element_details(state : EditorState) -> @element.DomNode {
  div([
    // ID (読み取り専用)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("ID")]),
      div(style="font-family: monospace; font-size: 14px; color: #333;", [
        text_dyn(fn() { state.selected_id.get().unwrap_or("-") }),
      ]),
    ]),
    // Position X
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("X")]),
      input(
        type_="number",
        style=input_style,
        dyn_value=fn() {
          match state.selected_id.get() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.x.to_int().to_string()
                None => "0"
              }
            None => "0"
          }
        },
        on=events().change(fn(e) {
          if state.selected_id.get() is Some(id) {
            let value = get_event_target_value(e.as_any())
            if parse_double(value) is Some(x) {
              state.update_element(id, fn(el) { { ..el, x } })
            }
          }
        }),
      ),
    ]),
    // Position Y
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Y")]),
      input(
        type_="number",
        style=input_style,
        dyn_value=fn() {
          match state.selected_id.get() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.y.to_int().to_string()
                None => "0"
              }
            None => "0"
          }
        },
        on=events().change(fn(e) {
          if state.selected_id.get() is Some(id) {
            let value = get_event_target_value(e.as_any())
            if parse_double(value) is Some(y) {
              state.update_element(id, fn(el) { { ..el, y } })
            }
          }
        }),
      ),
    ]),
    // Shape (読み取り専用)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Shape")]),
      div(style="font-family: monospace; font-size: 14px;", [
        text_dyn(fn() {
          match state.selected_id.get() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => format_shape(el.shape)
                None => "-"
              }
            None => "-"
          }
        }),
      ]),
    ]),
    // Fill (カラーピッカー)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Fill")]),
      div(style="display: flex; gap: 8px; align-items: center;", [
        input(
          type_="color",
          style=color_input_style,
          dyn_value=fn() {
            match state.selected_id.get() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.fill.unwrap_or("#000000")
                  None => "#000000"
                }
              None => "#000000"
            }
          },
          on=events().input(fn(e) {
            if state.selected_id.get() is Some(id) {
              let value = get_event_target_value(e.as_any())
              state.update_element(id, fn(el) {
                { ..el, style: { ..el.style, fill: Some(value) } }
              })
            }
          }),
        ),
        @element.span(style="font-family: monospace; font-size: 12px;", [
          text_dyn(fn() {
            match state.selected_id.get() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.fill.unwrap_or("none")
                  None => "-"
                }
              None => "-"
            }
          }),
        ]),
      ]),
    ]),
    // Stroke (カラーピッカー)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Stroke")]),
      div(style="display: flex; gap: 8px; align-items: center;", [
        input(
          type_="color",
          style=color_input_style,
          dyn_value=fn() {
            match state.selected_id.get() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.stroke.unwrap_or("#000000")
                  None => "#000000"
                }
              None => "#000000"
            }
          },
          on=events().input(fn(e) {
            if state.selected_id.get() is Some(id) {
              let value = get_event_target_value(e.as_any())
              state.update_element(id, fn(el) {
                { ..el, style: { ..el.style, stroke: Some(value) } }
              })
            }
          }),
        ),
        @element.span(style="font-family: monospace; font-size: 12px;", [
          text_dyn(fn() {
            match state.selected_id.get() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.stroke.unwrap_or("none")
                  None => "-"
                }
              None => "-"
            }
          }),
        ]),
      ]),
    ]),
    // Stroke Width
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Stroke Width")]),
      input(
        type_="number",
        style=input_style,
        dyn_value=fn() {
          match state.selected_id.get() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.style.stroke_width.unwrap_or(1.0).to_string()
                None => "1"
              }
            None => "1"
          }
        },
        on=events().change(fn(e) {
          if state.selected_id.get() is Some(id) {
            let value = get_event_target_value(e.as_any())
            if parse_double(value) is Some(w) {
              state.update_element(id, fn(el) {
                { ..el, style: { ..el.style, stroke_width: Some(w) } }
              })
            }
          }
        }),
      ),
    ]),
  ])
}

///|
/// イベントから target.value を取得（FFI）
extern "js" fn get_event_target_value(e : @js.Any) -> String =
  #| (e) => e.target.value

///|
/// 文字列を Double にパース（FFI）
extern "js" fn parse_double_ffi(s : String) -> @js.Any =
  #| (s) => { const n = parseFloat(s); return isNaN(n) ? null : n; }

///|
fn parse_double(s : String) -> Double? {
  let result = parse_double_ffi(s)
  if @js.is_nullish(result) {
    None
  } else {
    Some(result.cast())
  }
}

///|
/// Shape を文字列にフォーマット
fn format_shape(shape : @model.ShapeType) -> String {
  match shape {
    @model.Rect(w, h, _, _) => "Rect(\{w.to_int()}x\{h.to_int()})"
    @model.Circle(r) => "Circle(r=\{r.to_int()})"
    @model.Ellipse(rx, ry) => "Ellipse(\{rx.to_int()}x\{ry.to_int()})"
    @model.Line(x2, y2) => "Line(to \{x2.to_int()},\{y2.to_int()})"
    @model.Polyline(_) => "Polyline"
    @model.Path(_) => "Path"
    @model.Text(content, _) => "Text(\"\{content}\")"
  }
}

///|
/// メニューボタンのスタイル
let menu_button_style : String = "width: 100%; text-align: left; background: none; border: none; cursor: pointer; padding: 4px 8px;"

///|
/// テキスト入力オーバーレイをレンダリング
fn render_text_input(
  state : EditorState,
  commit : (String) -> Unit,
) -> @element.DomNode {
  guard state.text_edit.get() is Some(edit_state)
  // シーン座標をスクリーン座標に変換
  let vp = state.viewport.get()
  let screen_pos = vp.scene_to_screen(edit_state.x, edit_state.y)
  // 入力フィールドの幅と高さ
  let input_width = 150
  let input_height = 28
  // 中央に配置（入力フィールドの半分をオフセット）
  let left = screen_pos.x - input_width.to_double() / 2.0
  let top = screen_pos.y - input_height.to_double() / 2.0
  let style =
    "position: absolute; left: \{left}px; top: \{top}px; width: \{input_width}px; height: \{input_height}px; padding: 4px 8px; border: 2px solid #0066ff; border-radius: 4px; font-size: 14px; text-align: center; box-sizing: border-box; outline: none;"
  // 自動フォーカス（初期値付き）
  let _ = schedule_focus_with_value_ffi("input[type=text]", edit_state.initial_text)
  input(
    type_="text",
    style~,
    on=events()
      .keydown(fn(e) {
        let key : String = e.as_any()._get("key").cast()
        if key == "Enter" {
          let value = get_event_target_value(e.as_any())
          commit(value)
        } else if key == "Escape" {
          state.end_text_edit()
        }
      })
      .blur(fn(e) {
        let value = get_event_target_value(e.as_any())
        commit(value)
      }),
  )
}

///|
/// コンテキストメニューをレンダリング
fn render_context_menu(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  guard state.context_menu.get() is Some(menu)
  let style =
    "position: fixed; left: \{menu.x}px; top: \{menu.y}px; background: white; border: 1px solid #ccc; border-radius: 4px; box-shadow: 2px 2px 10px rgba(0,0,0,0.1); min-width: 140px; z-index: 1000;"
  div(
    style~,
    [
      // 要素上でクリックした場合のみメニューを表示
      if menu.target_id is Some(id) {
        @element.fragment([
          // Bring to Front
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                if state.bring_to_front(id) is Some((from_idx, to_idx)) {
                  let cmd = @model.ReorderElement(id, from_idx, to_idx)
                  history.undo_stack.push(cmd)
                  history.redo_stack.clear()
                }
                state.hide_context_menu()
              }),
              [text("Bring to Front")],
            ),
          ]),
          // Send to Back
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                if state.send_to_back(id) is Some((from_idx, to_idx)) {
                  let cmd = @model.ReorderElement(id, from_idx, to_idx)
                  history.undo_stack.push(cmd)
                  history.redo_stack.clear()
                }
                state.hide_context_menu()
              }),
              [text("Send to Back")],
            ),
          ]),
          // Delete
          div(style="padding: 4px 12px;", [
            button(
              style=menu_button_style + " color: #c53030;",
              on=events().click(fn(_) {
                if state.find_element(id) is Some(el) {
                  execute_command(history, state, @model.RemoveElement(el))
                }
                state.hide_context_menu()
              }),
              [text("Delete")],
            ),
          ]),
        ])
      } else {
        // 空白部分を右クリックした場合 - 挿入メニュー
        let insert_x = menu.scene_x
        let insert_y = menu.scene_y
        @element.fragment([
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee; color: #666; font-size: 12px;", [
            text("Insert"),
          ]),
          // Rectangle
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                let el = @model.Element::new(
                  new_id(),
                  insert_x,
                  insert_y,
                  @model.Rect(80.0, 60.0, None, None),
                ).with_style({
                  fill: Some("#9f7aea"),
                  stroke: Some("#6b46c1"),
                  stroke_width: Some(2.0),
                  opacity: None,
                })
                execute_command(history, state, @model.AddElement(el))
                state.hide_context_menu()
              }),
              [text("Rectangle")],
            ),
          ]),
          // Circle
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                let el = @model.Element::new(
                  new_id(),
                  insert_x,
                  insert_y,
                  @model.Circle(40.0),
                ).with_style({
                  fill: Some("#f56565"),
                  stroke: Some("#c53030"),
                  stroke_width: Some(2.0),
                  opacity: None,
                })
                execute_command(history, state, @model.AddElement(el))
                state.hide_context_menu()
              }),
              [text("Circle")],
            ),
          ]),
          // Ellipse
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                let el = @model.Element::new(
                  new_id(),
                  insert_x,
                  insert_y,
                  @model.Ellipse(60.0, 35.0),
                ).with_style({
                  fill: Some("#38b2ac"),
                  stroke: Some("#234e52"),
                  stroke_width: Some(2.0),
                  opacity: None,
                })
                execute_command(history, state, @model.AddElement(el))
                state.hide_context_menu()
              }),
              [text("Ellipse")],
            ),
          ]),
          // Line
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                let el = @model.Element::new(
                  new_id(),
                  insert_x,
                  insert_y,
                  @model.Line(insert_x + 100.0, insert_y + 50.0),
                ).with_style({
                  fill: None,
                  stroke: Some("#805ad5"),
                  stroke_width: Some(3.0),
                  opacity: None,
                })
                execute_command(history, state, @model.AddElement(el))
                state.hide_context_menu()
              }),
              [text("Line")],
            ),
          ]),
          // Text
          div(style="padding: 4px 12px;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                let el = @model.Element::new(
                  new_id(),
                  insert_x,
                  insert_y,
                  @model.Text("Text", Some(24.0)),
                ).with_style({
                  fill: Some("#2d3748"),
                  stroke: None,
                  stroke_width: None,
                  opacity: None,
                })
                execute_command(history, state, @model.AddElement(el))
                state.hide_context_menu()
              }),
              [text("Text")],
            ),
          ]),
        ])
      },
    ],
  )
}
