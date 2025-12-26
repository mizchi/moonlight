// Scene - Signal ベースの要素管理

///|
/// ドラッグ状態
pub struct DragState {
  element_id : String // ドラッグ中の要素 ID
  start_x : Double // ドラッグ開始時の要素 X
  start_y : Double // ドラッグ開始時の要素 Y
  offset_x : Double // クリック位置と要素位置の差分 X
  offset_y : Double // クリック位置と要素位置の差分 Y
} derive(Show, Eq)

///|
/// コンテキストメニューの状態
pub struct ContextMenu {
  x : Double // メニュー表示位置 X
  y : Double // メニュー表示位置 Y
  target_id : String? // 右クリック対象の要素 ID（None = 空白部分）
} derive(Show, Eq)

///|
/// リサイズ状態
pub struct ResizeState {
  element_id : String // リサイズ中の要素 ID
  handle : HandlePosition // ドラッグ中のハンドル
  start_x : Double // リサイズ開始時の要素 X
  start_y : Double // リサイズ開始時の要素 Y
  start_shape : ShapeType // リサイズ開始時の形状
  mouse_start_x : Double // マウス開始位置 X
  mouse_start_y : Double // マウス開始位置 Y
} derive(Show, Eq)

///|
/// エディタの状態
pub struct EditorState {
  width : Int // キャンバス幅
  height : Int // キャンバス高さ
  elements : @luna.Signal[Array[Element]] // 要素リスト
  selected_id : @luna.Signal[String?] // 選択中の要素 ID
  drag_state : @luna.Signal[DragState?] // ドラッグ状態
  resize_state : @luna.Signal[ResizeState?] // リサイズ状態
  context_menu : @luna.Signal[ContextMenu?] // コンテキストメニュー
  viewport : @luna.Signal[@lib.Viewport] // ビューポート
}

///|
/// エディタ状態を作成
pub fn EditorState::new(width : Int, height : Int) -> EditorState {
  {
    width,
    height,
    elements: @luna.signal([]),
    selected_id: @luna.signal(None),
    drag_state: @luna.signal(None),
    resize_state: @luna.signal(None),
    context_menu: @luna.signal(None),
    viewport: @luna.signal(@lib.Viewport::default()),
  }
}

///|
/// 要素を追加
pub fn EditorState::add_element(self : EditorState, element : Element) -> Unit {
  self.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(element)
    new_els
  })
}

///|
/// 要素を ID で検索
pub fn EditorState::find_element(self : EditorState, id : String) -> Element? {
  for el in self.elements.get() {
    if el.id == id {
      return Some(el)
    }
  }
  None
}

///|
/// 要素を更新
pub fn EditorState::update_element(
  self : EditorState,
  id : String,
  updater : (Element) -> Element,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) { if el.id == id { updater(el) } else { el } })
  })
}

///|
/// 要素を移動
pub fn EditorState::move_element(
  self : EditorState,
  id : String,
  new_x : Double,
  new_y : Double,
) -> Unit {
  self.update_element(id, fn(el) { { ..el, x: new_x, y: new_y } })
}

///|
/// 指定座標にある要素を検索（上から順に）
pub fn EditorState::hit_test(
  self : EditorState,
  x : Double,
  y : Double,
) -> Element? {
  let point : Point = { x, y }
  let els = self.elements.get()
  // 後ろから探す（上にあるものが優先）
  for i = els.length() - 1; i >= 0; i = i - 1 {
    if els[i].hit_test(point) {
      return Some(els[i])
    }
  }
  None
}

///|
/// 要素を選択
pub fn EditorState::select(self : EditorState, id : String?) -> Unit {
  self.selected_id.set(id)
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
  let new_x = mouse_x - state.offset_x
  let new_y = mouse_y - state.offset_y
  self.move_element(state.element_id, new_x, new_y)
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
  target_id : String?,
) -> Unit {
  self.context_menu.set(Some({ x, y, target_id }))
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
  if self.selected_id.get() == Some(id) {
    self.selected_id.set(None)
  }
}

///|
/// 選択中の要素を削除
pub fn EditorState::delete_selected(self : EditorState) -> Unit {
  if self.selected_id.get() is Some(id) {
    self.remove_element(id)
  }
}

// ============================================================
// 履歴管理用の低レベル操作（_raw サフィックス）
// これらは直接履歴に記録せず、Command から呼び出される
// ============================================================

///|
/// 要素を追加（履歴なし）
pub fn EditorState::add_element_raw(self : EditorState, element : Element) -> Unit {
  self.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(element)
    new_els
  })
}

///|
/// 要素を削除（履歴なし）
pub fn EditorState::remove_element_raw(self : EditorState, id : String) -> Unit {
  self.elements.update(fn(els) { els.filter(fn(el) { el.id != id }) })
  if self.selected_id.get() == Some(id) {
    self.selected_id.set(None)
  }
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
  new_shape : ShapeType,
) -> Unit {
  self.elements.update(fn(els) {
    els.map(fn(el) { if el.id == id { { ..el, shape: new_shape } } else { el } })
  })
}

// ============================================================
// リサイズ操作
// ============================================================

///|
/// リサイズ開始
pub fn EditorState::start_resize(
  self : EditorState,
  element_id : String,
  handle : HandlePosition,
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
    Rect(w, h, rx, ry) => {
      let result = @lib.calc_rect_resize(
        state.start_x, state.start_y,
        w, h,
        dx, dy,
        state.handle.to_lib(),
        10.0, // min_size
      )
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, x: result.x, y: result.y, shape: Rect(result.width, result.height, rx, ry) }
          } else {
            el
          }
        })
      })
    }
    Circle(r) => {
      let new_r = @lib.calc_circle_resize(r, dx, dy, state.handle.to_lib(), 5.0)
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, shape: Circle(new_r) }
          } else {
            el
          }
        })
      })
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
