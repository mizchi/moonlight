// Scene - Signal ベースの要素管理

// =============================================================================
// 定数
// =============================================================================

/// 要素の最小サイズ（リサイズ時の下限）
let min_element_size : Double = 10.0

/// 配置オフセット（同一座標への連続配置時）
let placement_offset : Double = 15.0

/// アンカースナップ距離（Line端点のアンカースナップ判定）
let anchor_snap_threshold : Double = 20.0

// =============================================================================
// 型定義
// =============================================================================

///|
/// エディタモード
pub(all) enum EditorMode {
  Full // フル機能モード
  Embedded // 埋め込み簡易モード
}

///|
/// ツールモード
pub(all) enum ToolMode {
  Select // 選択モード（デフォルト）
  FreeDraw // フリードローモード
} derive(Show, Eq)

///|
/// フリードロー状態（描画中の点群）
pub(all) struct FreeDrawState {
  points : Array[@model.Point]
}

///|
/// フリードローオプション
pub(all) struct FreeDrawOptions {
  resample_dist : Double // リサンプリング間隔（デフォルト 4.0）
  epsilon : Double // RDP 簡略化パラメータ（デフォルト 2.0）
  max_error : Double // ベジェフィッティング最大誤差（デフォルト 8.0）
}

///|
/// 線のスナップ先プレビュー（ドラッグ中の視覚的フィードバック用）
pub(all) struct PendingConnection {
  target_id : String // 接続先の要素 ID
  anchor : @model.Anchor // アンカー位置
  point : @model.Point // 座標
}

///|
/// 配置モード状態（ショートカットキーからの要素挿入時）
pub(all) struct PlacementState {
  element_id : String // 配置中の要素ID
  anchor_element_id : String // アンカー元の要素ID
  anchor : @model.Anchor // アンカー位置
  anchor_point : @model.Point // アンカー座標
  is_line : Bool // Line/Arrow かどうか（接続情報を保存するか）
  is_arrow : Bool // Arrow かどうか（矢印マーカーを追加するか）
  has_moved : Bool // 1フレームでも動いたかどうか（Arrow表示判定用）
}

///|
/// アンカータイプ（アンカーポイントの位置）
pub(all) enum AnchorType {
  Top
  Bottom
  Left
  Right
  Center
  LineStart
  LineEnd
}

///|
/// アンカードラッグ状態（アンカーから線を描画中）
pub(all) struct AnchorDragState {
  source_element_id : String // ドラッグ開始元の要素ID
  source_anchor_type : AnchorType // どのアンカーから始まったか
  source_x : Double // アンカーポイントのX座標
  source_y : Double // アンカーポイントのY座標
  current_x : Double // 現在のマウスX座標
  current_y : Double // 現在のマウスY座標
}

///|
extern "js" fn js_null() -> @js.Any =
  #| () => null

///|
/// エディタの状態
pub struct EditorState {
  width : Int // 初期ビューポート幅
  height : Int // 初期ビューポート高さ
  canvas_width : @luna.Signal[Int] // キャンバス幅（動的）
  canvas_height : @luna.Signal[Int] // キャンバス高さ（動的）
  doc_width : @luna.Signal[Double] // ドキュメント幅
  doc_height : @luna.Signal[Double] // ドキュメント高さ
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
  placement_state : @luna.Signal[PlacementState?] // 配置モード状態
  mouse_scene_pos : @luna.Signal[@model.Point] // マウス位置（シーン座標）
  mouse_in_canvas : @luna.Signal[Bool] // マウスがキャンバス内にいるか
  preview_bg : @luna.Signal[String] // プレビュー背景色
  embed_bg : @luna.Signal[String] // 埋め込み時の背景色（デフォルト: transparent）
  theme_mode : @luna.Signal[@model.ThemeMode] // テーマモード
  is_mobile : @luna.Signal[Bool] // モバイル表示かどうか
  panel_visible : @luna.Signal[Bool] // パネル表示/非表示
  mode : EditorMode // エディタモード
  modal_open : @luna.Signal[Bool] // モーダル表示状態（埋め込みモード用）
  // 埋め込みモード用の追加フィールド
  has_focus : @luna.Signal[Bool] // フォーカスがあるか（キーボードイベント制御用）
  is_readonly : @luna.Signal[Bool] // 読み取り専用モード
  show_toolbar : @luna.Signal[Bool] // ツールバー表示/非表示
  // 埋め込みモード用 DOM 参照
  anchor_drag_state : @luna.Signal[AnchorDragState?] // アンカードラッグ状態
  svg_el : @luna.Signal[@js.Any] // SVG 要素への参照
  container_el : @luna.Signal[@js.Any] // コンテナ要素への参照
  // フリードロー関連
  tool_mode : @luna.Signal[ToolMode] // ツールモード（Select / FreeDraw）
  free_draw_state : @luna.Signal[FreeDrawState?] // フリードロー中の状態
  free_draw_options : @luna.Signal[FreeDrawOptions] // フリードローオプション
  // 配置位置オフセット
  last_placement_pos : @luna.Signal[@model.Point?] // 最後に配置した位置
}

///|
/// エディタ状態を作成
pub fn EditorState::new(width : Int, height : Int) -> EditorState {
  // 初期ドキュメントサイズ（キャンバスと同じ）
  let doc_w = 400.0
  let doc_h = 300.0
  // 初期 zoom は 100%、ドキュメント左上から表示
  let initial_viewport : @model.Viewport = {
    scroll_x: 0.0,
    scroll_y: 0.0,
    zoom: 1.0,
  }
  {
    width,
    height,
    canvas_width: @luna.signal(width),
    canvas_height: @luna.signal(height),
    doc_width: @luna.signal(doc_w),
    doc_height: @luna.signal(doc_h),
    elements: @luna.signal([]),
    selected_ids: @luna.signal([]),
    drag_state: @luna.signal(None),
    multi_drag_state: @luna.signal(None),
    resize_state: @luna.signal(None),
    box_select: @luna.signal(None),
    context_menu: @luna.signal(None),
    viewport: @luna.signal(initial_viewport),
    grid_enabled: @luna.signal(false),
    grid_size: @luna.signal(20),
    is_panning: @luna.signal(false),
    pan_start: @luna.signal(None),
    text_edit: @luna.signal(None),
    pending_connection: @luna.signal(None),
    placement_state: @luna.signal(None),
    mouse_scene_pos: @luna.signal({ x: 0.0, y: 0.0 }),
    mouse_in_canvas: @luna.signal(false),
    preview_bg: @luna.signal("#ffffff"),
    embed_bg: @luna.signal("transparent"),
    theme_mode: @luna.signal(@model.Light),
    is_mobile: @luna.signal(width < 768),
    panel_visible: @luna.signal(true),
    mode: Full,
    modal_open: @luna.signal(false),
    // 埋め込みモード用
    has_focus: @luna.signal(true), // Full モードではデフォルトで true
    is_readonly: @luna.signal(false),
    show_toolbar: @luna.signal(true),
    // 埋め込みモード用 DOM 参照
    anchor_drag_state: @luna.signal(None),
    svg_el: @luna.signal(js_null()),
    container_el: @luna.signal(js_null()),
    // フリードロー関連
    tool_mode: @luna.signal(Select),
    free_draw_state: @luna.signal(None),
    free_draw_options: @luna.signal({
      resample_dist: 4.0,
      epsilon: 2.0,
      max_error: 8.0,
    }),
    // 配置位置オフセット
    last_placement_pos: @luna.signal(None),
  }
}

///|
/// 指定モードでエディタ状態を作成
pub fn EditorState::new_with_mode(
  width : Int,
  height : Int,
  mode : EditorMode,
) -> EditorState {
  let state = EditorState::new(width, height)
  { ..state, mode, }
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
pub fn EditorState::get_default_style(_self : EditorState) -> @model.Style {
  {
    fill: Some(@model.css_var_fill),
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// テーマに基づいたテキストスタイルを取得（CSS変数を使用）
pub fn EditorState::get_text_style(_self : EditorState) -> @model.Style {
  {
    fill: Some(@model.css_var_text),
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
/// Line用のスタイルを取得（CSS変数を使用）
pub fn EditorState::get_line_style(_self : EditorState) -> @model.Style {
  {
    fill: None,
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// Arrow用のスタイルを取得（CSS変数を使用）
pub fn EditorState::get_arrow_style(_self : EditorState) -> @model.Style {
  {
    fill: None,
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: Some(@model.Arrow),
    font_family: None,
  }
}

///|
/// Arrow用のスタイルを取得（矢印なし - 配置モード初期用）
pub fn EditorState::get_arrow_style_initial(
  _self : EditorState,
) -> @model.Style {
  {
    fill: None,
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None, // 初期は矢印なし
    font_family: None,
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
  self.text_edit.set(
    Some({
      parent_id,
      x,
      y,
      editing_id: None,
      initial_text: "",
      font_size: None,
    }),
  )
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
  font_size : Double?,
) -> Unit {
  self.text_edit.set(
    Some({ parent_id, x, y, editing_id: Some(text_id), initial_text, font_size }),
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
pub fn EditorState::snap_to_grid(
  self : EditorState,
  x : Double,
  y : Double,
) -> (Double, Double) {
  @model.snap_to_grid(x, y, self.grid_size.get(), self.grid_enabled.get())
}

///|
/// 要素を追加（無効な要素は追加しない）
pub fn EditorState::add_element(
  self : EditorState,
  element : @model.Element,
) -> Unit {
  // サイズ0の図形やPathは追加しない
  guard element.is_valid() else { return }
  self.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(element)
    new_els
  })
}

///|
/// 要素を ID で検索
pub fn EditorState::find_element(
  self : EditorState,
  id : String,
) -> @model.Element? {
  for el in self.elements.get() {
    if el.id == id {
      return Some(el)
    }
  }
  None
}

///|
/// 指定IDの要素が存在するかチェック
pub fn EditorState::has_element_with_id(
  self : EditorState,
  id : String,
) -> Bool {
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
    els.map(fn(el) { if el.id == old_id { { ..el, id: new_id } } else { el } })
  })
  // 選択状態も更新
  self.selected_ids.update(fn(ids) {
    ids.map(fn(id) { if id == old_id { new_id } else { id } })
  })
  true
}

///|
/// 指定要素の子要素を取得
pub fn EditorState::get_children(
  self : EditorState,
  parent_id : String,
) -> Array[@model.Element] {
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
/// model 層の純粋関数を使用してアトミックに更新
pub fn EditorState::move_element(
  self : EditorState,
  id : String,
  new_x : Double,
  new_y : Double,
) -> Unit {
  // model 層の純粋関数で全ての更新を計算し、1回の set で適用
  let new_elements = @model.move_element_with_relations(
    self.elements.get(),
    id,
    new_x,
    new_y,
  )
  self.elements.set(new_elements)
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
pub fn EditorState::select_multiple(
  self : EditorState,
  ids : Array[String],
) -> Unit {
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
pub fn EditorState::remove_from_selection(
  self : EditorState,
  id : String,
) -> Unit {
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
  if ids.length() > 0 {
    Some(ids[0])
  } else {
    None
  }
}

///|
/// 全要素を選択（Line と子要素以外）
pub fn EditorState::select_all(self : EditorState) -> Unit {
  let ids : Array[String] = []
  for el in self.elements.get() {
    // 子要素は親と一緒に選択されるのでスキップ
    if el.parent_id is Some(_) {
      continue
    }
    // Line/Arrow は接続先と一緒に選択されることが多いので含める
    ids.push(el.id)
  }
  self.selected_ids.set(ids)
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
  let (start_shape, start_connections, connected_positions) : (
    @model.ShapeType?,
    @model.LineConnections?,
    Array[(String, Double, Double)],
  ) = match el.shape {
    @model.Line(_, _) => {
      let positions : Array[(String, Double, Double)] = []
      match el.connections {
        Some(conns) => {
          match conns.start {
            Some(conn) =>
              if self.find_element(conn.element_id) is Some(connected_el) {
                positions.push(
                  (conn.element_id, connected_el.x, connected_el.y),
                )
              }
            None => ()
          }
          match conns.end {
            Some(conn) =>
              if self.find_element(conn.element_id) is Some(connected_el) {
                positions.push(
                  (conn.element_id, connected_el.x, connected_el.y),
                )
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
  // Path も通常の要素と同様に el.x, el.y（transform オフセット）を基準にする
  let offset_x = mouse_x - el.x
  let offset_y = mouse_y - el.y
  self.drag_state.set(
    Some({
      element_id,
      start_x: el.x,
      start_y: el.y,
      offset_x,
      offset_y,
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
  let pos = @model.calc_drag_position(
    state.offset_x,
    state.offset_y,
    mouse_x,
    mouse_y,
  )
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
/// 要素を追加（履歴なし、無効な要素は追加しない）
pub fn EditorState::add_element_raw(
  self : EditorState,
  element : @model.Element,
) -> Unit {
  // サイズ0の図形やPathは追加しない
  guard element.is_valid() else { return }
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
    els.map(fn(el) { if el.id == id { { ..el, style: new_style } } else { el } })
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
    els.map(fn(el) { if el.id == old_id { { ..el, id: new_id } } else { el } })
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
          @model.Text(_, font_size) =>
            { ..el, shape: @model.Text(new_content, font_size) }
          _ => el
        }
      } else {
        el
      }
    })
  })
}

///|
/// 要素を1つ前面に移動
pub fn EditorState::bring_forward(
  self : EditorState,
  id : String,
) -> (Int, Int)? {
  let els = self.elements.get()
  if self.get_element_index(id) is Some(from_idx) {
    let to_idx = from_idx + 1
    if to_idx < els.length() {
      self.reorder_element_raw(id, to_idx)
      return Some((from_idx, to_idx))
    }
  }
  None
}

///|
/// 要素を最前面に移動
pub fn EditorState::bring_to_front(
  self : EditorState,
  id : String,
) -> (Int, Int)? {
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
/// 要素を1つ背面に移動
pub fn EditorState::send_backward(
  self : EditorState,
  id : String,
) -> (Int, Int)? {
  if self.get_element_index(id) is Some(from_idx) {
    if from_idx > 0 {
      let to_idx = from_idx - 1
      self.reorder_element_raw(id, to_idx)
      return Some((from_idx, to_idx))
    }
  }
  None
}

///|
/// 要素を最背面に移動
pub fn EditorState::send_to_back(
  self : EditorState,
  id : String,
) -> (Int, Int)? {
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
    let new_zoom = vp.zoom * 1.01
    // 最大 400%
    let clamped = if new_zoom > 4.0 { 4.0 } else { new_zoom }
    { ..vp, zoom: clamped }
  })
}

///|
/// ズームアウト
pub fn EditorState::zoom_out(self : EditorState) -> Unit {
  self.viewport.update(fn(vp) {
    let new_zoom = vp.zoom / 1.01
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
    // 新しいズーム値を計算（1%刻み）
    let factor = if zoom_in { 1.01 } else { 1.0 / 1.01 }
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
  self.fit_to_canvas()
}

///|
/// ドキュメント全体がキャンバスにフィットする zoom を計算してセット
pub fn EditorState::fit_to_canvas(self : EditorState) -> Unit {
  let doc_w = self.doc_width.get()
  let doc_h = self.doc_height.get()
  let canvas_w = self.canvas_width.get().to_double()
  let canvas_h = self.canvas_height.get().to_double()
  // 余白を含めてフィット
  let margin = 40.0
  let zoom_x = canvas_w / (doc_w + margin * 2.0)
  let zoom_y = canvas_h / (doc_h + margin * 2.0)
  let fit_zoom = if zoom_x < zoom_y { zoom_x } else { zoom_y }
  // ドキュメントを中央に配置
  let vb_width = canvas_w / fit_zoom
  let vb_height = canvas_h / fit_zoom
  let scroll_x = -(vb_width - doc_w) / 2.0
  let scroll_y = -(vb_height - doc_h) / 2.0
  self.viewport.set({ scroll_x, scroll_y, zoom: fit_zoom })
}

///|
/// ビューポートの中央座標を取得（シーン座標）
pub fn EditorState::get_viewport_center(self : EditorState) -> @model.Point {
  let vp = self.viewport.get()
  let canvas_w = self.canvas_width.get().to_double()
  let canvas_h = self.canvas_height.get().to_double()
  let center_x = vp.scroll_x + canvas_w / vp.zoom / 2.0
  let center_y = vp.scroll_y + canvas_h / vp.zoom / 2.0
  { x: center_x, y: center_y }
}

///|
/// 要素配置位置を取得（マウスがキャンバス内ならマウス位置、そうでなければ画面中央）
/// 同じ座標に繰り返し配置する場合は +15px ずらす
pub fn EditorState::get_placement_position(self : EditorState) -> @model.Point {
  let base_pos = if self.mouse_in_canvas.get() {
    self.mouse_scene_pos.get()
  } else {
    self.get_viewport_center()
  }
  // 最後の配置位置と同じなら offset ずらす
  let offset = placement_offset
  let final_pos = match self.last_placement_pos.get() {
    Some(last) =>
      if (base_pos.x - last.x).abs() < 1.0 && (base_pos.y - last.y).abs() < 1.0 {
        // 同じ位置なら右下にオフセット
        @model.Point::{ x: last.x + offset, y: last.y + offset }
      } else {
        base_pos
      }
    None => base_pos
  }
  // 位置を記録
  self.last_placement_pos.set(Some(final_pos))
  final_pos
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
pub fn EditorState::start_pan(
  self : EditorState,
  screen_x : Double,
  screen_y : Double,
) -> Unit {
  self.is_panning.set(true)
  self.pan_start.set(Some((screen_x, screen_y)))
}

///|
/// パン移動
pub fn EditorState::pan_move(
  self : EditorState,
  screen_x : Double,
  screen_y : Double,
) -> Unit {
  if self.pan_start.get() is Some((start_x, start_y)) {
    let vp = self.viewport.get()
    // スクリーン座標での移動量をシーン座標に変換
    let dx = (start_x - screen_x) / vp.zoom
    let dy = (start_y - screen_y) / vp.zoom
    self.viewport.update(fn(v) {
      { ..v, scroll_x: v.scroll_x + dx, scroll_y: v.scroll_y + dy }
    })
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
  // 単一値のグリッドスナップ
  let snap = fn(v : Double) -> Double {
    if self.grid_enabled.get() {
      let size = self.grid_size.get().to_double()
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
          let dragged_x = snap(x2 + dx)
          let dragged_y = snap(y2 + dy)
          (x1, y1, dragged_x, dragged_y)
        }
        @model.NW => {
          // NW（左上）をドラッグ：右下固定、左上をスナップ
          let dragged_x = snap(x1 + dx)
          let dragged_y = snap(y1 + dy)
          (dragged_x, dragged_y, x2, y2)
        }
        @model.NE => {
          // NE（右上）をドラッグ：左下固定、右上をスナップ
          let dragged_x = snap(x2 + dx)
          let dragged_y = snap(y1 + dy)
          (x1, dragged_y, dragged_x, y2)
        }
        @model.SW => {
          // SW（左下）をドラッグ：右上固定、左下をスナップ
          let dragged_x = snap(x1 + dx)
          let dragged_y = snap(y2 + dy)
          (dragged_x, y1, x2, dragged_y)
        }
        _ => (x1, y1, x2 + dx, y2 + dy)
      }
      // 最小サイズを保証（幅・高さが負にならないように）
      let min_size = min_element_size
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
      // 子要素の新しい中央位置
      let child_center_x = final_x + final_w / 2.0
      let child_center_y = final_y + final_h / 2.0
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            {
              ..el,
              x: final_x,
              y: final_y,
              shape: @model.Rect(final_w, final_h, rx, ry),
            }
          } else if el.parent_id == Some(state.element_id) {
            // 子要素を親の中央に配置
            { ..el, x: child_center_x, y: child_center_y }
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
      let snapped_edge_x = snap(edge_x)
      let snapped_edge_y = snap(edge_y)
      // 中心からの距離で半径を計算（x, y の平均を使用）
      let dist_x = (snapped_edge_x - cx).abs()
      let dist_y = (snapped_edge_y - cy).abs()
      let new_r = (dist_x + dist_y) / 2.0
      let final_r = if new_r < 5.0 { 5.0 } else { new_r }
      self.elements.update(fn(els) {
        els.map(fn(el) {
          if el.id == state.element_id {
            { ..el, shape: @model.Circle(final_r) }
          } else if el.parent_id == Some(state.element_id) {
            // 子要素を親の中央に配置（円の中心）
            { ..el, x: cx, y: cy }
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
          let dragged_x = snap(x2 + dx)
          let dragged_y = snap(y2 + dy)
          (x1, y1, dragged_x, dragged_y)
        }
        @model.NW => {
          let dragged_x = snap(x1 + dx)
          let dragged_y = snap(y1 + dy)
          (dragged_x, dragged_y, x2, y2)
        }
        @model.NE => {
          let dragged_x = snap(x2 + dx)
          let dragged_y = snap(y1 + dy)
          (x1, dragged_y, dragged_x, y2)
        }
        @model.SW => {
          let dragged_x = snap(x1 + dx)
          let dragged_y = snap(y2 + dy)
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
            {
              ..el,
              x: new_cx,
              y: new_cy,
              shape: @model.Ellipse(final_rx, final_ry),
            }
          } else if el.parent_id == Some(state.element_id) {
            // 子要素を親の中央に配置（楕円の中心）
            { ..el, x: new_cx, y: new_cy }
          } else {
            el
          }
        })
      })
      // 接続されているラインを更新
      self.update_connected_lines(state.element_id)
    }
    @model.Line(x2, y2) => {
      // 線の端点をドラッグ（アンカースナップ判定用）
      let snap_threshold = anchor_snap_threshold
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
            Some((_, _, snap_point)) =>
              // アンカースナップが優先
              (snap_point.x, snap_point.y)
            None =>
              // アンカーがなければグリッドスナップ
              (snap(raw_x), snap(raw_y))
          }
          // pending_connection を更新
          match snap_result {
            Some((target_el, anchor, snap_point)) =>
              self.pending_connection.set(
                Some({ target_id: target_el.id, anchor, point: snap_point }),
              )
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
            None =>
              // アンカーがなければグリッドスナップ
              (snap(raw_end_x), snap(raw_end_y))
          }
          // pending_connection を更新
          match snap_result {
            Some((target_el, anchor, snap_point)) =>
              self.pending_connection.set(
                Some({ target_id: target_el.id, anchor, point: snap_point }),
              )
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
          let current_conns = el.connections.unwrap_or(
            @model.LineConnections::none(),
          )
          // ハンドル位置に応じて始点または終点の接続を更新
          let new_conns = match resize.handle {
            @model.LineStart => {
              let conn : @model.Connection = {
                element_id: pending.target_id,
                anchor: pending.anchor,
              }
              { ..current_conns, start: Some(conn) }
            }
            @model.LineEnd => {
              let conn : @model.Connection = {
                element_id: pending.target_id,
                anchor: pending.anchor,
              }
              { ..current_conns, end: Some(conn) }
            }
            _ => current_conns
          }
          self.update_line_connection(resize.element_id, new_conns)
        } else {
          // スナップしていない場合は接続を解除
          let current_conns = el.connections.unwrap_or(
            @model.LineConnections::none(),
          )
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
      } else {
        // 親要素がリサイズされた場合、子テキストの位置を中央に調整
        self.center_child_elements(resize.element_id)
      }
      // 長さゼロの線は削除
      if el.shape is @model.Line(x2, y2) {
        let dx = x2 - el.x
        let dy = y2 - el.y
        let length = (dx * dx + dy * dy).sqrt()
        if length < 5.0 {
          self.remove_element(resize.element_id)
          self.pending_connection.set(None)
          self.resize_state.set(None)
          self.select(None)
          return
        }
      }
    }
  }
  // リサイズ完了後、要素を選択状態にする（ハンドルを表示するため）
  if self.resize_state.get() is Some(resize) {
    self.select(Some(resize.element_id))
  }
  self.pending_connection.set(None)
  self.resize_state.set(None)
}

///|
/// 親要素の子テキストを中央に配置
pub fn EditorState::center_child_elements(
  self : EditorState,
  parent_id : String,
) -> Unit {
  let elements = self.elements.get()
  // 親要素を検索
  let parent_el : @model.Element? = {
    let mut found : @model.Element? = None
    for e in elements {
      if e.id == parent_id {
        found = Some(e)
        break
      }
    }
    found
  }
  guard parent_el is Some(parent) else { return }

  // 親の中央座標を計算
  let bbox = parent.bounding_box()
  let center_x = bbox.x + bbox.width / 2.0
  let center_y = bbox.y + bbox.height / 2.0

  // 子要素の位置を更新
  self.elements.update(fn(els) {
    els.map(fn(el) {
      if el.parent_id == Some(parent_id) {
        { ..el, x: center_x, y: center_y }
      } else {
        el
      }
    })
  })
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
    @model.MoveElement(id, _, _, to_x, to_y) => {
      // model 層の純粋関数でアトミックに更新
      let new_elements = @model.move_element_with_relations(
        state.elements.get(),
        id,
        to_x,
        to_y,
      )
      state.elements.set(new_elements)
    }
    @model.ResizeElement(id, _, new_shape) => {
      // model 層の純粋関数でアトミックに更新
      let new_elements = @model.resize_element_with_relations(
        state.elements.get(),
        id,
        new_shape,
      )
      state.elements.set(new_elements)
    }
    @model.ReorderElement(id, _, to_idx) =>
      state.reorder_element_raw(id, to_idx)
    @model.UpdateStyle(id, _, new_style) =>
      state.update_style_raw(id, new_style)
    @model.RenameElement(old_id, new_id) =>
      state.rename_element_raw(old_id, new_id)
    @model.UpdateText(id, _, new_content) =>
      state.update_text_raw(id, new_content)
  }
}

///|
/// コマンドを取り消し（逆操作）
fn unapply_command(command : @model.Command, state : EditorState) -> Unit {
  match command {
    @model.AddElement(element) => state.remove_element_raw(element.id)
    @model.RemoveElement(element) => state.add_element_raw(element)
    @model.MoveElement(id, from_x, from_y, _, _) => {
      // model 層の純粋関数でアトミックに更新
      let new_elements = @model.move_element_with_relations(
        state.elements.get(),
        id,
        from_x,
        from_y,
      )
      state.elements.set(new_elements)
    }
    @model.ResizeElement(id, old_shape, _) => {
      // model 層の純粋関数でアトミックに更新
      let new_elements = @model.resize_element_with_relations(
        state.elements.get(),
        id,
        old_shape,
      )
      state.elements.set(new_elements)
    }
    @model.ReorderElement(id, from_idx, _) =>
      state.reorder_element_raw(id, from_idx)
    @model.UpdateStyle(id, old_style, _) =>
      state.update_style_raw(id, old_style)
    @model.RenameElement(old_id, new_id) =>
      state.rename_element_raw(new_id, old_id)
    @model.UpdateText(id, old_content, _) =>
      state.update_text_raw(id, old_content)
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
  self.box_select.set(
    Some({ start_x: x, start_y: y, current_x: x, current_y: y }),
  )
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
  self.multi_drag_state.set(
    Some({
      element_ids: ids,
      start_positions,
      line_endpoints,
      mouse_start_x: mouse_x,
      mouse_start_y: mouse_y,
    }),
  )
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
          guard find_initial_endpoint(id) is Some((init_x2, init_y2)) else {
            continue
          }
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
          guard find_initial_endpoint(id) is Some((init_x2, init_y2)) else {
            continue
          }
          let new_x = start_x + dx
          let new_y = start_y + dy
          let (snapped_x, snapped_y) = self.snap_to_grid(new_x, new_y)
          self.elements.update(fn(els) {
            els.map(fn(e) {
              if e.id == id {
                {
                  ..e,
                  x: snapped_x,
                  y: snapped_y,
                  shape: @model.Line(init_x2, init_y2),
                }
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
// 関連要素の同期
// ============================================================

///|
/// 要素の変更後に関連する要素を同期更新
/// - 子要素（テキストなど）を親の中央に再配置
/// - 接続されているラインの端点を更新
pub fn EditorState::sync_related_elements(
  self : EditorState,
  element_id : String,
) -> Unit {
  self.center_child_elements(element_id)
  self.update_connected_lines(element_id)
}

// ============================================================
// 接続ライン管理
// ============================================================

///|
/// 指定要素に接続されている全てのラインを更新
pub fn EditorState::update_connected_lines(
  self : EditorState,
  element_id : String,
) -> Unit {
  // 接続されているラインを探して更新
  self.elements.update(fn(elements) {
    // 更新対象の要素を elements から探す（最新の状態を取得）
    let target : @model.Element? = {
      let mut found : @model.Element? = None
      for e in elements {
        if e.id == element_id {
          found = Some(e)
          break
        }
      }
      found
    }
    guard target is Some(t) else { return elements }
    elements.map(fn(el) {
      // Line 要素のみ処理
      guard el.shape is @model.Line(x2, y2) else { return el }
      guard el.connections is Some(conns) else { return el }
      // 始点の接続を確認（el.x, el.y が始点の絶対座標）
      let (new_x, new_y) = match conns.start {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = t.get_anchor_point(conn.anchor)
          (anchor_point.x, anchor_point.y)
        }
        _ => (el.x, el.y)
      }
      // 終点の接続を確認（x2, y2 は終点の絶対座標）
      let (new_x2, new_y2) = match conns.end {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = t.get_anchor_point(conn.anchor)
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
  self.elements.update(fn(elements) {
    // 更新対象の要素を elements から探す（最新の状態を取得）
    let target : @model.Element? = {
      let mut found : @model.Element? = None
      for e in elements {
        if e.id == element_id {
          found = Some(e)
          break
        }
      }
      found
    }
    guard target is Some(t) else { return elements }
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
          let anchor_point = t.get_anchor_point(conn.anchor)
          (anchor_point.x, anchor_point.y)
        }
        _ => (el.x, el.y)
      }
      // 終点の接続を確認
      let (new_x2, new_y2) = match conns.end {
        Some(conn) if conn.element_id == element_id => {
          let anchor_point = t.get_anchor_point(conn.anchor)
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
/// 指定座標から最も近い接続ポイントを探す（全要素から）
pub fn EditorState::find_nearest_connection_point(
  self : EditorState,
  point : @model.Point,
  exclude_ids : Array[String],
  threshold : Double,
) -> (@model.Element, @model.Anchor, @model.Point)? {
  // 純粋関数を呼び出し、結果を変換
  match
    @model.find_nearest_connection(
      self.elements.get(),
      point,
      exclude_ids,
      threshold,
    ) {
    Some(result) => Some((result.element, result.anchor, result.point))
    None => None
  }
}

// ============================================================
// 配置モード関数
// ============================================================

///|
/// 配置モードを開始
pub fn EditorState::start_placement(
  self : EditorState,
  element_id : String,
  anchor_element_id : String,
  anchor : @model.Anchor,
  anchor_point : @model.Point,
  is_line : Bool,
  is_arrow? : Bool = false,
) -> Unit {
  self.placement_state.set(
    Some({
      element_id,
      anchor_element_id,
      anchor,
      anchor_point,
      is_line,
      is_arrow,
      has_moved: false,
    }),
  )
  self.select(Some(element_id))
}

///|
/// 配置モード中のマウス位置に応じて要素を更新
pub fn EditorState::update_placement(
  self : EditorState,
  mouse_pos : @model.Point,
) -> Unit {
  guard self.placement_state.get() is Some(placement)
  guard self.find_element(placement.element_id) is Some(el)

  // 初回移動時に has_moved を true に設定し、Arrow のマーカーを有効化
  if not(placement.has_moved) {
    self.placement_state.set(Some({ ..placement, has_moved: true }))
    // Arrow の場合、マーカーを追加
    if placement.is_arrow {
      self.update_element(placement.element_id, fn(e) {
        { ..e, style: { ..e.style, marker_end: Some(@model.Arrow) } }
      })
    }
  }

  // 単一値のグリッドスナップ
  let snap = fn(v : Double) -> Double {
    if self.grid_enabled.get() {
      let size = self.grid_size.get().to_double()
      (v / size).round() * size
    } else {
      v
    }
  }
  let anchor_x = placement.anchor_point.x
  let anchor_y = placement.anchor_point.y
  let mouse_x = snap(mouse_pos.x)
  let mouse_y = snap(mouse_pos.y)
  match el.shape {
    @model.Line(_, _) =>
      // Line/Arrow: 終点をマウス位置に更新（始点はアンカー位置で固定）
      self.update_element(placement.element_id, fn(e) {
        { ..e, shape: @model.Line(mouse_x, mouse_y) }
      })
    @model.Circle(_) => {
      // Circle: アンカーを中心として、マウス距離で半径を決定
      let dx = mouse_x - anchor_x
      let dy = mouse_y - anchor_y
      let raw_radius = (dx * dx + dy * dy).sqrt()
      let radius = if raw_radius < 5.0 { 5.0 } else { raw_radius }
      self.update_element(placement.element_id, fn(e) {
        { ..e, x: anchor_x, y: anchor_y, shape: @model.Circle(radius) }
      })
    }
    @model.Ellipse(_, _) => {
      // Ellipse: アンカーを中心として、マウス位置で rx/ry を決定
      let raw_rx = (mouse_x - anchor_x).abs()
      let raw_ry = (mouse_y - anchor_y).abs()
      let rx = if raw_rx < 5.0 { 5.0 } else { raw_rx }
      let ry = if raw_ry < 5.0 { 5.0 } else { raw_ry }
      self.update_element(placement.element_id, fn(e) {
        { ..e, x: anchor_x, y: anchor_y, shape: @model.Ellipse(rx, ry) }
      })
    }
    @model.Rect(_, _, corner_rx, corner_ry) => {
      // Rect: アンカーを固定点として、マウス位置で対角を決定
      let min_x = if anchor_x < mouse_x { anchor_x } else { mouse_x }
      let min_y = if anchor_y < mouse_y { anchor_y } else { mouse_y }
      let raw_width = (mouse_x - anchor_x).abs()
      let raw_height = (mouse_y - anchor_y).abs()
      let width = if raw_width < 10.0 { 10.0 } else { raw_width }
      let height = if raw_height < 10.0 { 10.0 } else { raw_height }
      self.update_element(placement.element_id, fn(e) {
        {
          ..e,
          x: min_x,
          y: min_y,
          shape: @model.Rect(width, height, corner_rx, corner_ry),
        }
      })
    }
    @model.Text(content, font_size) =>
      // Text: マウス位置に配置
      self.update_element(placement.element_id, fn(e) {
        { ..e, x: mouse_x, y: mouse_y, shape: @model.Text(content, font_size) }
      })
    _ =>
      // その他: マウス位置に配置
      self.update_element(placement.element_id, fn(e) {
        { ..e, x: mouse_x, y: mouse_y }
      })
  }
}

///|
/// 配置モードを終了（確定）
pub fn EditorState::end_placement(self : EditorState) -> Unit {
  guard self.placement_state.get() is Some(placement)
  guard self.find_element(placement.element_id) is Some(el)

  // 長さゼロの線は削除
  if el.shape is @model.Line(x2, y2) {
    let dx = x2 - el.x
    let dy = y2 - el.y
    let length = (dx * dx + dy * dy).sqrt()
    if length < 5.0 {
      // 最小長さ未満は削除
      self.remove_element(placement.element_id)
      self.placement_state.set(None)
      self.select(None)
      return
    }
  }

  // Line/Arrow の場合は接続情報を保存
  if placement.is_line {
    let connections : @model.LineConnections = {
      start: Some({
        element_id: placement.anchor_element_id,
        anchor: placement.anchor,
      }),
      end: None,
    }
    self.update_line_connection(placement.element_id, connections)
  }
  self.placement_state.set(None)
}

///|
/// 配置モードをキャンセル（要素を削除）
pub fn EditorState::cancel_placement(self : EditorState) -> Unit {
  guard self.placement_state.get() is Some(placement)

  // 配置中の要素を削除
  self.remove_element(placement.element_id)
  self.placement_state.set(None)
  self.select(None)
}

///|
/// 配置モード中かどうか
pub fn EditorState::is_placing(self : EditorState) -> Bool {
  self.placement_state.get() is Some(_)
}
