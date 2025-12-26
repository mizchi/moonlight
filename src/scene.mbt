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
/// エディタの状態
pub struct EditorState {
  width : Int // キャンバス幅
  height : Int // キャンバス高さ
  elements : @luna.Signal[Array[Element]] // 要素リスト
  selected_id : @luna.Signal[String?] // 選択中の要素 ID
  drag_state : @luna.Signal[DragState?] // ドラッグ状態
  viewport : @luna.Signal[Viewport] // ビューポート
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
    viewport: @luna.signal(Viewport::default()),
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
