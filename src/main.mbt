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
  add_sample_shapes(state, new_id)

  // SVG コンテナへの参照
  let svg_ref : Ref[@js.Any?] = { val: None }

  // Space キーが押されているか
  let space_pressed : Ref[Bool] = { val: false }

  // Space キーの監視を設定
  setup_space_key_listener(state, space_pressed)

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
    state, history, new_id, get_screen_coords, get_scene_coords,
    space_pressed, last_click_time, last_click_element, double_click_threshold,
  )
  let on_mousemove = create_mousemove_handler(state, get_screen_coords, get_scene_coords)
  let on_mouseup = create_mouseup_handler(state, history, get_screen_coords)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)

  // 初期 SVG を作成
  let initial_children : Array[@js.Any] = []
  let elements = state.elements.get()
  for el in elements {
    initial_children.push(render_element(el, state.is_selected(el.id)))
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

  // SVG 再描画関数
  let redraw_svg = fn() {
    redraw_svg_content(state, svg_ref, canvas_width, canvas_height)
  }

  // Signal の変更を監視して再描画
  setup_redraw_effect(state, redraw_svg)

  // Viewport の変更を監視して viewBox を更新
  setup_viewport_effect(state, svg_ref, canvas_width, canvas_height, redraw_svg)

  // キーボードショートカット
  setup_keyboard_shortcuts(state, history, new_id)

  // UI
  render_editor_ui(state, history, new_id, svg, commit_text_input)
}

// ============================================================
// 初期化ヘルパー
// ============================================================

///|
/// サンプル図形を追加
fn add_sample_shapes(state : EditorState, new_id : () -> String) -> Unit {
  let rect1 = @model.Element::new(
    new_id(),
    50.0,
    50.0,
    @model.Rect(80.0, 60.0, None, None),
  ).with_style({
    fill: Some("transparent"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  })
  let rect2 = @model.Element::new(
    new_id(),
    180.0,
    120.0,
    @model.Rect(70.0, 70.0, Some(8.0), Some(8.0)),
  ).with_style({
    fill: Some("transparent"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  })
  let circle1 = @model.Element::new(new_id(), 320.0, 80.0, @model.Circle(35.0)).with_style({
    fill: Some("transparent"),
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  })
  state.add_element_raw(rect1)
  state.add_element_raw(rect2)
  state.add_element_raw(circle1)
}

///|
/// Space キーリスナーを設定
fn setup_space_key_listener(state : EditorState, space_pressed : Ref[Bool]) -> Unit {
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
    state.hide_context_menu()

    // Space キーが押されていればパンを開始
    if space_pressed.val {
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

    let data_id_raw = dataset._get("id")
    let data_id : String? = if @js.is_nullish(data_id_raw) {
      None
    } else {
      Some(data_id_raw.cast())
    }

    let (scene_x, scene_y) = get_scene_coords(e)
    if data_id is Some(id) {
      handle_element_click(
        state, id, scene_x, scene_y,
        last_click_time, last_click_element, double_click_threshold,
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
  ).with_style({
    fill: None,
    stroke: Some("#000000"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: Some(@model.Arrow),
  })
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
  if last_click_element.val == dblclick_target && now - last_click_time.val < double_click_threshold {
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
  let bbox = el.bounding_box()
  let center_x = bbox.x + bbox.width / 2.0
  let center_y = bbox.y + bbox.height / 2.0
  state.start_text_edit(element_id, center_x, center_y)
}

///|
/// テキスト要素の編集開始
fn handle_text_edit(state : EditorState, text_id : String) -> Unit {
  guard state.find_element(text_id) is Some(el)
  guard el.shape is @model.Text(content, _)
  guard el.parent_id is Some(parent_id)
  state.start_text_edit_existing(text_id, parent_id, el.x, el.y, content)
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
    Some(text_id) => {
      if text_content == "" {
        if state.find_element(text_id) is Some(el) {
          execute_command(history, state, @model.RemoveElement(el))
        }
      } else if text_content != edit_state.initial_text {
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
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        }).with_parent(edit_state.parent_id)
        execute_command(history, state, @model.AddElement(text_el))
      }
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
    // マウス位置を更新（キーバインドでの挿入用）
    let (scene_x, scene_y) = get_scene_coords(e)
    state.mouse_scene_pos.set({ x: scene_x, y: scene_y })

    if state.is_panning.get() {
      let (screen_x, screen_y) = get_screen_coords(e)
      state.pan_move(screen_x, screen_y)
      return
    }
    if state.is_resizing() {
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
        if resize.start_shape != el.shape || resize.start_x != el.x || resize.start_y != el.y {
          let cmd = @model.ResizeElement(resize.element_id, resize.start_shape, el.shape)
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
            (Some(@model.Line(_, _) as old_shape), @model.Line(_, _) as new_shape) => {
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
    let data_id_raw = target._get("dataset")._get("id")
    let target_id : String? = if @js.is_nullish(data_id_raw) {
      None
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

// ============================================================
// 描画関数
// ============================================================

///|
/// SVG コンテンツを再描画
fn redraw_svg_content(
  state : EditorState,
  svg_ref : Ref[@js.Any?],
  canvas_width : Int,
  canvas_height : Int,
) -> Unit {
  guard svg_ref.val is Some(svg)
  clear_children_ffi(svg)

  // 矢印マーカーの defs を追加
  let defs = create_arrow_defs()
  append_child_ffi(svg, defs)

  // グリッド線を描画
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

  // 要素を描画
  let elements = state.elements.get()
  for el in elements {
    let is_selected = state.is_selected(el.id)
    let child = render_element(el, is_selected)
    append_child_ffi(svg, child)
  }

  // 選択中の要素のアンカーポイントとリサイズハンドルを描画
  let selected_ids = state.selected_ids.get()
  for id in selected_ids {
    if state.find_element(id) is Some(el) {
      let anchors = render_element_anchors(el)
      for anchor in anchors {
        append_child_ffi(svg, anchor)
      }
      if selected_ids.length() == 1 {
        let handles = render_resize_handles(el)
        for handle in handles {
          append_child_ffi(svg, handle)
        }
      }
    }
  }

  // 矩形選択ボックスを描画
  if state.box_select.get() is Some(box_state) {
    let box_el = render_selection_box(box_state)
    append_child_ffi(svg, box_el)
  }

  // 線の端点ドラッグ中はアンカーポイントを可視化
  if state.resize_state.get() is Some(resize) {
    if resize.start_shape is @model.Line(_, _) {
      let anchors = render_all_anchor_points(state.elements.get(), resize.element_id)
      for anchor in anchors {
        append_child_ffi(svg, anchor)
      }
    }
  }

  // 接続ポイントのハイライトを描画
  if state.pending_connection.get() is Some(pending) {
    let highlight = render_connection_highlight(pending.point)
    append_child_ffi(svg, highlight)
  }
}

///|
/// 再描画エフェクトを設定
fn setup_redraw_effect(state : EditorState, redraw_svg : () -> Unit) -> Unit {
  let is_first_run : Ref[Bool] = { val: true }
  let _ = @luna.effect(fn() {
    let _ = state.elements.get()
    let _ = state.selected_ids.get()
    let _ = state.grid_enabled.get()
    let _ = state.box_select.get()
    let _ = state.pending_connection.get()
    let _ = state.resize_state.get()
    if is_first_run.val {
      is_first_run.val = false
      return
    }
    redraw_svg()
  })
}

///|
/// ビューポートエフェクトを設定
fn setup_viewport_effect(
  state : EditorState,
  svg_ref : Ref[@js.Any?],
  canvas_width : Int,
  canvas_height : Int,
  redraw_svg : () -> Unit,
) -> Unit {
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
      redraw_svg()
    }
  })
}

///|
/// キーボードショートカットを設定
fn setup_keyboard_shortcuts(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  let handler : (@js.Any) -> Unit = fn(e) {
    if state.text_edit.get() is Some(_) {
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
      // 1: Rectangle をマウス位置に挿入
      "1" => {
        let el_id = new_id()
        let new_rect = @model.Element::new(
          el_id,
          pos.x - 40.0,
          pos.y - 30.0,
          @model.Rect(80.0, 60.0, None, None),
        ).with_style({
          fill: Some("transparent"),
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_rect))
        state.select(Some(el_id))
      }
      // 2: Circle をマウス位置に挿入
      "2" => {
        let el_id = new_id()
        let new_circle = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Circle(40.0),
        ).with_style({
          fill: Some("transparent"),
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_circle))
        state.select(Some(el_id))
      }
      // 3: Line をマウス位置に挿入
      "3" => {
        let el_id = new_id()
        let new_line = @model.Element::new(
          el_id,
          pos.x - 50.0,
          pos.y,
          @model.Line(pos.x + 50.0, pos.y),
        ).with_style({
          fill: None,
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: Some(@model.Arrow),
        })
        execute_command(history, state, @model.AddElement(new_line))
        state.select(Some(el_id))
      }
      // 4: Text をマウス位置に挿入
      "4" => {
        let el_id = new_id()
        let new_text = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Text("Text", Some(16.0)),
        ).with_style({
          fill: Some("#000000"),
          stroke: None,
          stroke_width: None,
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_text))
        state.select(Some(el_id))
      }
      "d" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let selected_ids = state.selected_ids.get()
          let new_ids : Array[String] = []
          for id in selected_ids {
            if state.find_element(id) is Some(el) {
              let dup_id = new_id()
              let new_el = {
                ..el,
                id: dup_id,
                x: el.x + 20.0,
                y: el.y + 20.0,
              }
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
/// エディタ UI をレンダリング
fn render_editor_ui(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
  svg : @js.Any,
  commit_text_input : (String) -> Unit,
) -> @element.DomNode {
  div([
    // タイトル
    @element.h1(style="margin: 0 0 8px 0; font-size: 18px;", [text("Moonlight SVG Editor")]),
    // メインエリア
    div(style="display: flex; gap: 12px;", [
      // サイドバー
      render_sidebar(state, history, canvas_height),
      // キャンバスエリア
      div([
        // ツールバー（SVG上部）
        div(style="display: flex; gap: 4px; align-items: center; background: #f8f8f8; padding: 4px 6px; border: 1px solid #ddd; border-bottom: none; border-radius: 4px 4px 0 0; font-size: 11px;", [
          render_embedded_toolbar(state, history, new_id),
        ]),
        // SVG コンテナ
        div(style="position: relative;", [
          svg_to_dom_node(svg),
          // コンテキストメニュー
          show(
            fn() { state.context_menu.get() is Some(_) },
            fn() { render_context_menu(state, history, new_id) },
          ),
          // テキスト入力
          show(
            fn() { state.text_edit.get() is Some(_) },
            fn() { render_text_input(state, commit_text_input) },
          ),
        ]),
      ]),
    ]),
  ])
}

///|
/// 埋め込みツールバー（コンパクト版）
fn render_embedded_toolbar(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  let btn_style = "padding: 2px 6px; font-size: 10px; cursor: pointer; border: 1px solid #ccc; border-radius: 3px; background: #fff;"
  let sep_style = "width: 1px; height: 16px; background: #ddd; margin: 0 4px;"
  let id_counter : Ref[Int] = { val: 0 }

  div(style="display: flex; gap: 4px; align-items: center;", [
    // 図形追加ボタン
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Add Rectangle"))],
      on=events().click(fn(_) {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_rect = @model.Element::new(
          el_id,
          150.0 + offset,
          150.0 + offset,
          @model.Rect(80.0, 60.0, None, None),
        ).with_style({
          fill: Some("transparent"),
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_rect))
        state.select(Some(el_id))
      }),
      [text("Rect (1)")],
    ),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Add Circle"))],
      on=events().click(fn(_) {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_circle = @model.Element::new(
          el_id,
          200.0 + offset,
          200.0 + offset,
          @model.Circle(40.0),
        ).with_style({
          fill: Some("transparent"),
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_circle))
        state.select(Some(el_id))
      }),
      [text("Circle (2)")],
    ),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Add Ellipse"))],
      on=events().click(fn(_) {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_ellipse = @model.Element::new(
          el_id,
          180.0 + offset,
          120.0 + offset,
          @model.Ellipse(60.0, 35.0),
        ).with_style({
          fill: Some("transparent"),
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_ellipse))
        state.select(Some(el_id))
      }),
      [text("Ellipse")],
    ),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Add Line"))],
      on=events().click(fn(_) {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_line = @model.Element::new(
          el_id,
          50.0 + offset,
          220.0,
          @model.Line(180.0 + offset, 260.0),
        ).with_style({
          fill: None,
          stroke: Some("#000000"),
          stroke_width: Some(2.0),
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: Some(@model.Arrow),
        })
        execute_command(history, state, @model.AddElement(new_line))
        state.select(Some(el_id))
      }),
      [text("Line (3)")],
    ),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Add Text"))],
      on=events().click(fn(_) {
        id_counter.val = id_counter.val + 1
        let el_id = new_id()
        let offset = id_counter.val.to_double() * 20.0
        let new_text = @model.Element::new(
          el_id,
          100.0 + offset,
          200.0 + offset * 0.75,
          @model.Text("Hello", Some(24.0)),
        ).with_style({
          fill: Some("#000000"),
          stroke: None,
          stroke_width: None,
          opacity: None,
          stroke_dasharray: None,
          marker_start: None,
          marker_end: None,
        })
        execute_command(history, state, @model.AddElement(new_text))
        state.select(Some(el_id))
      }),
      [text("Text (4)")],
    ),
    // セパレータ
    @element.span(style=sep_style, []),
    // Undo/Redo
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Undo"))],
      on=events().click(fn(_) { let _ = undo_command(history, state) }),
      [text("Undo")],
    ),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Redo"))],
      on=events().click(fn(_) { let _ = redo_command(history, state) }),
      [text("Redo")],
    ),
    // セパレータ
    @element.span(style=sep_style, []),
    // ズームコントロール
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Zoom Out"))],
      on=events().click(fn(_) { state.zoom_out() }),
      [text("-")],
    ),
    @element.span(style="min-width: 36px; text-align: center;", [
      text_dyn(fn() {
        let zoom = state.viewport.get().zoom
        "\{(zoom * 100.0).to_int()}%"
      }),
    ]),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Zoom In"))],
      on=events().click(fn(_) { state.zoom_in() }),
      [text("+")],
    ),
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Reset Zoom"))],
      on=events().click(fn(_) { state.reset_viewport() }),
      [text("Reset")],
    ),
    // セパレータ
    @element.span(style=sep_style, []),
    // グリッドスナップ
    @element.label(style="display: inline-flex; align-items: center; gap: 2px; cursor: pointer;", [
      input(
        type_="checkbox",
        attrs=[("aria-label", @element.AttrString("Grid Snap"))],
        on=events().change(fn(_) { state.toggle_grid() }),
      ),
      text("Grid Snap"),
    ]),
    // セパレータ
    @element.span(style=sep_style, []),
    // エクスポート
    button(
      style=btn_style,
      attrs=[("aria-label", @element.AttrString("Export SVG"))],
      on=events().click(fn(_) {
        let svg_str = elements_to_svg(
          state.elements.get(),
          canvas_width,
          canvas_height,
        )
        download_file(svg_str, "drawing.svg", "image/svg+xml")
      }),
      [text("Export")],
    ),
  ])
}

