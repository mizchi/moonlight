// キーボードハンドリング - 埋め込みシェル用
//
// 埋め込み（create_js_editor / WebComponent / API / ?mode=embed）は window では
// なくコンテナで keydown を受ける。スタンドアロンの editor_app() だけが window
// 側の setup_keyboard_shortcuts を使う。
//
// 以前この隣に setup_editor() という二つ目の初期化経路があったが、呼び出し元は
// 無かった。「埋め込みのキーボードはあちらで繋がっている」という誤読を生むので
// 消してある。

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
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  let container = state.container_el.get()
  if is_container_null(container) {
    return
  }
  // コンテナにキーボードイベントを追加
  add_keyboard_handler(container, fn(e) {
    // フォーカスがない場合は無視
    if !state.has_focus.get() {
      return
    }
    // 読み取り専用モードの場合は無視
    if state.is_readonly.get() {
      return
    }
    let key_event = parse_key_event(e)
    let handled = handle_key(state, history, key_event, new_id)
    if handled {
      prevent_default_ffi(e)
    }
  })
}

///|
/// キーイベントを処理（keybindings を使用）
fn handle_key(
  state : @core.EditorState,
  history : @model.History,
  e : KeyEvent,
  new_id : () -> String,
) -> Bool {
  // テキスト編集中はショートカットキーを無視（Escapeのみ例外）
  if state.text_edit.get() is Some(_) {
    // Escapeはテキスト編集を終了するために許可
    if e.key == "Escape" {
      state.text_edit.set(None)
      return true
    }
    // その他のキーはテキスト入力として扱う（ブラウザに処理させる）
    return false
  }
  // モーダル表示中の Escape は選択解除ではなくモーダルを閉じる
  if state.modal_open.get() && e.key == "Escape" {
    state.modal_open.set(false)
    return true
  }
  // 矢印はキーバインド表を通さずここで捌く。Shift+矢印はリサイズという
  // 「同じキーで違う動作」なので、key と修飾キーの一対一表では書けない。
  match e.key {
    "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight" => {
      handle_arrow_key(state, history, e.key, e.shift_key)
      return true
    }
    _ => ()
  }
  // keybindings から一致するアクションを検索
  match @model.match_keybinding(e.key, e.ctrl_key, e.shift_key, e.meta_key) {
    Some(kb) => execute_action(state, history, kb.action, new_id)
    None => false
  }
}

///|
/// アクションを実行
fn execute_action(
  state : @core.EditorState,
  history : @model.History,
  action : String,
  new_id : () -> String,
) -> Bool {
  let pos = get_placement_position(state)
  match action {
    "delete" => {
      delete_selection(state, history)
      true
    }
    "undo" => {
      let _ = @core.undo_command(history, state)
      // 取り消すものが無くてもキーは飲む（埋め込み先のページに漏らさない）
      true
    }
    "redo" => {
      let _ = @core.redo_command(history, state)
      true
    }
    "duplicate" => {
      duplicate_selection(state, history, new_id)
      true
    }
    "copy" => {
      copy_selection(state)
      true
    }
    "paste" => {
      paste_clipboard(state, history, new_id)
      true
    }
    "select_all" => {
      state.select_all()
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
      @core.execute_command(history, state, @model.AddElement(el))
      set_selected_id(state, Some(el_id))
      true
    }
    "create_circle" => {
      let el_id = new_id()
      let el = create_circle_element(el_id, pos.0, pos.1, 40.0)
      @core.execute_command(history, state, @model.AddElement(el))
      set_selected_id(state, Some(el_id))
      true
    }
    "create_ellipse" => {
      let el_id = new_id()
      let el = create_ellipse_element(el_id, pos.0, pos.1, 60.0, 35.0)
      @core.execute_command(history, state, @model.AddElement(el))
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
      @core.execute_command(history, state, @model.AddElement(el))
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
      @core.execute_command(history, state, @model.AddElement(el))
      set_selected_id(state, Some(el_id))
      true
    }
    "create_text" => {
      let el_id = new_id()
      let el = create_text_element(el_id, pos.0, pos.1, "Text")
      @core.execute_command(history, state, @model.AddElement(el))
      set_selected_id(state, Some(el_id))
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
/// 選択要素を削除する（親子関係を考慮）。両方のシェルから呼ぶ。
///
/// ラベル付きの図形を消すと要素は複数消えるが、操作としては一回なので、
/// Undo も一回で全部戻るように Batch でまとめて積む。
pub fn delete_selection(
  state : @core.EditorState,
  history : @model.History,
) -> Unit {
  // EditorState.delete_selected() が親子をたどって消す範囲を決めるので、
  // 何が消えたかは前後の差分から取る（呼ぶ側に同じ計算を持たない）
  let before = state.elements.get()
  state.delete_selected()
  let remaining = state.elements.get().map(fn(el) { el.id })
  // Batch は後ろから戻すので、ここでは後ろから積む。そうすると戻したときに
  // 元の並び（＝重なり順）で戻る。
  let removed : Array[@model.Command] = []
  for i = before.length() - 1; i >= 0; i = i - 1 {
    let el = before[i]
    if !remaining.contains(el.id) {
      removed.push(@model.RemoveElement(el))
    }
  }
  // 何も消えていないなら履歴に段を作らない（Ctrl+Z が空振りする段になる）
  guard removed.length() > 0 else { return }
  history.undo_stack.push(@model.Batch(removed))
  history.redo_stack.clear()
}

///|
/// 選択要素を複製して、複製したほうを選択する。両方のシェルから呼ぶ。
pub fn duplicate_selection(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  let added : Array[@model.Command] = []
  let new_ids : Array[String] = []
  for id in state.selected_ids.get() {
    guard state.find_element(id) is Some(el) else { continue }
    let dup_id = new_id()
    let dup = { ..el, id: dup_id, x: el.x + 20.0, y: el.y + 20.0, }
    state.add_element_raw(dup)
    added.push(@model.AddElement(dup))
    new_ids.push(dup_id)
  }
  guard added.length() > 0 else { return }
  history.undo_stack.push(@model.Batch(added))
  history.redo_stack.clear()
  state.select_multiple(new_ids)
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
