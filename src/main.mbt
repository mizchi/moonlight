// Moonlight - 軽量 SVG エディタ

///|
using @element {div, button, text, text_dyn, events, show, input}

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
/// URL パラメータからモードを取得
fn get_mode_from_url() -> EditorMode {
  let search = get_url_search_ffi()
  if search.contains("mode=embed") {
    Embedded
  } else {
    Full
  }
}

///|
fn main {
  guard @js_dom.document().getElementById("app") is Some(el)
  let mode = get_mode_from_url()
  match mode {
    Full => @element.render(el |> @element.DomElement::from_dom, editor_app())
    Embedded =>
      @element.render(
        el |> @element.DomElement::from_dom,
        create_embedded_app(),
      )
  }
}

///|
/// 埋め込みモード用のアプリを作成
fn create_embedded_app() -> @element.DomNode {
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }
  let state = EditorState::new_with_mode(canvas_width, canvas_height, Embedded)
  let history = @model.History::new()
  add_sample_shapes(state, new_id)
  embedded_editor_app(state, history, new_id)
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
  add_sample_shapes(state, new_id)

  // ウィンドウサイズを監視してモバイル判定を更新
  observe_window_resize_ffi(fn(width, _height) {
    state.is_mobile.set(width < 768)
  })

  // Space キーが押されているか
  let space_pressed : Ref[Bool] = { val: false }

  // Space キーの監視を設定
  setup_keyboard_listener(state, history, space_pressed)

  // 座標取得ヘルパー
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }

  // ダブルクリック検出用の状態
  let last_click_time : Ref[Double] = { val: 0.0 }
  let last_click_element : Ref[String] = { val: "" }
  let double_click_threshold : Double = 300.0

  // テキスト入力を確定するコールバック
  let commit_text_input = fn(text_content : String) {
    commit_text_edit(state, history, new_id, text_content)
  }

  // マウスイベントハンドラ
  let on_mousedown = create_mousedown_handler(
    state, history, new_id, get_screen_coords, get_scene_coords, space_pressed, last_click_time,
    last_click_element, double_click_threshold,
  )
  let on_mousemove = create_mousemove_handler(
    state, get_screen_coords, get_scene_coords,
  )
  let on_mouseup = create_mouseup_handler(state, history, get_screen_coords)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)

  // キーボードショートカット
  setup_keyboard_shortcuts(state, history, new_id)

  // SVG キャンバスを Luna VNode として作成（for_each による差分更新）
  let svg_canvas = render_svg_canvas_node(
    state, on_mousedown, on_mousemove, on_mouseup, on_contextmenu, on_wheel,
  )

  // UI
  render_editor_ui_vnode(state, history, new_id, svg_canvas, commit_text_input)
}

// ============================================================
// 初期化ヘルパー
// ============================================================

///|
/// サンプル図形を追加
fn add_sample_shapes(state : EditorState, new_id : () -> String) -> Unit {
  let default_style = state.get_default_style()
  let text_style = state.get_text_style()

  // 矩形1（テキスト付き）
  let rect1_id = new_id()
  let rect1 = @model.Element::new(
    rect1_id,
    50.0,
    50.0,
    @model.Rect(120.0, 80.0, None, None),
  ).with_style(default_style)
  let text1_id = new_id()
  let text1 = @model.Element::new(
      text1_id,
      110.0, // rect1 の中央
      90.0,
      @model.Text("Hello", Some(16.0)),
    )
    .with_style(text_style)
    .with_parent(rect1_id)

  // 矩形2（テキスト付き）
  let rect2_id = new_id()
  let rect2 = @model.Element::new(
    rect2_id,
    220.0,
    50.0,
    @model.Rect(100.0, 80.0, None, None),
  ).with_style(default_style)
  let text2_id = new_id()
  let text2 = @model.Element::new(
      text2_id,
      270.0, // rect2 の中央
      90.0,
      @model.Text("World", Some(16.0)),
    )
    .with_style(text_style)
    .with_parent(rect2_id)

  // 円（2つのボックスの下に配置）
  let circle1 = @model.Element::new(new_id(), 200.0, 200.0, @model.Circle(40.0)).with_style(
    default_style,
  )
  state.add_element_raw(rect1)
  state.add_element_raw(text1)
  state.add_element_raw(rect2)
  state.add_element_raw(text2)
  state.add_element_raw(circle1)
}

///|
/// キーボードリスナーを設定（Space + Arrow）
fn setup_keyboard_listener(
  state : EditorState,
  history : @model.History,
  space_pressed : Ref[Bool],
) -> Unit {
  // 移動量（ピクセル）- グリッドスナップ時はグリッドサイズ
  let default_step = 10.0
  let grid_size = 20.0
  let _ = add_keydown_listener(fn(e) {
    // 入力要素にフォーカスがある場合はショートカットを無視
    if is_input_focused_ffi() {
      return
    }
    let key : String = e._get("key").cast()
    let keyboard_event : @js_dom.KeyboardEvent = e.cast()
    // Escape キーで配置モードキャンセル、またはコンテキストメニューを閉じる
    if key == "Escape" {
      if state.is_placing() {
        state.cancel_placement()
        keyboard_event.preventDefault()
        return
      }
      if state.context_menu.get() is Some(_) {
        state.hide_context_menu()
        keyboard_event.preventDefault()
        return
      }
    }
    // Space キーでパンモード
    if key == " " {
      space_pressed.val = true
      return
    }
    // コンテキストメニューが開いている場合は他のキー操作を無効化
    if state.context_menu.get() is Some(_) {
      return
    }
    // Arrow キーでパン（選択なし時）または要素移動（選択あり時）
    let selected_ids = state.selected_ids.get()
    let has_selection = selected_ids.length() > 0
    match key {
      "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight" =>
        if has_selection {
          // 選択要素がある場合は要素を移動
          let step = if state.grid_enabled.get() {
            grid_size
          } else {
            default_step
          }
          let (dx, dy) : (Double, Double) = match key {
            "ArrowUp" => (0.0, -step)
            "ArrowDown" => (0.0, step)
            "ArrowLeft" => (-step, 0.0)
            "ArrowRight" => (step, 0.0)
            _ => (0.0, 0.0)
          }
          // 選択中の全要素を移動
          for id in selected_ids {
            if state.find_element(id) is Some(el) {
              let old_x = el.x
              let old_y = el.y
              let new_x = old_x + dx
              let new_y = old_y + dy
              // 要素を移動
              state.update_element(id, fn(e) { { ..e, x: new_x, y: new_y } })
              // 子要素（テキストなど）も一緒に移動
              let children = state.get_children(id)
              for child in children {
                let child_old_x = child.x
                let child_old_y = child.y
                let child_new_x = child_old_x + dx
                let child_new_y = child_old_y + dy
                state.update_element(child.id, fn(c) {
                  { ..c, x: child_new_x, y: child_new_y }
                })
                // 子要素の移動もUndoスタックに記録
                let child_cmd = @model.MoveElement(
                  child.id,
                  child_old_x,
                  child_old_y,
                  child_new_x,
                  child_new_y,
                )
                history.undo_stack.push(child_cmd)
              }
              // 接続されているラインを更新
              state.update_connected_lines(id)
              // Undo スタックに記録
              let cmd = @model.MoveElement(id, old_x, old_y, new_x, new_y)
              history.undo_stack.push(cmd)
            }
          }
          history.redo_stack.clear()
          keyboard_event.preventDefault()
        } else {
          // 選択なしの場合はパン
          let zoom = state.viewport.get().zoom
          let pan_step = 12.0
          match key {
            "ArrowUp" => state.pan(0.0, -pan_step / zoom)
            "ArrowDown" => state.pan(0.0, pan_step / zoom)
            "ArrowLeft" => state.pan(-pan_step / zoom, 0.0)
            "ArrowRight" => state.pan(pan_step / zoom, 0.0)
            _ => ()
          }
          keyboard_event.preventDefault()
        }
      _ => ()
    }
  })
  let _ = add_keyup_listener(fn(e) {
    let key : String = e._get("key").cast()
    if key == " " {
      space_pressed.val = false
      if state.is_panning.get() {
        state.end_pan()
      }
    }
  })

}

// ============================================================
// イベントハンドラ作成
// ============================================================

///|
/// mousedown ハンドラを作成
fn create_mousedown_handler(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
  get_screen_coords : (@js.Any) -> (Double, Double),
  get_scene_coords : (@js.Any) -> (Double, Double),
  space_pressed : Ref[Bool],
  last_click_time : Ref[Double],
  last_click_element : Ref[String],
  double_click_threshold : Double,
) -> (@js.Any) -> Unit {
  fn(e) {
    // コンテキストメニューが開いている場合は閉じるだけで他のアクションを実行しない
    if state.context_menu.get() is Some(_) {
      state.hide_context_menu()
      return
    }

    // 配置モード中はクリックで確定
    if state.is_placing() {
      state.end_placement()
      return
    }

    // マウスボタンをチェック
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let button = mouse_event.button

    // 中クリック（button === 1）または Space キーでパン開始
    if button == 1 || space_pressed.val {
      let (screen_x, screen_y) = get_screen_coords(e)
      state.start_pan(screen_x, screen_y)
      return
    }
    let target = e._get("target")
    let dataset = target._get("dataset")

    // アンカーポイントのクリックをチェック（ライン生成）
    if handle_anchor_click(state, history, new_id, get_scene_coords, e, dataset) {
      return
    }

    // リサイズハンドルのクリックをチェック
    if handle_resize_click(state, get_scene_coords, e, dataset) {
      return
    }

    // data-id を直接取得、なければ親要素から取得（tspan 対応）
    let data_id_raw = dataset._get("id")
    let data_id : String? = if @js.is_nullish(data_id_raw) {
      let closest_id = get_closest_data_id_ffi(target)
      if @js.is_nullish(closest_id) {
        None
      } else {
        Some(closest_id.cast())
      }
    } else {
      Some(data_id_raw.cast())
    }
    let (scene_x, scene_y) = get_scene_coords(e)
    if data_id is Some(id) {
      handle_element_click(
        state, id, scene_x, scene_y, last_click_time, last_click_element, double_click_threshold,
      )
    } else {
      // 空白をクリック - 矩形選択を開始
      state.select(None)
      state.start_box_select(scene_x, scene_y)
      last_click_time.val = 0.0
      last_click_element.val = ""
    }
  }
}

///|
/// アンカーポイントクリックを処理
fn handle_anchor_click(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
  get_scene_coords : (@js.Any) -> (Double, Double),
  e : @js.Any,
  dataset : @js.Any,
) -> Bool {
  let data_anchor_raw = dataset._get("anchor")
  if @js.is_nullish(data_anchor_raw) {
    return false
  }
  let anchor_str : String = data_anchor_raw.cast()
  let element_id_raw = dataset._get("elementId")
  if @js.is_nullish(element_id_raw) {
    return false
  }
  let source_id : String = element_id_raw.cast()
  guard @model.parse_anchor(anchor_str) is Some(anchor) else { return false }
  guard state.find_element(source_id) is Some(source_el) else { return false }
  let anchor_point = source_el.get_anchor_point(anchor)
  let (scene_x, scene_y) = get_scene_coords(e)
  let line_id = new_id()
  let new_line = @model.Element::new(
    line_id,
    anchor_point.x,
    anchor_point.y,
    @model.Line(anchor_point.x, anchor_point.y),
  ).with_style(state.get_arrow_style())
  let line_with_conn = {
    ..new_line,
    connections: Some({
      start: Some({ element_id: source_id, anchor }),
      end: None,
    }),
  }
  execute_command(history, state, @model.AddElement(line_with_conn))
  state.start_resize(line_id, @model.LineEnd, scene_x, scene_y)
  true
}

///|
/// リサイズハンドルクリックを処理
fn handle_resize_click(
  state : EditorState,
  get_scene_coords : (@js.Any) -> (Double, Double),
  e : @js.Any,
  dataset : @js.Any,
) -> Bool {
  let data_handle_raw = dataset._get("handle")
  if @js.is_nullish(data_handle_raw) {
    return false
  }
  let handle_str : String = data_handle_raw.cast()
  let element_id_raw = dataset._get("elementId")
  if @js.is_nullish(element_id_raw) {
    return false
  }
  let element_id : String = element_id_raw.cast()
  let (scene_x, scene_y) = get_scene_coords(e)
  let handle = @model.parse_handle_position(handle_str)
  state.start_resize(element_id, handle, scene_x, scene_y)
  true
}

///|
/// 要素クリックを処理
fn handle_element_click(
  state : EditorState,
  id : String,
  scene_x : Double,
  scene_y : Double,
  last_click_time : Ref[Double],
  last_click_element : Ref[String],
  double_click_threshold : Double,
) -> Unit {
  // 子要素の場合は親を取得
  let target_id = match state.get_parent_id(id) {
    Some(parent_id) => parent_id
    None => id
  }
  let now = get_current_time()
  let is_child = state.is_child_element(id)
  let is_text_child = if is_child {
    match state.find_element(id) {
      Some(el) => el.shape is @model.Text(_, _)
      None => false
    }
  } else {
    false
  }
  let dblclick_target = if is_text_child { id } else { target_id }
  if last_click_element.val == dblclick_target &&
    now - last_click_time.val < double_click_threshold {
    // ダブルクリック検出
    last_click_time.val = 0.0
    last_click_element.val = ""
    state.end_drag()
    if is_text_child {
      handle_text_edit(state, id)
    } else {
      handle_double_click(state, target_id)
    }
    return
  }
  last_click_time.val = now
  last_click_element.val = dblclick_target
  let already_selected = state.is_selected(target_id)
  let selected_count = state.selected_ids.get().length()
  if already_selected && selected_count > 1 {
    state.start_multi_drag(scene_x, scene_y)
  } else {
    state.select(Some(target_id))
    state.start_drag(target_id, scene_x, scene_y)
  }
}

///|
/// ダブルクリック時のテキスト編集開始
fn handle_double_click(state : EditorState, element_id : String) -> Unit {
  guard state.find_element(element_id) is Some(el)
  // テキスト要素の場合は直接編集
  if el.shape is @model.Text(content, font_size) {
    // parent_id がない場合は自分自身を親として扱う
    let parent_id = el.parent_id.unwrap_or(element_id)
    state.start_text_edit_existing(
      element_id,
      parent_id,
      el.x,
      el.y,
      content,
      font_size,
    )
    return
  }
  // 親要素の場合：既存のテキスト子要素があるかチェック
  let children = state.get_children(element_id)
  for child in children {
    if child.shape is @model.Text(content, font_size) {
      // 既存テキストを編集
      state.start_text_edit_existing(
        child.id,
        element_id,
        child.x,
        child.y,
        content,
        font_size,
      )
      return
    }
  }
  // テキスト子要素がない場合は新規作成
  let bbox = el.bounding_box()
  let center_x = bbox.x + bbox.width / 2.0
  let center_y = bbox.y + bbox.height / 2.0
  state.start_text_edit(element_id, center_x, center_y)
}

///|
/// テキスト要素の編集開始
fn handle_text_edit(state : EditorState, text_id : String) -> Unit {
  guard state.find_element(text_id) is Some(el)
  guard el.shape is @model.Text(content, font_size)
  // parent_id がない場合は自分自身を親として扱う
  let parent_id = el.parent_id.unwrap_or(text_id)
  state.start_text_edit_existing(
    text_id,
    parent_id,
    el.x,
    el.y,
    content,
    font_size,
  )
}

///|
/// テキスト入力を確定
fn commit_text_edit(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
  text_content : String,
) -> Unit {
  guard state.text_edit.get() is Some(edit_state)
  match edit_state.editing_id {
    Some(text_id) =>
      if text_content == "" {
        if state.find_element(text_id) is Some(el) {
          execute_command(history, state, @model.RemoveElement(el))
        }
      } else if text_content != edit_state.initial_text {
        // UpdateText コマンドを使ってUndoスタックに記録
        execute_command(
          history,
          state,
          @model.UpdateText(text_id, edit_state.initial_text, text_content),
        )
      }
    None =>
      if text_content != "" {
        let text_el = @model.Element::new(
            new_id(),
            edit_state.x,
            edit_state.y,
            @model.Text(text_content, Some(16.0)),
          )
          .with_style(state.get_text_style())
          .with_parent(edit_state.parent_id)
        execute_command(history, state, @model.AddElement(text_el))
      }
  }
  state.end_text_edit()
}

///|
/// mousemove ハンドラを作成
fn create_mousemove_handler(
  state : EditorState,
  get_screen_coords : (@js.Any) -> (Double, Double),
  get_scene_coords : (@js.Any) -> (Double, Double),
) -> (@js.Any) -> Unit {
  fn(e) {
    // コンテキストメニューが開いている場合は移動操作を無効化
    if state.context_menu.get() is Some(_) {
      return
    }

    // マウス位置を更新（キーバインドでの挿入用）
    let (scene_x, scene_y) = get_scene_coords(e)
    state.mouse_scene_pos.set({ x: scene_x, y: scene_y })
    if state.is_panning.get() {
      let (screen_x, screen_y) = get_screen_coords(e)
      state.pan_move(screen_x, screen_y)
      return
    }
    if state.is_placing() {
      // 配置モード中は要素をマウス位置に追従
      state.update_placement({ x: scene_x, y: scene_y })
    } else if state.is_resizing() {
      state.resize_move(scene_x, scene_y)
    } else if state.is_multi_dragging() {
      state.multi_drag_move(scene_x, scene_y)
    } else if state.is_dragging() {
      state.drag_move(scene_x, scene_y)
    } else if state.is_box_selecting() {
      state.update_box_select(scene_x, scene_y)
    }
  }
}

///|
/// mouseup ハンドラを作成
fn create_mouseup_handler(
  state : EditorState,
  history : @model.History,
  get_screen_coords : (@js.Any) -> (Double, Double),
) -> (@js.Any) -> Unit {
  let _ = get_screen_coords // unused but kept for consistency
  fn(_e) {
    if state.is_panning.get() {
      state.end_pan()
      return
    }
    if state.is_box_selecting() {
      state.end_box_select()
      return
    }
    // リサイズ終了時
    if state.resize_state.get() is Some(resize) {
      if state.find_element(resize.element_id) is Some(el) {
        if resize.start_shape != el.shape ||
          resize.start_x != el.x ||
          resize.start_y != el.y {
          let cmd = @model.ResizeElement(
            resize.element_id,
            resize.start_shape,
            el.shape,
          )
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
    // 複数要素ドラッグ終了時
    if state.multi_drag_state.get() is Some(multi_drag) {
      for pos in multi_drag.start_positions {
        let (id, start_x, start_y) = pos
        if state.find_element(id) is Some(el) {
          if start_x != el.x || start_y != el.y {
            let cmd = @model.MoveElement(id, start_x, start_y, el.x, el.y)
            history.undo_stack.push(cmd)
          }
        }
      }
      history.redo_stack.clear()
      state.end_multi_drag()
      return
    }
    // ドラッグ終了時
    if state.drag_state.get() is Some(drag) {
      if state.find_element(drag.element_id) is Some(el) {
        if drag.start_x != el.x || drag.start_y != el.y {
          // Line の場合は終点の変更もコマンドとして記録
          match (drag.start_shape, el.shape) {
            (
              Some(@model.Line(_, _) as old_shape),
              @model.Line(_, _) as new_shape,
            ) => {
              // 接続要素の移動を先に記録（Undoは逆順で実行されるため）
              for pos in drag.connected_start_positions {
                let (id, start_x, start_y) = pos
                if state.find_element(id) is Some(connected_el) {
                  if start_x != connected_el.x || start_y != connected_el.y {
                    let connected_cmd = @model.MoveElement(
                      id,
                      start_x,
                      start_y,
                      connected_el.x,
                      connected_el.y,
                    )
                    history.undo_stack.push(connected_cmd)
                  }
                }
              }
              // Line の終点変更を記録
              if old_shape != new_shape {
                let resize_cmd = @model.ResizeElement(
                  drag.element_id,
                  old_shape,
                  new_shape,
                )
                history.undo_stack.push(resize_cmd)
              }
            }
            _ => ()
          }
          // Line の始点移動を記録
          let cmd = @model.MoveElement(
            drag.element_id,
            drag.start_x,
            drag.start_y,
            el.x,
            el.y,
          )
          history.undo_stack.push(cmd)
          history.redo_stack.clear()
        }
      }
    }
    state.end_drag()
  }
}

///|
/// wheel ハンドラを作成（マウス位置を基準にズーム）
fn create_wheel_handler(
  state : EditorState,
  get_screen_coords : (@js.Any) -> (Double, Double),
) -> (@js.Any) -> Unit {
  fn(e) {
    let _ = e._call("preventDefault", [])
    let delta_y : Double = e._get("deltaY").cast()
    let (screen_x, screen_y) = get_screen_coords(e)
    let zoom_in = delta_y < 0.0
    state.zoom_at(screen_x, screen_y, zoom_in)
  }
}

///|
/// contextmenu ハンドラを作成
fn create_contextmenu_handler(
  state : EditorState,
  get_scene_coords : (@js.Any) -> (Double, Double),
) -> (@js.Any) -> Unit {
  fn(e) {
    let _ = e._call("preventDefault", [])
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let (scene_x, scene_y) = get_scene_coords(e)
    let target = e._get("target")
    // data-id を直接取得、なければ親要素から取得（tspan 対応）
    let data_id_raw = target._get("dataset")._get("id")
    let target_id : String? = if @js.is_nullish(data_id_raw) {
      let closest_id = get_closest_data_id_ffi(target)
      if @js.is_nullish(closest_id) {
        None
      } else {
        Some(closest_id.cast())
      }
    } else {
      Some(data_id_raw.cast())
    }
    if target_id is Some(id) {
      state.select(Some(id))
    }
    state.show_context_menu(
      mouse_event.clientX,
      mouse_event.clientY,
      scene_x,
      scene_y,
      target_id,
    )
  }
}

///|
/// アンカー近くで要素を作成し、配置モードを開始するヘルパー
fn try_start_placement(
  state : EditorState,
  history : @model.History,
  element : @model.Element,
  is_line : Bool,
  anchor_threshold : Double,
) -> Bool {
  let pos = state.mouse_scene_pos.get()
  // アンカー検索
  let anchor_result = state.find_nearest_connection_point(
    pos,
    [],
    anchor_threshold,
  )
  match anchor_result {
    Some((anchor_el, anchor, anchor_point)) => {
      // アンカーポイントを基準に要素を配置（形状に応じて初期サイズを設定）
      let placed_element = match element.shape {
        @model.Line(_, _) =>
          // Line/Arrow: 始点をアンカー位置に設定
          { ..element, x: anchor_point.x, y: anchor_point.y }
        @model.Circle(_) =>
          // Circle: アンカーを中心、最小半径で開始
          {
            ..element,
            x: anchor_point.x,
            y: anchor_point.y,
            shape: @model.Circle(5.0),
          }
        @model.Ellipse(_, _) =>
          // Ellipse: アンカーを中心、最小サイズで開始
          {
            ..element,
            x: anchor_point.x,
            y: anchor_point.y,
            shape: @model.Ellipse(5.0, 5.0),
          }
        @model.Rect(_, _, rx, ry) =>
          // Rect: アンカーを起点、最小サイズで開始
          {
            ..element,
            x: anchor_point.x,
            y: anchor_point.y,
            shape: @model.Rect(10.0, 10.0, rx, ry),
          }
        _ =>
          // その他: そのまま配置
          { ..element, x: anchor_point.x, y: anchor_point.y }
      }
      execute_command(history, state, @model.AddElement(placed_element))
      state.start_placement(
        element.id,
        anchor_el.id,
        anchor,
        anchor_point,
        is_line,
      )
      true
    }
    None => false
  }
}

///|
/// キーボードショートカットを設定
fn setup_keyboard_shortcuts(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  let handler : (@js.Any) -> Unit = fn(e) {
    // テキスト編集中または入力要素にフォーカスがある場合は無視
    if state.text_edit.get() is Some(_) {
      return
    }
    if is_input_focused_ffi() {
      return
    }
    let key : String = e._get("key").cast()
    let ctrl_key : Bool = e._get("ctrlKey").cast()
    let meta_key : Bool = e._get("metaKey").cast()
    let is_cmd = ctrl_key || meta_key

    // マウス位置を取得
    let pos = state.mouse_scene_pos.get()
    match key {
      "Delete" | "Backspace" => {
        let selected_ids = state.selected_ids.get()
        for id in selected_ids {
          if state.find_element(id) is Some(el) {
            execute_command(history, state, @model.RemoveElement(el))
          }
        }
      }
      "Escape" => state.select(None)
      // 1: Rectangle をマウス位置に挿入（アンカー近くなら配置モード）
      "1" => {
        let el_id = new_id()
        let new_rect = @model.Element::new(
          el_id,
          pos.x - 40.0,
          pos.y - 30.0,
          @model.Rect(80.0, 60.0, None, None),
        ).with_style(state.get_default_style())
        if not(try_start_placement(state, history, new_rect, false, 20.0)) {
          // アンカー近くでなければ即時配置
          execute_command(history, state, @model.AddElement(new_rect))
          state.select(Some(el_id))
        }
      }
      // 2: Circle をマウス位置に挿入（アンカー近くなら配置モード）
      "2" => {
        let el_id = new_id()
        let new_circle = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Circle(40.0),
        ).with_style(state.get_default_style())
        if not(try_start_placement(state, history, new_circle, false, 20.0)) {
          execute_command(history, state, @model.AddElement(new_circle))
          state.select(Some(el_id))
        }
      }
      // 3: Ellipse をマウス位置に挿入（アンカー近くなら配置モード）
      "3" => {
        let el_id = new_id()
        let new_ellipse = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Ellipse(60.0, 35.0),
        ).with_style(state.get_default_style())
        if not(try_start_placement(state, history, new_ellipse, false, 20.0)) {
          execute_command(history, state, @model.AddElement(new_ellipse))
          state.select(Some(el_id))
        }
      }
      // 4: Line をマウス位置に挿入（アンカー近くなら配置モード）
      "4" => {
        let el_id = new_id()
        let new_line = @model.Element::new(
          el_id,
          pos.x - 50.0,
          pos.y,
          @model.Line(pos.x + 50.0, pos.y),
        ).with_style(state.get_line_style())
        if not(try_start_placement(state, history, new_line, true, 20.0)) {
          execute_command(history, state, @model.AddElement(new_line))
          state.select(Some(el_id))
        }
      }
      // 5: Arrow をマウス位置に挿入（アンカー近くなら配置モード）
      "5" => {
        let el_id = new_id()
        let new_arrow = @model.Element::new(
          el_id,
          pos.x - 50.0,
          pos.y,
          @model.Line(pos.x + 50.0, pos.y),
        ).with_style(state.get_arrow_style())
        if not(try_start_placement(state, history, new_arrow, true, 20.0)) {
          execute_command(history, state, @model.AddElement(new_arrow))
          state.select(Some(el_id))
        }
      }
      // 6: Text をマウス位置に挿入（アンカー近くなら配置モード）
      "6" => {
        let el_id = new_id()
        let new_text = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Text("Text", Some(16.0)),
        ).with_style(state.get_text_style())
        if not(try_start_placement(state, history, new_text, false, 20.0)) {
          execute_command(history, state, @model.AddElement(new_text))
          state.select(Some(el_id))
        }
      }
      "d" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let selected_ids = state.selected_ids.get()
          let new_ids : Array[String] = []
          for id in selected_ids {
            if state.find_element(id) is Some(el) {
              let dup_id = new_id()
              let new_el = { ..el, id: dup_id, x: el.x + 20.0, y: el.y + 20.0 }
              execute_command(history, state, @model.AddElement(new_el))
              new_ids.push(dup_id)
            }
          }
          state.select_multiple(new_ids)
        }
      "z" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let _ = undo_command(history, state)

        }
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

// ============================================================
// UI レンダリング
// ============================================================

///|
/// エディタ UI をレンダリング（Luna VNode ベース）
fn render_editor_ui_vnode(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
  svg_canvas : @element.DomNode,
  commit_text_input : (String) -> Unit,
) -> @element.DomNode {
  // メインレイアウト（全画面キャンバス + フローティングUI）
  div(
    style="position: relative; width: 100vw; height: 100vh; overflow: hidden;",
    [
      // キャンバス（画面全体）
      div(style="position: absolute; inset: 0;", [
        svg_canvas,
        // テキスト入力
        render_text_input_container(state, commit_text_input),
      ]),
      // フローティングツールバー（上部中央）
      div(
        dyn_style=fn() {
          let is_mobile = state.is_mobile.get()
          if is_mobile {
            "position: fixed; bottom: 60px; left: 50%; transform: translateX(-50%); display: flex; gap: 4px; align-items: center; background: rgba(255,255,255,0.95); padding: 6px 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 11px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 100;"
          } else {
            "position: fixed; top: 12px; left: 50%; transform: translateX(-50%); display: flex; gap: 4px; align-items: center; background: rgba(255,255,255,0.95); padding: 6px 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 11px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 100;"
          }
        },
        [render_embedded_toolbar(state, history, new_id)],
      ),
      // フローティングパネル（デスクトップ: 右端、モバイル: 下部）
      show(fn() { state.panel_visible.get() }, fn() {
        render_floating_panel(state, history)
      }),
      // パネル表示/非表示トグル
      render_panel_toggle(state),
      // コンテキストメニュー
      show(fn() { state.context_menu.get() is Some(_) }, fn() {
        render_context_menu(state, history, new_id)
      }),
    ],
  )
}

///|
/// パネル表示/非表示トグルボタン
fn render_panel_toggle(state : EditorState) -> @element.DomNode {
  button(
    dyn_style=fn() {
      let is_mobile = state.is_mobile.get()
      let visible = state.panel_visible.get()
      let icon_transform = if visible {
        ""
      } else {
        "transform: rotate(180deg);"
      }
      if is_mobile {
        "position: fixed; bottom: 12px; right: 12px; width: 36px; height: 36px; border-radius: 50%; background: rgba(255,255,255,0.95); border: 1px solid #ddd; cursor: pointer; font-size: 14px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 101; " +
        icon_transform
      } else {
        "position: fixed; top: 12px; right: 12px; width: 32px; height: 32px; border-radius: 50%; background: rgba(255,255,255,0.95); border: 1px solid #ddd; cursor: pointer; font-size: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 101; " +
        icon_transform
      }
    },
    on=events().click(fn(_) { state.panel_visible.update(fn(v) { not(v) }) }),
    [text_dyn(fn() { if state.panel_visible.get() { "×" } else { "☰" } })],
  )
}

// ============================================================
// 埋め込みモード
// ============================================================

///|
/// 埋め込みビューをレンダリング（簡易モード）
fn render_embedded_view(
  state : EditorState,
  svg_canvas : @element.DomNode,
  commit_text_input : (String) -> Unit,
) -> @element.DomNode {
  div(style="position: relative; width: 100%;", [
    // SVG コンテナ（アスペクト比維持）
    div(
      dyn_style=fn() {
        let doc_w = state.doc_width.get()
        let doc_h = state.doc_height.get()
        let ratio = doc_h / doc_w * 100.0
        "width: 100%; padding-bottom: \{ratio}%; position: relative;"
      },
      [
        // SVG キャンバス（絶対位置で配置）
        div(style="position: absolute; inset: 0;", [
          svg_canvas,
          // テキスト入力
          render_text_input_container(state, commit_text_input),
        ]),
      ],
    ),
    // 編集ボタン（右上固定）
    button(
      style="position: absolute; top: 8px; right: 8px; padding: 6px 12px; background: rgba(255,255,255,0.95); border: 1px solid #ddd; border-radius: 4px; cursor: pointer; font-size: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
      on=events().click(fn(_) { state.modal_open.set(true) }),
      [text("編集")],
    ),
  ])
}

///|
/// エディタモーダルをレンダリング（フルエディタを別ウィンドウ風に表示）
pub fn render_editor_modal(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  // フルエディタ用の SVG を作成
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }
  let space_pressed : Ref[Bool] = { val: false }
  let last_click_time : Ref[Double] = { val: 0.0 }
  let last_click_element : Ref[String] = { val: "" }
  let double_click_threshold : Double = 300.0
  let commit_text_input = fn(text_content : String) {
    commit_text_edit(state, history, new_id, text_content)
  }
  let on_mousedown = create_mousedown_handler(
    state, history, new_id, get_screen_coords, get_scene_coords, space_pressed, last_click_time,
    last_click_element, double_click_threshold,
  )
  let on_mousemove = create_mousemove_handler(
    state, get_screen_coords, get_scene_coords,
  )
  let on_mouseup = create_mouseup_handler(state, history, get_screen_coords)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)
  let modal_svg = render_svg_canvas_node(
    state, on_mousedown, on_mousemove, on_mouseup, on_contextmenu, on_wheel,
  )

  // モーダルオーバーレイ
  div(
    style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000; display: flex; align-items: center; justify-content: center;",
    [
      // モーダルウィンドウ
      div(
        style="width: 90vw; max-width: 1200px; height: 85vh; background: white; border-radius: 8px; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 4px 24px rgba(0,0,0,0.3);",
        [
          // ヘッダー
          div(
            style="display: flex; justify-content: space-between; align-items: center; padding: 8px 16px; border-bottom: 1px solid #ddd; background: #f8f8f8;",
            [
              div(style="font-weight: 500;", [text("Moonlight Editor")]),
              button(
                style="padding: 4px 12px; background: #f0f0f0; border: 1px solid #ccc; border-radius: 4px; cursor: pointer;",
                on=events().click(fn(_) { state.modal_open.set(false) }),
                [text("閉じる")],
              ),
            ],
          ),
          // エディタ本体
          div(style="flex: 1; display: flex; overflow: hidden;", [
            // キャンバス領域
            div(style="flex: 1; position: relative; min-width: 0;", [
              modal_svg,
              render_text_input_container(state, commit_text_input),
            ]),
            // サイドパネル
            div(
              style="width: 240px; border-left: 1px solid #ddd; overflow-y: auto;",
              [render_floating_panel(state, history)],
            ),
          ]),
          // ツールバー（下部）
          div(
            style="display: flex; gap: 4px; align-items: center; padding: 8px 12px; border-top: 1px solid #ddd; background: #f8f8f8;",
            [render_embedded_toolbar(state, history, new_id)],
          ),
        ],
      ),
    ],
  )
}

///|
/// 埋め込みエディタアプリをレンダリング
fn embedded_editor_app(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  // 埋め込み用の簡易イベントハンドラ（選択・ドラッグ・テキスト編集のみ）
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }
  let space_pressed : Ref[Bool] = { val: false }
  let last_click_time : Ref[Double] = { val: 0.0 }
  let last_click_element : Ref[String] = { val: "" }
  let double_click_threshold : Double = 300.0
  let commit_text_input = fn(text_content : String) {
    commit_text_edit(state, history, new_id, text_content)
  }

  // 簡易ハンドラ（選択・移動・テキスト編集のみ）
  let on_mousedown = create_mousedown_handler(
    state, history, new_id, get_screen_coords, get_scene_coords, space_pressed, last_click_time,
    last_click_element, double_click_threshold,
  )
  let on_mousemove = create_mousemove_handler(
    state, get_screen_coords, get_scene_coords,
  )
  let on_mouseup = create_mouseup_handler(state, history, get_screen_coords)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = fn(_e : @js.Any) { () } // コンテキストメニュー無効
  let svg_canvas = render_svg_canvas_node(
    state, on_mousedown, on_mousemove, on_mouseup, on_contextmenu, on_wheel,
  )
  div(style="width: 100%;", [
    // 埋め込みビュー
    render_embedded_view(state, svg_canvas, commit_text_input),
    // モーダル（表示時のみ）
    show(fn() { state.modal_open.get() }, fn() {
      render_editor_modal(state, history, new_id)
    }),
  ])
}

///|
/// テキスト入力コンテナ（FFI 要素を Effect で手動管理）
fn render_text_input_container(
  state : EditorState,
  commit : (String) -> Unit,
) -> @element.DomNode {
  let container_ref : Ref[@js.Any?] = { val: None }
  let current_textarea : Ref[@js.Any?] = { val: None }

  // Effect で text_edit の変更を監視
  let _ = @luna.effect(fn() {
    let text_edit = state.text_edit.get()

    // コンテナがまだレンダリングされていない場合は何もしない
    let container = match container_ref.val {
      Some(c) => c
      None => return
    }

    // 既存の textarea を削除
    if current_textarea.val is Some(textarea) {
      remove_child_safe_ffi(container, textarea)
      current_textarea.val = None
    }

    // 新しい textarea を作成
    if text_edit is Some(edit_state) {
      let vp = state.viewport.get()
      let theme = state.theme_mode.get()
      let text_color = match theme {
        @model.Dark => "#ffffff"
        @model.Light => "#000000"
      }
      let (text_x, text_y, max_width) : (Double, Double, Double) = match
        state.find_element(edit_state.parent_id) {
        Some(parent) => {
          let bbox = parent.bounding_box()
          let center_x = bbox.x + bbox.width / 2.0
          let center_y = bbox.y + bbox.height / 2.0
          (center_x, center_y, bbox.width * vp.zoom - 16.0)
        }
        None => (edit_state.x, edit_state.y, 200.0)
      }
      let screen_pos = vp.scene_to_screen(text_x, text_y)
      let clamped_width = if max_width < 40.0 { 40.0 } else { max_width }
      // フォントサイズをズーム率に合わせてスケール
      let base_font_size = match edit_state.font_size {
        Some(size) => size
        None => 16.0
      }
      let scaled_font_size = base_font_size * vp.zoom
      let scaled_min_height = 19.0 * vp.zoom
      let scaled_max_height = 100.0 * vp.zoom
      let style = "position: absolute; left: \{screen_pos.x}px; top: \{screen_pos.y}px; transform: translate(-50%, -50%); width: \{clamped_width}px; min-height: \{scaled_min_height}px; max-height: \{scaled_max_height}px; padding: 0; border: none; background: transparent; color: \{text_color}; font-family: sans-serif; font-size: \{scaled_font_size}px; line-height: 1.2; text-align: center; outline: none; box-sizing: border-box; resize: none; overflow: hidden; caret-color: currentColor;"
      let textarea = create_textarea_ffi(
        style,
        edit_state.initial_text,
        fn(value) { commit(value) },
        fn(_) { state.text_edit.set(None) },
      )
      append_child_ffi(container, textarea)
      current_textarea.val = Some(textarea)
    }
  })
  @element.create_element(
    "div",
    [
      (
        "style",
        @element.Static(
          "position: absolute; top: 0; left: 0; pointer-events: none;",
        ),
      ),
      ("__ref", @element.Handler(fn(el) { container_ref.val = Some(el) })),
    ],
    [],
  )
}

///|
/// ツールバーボタン用のユニーク ID カウンター
let toolbar_btn_id_counter : Ref[Int] = { val: 0 }

///|
/// SVG アイコンを作成するヘルパー
fn svg_icon(path_d : String, size : Int) -> @element.DomNode {
  let size_str = size.to_string()
  @element.create_element_ns(
    @element.svg_ns,
    "svg",
    [
      ("width", @element.Static(size_str)),
      ("height", @element.Static(size_str)),
      ("viewBox", @element.Static("0 0 24 24")),
      ("fill", @element.Static("none")),
      ("stroke", @element.Static("currentColor")),
      ("stroke-width", @element.Static("2")),
      ("stroke-linecap", @element.Static("round")),
      ("stroke-linejoin", @element.Static("round")),
      ("style", @element.Static("display: block;")),
    ],
    [
      @element.create_element_ns(
        @element.svg_ns,
        "path",
        [("d", @element.Static(path_d))],
        [],
      ),
    ],
  )
}

///|
/// ツールバーボタン（アイコン + キーバインド + Popover ツールチップ）
fn toolbar_button(
  icon : @element.DomNode,
  shortcut : String?,
  tooltip : String,
  on_click : () -> Unit,
  theme? : @model.Theme = @model.Theme::light(),
) -> @element.DomNode {
  toolbar_btn_id_counter.val = toolbar_btn_id_counter.val + 1
  let popover_id = "tooltip-\{toolbar_btn_id_counter.val}"
  let btn_style = "display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; padding: 4px 6px; cursor: pointer; border: 1px solid \{theme.ui_border}; border-radius: 4px; background: \{theme.ui_bg}; min-width: 36px; height: 40px; position: relative; color: \{theme.ui_text};"
  let shortcut_style = "color: \{theme.ui_text_muted}; font-size: 9px; font-family: system-ui, sans-serif; line-height: 1;"
  let popover_style = "position: fixed; margin: 0; padding: 4px 8px; background: #333; color: #fff; font-size: 11px; border-radius: 4px; white-space: nowrap; border: none;"
  div(style="position: relative; display: inline-block;", [
    @element.create_element(
      "button",
      [
        ("style", @element.Static(btn_style)),
        ("aria-label", @element.Static(tooltip)),
        ("click", @element.Handler(fn(_) { on_click() })),
        (
          "mouseenter",
          @element.Handler(fn(e) { show_popover_at_button(popover_id, e) }),
        ),
        ("mouseleave", @element.Handler(fn(_) { hide_popover(popover_id) })),
      ],
      match shortcut {
        Some(key) => [icon, @element.span(style=shortcut_style, [text(key)])]
        None => [icon]
      },
    ),
    // Popover ツールチップ
    div(
      style=popover_style,
      attrs=[
        ("id", @element.AttrString(popover_id)),
        ("popover", @element.AttrString("manual")),
      ],
      [text(tooltip)],
    ),
  ])
}

///|
/// 埋め込みツールバー（SVGアイコン + キーバインド表示）
fn render_embedded_toolbar(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  let theme = state.get_theme()
  let sep_style = "width: 1px; height: 24px; background: \{theme.ui_border}; margin: 0 2px;"
  let id_counter : Ref[Int] = { val: 0 }

  // アイコンパス定義
  let icon_rect = "M3 3h18v18H3z"
  let icon_circle = "M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0"
  let icon_ellipse = "M12 12m-9 0a9 5 0 1 0 18 0a9 5 0 1 0 -18 0"
  let icon_line = "M5 19L19 5"
  let icon_arrow = "M5 19L19 5M19 5L19 12M19 5L12 5"
  let icon_text = "M4 7V4h16v3M9 20h6M12 4v16"
  let icon_undo = "M3 7v6h6M3 13a9 9 0 1 0 3-7.5"
  let icon_redo = "M21 7v6h-6M21 13a9 9 0 1 1 -3-7.5"
  let icon_zoom_in = "M21 21l-6-6m2-5a7 7 0 1 1 -14 0a7 7 0 0 1 14 0zM10 7v6M7 10h6"
  let icon_zoom_out = "M21 21l-6-6m2-5a7 7 0 1 1 -14 0a7 7 0 0 1 14 0zM7 10h6"
  let icon_reset = "M3 12a9 9 0 1 0 9-9M3 3v6h6"
  let icon_grid = "M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z"
  let icon_export = "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5l5-5M12 15V3"
  div(style="display: flex; gap: 3px; align-items: center;", [
    // 図形追加ボタン
    toolbar_button(
      svg_icon(icon_rect, 16),
      Some("1"),
      "Rectangle",
      fn() {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_rect = @model.Element::new(
          el_id,
          150.0 + offset,
          150.0 + offset,
          @model.Rect(80.0, 60.0, None, None),
        ).with_style(state.get_default_style())
        execute_command(history, state, @model.AddElement(new_rect))
        state.select(Some(el_id))
      },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_circle, 16),
      Some("2"),
      "Circle",
      fn() {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_circle = @model.Element::new(
          el_id,
          200.0 + offset,
          200.0 + offset,
          @model.Circle(40.0),
        ).with_style(state.get_default_style())
        execute_command(history, state, @model.AddElement(new_circle))
        state.select(Some(el_id))
      },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_ellipse, 16),
      Some("3"),
      "Ellipse",
      fn() {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_ellipse = @model.Element::new(
          el_id,
          180.0 + offset,
          120.0 + offset,
          @model.Ellipse(60.0, 35.0),
        ).with_style(state.get_default_style())
        execute_command(history, state, @model.AddElement(new_ellipse))
        state.select(Some(el_id))
      },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_line, 16),
      Some("4"),
      "Line",
      fn() {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_line = @model.Element::new(
          el_id,
          50.0 + offset,
          220.0,
          @model.Line(180.0 + offset, 260.0),
        ).with_style(state.get_line_style())
        execute_command(history, state, @model.AddElement(new_line))
        state.select(Some(el_id))
      },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_arrow, 16),
      Some("5"),
      "Arrow",
      fn() {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_arrow = @model.Element::new(
          el_id,
          50.0 + offset,
          240.0,
          @model.Line(180.0 + offset, 280.0),
        ).with_style(state.get_arrow_style())
        execute_command(history, state, @model.AddElement(new_arrow))
        state.select(Some(el_id))
      },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_text, 16),
      Some("6"),
      "Text",
      fn() {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_text = @model.Element::new(
          el_id,
          100.0 + offset,
          200.0 + offset * 0.75,
          @model.Text("Hello", Some(24.0)),
        ).with_style(state.get_text_style())
        execute_command(history, state, @model.AddElement(new_text))
        state.select(Some(el_id))
      },
      theme~,
    ),
    // セパレータ
    @element.span(style=sep_style, []),
    // Undo/Redo
    toolbar_button(
      svg_icon(icon_undo, 16),
      Some("⌘Z"),
      "Undo",
      fn() {
        let _ = undo_command(history, state)

      },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_redo, 16),
      Some("⌘Y"),
      "Redo",
      fn() {
        let _ = redo_command(history, state)

      },
      theme~,
    ),
    // セパレータ
    @element.span(style=sep_style, []),
    // ズームコントロール
    toolbar_button(
      svg_icon(icon_zoom_out, 16),
      None,
      "Zoom Out",
      fn() { state.zoom_out() },
      theme~,
    ),
    @element.span(
      style="min-width: 44px; text-align: center; font-size: 11px; font-weight: 500; color: \{theme.ui_text};",
      [
        text_dyn(fn() {
          let zoom = state.viewport.get().zoom
          "\{(zoom * 100.0).to_int()}%"
        }),
      ],
    ),
    toolbar_button(
      svg_icon(icon_zoom_in, 16),
      None,
      "Zoom In",
      fn() { state.zoom_in() },
      theme~,
    ),
    toolbar_button(
      svg_icon(icon_reset, 16),
      None,
      "Fit to Canvas",
      fn() { state.reset_viewport() },
      theme~,
    ),
    // セパレータ
    @element.span(style=sep_style, []),
    // グリッドスナップ（トグルボタン + Popover）
    {
      toolbar_btn_id_counter.val = toolbar_btn_id_counter.val + 1
      let snap_popover_id = "tooltip-\{toolbar_btn_id_counter.val}"
      let snap_popover_style = "position: fixed; margin: 0; padding: 4px 8px; background: #333; color: #fff; font-size: 11px; border-radius: 4px; white-space: nowrap; border: none;"
      let is_dark = state.theme_mode.get() == @model.Dark
      let enabled_bg = if is_dark { "#1e3a5f" } else { "#e3f2fd" }
      let enabled_border = if is_dark { "#4a9eff" } else { "#2196f3" }
      let enabled_color = if is_dark { "#60a5fa" } else { "#1976d2" }
      div(style="position: relative; display: inline-block;", [
        @element.create_element(
          "button",
          [
            (
              "style",
              @element.Dynamic(fn() {
                let enabled = state.grid_enabled.get()
                let base = "display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; padding: 4px 6px; cursor: pointer; border: 1px solid; border-radius: 4px; min-width: 36px; height: 40px;"
                if enabled {
                  base +
                  "background: \{enabled_bg}; border-color: \{enabled_border}; color: \{enabled_color};"
                } else {
                  base +
                  "background: \{theme.ui_bg}; border-color: \{theme.ui_border}; color: \{theme.ui_text_muted};"
                }
              }),
            ),
            ("aria-label", @element.Static("Grid Snap")),
            ("click", @element.Handler(fn(_) { state.toggle_grid() })),
            (
              "mouseenter",
              @element.Handler(fn(e) {
                show_popover_at_button(snap_popover_id, e)
              }),
            ),
            (
              "mouseleave",
              @element.Handler(fn(_) { hide_popover(snap_popover_id) }),
            ),
          ],
          [
            svg_icon(icon_grid, 16),
            @element.span(
              style="color: inherit; font-size: 9px; line-height: 1;",
              [text("Snap")],
            ),
          ],
        ),
        div(
          style=snap_popover_style,
          attrs=[
            ("id", @element.AttrString(snap_popover_id)),
            ("popover", @element.AttrString("manual")),
          ],
          [text("Grid Snap")],
        ),
      ])
    },
    // セパレータ
    @element.span(style=sep_style, []),
    // エクスポート
    toolbar_button(
      svg_icon(icon_export, 16),
      None,
      "Export SVG",
      fn() {
        let svg_str = elements_to_svg(
          state.elements.get(),
          canvas_width,
          canvas_height,
        )
        download_file(svg_str, "drawing.svg", "image/svg+xml")
      },
      theme~,
    ),
  ])
}

// =============================================================================
// SVG キャンバス（Luna VNode + for_each による差分更新）
// =============================================================================

///|
/// SVG キャンバスを作成（Luna VNode + for_each による差分更新）
fn render_svg_canvas_node(
  state : EditorState,
  on_mousedown : (@js.Any) -> Unit,
  on_mousemove : (@js.Any) -> Unit,
  on_mouseup : (@js.Any) -> Unit,
  on_contextmenu : (@js.Any) -> Unit,
  on_wheel : (@js.Any) -> Unit,
) -> @element.DomNode {
  // 要素 ID リスト（for_each のキーとして使用）
  // Line/Arrow を最後に描画（常に上に表示）するためソート
  let element_ids = @luna.memo(fn() {
    let elements = state.elements.get()
    let non_lines : Array[String] = []
    let lines : Array[String] = []
    for el in elements {
      if el.shape is @model.Line(_, _) {
        lines.push(el.id)
      } else {
        non_lines.push(el.id)
      }
    }
    non_lines.append(lines)
    non_lines
  })

  // SVG 子要素
  let children : Array[@element.DomNode] = []

  // 矢印マーカーの defs（静的）+ ドキュメントシャドウフィルタ
  let defs_node : @js_dom.Node = create_arrow_defs().cast()
  children.push(@element.static_node(defs_node))
  // ドキュメントシャドウフィルタ（テーマに応じて変化）
  children.push(
    create_doc_shadow_filter_node(state.theme_mode.get() == @model.Dark),
  )

  // Canvas 背景（境界外グレー + ドキュメント境界）
  children.push(render_canvas_background_vnode(state))

  // グリッド線
  children.push(
    @element.show(fn() { state.grid_enabled.get() }, fn() {
      render_grid_vnode(state)
    }),
  )

  // 要素を for_each で描画（ID ベースの差分更新）
  children.push(
    @element.for_each(fn() { element_ids() }, fn(id, _idx) {
      render_element_vnode(state, id)
    }),
  )

  // 選択ハンドル・アンカー
  children.push(render_selection_overlay(state))

  // 矩形選択ボックス
  children.push(
    @element.show(fn() { state.box_select.get() is Some(_) }, fn() {
      render_box_select_vnode(state)
    }),
  )

  // 線ドラッグ中のアンカーポイント
  children.push(
    @element.show(
      fn() {
        match state.resize_state.get() {
          Some(resize) => resize.start_shape is @model.Line(_, _)
          None => false
        }
      },
      fn() { render_all_anchors_vnode(state) },
    ),
  )

  // 接続ハイライト
  children.push(
    @element.show(fn() { state.pending_connection.get() is Some(_) }, fn() {
      render_connection_highlight_vnode(state)
    }),
  )

  // SVG 属性（100% サイズ、viewBox は動的）
  let svg_attrs : Array[(String, @element.AttrValue)] = [
    ("width", @element.Static("100%")),
    ("height", @element.Static("100%")),
    (
      "viewBox",
      @element.Dynamic(fn() {
        let vp = state.viewport.get()
        let cw = state.canvas_width.get().to_double()
        let ch = state.canvas_height.get().to_double()
        let vb_width = cw / vp.zoom
        let vb_height = ch / vp.zoom
        "\{vp.scroll_x} \{vp.scroll_y} \{vb_width} \{vb_height}"
      }),
    ),
    (
      "style",
      @element.Dynamic(fn() {
        let theme = state.get_theme()
        "border: 1px solid #ccc; user-select: none; overflow: hidden; --ml-stroke: \{theme.stroke}; --ml-fill: \{theme.fill}; --ml-text: \{theme.text};"
      }),
    ),
    ("mousedown", @element.Handler(on_mousedown)),
    ("mousemove", @element.Handler(on_mousemove)),
    ("mouseup", @element.Handler(on_mouseup)),
    ("contextmenu", @element.Handler(on_contextmenu)),
    ("wheel", @element.Handler(on_wheel)),
    // ResizeObserver で canvas サイズを更新し、初回はドキュメントを中央に配置
    (
      "__ref",
      @element.Handler(fn(svg_el) {
        let is_first_resize : Ref[Bool] = { val: true }
        observe_resize_ffi(svg_el, fn(width : Double, height : Double) {
          let w = width.to_int()
          let h = height.to_int()
          if w > 0 && h > 0 {
            state.canvas_width.set(w)
            state.canvas_height.set(h)
            // 初回のみドキュメントを中央に配置
            if is_first_resize.val {
              is_first_resize.val = false
              state.fit_to_canvas()
            }
          }
        })
      }),
    ),
  ]
  @element.create_element_ns(@element.svg_ns, "svg", svg_attrs, children)
}
