// キーボードハンドリング - 埋め込みモード用

///|
/// キーボードイベント情報
pub struct KeyEvent {
  key : String
  ctrl_key : Bool
  meta_key : Bool
  shift_key : Bool
}

///|
/// キーボードハンドラをセットアップ
pub fn setup_keyboard_handler(
  state : @core.EditorState,
  new_id : () -> String,
) -> Unit {
  let container = state.container_el.get()
  if is_container_null(container) {
    return
  }
  // コンテナにキーボードイベントを追加
  add_keyboard_handler(container, fn(e) {
    // フォーカスがない場合は無視
    if not(state.has_focus.get()) {
      return
    }
    // 読み取り専用モードの場合は無視
    if state.is_readonly.get() {
      return
    }
    let key_event = parse_key_event(e)
    let handled = handle_key(state, key_event, new_id)
    if handled {
      prevent_default_ffi(e)
    }
  })
}

///|
/// キーイベントを処理（keybindings を使用）
fn handle_key(
  state : @core.EditorState,
  e : KeyEvent,
  new_id : () -> String,
) -> Bool {
  // keybindings から一致するアクションを検索
  match @model.match_keybinding(e.key, e.ctrl_key, e.shift_key, e.meta_key) {
    Some(kb) => execute_action(state, kb.action, new_id)
    None => false
  }
}

///|
/// アクションを実行
fn execute_action(
  state : @core.EditorState,
  action : String,
  new_id : () -> String,
) -> Bool {
  let pos = get_placement_position(state)
  match action {
    "delete" => {
      delete_selected(state)
      true
    }
    "escape" => {
      if state.tool_mode.get() == @core.FreeDraw {
        state.tool_mode.set(@core.Select)
      } else {
        set_selected_id(state, None)
      }
      true
    }
    "create_rect" => {
      let el_id = new_id()
      let el = create_rect_element(
        el_id,
        pos.0 - 40.0,
        pos.1 - 30.0,
        80.0,
        60.0,
      )
      add_element(state, el)
      set_selected_id(state, Some(el_id))
      true
    }
    "create_circle" => {
      let el_id = new_id()
      let el = create_circle_element(el_id, pos.0, pos.1, 40.0)
      add_element(state, el)
      set_selected_id(state, Some(el_id))
      true
    }
    "create_ellipse" => {
      let el_id = new_id()
      let el = create_ellipse_element(el_id, pos.0, pos.1, 60.0, 35.0)
      add_element(state, el)
      set_selected_id(state, Some(el_id))
      true
    }
    "create_line" => {
      let el_id = new_id()
      let el = create_line_element(
        el_id,
        pos.0 - 50.0,
        pos.1,
        pos.0 + 50.0,
        pos.1,
      )
      add_element(state, el)
      set_selected_id(state, Some(el_id))
      true
    }
    "create_arrow" => {
      let el_id = new_id()
      let el = create_arrow_element(
        el_id,
        pos.0 - 50.0,
        pos.1,
        pos.0 + 50.0,
        pos.1,
      )
      add_element(state, el)
      set_selected_id(state, Some(el_id))
      true
    }
    "create_text" => {
      let el_id = new_id()
      let el = create_text_element(el_id, pos.0, pos.1, "Text")
      add_element(state, el)
      set_selected_id(state, Some(el_id))
      true
    }
    "move_up" => {
      move_selected(state, 0.0, -10.0)
      true
    }
    "move_down" => {
      move_selected(state, 0.0, 10.0)
      true
    }
    "move_left" => {
      move_selected(state, -10.0, 0.0)
      true
    }
    "move_right" => {
      move_selected(state, 10.0, 0.0)
      true
    }
    "toggle_draw_mode" => {
      toggle_tool_mode(state)
      true
    }
    "select_mode" => {
      set_select_mode(state)
      true
    }
    "show_help" => {
      open_help_page()
      true
    }
    _ => false
  }
}

///|
/// 要素配置位置を取得（画面中央）
fn get_placement_position(state : @core.EditorState) -> (Double, Double) {
  let w = state.width.to_double()
  let h = state.height.to_double()
  (w / 2.0, h / 2.0)
}

///|
/// 選択要素を削除
fn delete_selected(state : @core.EditorState) -> Unit {
  match state.get_selected_id() {
    None => ()
    Some(id) => {
      state.elements.update(fn(els) { els.filter(fn(el) { el.id != id }) })
      set_selected_id(state, None)
    }
  }
}

///|
/// 選択要素を移動
fn move_selected(state : @core.EditorState, dx : Double, dy : Double) -> Unit {
  match state.get_selected_id() {
    None => ()
    Some(id) =>
      state.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == id {
            { ..el, x: el.x + dx, y: el.y + dy }
          } else {
            el
          }
        })
      })
  }
}

///|
/// 要素を追加
fn add_element(state : @core.EditorState, el : @model.Element) -> Unit {
  state.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(el)
    new_els
  })
}

///|
/// Rect 要素を作成
fn create_rect_element(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Rect(w, h, None, None),
    style: default_style(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// Circle 要素を作成
fn create_circle_element(
  id : String,
  x : Double,
  y : Double,
  r : Double,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Circle(r),
    style: default_style(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// Ellipse 要素を作成
fn create_ellipse_element(
  id : String,
  x : Double,
  y : Double,
  rx : Double,
  ry : Double,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Ellipse(rx, ry),
    style: default_style(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// Line 要素を作成
fn create_line_element(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> @model.Element {
  {
    id,
    x: x1,
    y: y1,
    shape: @model.Line(x2, y2),
    style: line_style(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// Arrow 要素を作成（矢印付き Line）
fn create_arrow_element(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> @model.Element {
  {
    id,
    x: x1,
    y: y1,
    shape: @model.Line(x2, y2),
    style: arrow_style(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// Text 要素を作成
fn create_text_element(
  id : String,
  x : Double,
  y : Double,
  content : String,
) -> @model.Element {
  {
    id,
    x,
    y,
    shape: @model.Text(content, Some(16.0)),
    style: text_style(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// デフォルトスタイル
fn default_style() -> @model.Style {
  {
    fill: Some("#4CAF50"),
    stroke: Some("#2E7D32"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// Line スタイル
fn line_style() -> @model.Style {
  {
    fill: None,
    stroke: Some("#333333"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// Arrow スタイル（矢印付き Line）
fn arrow_style() -> @model.Style {
  {
    fill: None,
    stroke: Some("#333333"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: Some(@model.Arrow),
    font_family: None,
  }
}

///|
/// Text スタイル
fn text_style() -> @model.Style {
  {
    fill: Some("#333333"),
    stroke: None,
    stroke_width: None,
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// コンテナが null かどうかチェック
extern "js" fn is_container_null(container : @js.Any) -> Bool =
  #| (c) => c === null || c === undefined

///|
/// キーボードハンドラを追加
extern "js" fn add_keyboard_handler(
  container : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (container, handler) => {
  #|   container.addEventListener('keydown', handler);
  #| }

///|
/// キーイベントをパース
extern "js" fn parse_key_event(e : @js.Any) -> KeyEvent =
  #| (e) => ({
  #|   key: e.key,
  #|   ctrl_key: e.ctrlKey || false,
  #|   meta_key: e.metaKey || false,
  #|   shift_key: e.shiftKey || false
  #| })
