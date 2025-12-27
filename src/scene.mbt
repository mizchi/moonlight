// Scene - Signal ベースの要素管理

///|
/// 線のスナップ先プレビュー（ドラッグ中の視覚的フィードバック用）
pub(all) struct PendingConnection {
  target_id : String // 接続先の要素 ID
  anchor : @model.Anchor // アンカー位置
  point : @model.Point // 座標
}

///|
/// エディタの状態
pub struct EditorState {
  width : Int // キャンバス幅
  height : Int // キャンバス高さ
  elements : @luna.Signal[Array[@model.Element]] // 要素リスト
  selected_ids : @luna.Signal[Array[String]] // 選択中の要素 ID リスト（複数選択対応）
  drag_state : @luna.Signal[@model.DragState?] // ドラッグ状態
  multi_drag_state : @luna.Signal[@model.MultiDragState?] // 複数要素ドラッグ状態
  resize_state : @luna.Signal[@model.ResizeState?] // リサイズ状態
  box_select : @luna.Signal[@model.BoxSelectState?] // 矩形選択状態
  context_menu : @luna.Signal[@model.ContextMenu?] // コンテキストメニュー
  viewport : @luna.Signal[@model.Viewport] // ビューポート
  grid_enabled : @luna.Signal[Bool] // グリッドスナップ有効
  grid_size : @luna.Signal[Int] // グリッドサイズ（ピクセル）
  is_panning : @luna.Signal[Bool] // パン中かどうか
  pan_start : @luna.Signal[(Double, Double)?] // パン開始位置（スクリーン座標）
  text_edit : @luna.Signal[@model.TextEditState?] // テキスト編集状態
  pending_connection : @luna.Signal[PendingConnection?] // ドラッグ中の接続プレビュー
  mouse_scene_pos : @luna.Signal[@model.Point] // マウス位置（シーン座標）
  preview_bg : @luna.Signal[String] // プレビュー背景色
  embed_bg : @luna.Signal[String] // 埋め込み時の背景色（デフォルト: transparent）
  theme_mode : @luna.Signal[@model.ThemeMode] // テーマモード
}

///|
/// エディタ状態を作成
pub fn EditorState::new(width : Int, height : Int) -> EditorState {
  {
    width,
    height,
    elements: @luna.signal([]),
    selected_ids: @luna.signal([]),
    drag_state: @luna.signal(None),
    multi_drag_state: @luna.signal(None),
    resize_state: @luna.signal(None),
    box_select: @luna.signal(None),
    context_menu: @luna.signal(None),
    viewport: @luna.signal(@model.Viewport::default()),
    grid_enabled: @luna.signal(false),
    grid_size: @luna.signal(20),
    is_panning: @luna.signal(false),
    pan_start: @luna.signal(None),
    text_edit: @luna.signal(None),
    pending_connection: @luna.signal(None),
    mouse_scene_pos: @luna.signal({ x: 0.0, y: 0.0 }),
    preview_bg: @luna.signal("#ffffff"),
    embed_bg: @luna.signal("transparent"),
    theme_mode: @luna.signal(@model.Light),
  }
}

///|
/// 現在のテーマを取得
pub fn EditorState::get_theme(self : EditorState) -> @model.Theme {
  match self.theme_mode.get() {
    @model.Light => @model.Theme::light()
    @model.Dark => @model.Theme::dark()
  }
}

///|
/// テーマに基づいたデフォルトスタイルを取得（CSS変数を使用）
pub fn EditorState::get_default_style(self : EditorState) -> @model.Style {
  {
    fill: Some(@model.css_var_fill),
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
}

///|
/// テーマに基づいたテキストスタイルを取得（CSS変数を使用）
pub fn EditorState::get_text_style(self : EditorState) -> @model.Style {
  {
    fill: Some(@model.css_var_text),
    stroke: None,
    stroke_width: None,
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
}

///|
/// Line用のスタイルを取得（CSS変数を使用）
pub fn EditorState::get_line_style(self : EditorState) -> @model.Style {
  {
    fill: None,
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
}

///|
/// Arrow用のスタイルを取得（CSS変数を使用）
pub fn EditorState::get_arrow_style(self : EditorState) -> @model.Style {
  {
    fill: None,
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: Some(@model.Arrow),
  }
}

///|
/// テキスト編集を開始（新規作成）
pub fn EditorState::start_text_edit(
  self : EditorState,
  parent_id : String,
  x : Double,
  y : Double,
) -> Unit {
  self.text_edit.set(Some({ parent_id, x, y, editing_id: None, initial_text: "" }))
}

///|
/// テキスト編集を開始（既存テキストの編集）
pub fn EditorState::start_text_edit_existing(
  self : EditorState,
  text_id : String,
  parent_id : String,
  x : Double,
  y : Double,
  initial_text : String,
) -> Unit {
  self.text_edit.set(
    Some({ parent_id, x, y, editing_id: Some(text_id), initial_text }),
  )
}

///|
/// テキスト編集を終了
pub fn EditorState::end_text_edit(self : EditorState) -> Unit {
  self.text_edit.set(None)
}

///|
/// グリッドスナップを切り替え
pub fn EditorState::toggle_grid(self : EditorState) -> Unit {
  self.grid_enabled.update(fn(v) { not(v) })
}

///|
/// 座標をグリッドにスナップ
pub fn EditorState::snap_to_grid(self : EditorState, x : Double, y : Double) -> (Double, Double) {
  @model.snap_to_grid(x, y, self.grid_size.get(), self.grid_enabled.get())
}

///|
/// 要素を追加
pub fn EditorState::add_element(self : EditorState, element : @model.Element) -> Unit {
  self.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(element)
    new_els
  })
}

///|
/// 要素を ID で検索
pub fn EditorState::find_element(self : EditorState, id : String) -> @model.Element? {
  for el in self.elements.get() {
    if el.id == id {
      return Some(el)
    }
  }
  None
}

///|
/// 指定IDの要素が存在するかチェック
pub fn EditorState::has_element_with_id(self : EditorState, id : String) -> Bool {
  for el in self.elements.get() {
    if el.id == id {
      return true
    }
  }
  false
}

///|
/// 要素のIDを変更（衝突チェック付き）
/// 成功時は true、ID衝突時は false を返す
pub fn EditorState::rename_element_id(
  self : EditorState,
  old_id : String,
  new_id : String,
) -> Bool {
  // 同じIDなら何もしない
  if old_id == new_id {
    return true
  }
  // 新しいIDが既に存在する場合は失敗
  if self.has_element_with_id(new_id) {
    return false
  }
  // IDを更新
  self.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == old_id {
        { ..el, id: new_id }
      } else {
        el
      }
    })
  })
  // 選択状態も更新
  self.selected_ids.update(fn(ids) {
    ids.map(fn(id) { if id == old_id { new_id } else { id } })
  })
  true
}

///|
/// 指定要素の子要素を取得
pub fn EditorState::get_children(self : EditorState, parent_id : String) -> Array[@model.Element] {
  let children : Array[@model.Element] = []
  for el in self.elements.get() {
    if el.parent_id == Some(parent_id) {
      children.push(el)
    }
  }
  children
}

///|
/// 要素が子要素かどうか判定
pub fn EditorState::is_child_element(self : EditorState, id : String) -> Bool {
  if self.find_element(id) is Some(el) {
    el.parent_id is Some(_)
  } else {
    false
  }
}

///|
/// 子要素の親を取得
pub fn EditorState::get_parent_id(self : EditorState, id : String) -> String? {
  if self.find_element(id) is Some(el) {
    el.parent_id
  } else {
    None
  }
}

///|
/// 要素を更新
pub fn EditorState::update_element(
  self : EditorState,
  id : String,
  updater : (@model.Element) -> @model.Element,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) { if el.id == id { updater(el) } else { el } })
  })
}

///|
/// 要素を移動（子要素も一緒に移動、接続ラインも更新）
pub fn EditorState::move_element(
  self : EditorState,
  id : String,
  new_x : Double,
  new_y : Double,
) -> Unit {
  // 移動前の位置を取得
  guard self.find_element(id) is Some(el)
  let dx = new_x - el.x
  let dy = new_y - el.y
  // Line の場合は両端点を同時に移動し、接続された要素も一緒に移動
  match el.shape {
    @model.Line(x2, y2) => {
      // まず接続されている要素のIDを収集（重複を避ける）
      let connected_ids : Array[String] = []
      match el.connections {
        Some(conns) => {
          match conns.start {
            Some(conn) =>
              if not(connected_ids.contains(conn.element_id)) {
                connected_ids.push(conn.element_id)
              }
            None => ()
          }
          match conns.end {
            Some(conn) =>
              if not(connected_ids.contains(conn.element_id)) {
                connected_ids.push(conn.element_id)
              }
            None => ()
          }
        }
        None => ()
      }
      // 移動量をローカル変数に保存（クロージャ用）
      let move_dx = dx
      let move_dy = dy
      // ライン自体の両端点を移動（接続は維持）
      self.update_element(id, fn(e) {
        { ..e, x: new_x, y: new_y, shape: @model.Line(x2 + move_dx, y2 + move_dy) }
      })
      // 接続されている要素も一緒に移動
      for connected_id in connected_ids {
        if self.find_element(connected_id) is Some(_) {
          self.update_element(connected_id, fn(c) {
            { ..c, x: c.x + move_dx, y: c.y + move_dy }
          })
          // 子要素も移動
          let connected_children = self.get_children(connected_id)
          for child in connected_children {
            self.update_element(child.id, fn(c) {
              { ..c, x: c.x + move_dx, y: c.y + move_dy }
            })
          }
          // 接続要素に繋がっている他のラインも更新（自分自身を除く）
          self.update_connected_lines_except(connected_id, id)
        }
      }
    }
    _ => {
      // 親要素を移動
      self.update_element(id, fn(e) { { ..e, x: new_x, y: new_y } })
      // 子要素も移動
      let children = self.get_children(id)
      for child in children {
        self.update_element(child.id, fn(c) { { ..c, x: c.x + dx, y: c.y + dy } })
      }
      // 接続されているラインを更新
      self.update_connected_lines(id)
    }
  }
}

///|
/// 指定座標にある要素を検索（上から順に）
pub fn EditorState::hit_test(
  self : EditorState,
  x : Double,
  y : Double,
) -> @model.Element? {
  @model.find_element_at(self.elements.get(), { x, y })
}

///|
/// 要素を選択（単一）
pub fn EditorState::select(self : EditorState, id : String?) -> Unit {
  match id {
    Some(id) => self.selected_ids.set([id])
    None => self.selected_ids.set([])
  }
}

///|
/// 複数要素を選択
pub fn EditorState::select_multiple(self : EditorState, ids : Array[String]) -> Unit {
  self.selected_ids.set(ids)
}

///|
/// 選択に追加
pub fn EditorState::add_to_selection(self : EditorState, id : String) -> Unit {
  let current = self.selected_ids.get()
  if not(current.contains(id)) {
    let new_ids = current.copy()
    new_ids.push(id)
    self.selected_ids.set(new_ids)
  }
}

///|
/// 選択から除外
pub fn EditorState::remove_from_selection(self : EditorState, id : String) -> Unit {
  self.selected_ids.update(fn(ids) { ids.filter(fn(i) { i != id }) })
}

///|
/// 選択されているか判定
pub fn EditorState::is_selected(self : EditorState, id : String) -> Bool {
  self.selected_ids.get().contains(id)
}

///|
/// 最初の選択要素を取得（後方互換性用）
pub fn EditorState::get_selected_id(self : EditorState) -> String? {
  let ids = self.selected_ids.get()
  if ids.length() > 0 { Some(ids[0]) } else { None }
}

///|
/// ドラッグ開始
pub fn EditorState::start_drag(
  self : EditorState,
  element_id : String,
  mouse_x : Double,
  mouse_y : Double,
) -> Unit {
  guard self.find_element(element_id) is Some(el)
  // Line の場合は終点と接続情報、接続要素の位置も保存
  let (start_shape, start_connections, connected_positions) : (@model.ShapeType?, @model.LineConnections?, Array[(String, Double, Double)]) = match el.shape {
    @model.Line(_, _) => {
      let positions : Array[(String, Double, Double)] = []
      match el.connections {
        Some(conns) => {
          match conns.start {
            Some(conn) =>
              if self.find_element(conn.element_id) is Some(connected_el) {
                positions.push((conn.element_id, connected_el.x, connected_el.y))
              }
            None => ()
          }
          match conns.end {
            Some(conn) =>
              if self.find_element(conn.element_id) is Some(connected_el) {
                positions.push((conn.element_id, connected_el.x, connected_el.y))
              }
            None => ()
          }
        }
        None => ()
      }
      (Some(el.shape), el.connections, positions)
    }
    _ => (None, None, [])
  }
  self.drag_state.set(
    Some({
      element_id,
      start_x: el.x,
      start_y: el.y,
      offset_x: mouse_x - el.x,
      offset_y: mouse_y - el.y,
      start_shape,
      start_connections,
      connected_start_positions: connected_positions,
    }),
  )
}

///|
/// ドラッグ中の移動
pub fn EditorState::drag_move(
  self : EditorState,
  mouse_x : Double,
  mouse_y : Double,
) -> Unit {
  guard self.drag_state.get() is Some(state)
  let pos = @model.calc_drag_position(state.offset_x, state.offset_y, mouse_x, mouse_y)
  let (snapped_x, snapped_y) = self.snap_to_grid(pos.x, pos.y)
  self.move_element(state.element_id, snapped_x, snapped_y)
}

///|
/// ドラッグ終了
pub fn EditorState::end_drag(self : EditorState) -> Unit {
  self.drag_state.set(None)
}

///|
/// ドラッグ中かどうか
pub fn EditorState::is_dragging(self : EditorState) -> Bool {
  self.drag_state.get() is Some(_)
}

///|
/// コンテキストメニューを表示
pub fn EditorState::show_context_menu(
  self : EditorState,
  x : Double,
  y : Double,
  scene_x : Double,
  scene_y : Double,
  target_id : String?,
) -> Unit {
  self.context_menu.set(Some({ x, y, scene_x, scene_y, target_id }))
}

///|
/// コンテキストメニューを非表示
pub fn EditorState::hide_context_menu(self : EditorState) -> Unit {
  self.context_menu.set(None)
}

///|
/// 要素を削除
pub fn EditorState::remove_element(self : EditorState, id : String) -> Unit {
  self.elements.update(fn(els) { els.filter(fn(el) { el.id != id }) })
  // 選択中の要素が削除されたら選択解除
  self.remove_from_selection(id)
}

///|
/// 選択中の要素を削除
pub fn EditorState::delete_selected(self : EditorState) -> Unit {
  let ids = self.selected_ids.get().copy()
  for id in ids {
    self.remove_element(id)
  }
}

// ============================================================
// 履歴管理用の低レベル操作（_raw サフィックス）
// これらは直接履歴に記録せず、Command から呼び出される
// ============================================================

///|
/// 要素を追加（履歴なし）
pub fn EditorState::add_element_raw(self : EditorState, element : @model.Element) -> Unit {
  self.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(element)
    new_els
  })
}

///|
/// 要素を削除（履歴なし、子要素も削除）
pub fn EditorState::remove_element_raw(self : EditorState, id : String) -> Unit {
  // 要素とその子要素を削除
  self.elements.update(fn(els) {
    els.filter(fn(el) { el.id != id && el.parent_id != Some(id) })
  })
  // 選択から除外
  self.remove_from_selection(id)
}

///|
/// 要素を移動（履歴なし）
pub fn EditorState::move_element_raw(
  self : EditorState,
  id : String,
  new_x : Double,
  new_y : Double,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) { if el.id == id { { ..el, x: new_x, y: new_y } } else { el } })
  })
}

///|
/// 要素の形状を更新（履歴なし）
pub fn EditorState::update_shape_raw(
  self : EditorState,
  id : String,
  new_shape : @model.ShapeType,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) { if el.id == id { { ..el, shape: new_shape } } else { el } })
  })
}

///|
/// 要素の現在のインデックスを取得
pub fn EditorState::get_element_index(self : EditorState, id : String) -> Int? {
  let els = self.elements.get()
  for i = 0; i < els.length(); i = i + 1 {
    if els[i].id == id {
      return Some(i)
    }
  }
  None
}

///|
/// 要素を指定位置に移動（履歴なし）
pub fn EditorState::reorder_element_raw(
  self : EditorState,
  id : String,
  to_index : Int,
) -> Unit {
  self.elements.update(fn(els) {
    let mut from_idx = -1
    for i = 0; i < els.length(); i = i + 1 {
      if els[i].id == id {
        from_idx = i
        break
      }
    }
    if from_idx < 0 {
      return els
    }
    let el = els[from_idx]
    let new_els : Array[@model.Element] = []
    // 要素を除いた配列を作成
    for i = 0; i < els.length(); i = i + 1 {
      if i != from_idx {
        new_els.push(els[i])
      }
    }
    // 正しい位置に挿入
    let insert_idx = if to_index > new_els.length() {
      new_els.length()
    } else if to_index < 0 {
      0
    } else {
      to_index
    }
    let result : Array[@model.Element] = []
    for i = 0; i < new_els.length(); i = i + 1 {
      if i == insert_idx {
        result.push(el)
      }
      result.push(new_els[i])
    }
    if insert_idx >= new_els.length() {
      result.push(el)
    }
    result
  })
}

///|
/// 要素のスタイルを更新（履歴なし）
pub fn EditorState::update_style_raw(
  self : EditorState,
  id : String,
  new_style : @model.Style,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: new_style }
      } else {
        el
      }
    })
  })
}

///|
/// 要素のIDを変更（履歴なし、衝突チェックなし）
pub fn EditorState::rename_element_raw(
  self : EditorState,
  old_id : String,
  new_id : String,
) -> Unit {
  // IDを更新
  self.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == old_id {
        { ..el, id: new_id }
      } else {
        el
      }
    })
  })
  // 選択状態も更新
  self.selected_ids.update(fn(ids) {
    ids.map(fn(id) { if id == old_id { new_id } else { id } })
  })
}

///|
/// テキスト要素の内容を更新（履歴なし）
pub fn EditorState::update_text_raw(
  self : EditorState,
  id : String,
  new_content : String,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        match el.shape {
          @model.Text(_, font_size) => { ..el, shape: @model.Text(new_content, font_size) }
          _ => el
        }
      } else {
        el
      }
    })
  })
}

///|
/// 要素を最前面に移動
pub fn EditorState::bring_to_front(self : EditorState, id : String) -> (Int, Int)? {
  let els = self.elements.get()
  if self.get_element_index(id) is Some(from_idx) {
    let to_idx = els.length() - 1
    if from_idx != to_idx {
      self.reorder_element_raw(id, to_idx)
      return Some((from_idx, to_idx))
    }
  }
  None
}

///|
/// 要素を最背面に移動
pub fn EditorState::send_to_back(self : EditorState, id : String) -> (Int, Int)? {
  if self.get_element_index(id) is Some(from_idx) {
    if from_idx != 0 {
      self.reorder_element_raw(id, 0)
      return Some((from_idx, 0))
    }
  }
  None
}

// ============================================================
// ズーム/パン操作
// ============================================================

///|
/// ズームイン
pub fn EditorState::zoom_in(self : EditorState) -> Unit {
  self.viewport.update(fn(vp) {
    let new_zoom = vp.zoom * 1.25
    // 最大 400%
    let clamped = if new_zoom > 4.0 { 4.0 } else { new_zoom }
    { ..vp, zoom: clamped }
  })
}

///|
/// ズームアウト
pub fn EditorState::zoom_out(self : EditorState) -> Unit {
  self.viewport.update(fn(vp) {
    let new_zoom = vp.zoom / 1.25
    // 最小 25%
    let clamped = if new_zoom < 0.25 { 0.25 } else { new_zoom }
    { ..vp, zoom: clamped }
  })
}

///|
/// 指定位置を基準にズーム（マウス位置中心）
pub fn EditorState::zoom_at(
  self : EditorState,
  screen_x : Double,
  screen_y : Double,
  zoom_in : Bool,
) -> Unit {
  self.viewport.update(fn(vp) {
    // 現在のマウス位置のシーン座標を取得
    let scene = vp.screen_to_scene(screen_x, screen_y)
    // 新しいズーム値を計算
    let factor = if zoom_in { 1.25 } else { 1.0 / 1.25 }
    let new_zoom = vp.zoom * factor
    // 範囲制限
    let clamped = if new_zoom > 4.0 {
      4.0
    } else if new_zoom < 0.25 {
      0.25
    } else {
      new_zoom
    }
    // ズーム後も同じシーン座標がマウス位置に来るようにスクロール調整
    // scene.x = screen_x / clamped + new_scroll_x
    // new_scroll_x = scene.x - screen_x / clamped
    let new_scroll_x = scene.x - screen_x / clamped
    let new_scroll_y = scene.y - screen_y / clamped
    { zoom: clamped, scroll_x: new_scroll_x, scroll_y: new_scroll_y }
  })
}

///|
/// ビューポートをリセット
pub fn EditorState::reset_viewport(self : EditorState) -> Unit {
  self.viewport.set(@model.Viewport::default())
}

///|
/// パン（スクロール）
pub fn EditorState::pan(self : EditorState, dx : Double, dy : Double) -> Unit {
  self.viewport.update(fn(vp) {
    { ..vp, scroll_x: vp.scroll_x + dx, scroll_y: vp.scroll_y + dy }
  })
}

///|
/// パン開始
pub fn EditorState::start_pan(self : EditorState, screen_x : Double, screen_y : Double) -> Unit {
  self.is_panning.set(true)
  self.pan_start.set(Some((screen_x, screen_y)))
}

///|
/// パン移動
pub fn EditorState::pan_move(self : EditorState, screen_x : Double, screen_y : Double) -> Unit {
  if self.pan_start.get() is Some((start_x, start_y)) {
    let vp = self.viewport.get()
    // スクリーン座標での移動量をシーン座標に変換
    let dx = (start_x - screen_x) / vp.zoom
    let dy = (start_y - screen_y) / vp.zoom
    self.viewport.update(fn(v) { { ..v, scroll_x: v.scroll_x + dx, scroll_y: v.scroll_y + dy } })
    self.pan_start.set(Some((screen_x, screen_y)))
  }
}

///|
/// パン終了
pub fn EditorState::end_pan(self : EditorState) -> Unit {
  self.is_panning.set(false)
  self.pan_start.set(None)
}

// ============================================================
// リサイズ操作
// ============================================================

///|
/// リサイズ開始
pub fn EditorState::start_resize(
  self : EditorState,
  element_id : String,
  handle : @model.HandlePosition,
  mouse_x : Double,
  mouse_y : Double,
) -> Unit {
  guard self.find_element(element_id) is Some(el)
  self.resize_state.set(
    Some({
      element_id,
      handle,
      start_x: el.x,
      start_y: el.y,
      start_shape: el.shape,
      mouse_start_x: mouse_x,
      mouse_start_y: mouse_y,
    }),
  )
}

///|
/// リサイズ中の移動
pub fn EditorState::resize_move(
  self : EditorState,
  mouse_x : Double,
  mouse_y : Double,
) -> Unit {
  guard self.resize_state.get() is Some(state)
  let dx = mouse_x - state.mouse_start_x
  let dy = mouse_y - state.mouse_start_y
  let grid_enabled = self.grid_enabled.get()
  let grid_size = self.grid_size.get()
  // グリッドスナップ用ヘルパー（座標をスナップ）
  let snap_value = fn(v : Double) -> Double {
    if grid_enabled {
      let size = grid_size.to_double()
      (v / size).round() * size
    } else {
      v
    }
  }
  // ハンドル位置に応じて新しい位置と形状を計算
  match state.start_shape {
    @model.Rect(w, h, rx, ry) => {
      // 矩形の4隅を計算
      let x1 = state.start_x // 左
      let y1 = state.start_y // 上
      let x2 = state.start_x + w // 右
      let y2 = state.start_y + h // 下
      // ドラッグ中のハンドルに応じて、動かす点をスナップ、固定点は維持
      let (new_x1, new_y1, new_x2, new_y2) = match state.handle {
        @model.SE => {
          // SE（右下）をドラッグ：左上固定、右下をスナップ
          let dragged_x = snap_value(x2 + dx)
          let dragged_y = snap_value(y2 + dy)
          (x1, y1, dragged_x, dragged_y)
        }
        @model.NW => {
          // NW（左上）をドラッグ：右下固定、左上をスナップ
          let dragged_x = snap_value(x1 + dx)
          let dragged_y = snap_value(y1 + dy)
          (dragged_x, dragged_y, x2, y2)
        }
        @model.NE => {
          // NE（右上）をドラッグ：左下固定、右上をスナップ
          let dragged_x = snap_value(x2 + dx)
          let dragged_y = snap_value(y1 + dy)
          (x1, dragged_y, dragged_x, y2)
        }
        @model.SW => {
          // SW（左下）をドラッグ：右上固定、左下をスナップ
          let dragged_x = snap_value(x1 + dx)
          let dragged_y = snap_value(y2 + dy)
          (dragged_x, y1, x2, dragged_y)
        }
        _ => (x1, y1, x2 + dx, y2 + dy)
      }
      // 最小サイズを保証（幅・高さが負にならないように）
      let min_size = 10.0
      let (final_x1, final_x2) = if new_x2 - new_x1 < min_size {
        match state.handle {
          @model.NW | @model.SW => (new_x2 - min_size, new_x2)
          _ => (new_x1, new_x1 + min_size)
        }
      } else {
        (new_x1, new_x2)
      }
      let (final_y1, final_y2) = if new_y2 - new_y1 < min_size {
        match state.handle {
          @model.NW | @model.NE => (new_y2 - min_size, new_y2)
          _ => (new_y1, new_y1 + min_size)
        }
      } else {
        (new_y1, new_y2)
      }
      let final_x = final_x1
      let final_y = final_y1
      let final_w = final_x2 - final_x1
      let final_h = final_y2 - final_y1
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, x: final_x, y: final_y, shape: @model.Rect(final_w, final_h, rx, ry) }
          } else {
            el
          }
        })
      })
      // 接続されているラインを更新
      self.update_connected_lines(state.element_id)
    }
    @model.Circle(r) => {
      // 円の場合：中心は固定、ドラッグ点（辺）をスナップして半径を計算
      let cx = state.start_x
      let cy = state.start_y
      // ドラッグ中の辺の位置を計算
      let (edge_x, edge_y) = match state.handle {
        @model.SE => (cx + r + dx, cy + r + dy)
        @model.NW => (cx - r + dx, cy - r + dy)
        @model.NE => (cx + r + dx, cy - r + dy)
        @model.SW => (cx - r + dx, cy + r + dy)
        _ => (cx + r + dx, cy + r + dy)
      }
      // スナップ
      let snapped_edge_x = snap_value(edge_x)
      let snapped_edge_y = snap_value(edge_y)
      // 中心からの距離で半径を計算（x, y の平均を使用）
      let dist_x = (snapped_edge_x - cx).abs()
      let dist_y = (snapped_edge_y - cy).abs()
      let new_r = (dist_x + dist_y) / 2.0
      let final_r = if new_r < 5.0 { 5.0 } else { new_r }
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, shape: @model.Circle(final_r) }
          } else {
            el
          }
        })
      })
      // 接続されているラインを更新
      self.update_connected_lines(state.element_id)
    }
    @model.Ellipse(rx, ry) => {
      // 楕円の場合：中心は固定、ドラッグ点をスナップして rx, ry を計算
      let cx = state.start_x
      let cy = state.start_y
      // 楕円のバウンディングボックスの4隅
      let x1 = cx - rx
      let y1 = cy - ry
      let x2 = cx + rx
      let y2 = cy + ry
      // ドラッグ中のハンドルに応じて、動かす点をスナップ
      let (new_x1, new_y1, new_x2, new_y2) = match state.handle {
        @model.SE => {
          let dragged_x = snap_value(x2 + dx)
          let dragged_y = snap_value(y2 + dy)
          (x1, y1, dragged_x, dragged_y)
        }
        @model.NW => {
          let dragged_x = snap_value(x1 + dx)
          let dragged_y = snap_value(y1 + dy)
          (dragged_x, dragged_y, x2, y2)
        }
        @model.NE => {
          let dragged_x = snap_value(x2 + dx)
          let dragged_y = snap_value(y1 + dy)
          (x1, dragged_y, dragged_x, y2)
        }
        @model.SW => {
          let dragged_x = snap_value(x1 + dx)
          let dragged_y = snap_value(y2 + dy)
          (dragged_x, y1, x2, dragged_y)
        }
        _ => (x1, y1, x2 + dx, y2 + dy)
      }
      // 新しい中心と半径を計算
      let new_cx = (new_x1 + new_x2) / 2.0
      let new_cy = (new_y1 + new_y2) / 2.0
      let new_rx = (new_x2 - new_x1) / 2.0
      let new_ry = (new_y2 - new_y1) / 2.0
      // 最小サイズを保証
      let final_rx = if new_rx < 5.0 { 5.0 } else { new_rx }
      let final_ry = if new_ry < 5.0 { 5.0 } else { new_ry }
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, x: new_cx, y: new_cy, shape: @model.Ellipse(final_rx, final_ry) }
          } else {
            el
          }
        })
      })
      // 接続されているラインを更新
      self.update_connected_lines(state.element_id)
    }
    @model.Line(x2, y2) => {
      // 線の端点をドラッグ
      let snap_threshold = 20.0
      match state.handle {
        @model.LineStart => {
          // 始点を移動
          let raw_x = state.start_x + dx
          let raw_y = state.start_y + dy
          // 近くのアンカーポイントを探す（アンカースナップが優先）
          let snap_result = self.find_nearest_connection_point(
            { x: raw_x, y: raw_y },
            [state.element_id],
            snap_threshold,
          )
          let (new_x, new_y) = match snap_result {
            Some((_, _, snap_point)) => {
              // アンカースナップが優先
              (snap_point.x, snap_point.y)
            }
            None => {
              // アンカーがなければグリッドスナップ
              (snap_value(raw_x), snap_value(raw_y))
            }
          }
          // pending_connection を更新
          match snap_result {
            Some((target_el, anchor, snap_point)) =>
              self.pending_connection.set(Some({ target_id: target_el.id, anchor, point: snap_point }))
            None => self.pending_connection.set(None)
          }
          self.elements.update(fn(els) {
            els.map(fn(el) {
              if el.id == state.element_id {
                { ..el, x: new_x, y: new_y }
              } else {
                el
              }
            })
          })
        }
        @model.LineEnd => {
          // 終点を移動（Line の x2, y2 は絶対座標）
          // 新しい終点の絶対座標を計算
          let raw_end_x = x2 + dx
          let raw_end_y = y2 + dy
          // 近くのアンカーポイントを探す（アンカースナップが優先）
          let snap_result = self.find_nearest_connection_point(
            { x: raw_end_x, y: raw_end_y },
            [state.element_id],
            snap_threshold,
          )
          let (final_x2, final_y2) = match snap_result {
            Some((_, _, snap_point)) => (snap_point.x, snap_point.y)
            None => {
              // アンカーがなければグリッドスナップ
              (snap_value(raw_end_x), snap_value(raw_end_y))
            }
          }
          // pending_connection を更新
          match snap_result {
            Some((target_el, anchor, snap_point)) =>
              self.pending_connection.set(Some({ target_id: target_el.id, anchor, point: snap_point }))
            None => self.pending_connection.set(None)
          }
          self.elements.update(fn(els) {
            els.map(fn(el) {
              if el.id == state.element_id {
                { ..el, shape: @model.Line(final_x2, final_y2) }
              } else {
                el
              }
            })
          })
        }
        _ => () // Line に対して NW/NE/SW/SE ハンドルは無効
      }
    }
    _ => () // 他の形状は未対応
  }
}

///|
/// リサイズ終了
pub fn EditorState::end_resize(self : EditorState) -> Unit {
  // Line の場合、pending_connection があれば接続情報を保存
  if self.resize_state.get() is Some(resize) {
    if self.find_element(resize.element_id) is Some(el) {
      if el.shape is @model.Line(_, _) {
        if self.pending_connection.get() is Some(pending) {
          // 現在の接続情報を取得または新規作成
          let current_conns = el.connections.unwrap_or(@model.LineConnections::none())
          // ハンドル位置に応じて始点または終点の接続を更新
          let new_conns = match resize.handle {
            @model.LineStart => {
              let conn : @model.Connection = { element_id: pending.target_id, anchor: pending.anchor }
              { ..current_conns, start: Some(conn) }
            }
            @model.LineEnd => {
              let conn : @model.Connection = { element_id: pending.target_id, anchor: pending.anchor }
              { ..current_conns, end: Some(conn) }
            }
            _ => current_conns
          }
          self.update_line_connection(resize.element_id, new_conns)
        } else {
          // スナップしていない場合は接続を解除
          let current_conns = el.connections.unwrap_or(@model.LineConnections::none())
          let new_conns = match resize.handle {
            @model.LineStart => { ..current_conns, start: None }
            @model.LineEnd => { ..current_conns, end: None }
            _ => current_conns
          }
          // 接続が両方なくなった場合は connections を None に
          if new_conns.start is None && new_conns.end is None {
            self.elements.update(fn(els) {
              els.map(fn(e) {
                if e.id == resize.element_id {
                  { ..e, connections: None }
                } else {
                  e
                }
              })
            })
          } else {
            self.update_line_connection(resize.element_id, new_conns)
          }
        }
      }
    }
  }
  self.pending_connection.set(None)
  self.resize_state.set(None)
}

///|
/// リサイズ中かどうか
pub fn EditorState::is_resizing(self : EditorState) -> Bool {
  self.resize_state.get() is Some(_)
}

// ============================================================
// コマンド実行（Undo/Redo）
// ============================================================

///|
/// コマンドを実行して履歴に追加
pub fn execute_command(
  history : @model.History,
  state : EditorState,
  command : @model.Command,
) -> Unit {
  // コマンドを実行
  apply_command(command, state)
  // Undo スタックに追加
  history.undo_stack.push(command)
  // Redo スタックをクリア（新しい操作後は Redo できない）
  history.redo_stack.clear()
}

///|
/// Undo（取り消し）
pub fn undo_command(history : @model.History, state : EditorState) -> Bool {
  match history.undo_stack.pop() {
    None => false
    Some(command) => {
      // 逆操作を実行
      unapply_command(command, state)
      // Redo スタックに追加
      history.redo_stack.push(command)
      true
    }
  }
}

///|
/// Redo（やり直し）
pub fn redo_command(history : @model.History, state : EditorState) -> Bool {
  match history.redo_stack.pop() {
    None => false
    Some(command) => {
      // 操作を再実行
      apply_command(command, state)
      // Undo スタックに追加
      history.undo_stack.push(command)
      true
    }
  }
}

///|
/// コマンドを適用（実行）
fn apply_command(command : @model.Command, state : EditorState) -> Unit {
  match command {
    @model.AddElement(element) => state.add_element_raw(element)
    @model.RemoveElement(element) => state.remove_element_raw(element.id)
    @model.MoveElement(id, _, _, to_x, to_y) => state.move_element_raw(id, to_x, to_y)
    @model.ResizeElement(id, _, new_shape) => state.update_shape_raw(id, new_shape)
    @model.ReorderElement(id, _, to_idx) => state.reorder_element_raw(id, to_idx)
    @model.UpdateStyle(id, _, new_style) => state.update_style_raw(id, new_style)
    @model.RenameElement(old_id, new_id) => state.rename_element_raw(old_id, new_id)
    @model.UpdateText(id, _, new_content) => state.update_text_raw(id, new_content)
  }
}

///|
/// コマンドを取り消し（逆操作）
fn unapply_command(command : @model.Command, state : EditorState) -> Unit {
  match command {
    @model.AddElement(element) => state.remove_element_raw(element.id)
    @model.RemoveElement(element) => state.add_element_raw(element)
    @model.MoveElement(id, from_x, from_y, _, _) =>
      state.move_element_raw(id, from_x, from_y)
    @model.ResizeElement(id, old_shape, _) => state.update_shape_raw(id, old_shape)
    @model.ReorderElement(id, from_idx, _) => state.reorder_element_raw(id, from_idx)
    @model.UpdateStyle(id, old_style, _) => state.update_style_raw(id, old_style)
    @model.RenameElement(old_id, new_id) => state.rename_element_raw(new_id, old_id)
    @model.UpdateText(id, old_content, _) => state.update_text_raw(id, old_content)
  }
}

// ============================================================
// 矩形選択
// ============================================================

///|
/// 矩形選択を開始
pub fn EditorState::start_box_select(
  self : EditorState,
  x : Double,
  y : Double,
) -> Unit {
  self.box_select.set(Some({
    start_x: x,
    start_y: y,
    current_x: x,
    current_y: y,
  }))
}

///|
/// 矩形選択を更新
pub fn EditorState::update_box_select(
  self : EditorState,
  x : Double,
  y : Double,
) -> Unit {
  guard self.box_select.get() is Some(state)
  self.box_select.set(Some({ ..state, current_x: x, current_y: y }))
}

///|
/// 矩形選択を終了し、範囲内の要素を選択
pub fn EditorState::end_box_select(self : EditorState) -> Unit {
  if self.box_select.get() is Some(state) {
    let bbox = state.to_bbox()
    // 一定サイズ以上の選択範囲の場合のみ処理
    if bbox.width > 5.0 || bbox.height > 5.0 {
      let elements = @model.find_elements_in_box(self.elements.get(), bbox)
      let ids = elements.map(fn(el) { el.id })
      self.select_multiple(ids)
    }
  }
  self.box_select.set(None)
}

///|
/// 矩形選択中かどうか
pub fn EditorState::is_box_selecting(self : EditorState) -> Bool {
  self.box_select.get() is Some(_)
}

// ============================================================
// 複数要素ドラッグ
// ============================================================

///|
/// 複数要素のドラッグを開始
pub fn EditorState::start_multi_drag(
  self : EditorState,
  mouse_x : Double,
  mouse_y : Double,
) -> Unit {
  let ids = self.selected_ids.get()
  if ids.length() == 0 {
    return
  }
  // 各要素の開始位置を記録
  let start_positions : Array[(String, Double, Double)] = []
  let line_endpoints : Array[(String, Double, Double)] = []
  for id in ids {
    if self.find_element(id) is Some(el) {
      start_positions.push((id, el.x, el.y))
      // Line の場合は終点も記録
      if el.shape is @model.Line(x2, y2) {
        line_endpoints.push((id, x2, y2))
      }
    }
  }
  self.multi_drag_state.set(Some({
    element_ids: ids,
    start_positions,
    line_endpoints,
    mouse_start_x: mouse_x,
    mouse_start_y: mouse_y,
  }))
}

///|
/// 複数要素のドラッグ中の移動
pub fn EditorState::multi_drag_move(
  self : EditorState,
  mouse_x : Double,
  mouse_y : Double,
) -> Unit {
  guard self.multi_drag_state.get() is Some(state)
  let dx = mouse_x - state.mouse_start_x
  let dy = mouse_y - state.mouse_start_y
  let selected_ids = state.element_ids
  // Line の初期終点を検索するヘルパー
  let find_initial_endpoint = fn(id : String) -> (Double, Double)? {
    for ep in state.line_endpoints {
      let (ep_id, x2, y2) = ep
      if ep_id == id {
        return Some((x2, y2))
      }
    }
    None
  }
  // 各要素を移動
  for pos in state.start_positions {
    let (id, start_x, start_y) = pos
    guard self.find_element(id) is Some(el) else { continue }
    // Line の場合は接続を考慮
    match el.shape {
      @model.Line(_, _) => {
        // 接続情報を確認
        let conns = el.connections.unwrap_or(@model.LineConnections::none())
        // 始点が選択外の要素に接続されているか
        let start_connected_outside = match conns.start {
          Some(conn) => not(selected_ids.contains(conn.element_id))
          None => false
        }
        // 終点が選択外の要素に接続されているか
        let end_connected_outside = match conns.end {
          Some(conn) => not(selected_ids.contains(conn.element_id))
          None => false
        }
        if start_connected_outside && end_connected_outside {
          // 両端が選択外に接続 → 移動しない
          continue
        } else if start_connected_outside {
          // 始点が選択外に接続 → 終点だけ移動（初期値から計算）
          guard find_initial_endpoint(id) is Some((init_x2, init_y2)) else { continue }
          let new_x2 = init_x2 + dx
          let new_y2 = init_y2 + dy
          self.elements.update(fn(els) {
            els.map(fn(e) {
              if e.id == id {
                { ..e, shape: @model.Line(new_x2, new_y2) }
              } else {
                e
              }
            })
          })
        } else if end_connected_outside {
          // 終点が選択外に接続 → 始点だけ移動（x2, y2 は絶対座標なのでそのまま）
          guard find_initial_endpoint(id) is Some((init_x2, init_y2)) else { continue }
          let new_x = start_x + dx
          let new_y = start_y + dy
          let (snapped_x, snapped_y) = self.snap_to_grid(new_x, new_y)
          self.elements.update(fn(els) {
            els.map(fn(e) {
              if e.id == id {
                { ..e, x: snapped_x, y: snapped_y, shape: @model.Line(init_x2, init_y2) }
              } else {
                e
              }
            })
          })
        } else {
          // 両端とも選択外に接続していない → 通常移動
          let new_x = start_x + dx
          let new_y = start_y + dy
          let (snapped_x, snapped_y) = self.snap_to_grid(new_x, new_y)
          self.move_element(id, snapped_x, snapped_y)
        }
      }
      _ => {
        // Line 以外は通常移動
        let new_x = start_x + dx
        let new_y = start_y + dy
        let (snapped_x, snapped_y) = self.snap_to_grid(new_x, new_y)
        self.move_element(id, snapped_x, snapped_y)
      }
    }
  }
}

///|
/// 複数要素のドラッグを終了
pub fn EditorState::end_multi_drag(self : EditorState) -> Unit {
  self.multi_drag_state.set(None)
}

///|
/// 複数要素ドラッグ中かどうか
pub fn EditorState::is_multi_dragging(self : EditorState) -> Bool {
  self.multi_drag_state.get() is Some(_)
}

// ============================================================
// 接続ライン管理
// ============================================================

///|
/// 指定要素に接続されている全てのラインを更新
pub fn EditorState::update_connected_lines(self : EditorState, element_id : String) -> Unit {
  guard self.find_element(element_id) is Some(target)
  // 接続されているラインを探して更新
  self.elements.update(fn(elements) {
    elements.map(fn(el) {
      // Line 要素のみ処理
      guard el.shape is @model.Line(x2, y2) else { return el }
      guard el.connections is Some(conns) else { return el }
      // 始点の接続を確認（el.x, el.y が始点の絶対座標）
      let (new_x, new_y) = match conns.start {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = target.get_anchor_point(conn.anchor)
          (anchor_point.x, anchor_point.y)
        }
        _ => (el.x, el.y)
      }
      // 終点の接続を確認（x2, y2 は終点の絶対座標）
      let (new_x2, new_y2) = match conns.end {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = target.get_anchor_point(conn.anchor)
          (anchor_point.x, anchor_point.y)
        }
        _ => (x2, y2)
      }
      // 変更があれば更新
      if new_x != el.x || new_y != el.y || new_x2 != x2 || new_y2 != y2 {
        { ..el, x: new_x, y: new_y, shape: @model.Line(new_x2, new_y2) }
      } else {
        el
      }
    })
  })
}

///|
/// 指定要素に接続されているラインを更新（特定のラインを除く）
pub fn EditorState::update_connected_lines_except(
  self : EditorState,
  element_id : String,
  except_line_id : String,
) -> Unit {
  guard self.find_element(element_id) is Some(target)
  self.elements.update(fn(elements) {
    elements.map(fn(el) {
      // 除外するラインはスキップ
      if el.id == except_line_id {
        return el
      }
      // Line 要素のみ処理
      guard el.shape is @model.Line(x2, y2) else { return el }
      guard el.connections is Some(conns) else { return el }
      // 始点の接続を確認
      let (new_x, new_y) = match conns.start {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = target.get_anchor_point(conn.anchor)
          (anchor_point.x, anchor_point.y)
        }
        _ => (el.x, el.y)
      }
      // 終点の接続を確認
      let (new_x2, new_y2) = match conns.end {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = target.get_anchor_point(conn.anchor)
          (anchor_point.x, anchor_point.y)
        }
        _ => (x2, y2)
      }
      // 変更があれば更新
      if new_x != el.x || new_y != el.y || new_x2 != x2 || new_y2 != y2 {
        { ..el, x: new_x, y: new_y, shape: @model.Line(new_x2, new_y2) }
      } else {
        el
      }
    })
  })
}

///|
/// 線の接続情報を更新
pub fn EditorState::update_line_connection(
  self : EditorState,
  line_id : String,
  connections : @model.LineConnections,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == line_id {
        { ..el, connections: Some(connections) }
      } else {
        el
      }
    })
  })
}

///|
/// 指定座標から最も近い接続ポイントを探す（線を除く全要素から）
pub fn EditorState::find_nearest_connection_point(
  self : EditorState,
  point : @model.Point,
  exclude_ids : Array[String],
  threshold : Double,
) -> (@model.Element, @model.Anchor, @model.Point)? {
  let mut nearest : (@model.Element, @model.Anchor, @model.Point, Double)? = None
  for el in self.elements.get() {
    // 除外リストに含まれる要素はスキップ
    if exclude_ids.contains(el.id) {
      continue
    }
    // Line 要素はスキップ（Lineには接続しない）
    if el.shape is @model.Line(_, _) {
      continue
    }
    // 子要素はスキップ
    if el.parent_id is Some(_) {
      continue
    }
    // 最寄りのアンカーを探す
    if el.find_nearest_anchor(point, threshold) is Some((anchor, anchor_point, dist)) {
      match nearest {
        None => nearest = Some((el, anchor, anchor_point, dist))
        Some((_, _, _, prev_dist)) =>
          if dist < prev_dist {
            nearest = Some((el, anchor, anchor_point, dist))
          }
      }
    }
  }
  match nearest {
    Some((el, anchor, point, _)) => Some((el, anchor, point))
    None => None
  }
}
