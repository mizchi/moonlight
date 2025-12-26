// Scene - Signal ベースの要素管理

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
/// 要素を移動（子要素も一緒に移動）
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
  // 親要素を移動
  self.update_element(id, fn(e) { { ..e, x: new_x, y: new_y } })
  // 子要素も移動
  let children = self.get_children(id)
  for child in children {
    self.update_element(child.id, fn(c) { { ..c, x: c.x + dx, y: c.y + dy } })
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
  self.drag_state.set(
    Some({
      element_id,
      start_x: el.x,
      start_y: el.y,
      offset_x: mouse_x - el.x,
      offset_y: mouse_y - el.y,
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
  // ハンドル位置に応じて新しい位置と形状を計算
  match state.start_shape {
    @model.Rect(w, h, rx, ry) => {
      let result = @model.calc_rect_resize(
        state.start_x, state.start_y,
        w, h,
        dx, dy,
        state.handle,
        10.0, // min_size
      )
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, x: result.x, y: result.y, shape: @model.Rect(result.width, result.height, rx, ry) }
          } else {
            el
          }
        })
      })
    }
    @model.Circle(r) => {
      let new_r = @model.calc_circle_resize(r, dx, dy, state.handle, 5.0)
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, shape: @model.Circle(new_r) }
          } else {
            el
          }
        })
      })
    }
    @model.Ellipse(rx, ry) => {
      // 楕円は矩形と同様にリサイズ
      let result = @model.calc_rect_resize(
        state.start_x - rx, state.start_y - ry,
        rx * 2.0, ry * 2.0,
        dx, dy,
        state.handle,
        10.0, // min_size
      )
      let new_rx = result.width / 2.0
      let new_ry = result.height / 2.0
      let new_cx = result.x + new_rx
      let new_cy = result.y + new_ry
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, x: new_cx, y: new_cy, shape: @model.Ellipse(new_rx, new_ry) }
          } else {
            el
          }
        })
      })
    }
    @model.Line(x2, y2) => {
      // 線の端点をドラッグ
      match state.handle {
        @model.LineStart => {
          // 始点を移動
          let new_x = state.start_x + dx
          let new_y = state.start_y + dy
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
          // 終点を移動
          let new_x2 = x2 + dx
          let new_y2 = y2 + dy
          self.elements.update(fn(els) {
            els.map(fn(el) {
              if el.id == state.element_id {
                { ..el, shape: @model.Line(new_x2, new_y2) }
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
  for id in ids {
    if self.find_element(id) is Some(el) {
      start_positions.push((id, el.x, el.y))
    }
  }
  self.multi_drag_state.set(Some({
    element_ids: ids,
    start_positions,
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
  // 各要素を移動
  for pos in state.start_positions {
    let (id, start_x, start_y) = pos
    let new_x = start_x + dx
    let new_y = start_y + dy
    let (snapped_x, snapped_y) = self.snap_to_grid(new_x, new_y)
    // 子要素も含めて移動
    self.move_element(id, snapped_x, snapped_y)
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
