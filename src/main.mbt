// Moonlight - 軽量 SVG エディタ

///|
using @element {div, button, text, text_dyn, events, show, input}

///|
/// キャンバスサイズ
let canvas_width : Int = 400

///|
/// クリップボード（コピーした要素を保持）
let clipboard : Ref[Array[@model.Element]] = { val: [] }

///|
let canvas_height : Int = 300

///|
/// IndexedDB 設定
let db_name : String = "moonlight-editor"

///|
let store_name : String = "scenes"

///|
let scene_key : String = "current"

///|
/// ID カウンター（Signal で管理）
fn create_id_counter() -> @luna.Signal[Int] {
  @luna.signal(0)
}

// ============================================================
// JavaScript 埋め込み用 API
// ============================================================

///|
/// エディタオプション（JavaScript から渡される）
pub struct EmbedOptions {
  width : Int
  height : Int
  theme : String
  is_readonly : Bool
}

///|
/// デフォルトオプション
pub fn EmbedOptions::default() -> EmbedOptions {
  { width: 400, height: 300, theme: "light", is_readonly: false }
}

///|
/// JavaScript オブジェクトからオプションを作成
pub fn EmbedOptions::from_js(js_obj : @js.Any) -> EmbedOptions {
  let width = get_int_or_default(js_obj, "width", 400)
  let height = get_int_or_default(js_obj, "height", 300)
  let theme = get_string_or_default(js_obj, "theme", "light")
  let is_readonly = get_bool_or_default(js_obj, "readonly", false)
  { width, height, theme, is_readonly }
}

///|
extern "js" fn get_int_or_default(obj : @js.Any, key : String, default_val : Int) -> Int =
  #| (obj, key, def) => typeof obj[key] === 'number' ? obj[key] : def

///|
extern "js" fn get_string_or_default(obj : @js.Any, key : String, default_val : String) -> String =
  #| (obj, key, def) => typeof obj[key] === 'string' ? obj[key] : def

///|
extern "js" fn get_bool_or_default(obj : @js.Any, key : String, default_val : Bool) -> Bool =
  #| (obj, key, def) => typeof obj[key] === 'boolean' ? obj[key] : def

///|
/// JavaScript 埋め込み用エディタを作成
/// container: DOM コンテナ要素
/// options: エディタオプション
/// 戻り値: エディタハンドル
pub fn create_js_editor(
  container : @js.Any,
  options : EmbedOptions,
) -> @js.Any {
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }

  // 状態を作成
  let state = @core.EditorState::new_with_mode(options.width, options.height, @core.Embedded)
  let history = @model.History::new()

  // テーマを設定
  let theme = if options.theme == "dark" { @model.Dark } else { @model.Light }
  state.theme_mode.set(theme)
  state.is_readonly.set(options.is_readonly)

  // サンプル要素を追加
  add_sample_shapes(state, new_id)

  // Luna でレンダリング
  let editor_node = embedded_editor_app(state, history, new_id)
  let dom_container : @js_dom.Element = @js.identity(container)
  @element.render(dom_container |> @element.DomElement::from_dom, editor_node)

  // ハンドルを作成して返す
  create_editor_handle_js(state, options.width, options.height)
}

///|
/// エディタハンドルを作成（JavaScript オブジェクト）
fn create_editor_handle_js(
  state : @core.EditorState,
  width : Int,
  height : Int,
) -> @js.Any {
  let export_svg = fn() -> String {
    let bg_color = match state.theme_mode.get() {
      @model.Dark => "#1a1a2e"
      @model.Light => "#ffffff"
    }
    elements_to_moonlight_svg(state.elements.get(), width, height, bg_color)
  }
  let import_svg = fn(svg_str : String) -> Unit {
    let id_counter = create_id_counter()
    let new_id = fn() -> String {
      let current = id_counter.get()
      id_counter.set(current + 1)
      "el-\{current + 1}"
    }
    let elements = import_svg_elements(svg_str, new_id)
    if elements.length() > 0 {
      state.elements.set(elements)
    }
  }
  let clear = fn() -> Unit { state.elements.set([]) }
  let has_focus = fn() -> Bool { state.has_focus.get() }

  create_editor_handle_ffi(export_svg, import_svg, clear, has_focus)
}

///|
/// FFI でハンドルオブジェクトを作成
extern "js" fn create_editor_handle_ffi(
  export_svg : () -> String,
  import_svg : (String) -> Unit,
  clear : () -> Unit,
  has_focus : () -> Bool,
) -> @js.Any =
  #| (exportSvg, importSvg, clear, hasFocus) => ({
  #|   _changeCallbacks: [],
  #|   exportSvg: exportSvg,
  #|   importSvg: importSvg,
  #|   clear: clear,
  #|   destroy: () => {},
  #|   hasFocus: hasFocus,
  #|   onChange: function(callback) { this._changeCallbacks.push(callback); }
  #| })

///|
/// 現在の状態を IndexedDB に保存
fn save_state(state : @core.EditorState) -> Unit {
  let elements = state.elements.get()
  let theme = state.theme_mode.get()
  let bg_color = match theme {
    @model.Dark => "#1a1a2e"
    @model.Light => "#ffffff"
  }
  let svg = elements_to_moonlight_svg(
    elements, canvas_width, canvas_height, bg_color,
  )
  save_to_indexeddb(db_name, store_name, scene_key, svg, fn() { () }, fn() {
    ()
  })
}

///|
/// IndexedDB から状態を読み込み
fn load_state(
  state : @core.EditorState,
  new_id : () -> String,
  on_loaded : () -> Unit,
  on_not_found : () -> Unit,
) -> Unit {
  load_from_indexeddb(
    db_name,
    store_name,
    scene_key,
    fn(svg_str) {
      let elements = import_svg_elements(svg_str, new_id)
      if elements.length() > 0 {
        state.elements.set(elements)
      }
      on_loaded()
    },
    on_not_found,
    on_not_found,
  )
}

///|
/// 自動保存の Effect を設定
fn setup_auto_save(state : @core.EditorState) -> Unit {
  let _ = @luna.effect(fn() {
    let _ = state.elements.get() // 依存関係を登録
    save_state(state)
  })

}

///|
/// URL パラメータからモードを取得
fn get_mode_from_url() -> @core.EditorMode {
  let search = get_url_search_ffi()
  if search.contains("mode=embed") {
    @core.Embedded
  } else {
    @core.Full
  }
}

///|
///|
/// アプリケーションのエントリポイント（外部から呼び出し可能）
pub fn app_main() -> Unit {
  guard @js_dom.document().getElementById("app") is Some(el)
  let mode = get_mode_from_url()
  match mode {
    @core.Full => @element.render(el |> @element.DomElement::from_dom, editor_app())
    @core.Embedded =>
      @element.render(
        el |> @element.DomElement::from_dom,
        create_embedded_app(),
      )
  }
}

///|
/// 埋め込みモード用のアプリを作成（外部から呼び出し可能）
pub fn create_embedded_app() -> @element.DomNode {
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }
  let state = @core.EditorState::new_with_mode(canvas_width, canvas_height, @core.Embedded)
  let history = @model.History::new()
  // IndexedDB から読み込み、なければサンプルを追加
  load_state(state, new_id, fn() { setup_auto_save(state) }, fn() {
    add_sample_shapes(state, new_id)
    setup_auto_save(state)
  })
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
  let state = @core.EditorState::new(canvas_width, canvas_height)

  // 履歴管理
  let history = @model.History::new()

  // IndexedDB から読み込み、なければサンプルを追加
  load_state(state, new_id, fn() { setup_auto_save(state) }, fn() {
    add_sample_shapes(state, new_id)
    setup_auto_save(state)
  })

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
  let on_mouseleave = create_mouseleave_handler(state)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)

  // キーボードショートカット
  setup_keyboard_shortcuts(state, history, new_id)

  // SVG キャンバスを Luna VNode として作成（for_each による差分更新）
  let svg_canvas = render_svg_canvas_node(
    state, on_mousedown, on_mousemove, on_mouseup, on_mouseleave, on_contextmenu,
    on_wheel,
  )

  // UI
  render_editor_ui_vnode(state, history, new_id, svg_canvas, commit_text_input)
}

// ============================================================
// 初期化ヘルパー
// ============================================================

///|
/// 矢印キー方向に応じて図形をリサイズ
/// 戻り値: (新しい shape, 新しい x, 新しい y)
fn resize_shape_by_arrow(
  shape : @model.ShapeType,
  x : Double,
  y : Double,
  key : String,
  step : Double,
) -> (@model.ShapeType, Double, Double) {
  let min_size = 10.0 // 最小サイズ
  match shape {
    @model.Rect(w, h, rx, ry) =>
      match key {
        "ArrowRight" => (@model.Rect(w + step, h, rx, ry), x, y)
        "ArrowLeft" => {
          let new_w = if w + step >= min_size { w + step } else { min_size }
          (@model.Rect(new_w, h, rx, ry), x - step, y)
        }
        "ArrowDown" => (@model.Rect(w, h + step, rx, ry), x, y)
        "ArrowUp" => {
          let new_h = if h + step >= min_size { h + step } else { min_size }
          (@model.Rect(w, new_h, rx, ry), x, y - step)
        }
        _ => (shape, x, y)
      }
    @model.Circle(r) => {
      // 円は全方向同じ（半径を増加）
      let new_r = if r + step >= min_size / 2.0 {
        r + step
      } else {
        min_size / 2.0
      }
      (@model.Circle(new_r), x, y)
    }
    @model.Ellipse(rx, ry) =>
      match key {
        "ArrowRight" | "ArrowLeft" => {
          let new_rx = if rx + step >= min_size / 2.0 {
            rx + step
          } else {
            min_size / 2.0
          }
          (@model.Ellipse(new_rx, ry), x, y)
        }
        "ArrowDown" | "ArrowUp" => {
          let new_ry = if ry + step >= min_size / 2.0 {
            ry + step
          } else {
            min_size / 2.0
          }
          (@model.Ellipse(rx, new_ry), x, y)
        }
        _ => (shape, x, y)
      }
    @model.Line(x2, y2) =>
      match key {
        "ArrowRight" => (@model.Line(x2 + step, y2), x, y)
        "ArrowLeft" => (@model.Line(x2, y2), x - step, y)
        "ArrowDown" => (@model.Line(x2, y2 + step), x, y)
        "ArrowUp" => (@model.Line(x2, y2), x, y - step)
        _ => (shape, x, y)
      }
    @model.Text(content, font_size) => {
      // テキストはフォントサイズを変更
      let size = font_size.unwrap_or(16.0)
      match key {
        "ArrowRight" | "ArrowDown" => {
          let new_size = size + step / 2.0
          (@model.Text(content, Some(new_size)), x, y)
        }
        "ArrowLeft" | "ArrowUp" => {
          let new_size = if size - step / 2.0 >= 8.0 {
            size - step / 2.0
          } else {
            8.0
          }
          (@model.Text(content, Some(new_size)), x, y)
        }
        _ => (shape, x, y)
      }
    }
    _ => (shape, x, y) // Polyline, Path はそのまま
  }
}

///|
/// サンプル図形を追加
fn add_sample_shapes(state : @core.EditorState, new_id : () -> String) -> Unit {
  let text_style = state.get_text_style()
  let arrow_style = state.get_arrow_style()

  // カスタムスタイル
  let magenta_fill : @model.Style = {
    fill: Some("#e040e0"),
    stroke: Some("#c030c0"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
  let blue_stroke : @model.Style = {
    fill: Some("transparent"),
    stroke: Some("#3355aa"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
  let yellow_fill : @model.Style = {
    fill: Some("#ffee44"),
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
  let yellow_stroke : @model.Style = {
    fill: Some("transparent"),
    stroke: Some("#ddcc00"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
  let brown_fill : @model.Style = {
    fill: Some("#8b7080"),
    stroke: Some("#6b5060"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
  let default_rect : @model.Style = {
    fill: Some("transparent"),
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }

  // 行1: Moonbit → Luna → JS
  // Moonbit (マゼンタの円)
  let moonbit_id = new_id()
  let moonbit = @model.Element::new(moonbit_id, 55.0, 65.0, @model.Circle(35.0)).with_style(
    magenta_fill,
  )
  let moonbit_text_id = new_id()
  let moonbit_text = @model.Element::new(
      moonbit_text_id,
      55.0,
      65.0,
      @model.Text("Moonbit", Some(14.0)),
    )
    .with_style(text_style)
    .with_parent(moonbit_id)

  // Luna (青い枠の矩形)
  let luna_id = new_id()
  let luna = @model.Element::new(
    luna_id,
    130.0,
    40.0,
    @model.Rect(100.0, 50.0, None, None),
  ).with_style(blue_stroke)
  let luna_text_id = new_id()
  let luna_text = @model.Element::new(
      luna_text_id,
      180.0,
      65.0,
      @model.Text("Luna", Some(16.0)),
    )
    .with_style(text_style)
    .with_parent(luna_id)

  // JS (黄色背景の矩形)
  let js_id = new_id()
  let js = @model.Element::new(
    js_id,
    280.0,
    40.0,
    @model.Rect(70.0, 50.0, None, None),
  ).with_style(yellow_fill)
  let js_text_id = new_id()
  let js_text = @model.Element::new(
      js_text_id,
      315.0,
      65.0,
      @model.Text("JS", Some(18.0)),
    )
    .with_style(text_style)
    .with_parent(js_id)

  // 矢印: Moonbit → Luna
  let arrow1_id = new_id()
  let arrow1 = @model.Element::new(
    arrow1_id,
    90.0,
    65.0,
    @model.Line(130.0, 65.0),
  ).with_style(arrow_style)
  let arrow1_conn = {
    ..arrow1,
    connections: Some({
      start: Some({ element_id: moonbit_id, anchor: @model.Right }),
      end: Some({ element_id: luna_id, anchor: @model.Left }),
    }),
  }

  // 矢印: Luna → JS
  let arrow2_id = new_id()
  let arrow2 = @model.Element::new(
    arrow2_id,
    230.0,
    65.0,
    @model.Line(280.0, 65.0),
  ).with_style(arrow_style)
  let arrow2_conn = {
    ..arrow2,
    connections: Some({
      start: Some({ element_id: luna_id, anchor: @model.Right }),
      end: Some({ element_id: js_id, anchor: @model.Left }),
    }),
  }

  // 行2: Excalidraw → Moonlight → Svg
  // Excalidraw (黄色い枠の楕円)
  let excalidraw_id = new_id()
  let excalidraw = @model.Element::new(
    excalidraw_id,
    55.0,
    200.0,
    @model.Ellipse(50.0, 28.0),
  ).with_style(yellow_stroke)
  let excalidraw_text_id = new_id()
  let excalidraw_text = @model.Element::new(
      excalidraw_text_id,
      55.0,
      200.0,
      @model.Text("Excalidraw", Some(12.0)),
    )
    .with_style(text_style)
    .with_parent(excalidraw_id)

  // Moonlight (茶色の塗りつぶし矩形)
  let moonlight_id = new_id()
  let moonlight = @model.Element::new(
    moonlight_id,
    150.0,
    160.0,
    @model.Rect(100.0, 70.0, None, None),
  ).with_style(brown_fill)
  let moonlight_text_id = new_id()
  let moonlight_text = @model.Element::new(
      moonlight_text_id,
      200.0,
      195.0,
      @model.Text("Moonlight", Some(14.0)),
    )
    .with_style(text_style)
    .with_parent(moonlight_id)

  // Svg (白い矩形)
  let svg_id = new_id()
  let svg = @model.Element::new(
    svg_id,
    300.0,
    165.0,
    @model.Rect(70.0, 60.0, None, None),
  ).with_style(default_rect)
  let svg_text_id = new_id()
  let svg_text = @model.Element::new(
      svg_text_id,
      335.0,
      195.0,
      @model.Text("Svg", Some(16.0)),
    )
    .with_style(text_style)
    .with_parent(svg_id)

  // 矢印: Luna → Moonlight (下向き)
  let arrow3_id = new_id()
  let arrow3 = @model.Element::new(
    arrow3_id,
    180.0,
    90.0,
    @model.Line(200.0, 160.0),
  ).with_style(arrow_style)
  let arrow3_conn = {
    ..arrow3,
    connections: Some({
      start: Some({ element_id: luna_id, anchor: @model.Bottom }),
      end: Some({ element_id: moonlight_id, anchor: @model.Top }),
    }),
  }

  // 矢印: Excalidraw → Moonlight
  let arrow4_id = new_id()
  let arrow4 = @model.Element::new(
    arrow4_id,
    105.0,
    200.0,
    @model.Line(150.0, 195.0),
  ).with_style(arrow_style)
  let arrow4_conn = {
    ..arrow4,
    connections: Some({
      start: Some({ element_id: excalidraw_id, anchor: @model.Right }),
      end: Some({ element_id: moonlight_id, anchor: @model.Left }),
    }),
  }

  // 矢印: Moonlight → Svg
  let arrow5_id = new_id()
  let arrow5 = @model.Element::new(
    arrow5_id,
    250.0,
    195.0,
    @model.Line(300.0, 195.0),
  ).with_style(arrow_style)
  let arrow5_conn = {
    ..arrow5,
    connections: Some({
      start: Some({ element_id: moonlight_id, anchor: @model.Right }),
      end: Some({ element_id: svg_id, anchor: @model.Left }),
    }),
  }

  // 要素を追加
  state.add_element_raw(moonbit)
  state.add_element_raw(moonbit_text)
  state.add_element_raw(luna)
  state.add_element_raw(luna_text)
  state.add_element_raw(js)
  state.add_element_raw(js_text)
  state.add_element_raw(excalidraw)
  state.add_element_raw(excalidraw_text)
  state.add_element_raw(moonlight)
  state.add_element_raw(moonlight_text)
  state.add_element_raw(svg)
  state.add_element_raw(svg_text)
  // 矢印は最後に追加（最前面に表示）
  state.add_element_raw(arrow1_conn)
  state.add_element_raw(arrow2_conn)
  state.add_element_raw(arrow3_conn)
  state.add_element_raw(arrow4_conn)
  state.add_element_raw(arrow5_conn)
}

///|
/// 矢印キーで選択要素をリサイズ
fn resize_selected_by_arrow(
  state : @core.EditorState,
  history : @model.History,
  selected_ids : Array[String],
  key : String,
  step : Double,
) -> Unit {
  for id in selected_ids {
    guard state.find_element(id) is Some(el)
    let old_shape = el.shape
    let (new_shape, new_x, new_y) = resize_shape_by_arrow(
      el.shape,
      el.x,
      el.y,
      key,
      step,
    )
    // 子要素の現在位置を記録（履歴用）
    let children = state.get_children(id)
    let child_old_positions : Array[(String, Double, Double)] = []
    for child in children {
      child_old_positions.push((child.id, child.x, child.y))
    }
    // 要素をリサイズ
    state.update_element(id, fn(e) {
      { ..e, shape: new_shape, x: new_x, y: new_y }
    })
    // 位置も変わった場合は移動も記録
    if new_x != el.x || new_y != el.y {
      history.undo_stack.push(@model.MoveElement(id, el.x, el.y, new_x, new_y))
    }
    history.undo_stack.push(@model.ResizeElement(id, old_shape, new_shape))
    // 関連要素（子テキスト、接続ライン）を同期更新
    state.sync_related_elements(id)
    // 子要素の移動を履歴に記録
    for pos in child_old_positions {
      let (child_id, old_cx, old_cy) = pos
      if state.find_element(child_id) is Some(child) {
        if child.x != old_cx || child.y != old_cy {
          history.undo_stack.push(
            @model.MoveElement(child_id, old_cx, old_cy, child.x, child.y),
          )
        }
      }
    }
  }
  history.redo_stack.clear()
}

///|
/// 矢印キーで選択要素を移動
fn move_selected_by_arrow(
  state : @core.EditorState,
  history : @model.History,
  selected_ids : Array[String],
  key : String,
  step : Double,
) -> Unit {
  let (dx, dy) : (Double, Double) = match key {
    "ArrowUp" => (0.0, -step)
    "ArrowDown" => (0.0, step)
    "ArrowLeft" => (-step, 0.0)
    "ArrowRight" => (step, 0.0)
    _ => (0.0, 0.0)
  }
  for id in selected_ids {
    guard state.find_element(id) is Some(el)
    let (old_x, old_y) = (el.x, el.y)
    let (new_x, new_y) = (old_x + dx, old_y + dy)
    state.update_element(id, fn(e) { { ..e, x: new_x, y: new_y } })
    // 子要素（テキストなど）も一緒に移動
    for child in state.get_children(id) {
      let (cx, cy) = (child.x, child.y)
      state.update_element(child.id, fn(c) { { ..c, x: cx + dx, y: cy + dy } })
      history.undo_stack.push(
        @model.MoveElement(child.id, cx, cy, cx + dx, cy + dy),
      )
    }
    state.update_connected_lines(id)
    history.undo_stack.push(@model.MoveElement(id, old_x, old_y, new_x, new_y))
  }
  history.redo_stack.clear()
}

///|
/// 矢印キーでキャンバスをパン
fn pan_by_arrow(state : @core.EditorState, key : String) -> Unit {
  let zoom = state.viewport.get().zoom
  let pan_step = 12.0 / zoom
  match key {
    "ArrowUp" => state.pan(0.0, -pan_step)
    "ArrowDown" => state.pan(0.0, pan_step)
    "ArrowLeft" => state.pan(-pan_step, 0.0)
    "ArrowRight" => state.pan(pan_step, 0.0)
    _ => ()
  }
}

///|
/// 矢印キーイベントを処理
fn handle_arrow_key(
  state : @core.EditorState,
  history : @model.History,
  key : String,
  shift_key : Bool,
) -> Unit {
  let selected_ids = state.selected_ids.get()
  if selected_ids.length() == 0 {
    pan_by_arrow(state, key)
    return
  }
  let step = if state.grid_enabled.get() { 20.0 } else { 10.0 }
  if shift_key {
    resize_selected_by_arrow(state, history, selected_ids, key, step)
  } else {
    move_selected_by_arrow(state, history, selected_ids, key, step)
  }
}

///|
/// キーボードリスナーを設定（Space + Arrow）
fn setup_keyboard_listener(
  state : @core.EditorState,
  history : @model.History,
  space_pressed : Ref[Bool],
) -> Unit {
  let _ = add_keydown_listener(fn(e) {
    if is_input_focused_ffi() {
      return
    }
    let key : String = e._get("key").cast()
    let keyboard_event : @js_dom.KeyboardEvent = e.cast()
    // Escape キー
    if key == "Escape" {
      if state.is_placing() {
        state.cancel_placement()
      } else if state.context_menu.get() is Some(_) {
        state.hide_context_menu()
      } else {
        return
      }
      keyboard_event.preventDefault()
      return
    }
    // Space キーでパンモード
    if key == " " {
      space_pressed.val = true
      return
    }
    // コンテキストメニュー表示中は他のキー操作を無効化
    if state.context_menu.get() is Some(_) {
      return
    }
    // 矢印キー
    match key {
      "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight" => {
        let shift_key : Bool = e._get("shiftKey").cast()
        handle_arrow_key(state, history, key, shift_key)
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
  state : @core.EditorState,
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

    // 中クリック（button === 1）または Space キーでパン開始（埋め込みモードでは無効）
    if state.mode is @core.Full && (button == 1 || space_pressed.val) {
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
    let shift_key : Bool = e._get("shiftKey").cast()
    if data_id is Some(id) {
      handle_element_click(
        state, id, scene_x, scene_y, last_click_time, last_click_element, double_click_threshold,
        shift_key,
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
  state : @core.EditorState,
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
  // Arrow として作成（矢印付き）
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
  @core.execute_command(history, state, @model.AddElement(line_with_conn))
  // リサイズ開始
  state.start_resize(line_id, @model.LineEnd, scene_x, scene_y)
  true
}

///|
/// リサイズハンドルクリックを処理
fn handle_resize_click(
  state : @core.EditorState,
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
  state : @core.EditorState,
  id : String,
  scene_x : Double,
  scene_y : Double,
  last_click_time : Ref[Double],
  last_click_element : Ref[String],
  double_click_threshold : Double,
  shift_key : Bool,
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

  // Shift+クリック: 複数選択のトグル
  if shift_key {
    if already_selected {
      state.remove_from_selection(target_id)
    } else {
      state.add_to_selection(target_id)
    }
    // 複数選択中はドラッグを開始
    if state.selected_ids.get().length() > 1 {
      state.start_multi_drag(scene_x, scene_y)
    } else if state.selected_ids.get().length() == 1 {
      // 1つだけ選択中の場合は通常ドラッグ
      let selected_id = state.selected_ids.get()[0]
      state.start_drag(selected_id, scene_x, scene_y)
    }
    return
  }

  // 通常クリック
  if already_selected && selected_count > 1 {
    state.start_multi_drag(scene_x, scene_y)
  } else {
    state.select(Some(target_id))
    state.start_drag(target_id, scene_x, scene_y)
  }
}

///|
/// ダブルクリック時のテキスト編集開始
fn handle_double_click(state : @core.EditorState, element_id : String) -> Unit {
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
fn handle_text_edit(state : @core.EditorState, text_id : String) -> Unit {
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
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  text_content : String,
) -> Unit {
  guard state.text_edit.get() is Some(edit_state)
  match edit_state.editing_id {
    Some(text_id) =>
      if text_content == "" {
        if state.find_element(text_id) is Some(el) {
          @core.execute_command(history, state, @model.RemoveElement(el))
        }
      } else if text_content != edit_state.initial_text {
        // UpdateText コマンドを使ってUndoスタックに記録
        @core.execute_command(
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
        @core.execute_command(history, state, @model.AddElement(text_el))
      }
  }
  state.end_text_edit()
}

///|
/// mousemove ハンドラを作成
fn create_mousemove_handler(
  state : @core.EditorState,
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
    state.mouse_in_canvas.set(true)
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
/// リサイズ終了時のコマンド記録
fn record_resize_end(
  state : @core.EditorState,
  history : @model.History,
  resize : @model.ResizeState,
) -> Unit {
  guard state.find_element(resize.element_id) is Some(el) else { return }
  let changed = resize.start_shape != el.shape ||
    resize.start_x != el.x ||
    resize.start_y != el.y
  guard changed else { return }
  // 位置変更があれば記録
  if resize.start_x != el.x || resize.start_y != el.y {
    history.undo_stack.push(
      @model.MoveElement(
        resize.element_id,
        resize.start_x,
        resize.start_y,
        el.x,
        el.y,
      ),
    )
  }
  history.undo_stack.push(
    @model.ResizeElement(resize.element_id, resize.start_shape, el.shape),
  )
  history.redo_stack.clear()
}

///|
/// 複数要素ドラッグ終了時のコマンド記録
fn record_multi_drag_end(
  state : @core.EditorState,
  history : @model.History,
  multi_drag : @model.MultiDragState,
) -> Unit {
  for pos in multi_drag.start_positions {
    let (id, start_x, start_y) = pos
    guard state.find_element(id) is Some(el) else { continue }
    guard start_x != el.x || start_y != el.y else { continue }
    history.undo_stack.push(
      @model.MoveElement(id, start_x, start_y, el.x, el.y),
    )
  }
  history.redo_stack.clear()
}

///|
/// Line ドラッグ時の接続要素移動を記録
fn record_connected_moves(
  state : @core.EditorState,
  history : @model.History,
  positions : Array[(String, Double, Double)],
) -> Unit {
  for pos in positions {
    let (id, start_x, start_y) = pos
    guard state.find_element(id) is Some(el) else { continue }
    guard start_x != el.x || start_y != el.y else { continue }
    history.undo_stack.push(
      @model.MoveElement(id, start_x, start_y, el.x, el.y),
    )
  }
}

///|
/// ドラッグ終了時のコマンド記録
fn record_drag_end(
  state : @core.EditorState,
  history : @model.History,
  drag : @model.DragState,
) -> Unit {
  guard state.find_element(drag.element_id) is Some(el) else { return }
  guard drag.start_x != el.x || drag.start_y != el.y else { return }
  // Line の場合は終点の変更もコマンドとして記録
  match (drag.start_shape, el.shape) {
    (Some(@model.Line(_, _) as old_shape), @model.Line(_, _) as new_shape) => {
      record_connected_moves(state, history, drag.connected_start_positions)
      if old_shape != new_shape {
        history.undo_stack.push(
          @model.ResizeElement(drag.element_id, old_shape, new_shape),
        )
      }
    }
    _ => ()
  }
  history.undo_stack.push(
    @model.MoveElement(drag.element_id, drag.start_x, drag.start_y, el.x, el.y),
  )
  history.redo_stack.clear()
}

///|
/// mouseup ハンドラを作成
fn create_mouseup_handler(
  state : @core.EditorState,
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
    if state.resize_state.get() is Some(resize) {
      record_resize_end(state, history, resize)
      state.end_resize()
      return
    }
    if state.multi_drag_state.get() is Some(multi_drag) {
      record_multi_drag_end(state, history, multi_drag)
      state.end_multi_drag()
      return
    }
    if state.drag_state.get() is Some(drag) {
      record_drag_end(state, history, drag)
    }
    state.end_drag()
  }
}

///|
/// mouseleave ハンドラを作成（マウスが画面外に出た時に状態をリセット）
fn create_mouseleave_handler(state : @core.EditorState) -> (@js.Any) -> Unit {
  fn(_e) {
    // マウスがキャンバス外に出たことを記録
    state.mouse_in_canvas.set(false)
    // すべてのドラッグ・選択状態をリセット
    if state.is_panning.get() {
      state.end_pan()
    }
    if state.is_box_selecting() {
      state.end_box_select()
    }
    if state.resize_state.get() is Some(_) {
      state.end_resize()
    }
    if state.multi_drag_state.get() is Some(_) {
      state.end_multi_drag()
    }
    if state.drag_state.get() is Some(_) {
      state.end_drag()
    }
    if state.placement_state.get() is Some(_) {
      state.end_placement()
    }
  }
}

///|
/// wheel ハンドラを作成（マウス位置を基準にズーム）
fn create_wheel_handler(
  state : @core.EditorState,
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
  state : @core.EditorState,
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
  state : @core.EditorState,
  history : @model.History,
  element : @model.Element,
  is_line : Bool,
  anchor_threshold : Double,
  is_arrow? : Bool = false,
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
      @core.execute_command(history, state, @model.AddElement(placed_element))
      state.start_placement(
        element.id,
        anchor_el.id,
        anchor,
        anchor_point,
        is_line,
        is_arrow~,
      )
      true
    }
    None => false
  }
}

///|
/// キーボードショートカットを設定
fn setup_keyboard_shortcuts(
  state : @core.EditorState,
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
    let shift_key : Bool = e._get("shiftKey").cast()
    let is_cmd = ctrl_key || meta_key

    // マウス位置を取得
    let pos = state.mouse_scene_pos.get()
    match key {
      "Delete" | "Backspace" => {
        let selected_ids = state.selected_ids.get()
        for id in selected_ids {
          if state.find_element(id) is Some(el) {
            @core.execute_command(history, state, @model.RemoveElement(el))
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
          @core.execute_command(history, state, @model.AddElement(new_rect))
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
          @core.execute_command(history, state, @model.AddElement(new_circle))
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
          @core.execute_command(history, state, @model.AddElement(new_ellipse))
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
          @core.execute_command(history, state, @model.AddElement(new_line))
          state.select(Some(el_id))
        }
      }
      // 5: Arrow をマウス位置に挿入（アンカー近くなら配置モード）
      "5" => {
        let el_id = new_id()
        // 配置モード用に矢印なしスタイルで作成
        let new_arrow = @model.Element::new(
          el_id,
          pos.x - 50.0,
          pos.y,
          @model.Line(pos.x + 50.0, pos.y),
        ).with_style(state.get_arrow_style_initial())
        if not(
            try_start_placement(
              state,
              history,
              new_arrow,
              true,
              20.0,
              is_arrow=true,
            ),
          ) {
          // 配置モードでなければ矢印ありスタイルで直接追加
          let arrow_with_marker = {
            ..new_arrow,
            style: state.get_arrow_style(),
          }
          @core.execute_command(history, state, @model.AddElement(arrow_with_marker))
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
          @core.execute_command(history, state, @model.AddElement(new_text))
          state.select(Some(el_id))
        }
      }
      "a" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          state.select_all()
        }
      "c" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          // 選択中の要素をクリップボードにコピー
          let selected_ids = state.selected_ids.get()
          let copied : Array[@model.Element] = []
          for id in selected_ids {
            if state.find_element(id) is Some(el) {
              copied.push(el)
              // 子要素もコピー
              for child in state.get_children(id) {
                copied.push(child)
              }
            }
          }
          clipboard.val = copied
        }
      "v" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          // クリップボードから貼り付け（右下に少しずらす）
          if clipboard.val.length() > 0 {
            let id_map : Array[(String, String)] = [] // (old_id, new_id)
            let new_ids : Array[String] = []
            // まず全要素の新しいIDを生成
            for el in clipboard.val {
              let old_id = el.id
              let dup_id = new_id()
              id_map.push((old_id, dup_id))
            }
            // IDマッピングを検索するヘルパー
            let find_new_id = fn(old_id : String) -> String {
              for mapping in id_map {
                let (o, n) = mapping
                if o == old_id {
                  return n
                }
              }
              old_id
            }
            // 要素を追加
            for el in clipboard.val {
              let new_el_id = find_new_id(el.id)
              // parent_id も更新
              let new_parent_id = match el.parent_id {
                Some(pid) => Some(find_new_id(pid))
                None => None
              }
              // 接続情報も更新
              let new_connections : @model.LineConnections? = match
                el.connections {
                Some(conns) => {
                  let new_start : @model.Connection? = match conns.start {
                    Some(conn) => {
                      let c : @model.Connection = {
                        element_id: find_new_id(conn.element_id),
                        anchor: conn.anchor,
                      }
                      Some(c)
                    }
                    None => None
                  }
                  let new_end : @model.Connection? = match conns.end {
                    Some(conn) => {
                      let c : @model.Connection = {
                        element_id: find_new_id(conn.element_id),
                        anchor: conn.anchor,
                      }
                      Some(c)
                    }
                    None => None
                  }
                  let lc : @model.LineConnections = {
                    start: new_start,
                    end: new_end,
                  }
                  Some(lc)
                }
                None => None
              }
              let new_el = {
                ..el,
                id: new_el_id,
                x: el.x + 20.0,
                y: el.y + 20.0,
                parent_id: new_parent_id,
                connections: new_connections,
              }
              // Line の場合は終点も移動
              let final_el = match new_el.shape {
                @model.Line(x2, y2) =>
                  { ..new_el, shape: @model.Line(x2 + 20.0, y2 + 20.0) }
                _ => new_el
              }
              @core.execute_command(history, state, @model.AddElement(final_el))
              // 子要素でなければ選択対象に追加
              if new_parent_id is None {
                new_ids.push(new_el_id)
              }
            }
            state.select_multiple(new_ids)
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
              @core.execute_command(history, state, @model.AddElement(new_el))
              new_ids.push(dup_id)
            }
          }
          state.select_multiple(new_ids)
        }
      "z" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let _ = @core.undo_command(history, state)

        }
      "y" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let _ = @core.redo_command(history, state)

        }
      "s" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          // Ctrl+S: SVGファイルをダウンロード
          let svg_str = elements_to_moonlight_svg(
            state.elements.get(),
            state.doc_width.get().to_int(),
            state.doc_height.get().to_int(),
            state.get_theme().background,
          )
          download_file(svg_str, "moonlight.svg", "image/svg+xml")
        }
      "C" =>
        // Ctrl+Shift+C: SVGテキストをクリップボードにコピー
        if is_cmd && shift_key {
          let _ = e._call("preventDefault", [])
          let svg_str = elements_to_moonlight_svg(
            state.elements.get(),
            state.doc_width.get().to_int(),
            state.doc_height.get().to_int(),
            state.get_theme().background,
          )
          copy_text_to_clipboard(svg_str, fn() { () }, fn() { () })
        }
      "V" =>
        // Ctrl+Shift+V: クリップボードからSVGをインポート
        if is_cmd && shift_key {
          let _ = e._call("preventDefault", [])
          read_clipboard_text(
            fn(text) {
              let imported = import_svg_elements(text, new_id)
              for el in imported {
                @core.execute_command(history, state, @model.AddElement(el))
              }
              if imported.length() > 0 {
                let ids = imported
                  .filter(fn(el) { el.parent_id is None })
                  .map(fn(el) { el.id })
                state.select_multiple(ids)
              }
            },
            fn() { () },
          )
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
  state : @core.EditorState,
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
fn render_panel_toggle(state : @core.EditorState) -> @element.DomNode {
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
/// 親要素のサイズにフィットし、aspect-ratio でアスペクト比を維持
fn render_embedded_view(
  state : @core.EditorState,
  svg_canvas : @element.DomNode,
  commit_text_input : (String) -> Unit,
) -> @element.DomNode {
  // 外側コンテナ：親要素のサイズにフィット
  div(
    dyn_style=fn() {
      let doc_w = state.doc_width.get()
      let doc_h = state.doc_height.get()
      // aspect-ratio で比率を維持、width/height: 100% で親にフィット
      "position: relative; width: 100%; height: 100%; aspect-ratio: \{doc_w} / \{doc_h}; max-width: 100%; max-height: 100%;"
    },
    [
      // SVG キャンバス（絶対位置で全体を埋める）
      div(style="position: absolute; inset: 0;", [
        svg_canvas,
        // テキスト入力
        render_text_input_container(state, commit_text_input),
      ]),
      // 編集ボタン（右上固定）- アイコンのみ、aria-label付き
      @element.create_element(
        "button",
        [
          ("style", @element.Static("position: absolute; top: 8px; right: 8px; padding: 10px; background: rgba(59, 130, 246, 0.95); border: none; border-radius: 8px; cursor: pointer; color: white; box-shadow: 0 2px 8px rgba(59, 130, 246, 0.4); z-index: 10; display: flex; align-items: center; justify-content: center;")),
          ("aria-label", @element.Static("Edit in fullscreen")),
          ("title", @element.Static("Edit in fullscreen")),
          ("click", @element.Handler(fn(_) { state.modal_open.set(true) })),
        ],
        [@components.svg_icon(@components.icon_edit_expand, 20)],
      ),
    ],
  )
}

///|
/// エディタモーダルをレンダリング（フルエディタを別ウィンドウ風に表示）
pub fn render_editor_modal(
  state : @core.EditorState,
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
  let on_mouseleave = create_mouseleave_handler(state)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)
  let modal_svg = render_svg_canvas_node(
    state, on_mousedown, on_mousemove, on_mouseup, on_mouseleave, on_contextmenu,
    on_wheel,
  )

  // Escキーでモーダルを閉じる
  let _ = @luna.effect(fn() {
    let _ = state.modal_open.get() // 依存関係を登録
    if state.modal_open.get() {
      let handler = fn(e : @js.Any) {
        let key : String = e._get("key").cast()
        if key == "Escape" {
          state.modal_open.set(false)
        }
      }
      let _ = add_keydown_listener(handler)
    }
  })

  // モーダルオーバーレイ（クリックで閉じる）
  div(
    style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000; display: flex; align-items: center; justify-content: center;",
    on=events().click(fn(_) { state.modal_open.set(false) }),
    [
      // モーダルウィンドウ（クリックイベントの伝播を止める）
      div(
        style="width: 90vw; max-width: 1200px; height: 85vh; background: white; border-radius: 8px; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 4px 24px rgba(0,0,0,0.3);",
        on=events().click(fn(e) {
          let _ = e.as_any()._call("stopPropagation", [])
        }),
        [
          // ヘッダー
          div(
            style="display: flex; justify-content: space-between; align-items: center; padding: 8px 16px; border-bottom: 1px solid #ddd; background: #f8f8f8; flex-shrink: 0;",
            [
              div(style="font-weight: 500; font-size: 14px;", [text("Moonlight Editor")]),
              // 閉じるボタン - アイコンのみ、aria-label付き
              @element.create_element(
                "button",
                [
                  ("style", @element.Static("padding: 8px; background: #f5f5f5; border: 1px solid #d0d0d0; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #555;")),
                  ("aria-label", @element.Static("Close")),
                  ("title", @element.Static("Close")),
                  ("click", @element.Handler(fn(_) { state.modal_open.set(false) })),
                ],
                [@components.svg_icon(@components.icon_close, 18)],
              ),
            ],
          ),
          // エディタ本体
          div(style="flex: 1; display: flex; overflow: hidden; min-height: 0;", [
            // キャンバス領域
            div(style="flex: 1; position: relative; min-width: 0;", [
              modal_svg,
              render_text_input_container(state, commit_text_input),
            ]),
            // サイドパネル（インライン版 - position: fixed なし）
            div(
              style="width: 240px; border-left: 1px solid #ddd; overflow-y: auto; background: #fafafa;",
              [render_inline_panel(state, history)],
            ),
          ]),
          // ツールバー（下部）
          div(
            style="display: flex; gap: 4px; align-items: center; padding: 8px 12px; border-top: 1px solid #ddd; background: #f8f8f8; flex-shrink: 0;",
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
  state : @core.EditorState,
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
  let on_mouseleave = create_mouseleave_handler(state)
  // 埋め込みモードではズームを無効化
  let on_wheel = fn(_e : @js.Any) { () }
  let on_contextmenu = fn(_e : @js.Any) { () } // コンテキストメニュー無効
  let svg_canvas = render_svg_canvas_node(
    state, on_mousedown, on_mousemove, on_mouseup, on_mouseleave, on_contextmenu,
    on_wheel,
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
  state : @core.EditorState,
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
      let (text_x, text_y) : (Double, Double) = match
        state.find_element(edit_state.parent_id) {
        Some(parent) => {
          let bbox = parent.bounding_box()
          let center_x = bbox.x + bbox.width / 2.0
          let center_y = bbox.y + bbox.height / 2.0
          (center_x, center_y)
        }
        None => (edit_state.x, edit_state.y)
      }
      let screen_pos = vp.scene_to_screen(text_x, text_y)
      let min_width = 40.0 * vp.zoom
      // フォントサイズをズーム率に合わせてスケール
      let base_font_size = match edit_state.font_size {
        Some(size) => size
        None => 16.0
      }
      let scaled_font_size = base_font_size * vp.zoom
      let scaled_height = scaled_font_size * 1.5
      // 背景色（テーマに応じて変更）
      let bg_color = match theme {
        @model.Dark => "#1a1a2e"
        @model.Light => "#ffffff"
      }
      // 横に伸びるスタイル（背景色でSVGテキストを覆う）
      let style = "position: absolute; left: \{screen_pos.x}px; top: \{screen_pos.y}px; transform: translate(-50%, -50%); min-width: \{min_width}px; height: \{scaled_height}px; padding: 2px 4px; border: none; background: \{bg_color}; color: \{text_color}; font-family: sans-serif; font-size: \{scaled_font_size}px; line-height: 1.2; text-align: center; outline: none; box-sizing: border-box; resize: none; overflow: hidden; caret-color: currentColor; white-space: nowrap; border-radius: 2px;"
      // リアルタイム更新用のコールバック
      let editing_id = edit_state.editing_id
      let initial_text = edit_state.initial_text
      // 入力中のリアルタイム更新は一時的に無効化（textareaが消える問題を調査中）
      let on_input = fn(_value : String) { () }
      let on_escape = fn(_value : String) {
        // キャンセル時は元のテキストに戻す
        match editing_id {
          Some(id) => state.update_text_raw(id, initial_text)
          None => ()
        }
        state.text_edit.set(None)
      }
      let textarea = create_textarea_ffi(
        style,
        initial_text,
        fn(value) { commit(value) },
        on_escape,
        on_input,
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
// svg_icon, toolbar_button は @components から利用

///|
/// 埋め込みツールバー（SVGアイコン + キーバインド表示）
fn render_embedded_toolbar(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  let theme = state.get_theme()
  div(style="display: flex; gap: 3px; align-items: center;", [
    // 図形追加ボタン
    @components.toolbar_button(
      @components.svg_icon(@components.icon_rect, 16),
      Some("1"),
      "Rectangle",
      fn() {
        let el_id = new_id()
        let pos = state.get_placement_position()
        let width = 80.0
        let height = 60.0
        let new_rect = @model.Element::new(
          el_id,
          pos.x - width / 2.0,
          pos.y - height / 2.0,
          @model.Rect(width, height, None, None),
        ).with_style(state.get_default_style())
        @core.execute_command(history, state, @model.AddElement(new_rect))
        state.select(Some(el_id))
      },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_circle, 16),
      Some("2"),
      "Circle",
      fn() {
        let el_id = new_id()
        let pos = state.get_placement_position()
        let new_circle = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Circle(40.0),
        ).with_style(state.get_default_style())
        @core.execute_command(history, state, @model.AddElement(new_circle))
        state.select(Some(el_id))
      },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_ellipse, 16),
      Some("3"),
      "Ellipse",
      fn() {
        let el_id = new_id()
        let pos = state.get_placement_position()
        let new_ellipse = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Ellipse(60.0, 35.0),
        ).with_style(state.get_default_style())
        @core.execute_command(history, state, @model.AddElement(new_ellipse))
        state.select(Some(el_id))
      },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_line, 16),
      Some("4"),
      "Line",
      fn() {
        let el_id = new_id()
        let pos = state.get_placement_position()
        let dx = 100.0
        let dy = 50.0
        let new_line = @model.Element::new(
          el_id,
          pos.x - dx / 2.0,
          pos.y - dy / 2.0,
          @model.Line(pos.x + dx / 2.0, pos.y + dy / 2.0),
        ).with_style(state.get_line_style())
        @core.execute_command(history, state, @model.AddElement(new_line))
        state.select(Some(el_id))
      },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_arrow, 16),
      Some("5"),
      "Arrow",
      fn() {
        let el_id = new_id()
        let pos = state.get_placement_position()
        let dx = 100.0
        let dy = 50.0
        let new_arrow = @model.Element::new(
          el_id,
          pos.x - dx / 2.0,
          pos.y - dy / 2.0,
          @model.Line(pos.x + dx / 2.0, pos.y + dy / 2.0),
        ).with_style(state.get_arrow_style())
        @core.execute_command(history, state, @model.AddElement(new_arrow))
        state.select(Some(el_id))
      },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_text, 16),
      Some("6"),
      "Text",
      fn() {
        let el_id = new_id()
        let pos = state.get_placement_position()
        let font_size = 24.0
        // テキストは左上基準、概算で中央配置（"Text"の幅≒50px）
        let new_text = @model.Element::new(
          el_id,
          pos.x - 25.0,
          pos.y + font_size / 3.0,
          @model.Text("Text", Some(font_size)),
        ).with_style(state.get_text_style())
        @core.execute_command(history, state, @model.AddElement(new_text))
        state.select(Some(el_id))
      },
      theme~,
    ),
    // セパレータ
    @components.toolbar_separator(theme),
    // Undo/Redo
    @components.toolbar_button(
      @components.svg_icon(@components.icon_undo, 16),
      Some("⌘Z"),
      "Undo",
      fn() {
        let _ = @core.undo_command(history, state)

      },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_redo, 16),
      Some("⌘Y"),
      "Redo",
      fn() {
        let _ = @core.redo_command(history, state)

      },
      theme~,
    ),
    // セパレータ
    @components.toolbar_separator(theme),
    // ズームコントロール
    @components.toolbar_button(
      @components.svg_icon(@components.icon_zoom_out, 16),
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
    @components.toolbar_button(
      @components.svg_icon(@components.icon_zoom_in, 16),
      None,
      "Zoom In",
      fn() { state.zoom_in() },
      theme~,
    ),
    @components.toolbar_button(
      @components.svg_icon(@components.icon_reset, 16),
      None,
      "Fit to Canvas",
      fn() { state.reset_viewport() },
      theme~,
    ),
    // セパレータ
    @components.toolbar_separator(theme),
    // グリッドスナップ（トグルボタン + Popover）
    {
      let snap_popover_id = "tooltip-grid-snap"
      let snap_popover_style = "position: fixed; margin: 0; padding: 4px 8px; background: #333; color: #fff; font-size: 11px; border-radius: 4px; white-space: nowrap; border: none;"
      div(style="position: relative; display: inline-block;", [
        @element.create_element(
          "button",
          [
            (
              "style",
              @element.Dynamic(fn() {
                let enabled = state.grid_enabled.get()
                let is_dark = state.theme_mode.get() == @model.Dark
                let current_theme = if is_dark {
                  @model.Theme::dark()
                } else {
                  @model.Theme::light()
                }
                let base = "display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; padding: 4px 6px; cursor: pointer; border: 1px solid; border-radius: 4px; min-width: 36px; height: 40px;"
                if enabled {
                  let enabled_bg = if is_dark { "#1e3a5f" } else { "#e3f2fd" }
                  let enabled_border = if is_dark {
                    "#4a9eff"
                  } else {
                    "#2196f3"
                  }
                  let enabled_color = if is_dark {
                    "#60a5fa"
                  } else {
                    "#1976d2"
                  }
                  base +
                  "background: \{enabled_bg}; border-color: \{enabled_border}; color: \{enabled_color};"
                } else {
                  base +
                  "background: \{current_theme.ui_bg}; border-color: \{current_theme.ui_border}; color: \{current_theme.ui_text_muted};"
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
            @components.svg_icon(@components.icon_grid, 16),
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
    @components.toolbar_separator(theme),
    // エクスポート（Moonlight SVG形式でダウンロード）
    @components.toolbar_button(
      @components.svg_icon(@components.icon_export, 16),
      None,
      "Download SVG (Ctrl+S)",
      fn() {
        let svg_str = elements_to_moonlight_svg(
          state.elements.get(),
          state.doc_width.get().to_int(),
          state.doc_height.get().to_int(),
          state.get_theme().background,
        )
        download_file(svg_str, "moonlight.svg", "image/svg+xml")
      },
      theme~,
    ),
    // コピー（SVGテキスト）
    @components.toolbar_button(
      @components.svg_icon(@components.icon_copy, 16),
      None,
      "Copy SVG (Ctrl+Shift+C)",
      fn() {
        let svg_str = elements_to_moonlight_svg(
          state.elements.get(),
          state.doc_width.get().to_int(),
          state.doc_height.get().to_int(),
          state.get_theme().background,
        )
        copy_text_to_clipboard(svg_str, fn() { () }, fn() { () })
      },
      theme~,
    ),
    // インポート
    @components.toolbar_button(
      @components.svg_icon(@components.icon_import, 16),
      None,
      "Import SVG (Ctrl+Shift+V)",
      fn() {
        open_file_dialog(".svg", fn(text) {
          let imported = import_svg_elements(text, new_id)
          for el in imported {
            @core.execute_command(history, state, @model.AddElement(el))
          }
          if imported.length() > 0 {
            let ids = imported
              .filter(fn(el) { el.parent_id is None })
              .map(fn(el) { el.id })
            state.select_multiple(ids)
          }
        })
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
  state : @core.EditorState,
  on_mousedown : (@js.Any) -> Unit,
  on_mousemove : (@js.Any) -> Unit,
  on_mouseup : (@js.Any) -> Unit,
  on_mouseleave : (@js.Any) -> Unit,
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

  // グリッド線（grid_enabled に応じて表示/非表示）
  children.push(
    @element.create_element_ns(
      @element.svg_ns,
      "g",
      [
        (
          "style",
          @element.Dynamic(fn() {
            if state.grid_enabled.get() {
              "visibility: visible;"
            } else {
              "visibility: hidden;"
            }
          }),
        ),
      ],
      [render_grid_vnode(state)],
    ),
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
        // Embedモードではドキュメント全体を表示（0, 0, doc_w, doc_h）
        // ただしモーダルが開いている場合はフルモードのviewBoxを使用
        if state.mode is @core.Embedded && not(state.modal_open.get()) {
          let doc_w = state.doc_width.get()
          let doc_h = state.doc_height.get()
          "0 0 \{doc_w} \{doc_h}"
        } else {
          let vp = state.viewport.get()
          let cw = state.canvas_width.get().to_double()
          let ch = state.canvas_height.get().to_double()
          let vb_width = cw / vp.zoom
          let vb_height = ch / vp.zoom
          "\{vp.scroll_x} \{vp.scroll_y} \{vb_width} \{vb_height}"
        }
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
    ("mouseleave", @element.Handler(on_mouseleave)),
    ("contextmenu", @element.Handler(on_contextmenu)),
    ("wheel", @element.Handler(on_wheel)),
    // ResizeObserver で canvas サイズを更新し、初回はドキュメントを中央に配置（Fullモードのみ）
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
            // 初回のみドキュメントを中央に配置（Fullモードまたはモーダル表示時）
            if is_first_resize.val {
              is_first_resize.val = false
              // Embedモードでモーダルが閉じている場合はビューポートを (0, 0, 1.0) に固定
              if state.mode is @core.Full || state.modal_open.get() {
                state.fit_to_canvas()
              }
            }
          }
        })
      }),
    ),
  ]
  @element.create_element_ns(@element.svg_ns, "svg", svg_attrs, children)
}
