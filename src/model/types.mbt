// Moonlight - Pure Calculation Functions
// Signal や DOM に依存しない純粋な計算関数

///|
/// 2D 座標点
pub(all) struct Point {
  x : Double
  y : Double
} derive(Show, Eq)

///|
/// アンカー位置（図形上の接続点）
pub(all) enum Anchor {
  Center
  Top
  Bottom
  Left
  Right
  TopLeft
  TopRight
  BottomLeft
  BottomRight
} derive(Show, Eq)

///|
/// 接続情報（線の端点が他の要素に接続している場合）
pub(all) struct Connection {
  element_id : String // 接続先の要素 ID
  anchor : Anchor // 接続点の位置
} derive(Show, Eq)

///|
/// 線の接続情報
pub(all) struct LineConnections {
  start : Connection? // 始点の接続（None = 自由端点）
  end : Connection? // 終点の接続（None = 自由端点）
} derive(Show, Eq)

///|
/// デフォルトの接続情報（接続なし）
pub fn LineConnections::none() -> LineConnections {
  { start: None, end: None }
}

///|
/// 矢印の種類
pub(all) enum ArrowType {
  NoArrow // 矢印なし
  Arrow // 標準の矢印
} derive(Show, Eq)

///|
/// テーマモード
pub(all) enum ThemeMode {
  Light
  Dark
} derive(Show, Eq)

///|
/// テーマ設定
pub(all) struct Theme {
  background : String // 背景色
  stroke : String // デフォルト線色（実際の値）
  fill : String // デフォルト塗りつぶし色（実際の値）
  text : String // テキスト色（実際の値）
  // UI用
  ui_bg : String // UIパネル背景
  ui_bg_hover : String // UIホバー背景
  ui_border : String // UIボーダー
  ui_text : String // UIテキスト
  ui_text_muted : String // UI補助テキスト
  ui_accent : String // UIアクセント
} derive(Show, Eq)

///|
/// CSS変数名
pub let css_var_stroke : String = "var(--ml-stroke)"

///|
pub let css_var_fill : String = "var(--ml-fill)"

///|
pub let css_var_text : String = "var(--ml-text)"

///|
/// ライトテーマのデフォルト
pub fn Theme::light() -> Theme {
  {
    background: "#ffffff",
    stroke: "#000000",
    fill: "transparent",
    text: "#000000",
    ui_bg: "rgba(255,255,255,0.98)",
    ui_bg_hover: "#f3f4f6",
    ui_border: "#d1d5db",
    ui_text: "#1f2937",
    ui_text_muted: "#6b7280",
    ui_accent: "#2563eb",
  }
}

///|
/// ダークテーマのデフォルト
pub fn Theme::dark() -> Theme {
  {
    background: "#1a1a1a",
    stroke: "#ffffff",
    fill: "transparent",
    text: "#ffffff",
    ui_bg: "rgba(31,31,31,0.98)",
    ui_bg_hover: "#374151",
    ui_border: "#4b5563",
    ui_text: "#f3f4f6",
    ui_text_muted: "#9ca3af",
    ui_accent: "#60a5fa",
  }
}

///|
/// プリセットカラー
pub(all) struct PresetColor {
  name : String
  light : String // ライトモード用
  dark : String // ダークモード用
} derive(Show, Eq)

///|
/// プリセットカラー一覧
pub fn preset_colors() -> Array[PresetColor] {
  [
    { name: "Black", light: "#000000", dark: "#ffffff" },
    { name: "Gray", light: "#6b7280", dark: "#9ca3af" },
    { name: "Red", light: "#dc2626", dark: "#f87171" },
    { name: "Orange", light: "#ea580c", dark: "#fb923c" },
    { name: "Yellow", light: "#ca8a04", dark: "#facc15" },
    { name: "Green", light: "#16a34a", dark: "#4ade80" },
    { name: "Blue", light: "#2563eb", dark: "#60a5fa" },
    { name: "Purple", light: "#9333ea", dark: "#c084fc" },
  ]
}

///|
/// 共通スタイル属性
pub(all) struct Style {
  fill : String? // 塗りつぶし色 (e.g., "#ff0000", "none")
  stroke : String? // 線の色
  stroke_width : Double? // 線の太さ
  opacity : Double? // 不透明度 (0.0 - 1.0)
  stroke_dasharray : String? // 破線パターン (e.g., "5,5", "10,5,2,5")
  marker_start : ArrowType? // 始点の矢印
  marker_end : ArrowType? // 終点の矢印
} derive(Show, Eq)

///|
/// デフォルトスタイル
pub fn Style::default() -> Style {
  {
    fill: None,
    stroke: Some("#000000"),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
}

///|
/// 図形の種類
pub(all) enum ShapeType {
  /// 矩形: width, height, rx (角丸X), ry (角丸Y)
  Rect(Double, Double, Double?, Double?)
  /// 円: 半径
  Circle(Double)
  /// 楕円: rx, ry
  Ellipse(Double, Double)
  /// 線分: 終点座標 (始点は Element.x, Element.y)
  Line(Double, Double)
  /// 折れ線
  Polyline(Array[Point])
  /// パス (SVG path d 属性)
  Path(String)
  /// テキスト: 内容, フォントサイズ
  Text(String, Double?)
} derive(Show, Eq)

///|
/// 図形要素
pub(all) struct Element {
  id : String // 一意な識別子
  x : Double // 基準 X 座標
  y : Double // 基準 Y 座標
  shape : ShapeType // 図形タイプ
  style : Style // スタイル属性
  transform : String? // SVG transform 属性
  parent_id : String? // 親要素の ID（グループ化用）
  connections : LineConnections? // 線の接続情報（Line のみ使用）
} derive(Show, Eq)

///|
/// 新しい要素を作成
pub fn Element::new(
  id : String,
  x : Double,
  y : Double,
  shape : ShapeType,
) -> Element {
  {
    id,
    x,
    y,
    shape,
    style: Style::default(),
    transform: None,
    parent_id: None,
    connections: None,
  }
}

///|
/// 親要素を設定
pub fn Element::with_parent(self : Element, parent_id : String) -> Element {
  { ..self, parent_id: Some(parent_id) }
}

///|
/// スタイルを設定した要素を作成
pub fn Element::with_style(self : Element, style : Style) -> Element {
  { ..self, style, }
}

///|
/// 要素のバウンディングボックスを計算
pub fn Element::bounding_box(self : Element) -> BoundingBox {
  match self.shape {
    Rect(w, h, _, _) => { x: self.x, y: self.y, width: w, height: h }
    Circle(r) =>
      { x: self.x - r, y: self.y - r, width: r * 2.0, height: r * 2.0 }
    Ellipse(rx, ry) =>
      { x: self.x - rx, y: self.y - ry, width: rx * 2.0, height: ry * 2.0 }
    Line(x2, y2) => {
      let min_x = if self.x < x2 { self.x } else { x2 }
      let min_y = if self.y < y2 { self.y } else { y2 }
      let max_x = if self.x > x2 { self.x } else { x2 }
      let max_y = if self.y > y2 { self.y } else { y2 }
      { x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
    }
    Polyline(points) =>
      if points.length() == 0 {
        { x: self.x, y: self.y, width: 0.0, height: 0.0 }
      } else {
        let mut min_x = self.x
        let mut min_y = self.y
        let mut max_x = self.x
        let mut max_y = self.y
        for p in points {
          if p.x < min_x {
            min_x = p.x
          }
          if p.y < min_y {
            min_y = p.y
          }
          if p.x > max_x {
            max_x = p.x
          }
          if p.y > max_y {
            max_y = p.y
          }
        }
        { x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
      }
    Path(_) =>
      // Path のバウンディングボックスは簡易的に要素位置のみ
      { x: self.x, y: self.y, width: 0.0, height: 0.0 }
    Text(content, font_size) => {
      let size = font_size.unwrap_or(16.0)
      // テキストのバウンディングボックスは概算（中央基準）
      // text-anchor="middle", dominant-baseline="middle" に対応
      let estimated_width = content.iter().count().to_double() * size * 0.6
      let width = if estimated_width < 20.0 { 20.0 } else { estimated_width }
      { x: self.x - width / 2.0, y: self.y - size / 2.0, width, height: size }
    }
  }
}

///|
/// ポイントが要素上にあるか判定
pub fn Element::hit_test(self : Element, p : Point) -> Bool {
  self.bounding_box().contains(p)
}

///|
/// 指定アンカーの座標を取得
pub fn Element::get_anchor_point(self : Element, anchor : Anchor) -> Point {
  let bbox = self.bounding_box()
  let cx = bbox.x + bbox.width / 2.0
  let cy = bbox.y + bbox.height / 2.0
  match anchor {
    Center => { x: cx, y: cy }
    Top => { x: cx, y: bbox.y }
    Bottom => { x: cx, y: bbox.y + bbox.height }
    Left => { x: bbox.x, y: cy }
    Right => { x: bbox.x + bbox.width, y: cy }
    TopLeft => { x: bbox.x, y: bbox.y }
    TopRight => { x: bbox.x + bbox.width, y: bbox.y }
    BottomLeft => { x: bbox.x, y: bbox.y + bbox.height }
    BottomRight => { x: bbox.x + bbox.width, y: bbox.y + bbox.height }
  }
}

///|
/// 全てのアンカー位置を取得
pub fn Element::get_all_anchors(self : Element) -> Array[(Anchor, Point)] {
  // 円・楕円は四隅のアンカーを持たない（上下左右と中心のみ）
  let anchors : Array[Anchor] = match self.shape {
    Circle(_) | Ellipse(_, _) => [Center, Top, Bottom, Left, Right]
    _ =>
      [
        Center,
        Top,
        Bottom,
        Left,
        Right,
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight,
      ]
  }
  anchors.map(fn(a) { (a, self.get_anchor_point(a)) })
}

///|
/// 点から最も近いアンカーを探す
pub fn Element::find_nearest_anchor(
  self : Element,
  point : Point,
  threshold : Double,
) -> (Anchor, Point, Double)? {
  let mut nearest : (Anchor, Point, Double)? = None
  for anchor_data in self.get_all_anchors() {
    let (anchor, anchor_point) = anchor_data
    let dx = point.x - anchor_point.x
    let dy = point.y - anchor_point.y
    let dist = (dx * dx + dy * dy).sqrt()
    if dist <= threshold {
      match nearest {
        None => nearest = Some((anchor, anchor_point, dist))
        Some((_, _, prev_dist)) =>
          if dist < prev_dist {
            nearest = Some((anchor, anchor_point, dist))
          }
      }
    }
  }
  nearest
}

///|
/// バウンディングボックス
pub(all) struct BoundingBox {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Show, Eq)

///|
/// ポイントがバウンディングボックス内にあるか判定
pub fn BoundingBox::contains(self : BoundingBox, p : Point) -> Bool {
  p.x >= self.x &&
  p.x <= self.x + self.width &&
  p.y >= self.y &&
  p.y <= self.y + self.height
}

///|
/// リサイズハンドルの位置
pub(all) enum HandlePosition {
  NW // 左上
  NE // 右上
  SW // 左下
  SE // 右下
  LineStart // 線の始点
  LineEnd // 線の終点
} derive(Show, Eq)

///|
/// 矩形のリサイズ計算結果
pub(all) struct RectResizeResult {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Show, Eq)

///|
/// 矩形のリサイズを計算（純粋関数）
pub fn calc_rect_resize(
  start_x : Double,
  start_y : Double,
  start_w : Double,
  start_h : Double,
  dx : Double,
  dy : Double,
  handle : HandlePosition,
  min_size : Double,
) -> RectResizeResult {
  let (new_x, new_y, new_w, new_h) = match handle {
    NW => (start_x + dx, start_y + dy, start_w - dx, start_h - dy)
    NE => (start_x, start_y + dy, start_w + dx, start_h - dy)
    SW => (start_x + dx, start_y, start_w - dx, start_h + dy)
    SE | LineStart | LineEnd => (start_x, start_y, start_w + dx, start_h + dy)
  }
  // 最小サイズを保証
  let final_w = if new_w < min_size { min_size } else { new_w }
  let final_h = if new_h < min_size { min_size } else { new_h }
  let final_x = if new_w < min_size {
    match handle {
      NW | SW => start_x + start_w - min_size
      _ => new_x
    }
  } else {
    new_x
  }
  let final_y = if new_h < min_size {
    match handle {
      NW | NE => start_y + start_h - min_size
      _ => new_y
    }
  } else {
    new_y
  }
  { x: final_x, y: final_y, width: final_w, height: final_h }
}

///|
/// 円のリサイズを計算（純粋関数）
pub fn calc_circle_resize(
  start_r : Double,
  dx : Double,
  dy : Double,
  handle : HandlePosition,
  min_r : Double,
) -> Double {
  // 円の場合は対角距離から半径を計算
  let dist = match handle {
    SE | LineStart | LineEnd => (dx + dy) / 2.0
    NW => -(dx + dy) / 2.0
    NE => (dx - dy) / 2.0
    SW => (-dx + dy) / 2.0
  }
  let new_r = start_r + dist
  if new_r < min_r {
    min_r
  } else {
    new_r
  }
}

///|
/// Viewport (表示領域) 座標変換
pub(all) struct Viewport {
  scroll_x : Double
  scroll_y : Double
  zoom : Double // 1.0 = 100%
} derive(Show, Eq)

///|
/// デフォルトビューポート
pub fn Viewport::default() -> Viewport {
  { scroll_x: 0.0, scroll_y: 0.0, zoom: 1.0 }
}

///|
/// 画面座標からシーン座標への変換
pub fn Viewport::screen_to_scene(
  self : Viewport,
  screen_x : Double,
  screen_y : Double,
) -> Point {
  {
    x: screen_x / self.zoom + self.scroll_x,
    y: screen_y / self.zoom + self.scroll_y,
  }
}

///|
/// シーン座標から画面座標への変換
pub fn Viewport::scene_to_screen(
  self : Viewport,
  scene_x : Double,
  scene_y : Double,
) -> Point {
  {
    x: (scene_x - self.scroll_x) * self.zoom,
    y: (scene_y - self.scroll_y) * self.zoom,
  }
}

// ============================================================
// UI 状態（純粋なデータ構造）
// ============================================================

///|
/// ドラッグ状態
pub(all) struct DragState {
  element_id : String // ドラッグ中の要素 ID
  start_x : Double // ドラッグ開始時の要素 X
  start_y : Double // ドラッグ開始時の要素 Y
  offset_x : Double // クリック位置と要素位置の差分 X
  offset_y : Double // クリック位置と要素位置の差分 Y
  start_shape : ShapeType? // Line の場合、開始時の形状を保存
  start_connections : LineConnections? // Line の場合、開始時の接続情報を保存
  connected_start_positions : Array[(String, Double, Double)] // 接続要素の開始位置
} derive(Show, Eq)

///|
/// コンテキストメニューの状態
pub(all) struct ContextMenu {
  x : Double // メニュー表示位置 X（スクリーン座標）
  y : Double // メニュー表示位置 Y（スクリーン座標）
  scene_x : Double // シーン座標 X（図形挿入用）
  scene_y : Double // シーン座標 Y（図形挿入用）
  target_id : String? // 右クリック対象の要素 ID（None = 空白部分）
} derive(Show, Eq)

///|
/// リサイズ状態
pub(all) struct ResizeState {
  element_id : String // リサイズ中の要素 ID
  handle : HandlePosition // ドラッグ中のハンドル
  start_x : Double // リサイズ開始時の要素 X
  start_y : Double // リサイズ開始時の要素 Y
  start_shape : ShapeType // リサイズ開始時の形状
  mouse_start_x : Double // マウス開始位置 X
  mouse_start_y : Double // マウス開始位置 Y
} derive(Show, Eq)

///|
/// 矩形選択状態
pub(all) struct BoxSelectState {
  start_x : Double // 選択開始 X（シーン座標）
  start_y : Double // 選択開始 Y（シーン座標）
  current_x : Double // 現在の X（シーン座標）
  current_y : Double // 現在の Y（シーン座標）
} derive(Show, Eq)

///|
/// 矩形選択のバウンディングボックスを取得
pub fn BoxSelectState::to_bbox(self : BoxSelectState) -> BoundingBox {
  let min_x = if self.start_x < self.current_x {
    self.start_x
  } else {
    self.current_x
  }
  let min_y = if self.start_y < self.current_y {
    self.start_y
  } else {
    self.current_y
  }
  let max_x = if self.start_x > self.current_x {
    self.start_x
  } else {
    self.current_x
  }
  let max_y = if self.start_y > self.current_y {
    self.start_y
  } else {
    self.current_y
  }
  { x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
}

///|
/// 複数要素のドラッグ状態
pub(all) struct MultiDragState {
  element_ids : Array[String] // ドラッグ中の要素 ID リスト
  start_positions : Array[(String, Double, Double)] // 各要素の開始位置 (id, x, y)
  line_endpoints : Array[(String, Double, Double)] // Line の終点初期値 (id, x2, y2)
  mouse_start_x : Double // マウス開始位置 X
  mouse_start_y : Double // マウス開始位置 Y
} derive(Show, Eq)

///|
/// テキスト編集状態
pub(all) struct TextEditState {
  parent_id : String // 親要素のID
  x : Double // 入力欄のX座標（シーン座標）
  y : Double // 入力欄のY座標（シーン座標）
  editing_id : String? // 編集中のテキスト要素ID（None = 新規作成）
  initial_text : String // 初期テキスト（編集時は既存の内容）
  font_size : Double? // フォントサイズ（None = デフォルト16px）
} derive(Show, Eq)

///|
/// ドラッグ位置を計算（純粋関数）
pub fn calc_drag_position(
  offset_x : Double,
  offset_y : Double,
  mouse_x : Double,
  mouse_y : Double,
) -> Point {
  { x: mouse_x - offset_x, y: mouse_y - offset_y }
}

///|
/// 要素配列から座標にヒットする要素を検索（上から順に、純粋関数）
pub fn find_element_at(elements : Array[Element], point : Point) -> Element? {
  // 後ろから探す（上にあるものが優先）
  for i = elements.length() - 1; i >= 0; i = i - 1 {
    if elements[i].hit_test(point) {
      return Some(elements[i])
    }
  }
  None
}

///|
/// 2つのバウンディングボックスが交差するか判定
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  // 一方が他方の完全に外側にある場合は交差しない
  not(
    self.x + self.width < other.x ||
    other.x + other.width < self.x ||
    self.y + self.height < other.y ||
    other.y + other.height < self.y,
  )
}

///|
/// 矩形選択内の要素を検索（純粋関数）
pub fn find_elements_in_box(
  elements : Array[Element],
  box_bbox : BoundingBox,
) -> Array[Element] {
  let result : Array[Element] = []
  for el in elements {
    // 親要素のみを対象（子要素は除外）
    if el.parent_id is None {
      let el_bbox = el.bounding_box()
      if box_bbox.intersects(el_bbox) {
        result.push(el)
      }
    }
  }
  result
}

///|
/// 座標をグリッドにスナップ（純粋関数）
pub fn snap_to_grid(
  x : Double,
  y : Double,
  grid_size : Int,
  enabled : Bool,
) -> (Double, Double) {
  if not(enabled) {
    return (x, y)
  }
  let size = grid_size.to_double()
  let snapped_x = (x / size).round() * size
  let snapped_y = (y / size).round() * size
  (snapped_x, snapped_y)
}

///|
/// ShapeType の名前を小文字で取得
pub fn shape_name(shape : ShapeType) -> String {
  match shape {
    Rect(_, _, _, _) => "rect"
    Circle(_) => "circle"
    Ellipse(_, _) => "ellipse"
    Line(_, _) => "line"
    Polyline(_) => "polyline"
    Path(_) => "path"
    Text(_, _) => "text"
  }
}

///|
/// ShapeType を文字列にフォーマット
pub fn format_shape(shape : ShapeType) -> String {
  match shape {
    Rect(w, h, _, _) => "Rect(\{w.to_int()}×\{h.to_int()})"
    Circle(r) => "Circle(r=\{r.to_int()})"
    Ellipse(rx, ry) => "Ellipse(\{rx.to_int()}×\{ry.to_int()})"
    Line(x2, y2) => "Line(→\{x2.to_int()},\{y2.to_int()})"
    Polyline(points) => "Polyline(\{points.length()} pts)"
    Path(_) => "Path"
    Text(content, _) => "Text(\"\{content}\")"
  }
}

///|
/// ハンドル文字列を HandlePosition に変換
pub fn parse_handle_position(handle_str : String) -> HandlePosition {
  match handle_str {
    "nw" => NW
    "ne" => NE
    "sw" => SW
    "se" => SE
    "line-start" => LineStart
    "line-end" => LineEnd
    _ => SE // デフォルト
  }
}

///|
/// アンカー名文字列を Anchor に変換
pub fn parse_anchor(anchor_str : String) -> Anchor? {
  match anchor_str {
    "center" => Some(Center)
    "top" => Some(Top)
    "bottom" => Some(Bottom)
    "left" => Some(Left)
    "right" => Some(Right)
    "top-left" => Some(TopLeft)
    "top-right" => Some(TopRight)
    "bottom-left" => Some(BottomLeft)
    "bottom-right" => Some(BottomRight)
    _ => None
  }
}

// ============================================================
// 接続ライン計算（純粋関数）
// ============================================================

///|
/// LineConnections から接続要素のIDリストを取得
pub fn LineConnections::get_connected_ids(
  self : LineConnections,
) -> Array[String] {
  let ids : Array[String] = []
  match self.start {
    Some(conn) =>
      if not(ids.contains(conn.element_id)) {
        ids.push(conn.element_id)
      }
    None => ()
  }
  match self.end {
    Some(conn) =>
      if not(ids.contains(conn.element_id)) {
        ids.push(conn.element_id)
      }
    None => ()
  }
  ids
}

///|
/// 接続ラインの更新結果
pub(all) struct ConnectedLineUpdate {
  line_id : String
  new_x : Double
  new_y : Double
  new_x2 : Double
  new_y2 : Double
} derive(Show, Eq)

///|
/// 要素移動後の接続ラインの新座標を計算（純粋関数）
/// target_id: 移動した要素のID
/// new_target_x, new_target_y: 移動後の座標
/// lines: 接続されている可能性があるLine要素のリスト
/// all_elements: 全要素（アンカー位置計算用）
pub fn calc_connected_line_updates(
  target_id : String,
  new_target_x : Double,
  new_target_y : Double,
  lines : Array[Element],
  all_elements : Array[Element],
) -> Array[ConnectedLineUpdate] {
  let updates : Array[ConnectedLineUpdate] = []
  // 移動後のターゲット要素を作成（アンカー計算用）
  let mut moved_target : Element? = None
  for el in all_elements {
    if el.id == target_id {
      moved_target = Some({ ..el, x: new_target_x, y: new_target_y })
      break
    }
  }
  // ターゲット要素が見つからない場合は空配列を返す
  guard moved_target is Some(target) else { return updates }
  for line in lines {
    // Line 要素のみ処理
    guard line.shape is Line(x2, y2) else { continue }
    guard line.connections is Some(conns) else { continue }
    let mut new_x = line.x
    let mut new_y = line.y
    let mut new_x2 = x2
    let mut new_y2 = y2
    let mut changed = false
    // 始点の接続を確認
    match conns.start {
      Some(conn) if conn.element_id == target_id => {
        let anchor_point = target.get_anchor_point(conn.anchor)
        new_x = anchor_point.x
        new_y = anchor_point.y
        changed = true
      }
      _ => ()
    }
    // 終点の接続を確認
    match conns.end {
      Some(conn) if conn.element_id == target_id => {
        let anchor_point = target.get_anchor_point(conn.anchor)
        new_x2 = anchor_point.x
        new_y2 = anchor_point.y
        changed = true
      }
      _ => ()
    }
    if changed {
      updates.push({ line_id: line.id, new_x, new_y, new_x2, new_y2 })
    }
  }
  updates
}

///|
/// 子要素の移動後座標を計算（純粋関数）
pub(all) struct ChildMoveResult {
  child_id : String
  new_x : Double
  new_y : Double
} derive(Show, Eq)

///|
/// 親要素移動時の子要素の新座標を計算
pub fn calc_child_positions(
  parent_id : String,
  dx : Double,
  dy : Double,
  elements : Array[Element],
) -> Array[ChildMoveResult] {
  let results : Array[ChildMoveResult] = []
  for el in elements {
    if el.parent_id == Some(parent_id) {
      results.push({ child_id: el.id, new_x: el.x + dx, new_y: el.y + dy })
    }
  }
  results
}

///|
/// 要素の移動結果を計算（純粋関数）
/// 入力の要素配列を変更せず、更新後の新しい配列を返す
pub fn apply_element_move(
  elements : Array[Element],
  target_id : String,
  new_x : Double,
  new_y : Double,
) -> Array[Element] {
  // 移動差分を計算
  let mut dx = 0.0
  let mut dy = 0.0
  for el in elements {
    if el.id == target_id {
      dx = new_x - el.x
      dy = new_y - el.y
      break
    }
  }
  // 子要素のIDを収集
  let child_ids : Array[String] = []
  for el in elements {
    if el.parent_id == Some(target_id) {
      child_ids.push(el.id)
    }
  }
  // Line要素を収集（接続ライン更新用）
  let lines : Array[Element] = []
  for el in elements {
    if el.shape is Line(_, _) && el.connections is Some(_) && el.id != target_id {
      lines.push(el)
    }
  }
  // 接続ラインの更新を計算
  let line_updates = calc_connected_line_updates(
    target_id, new_x, new_y, lines, elements,
  )
  // 要素配列を更新
  elements.map(fn(el) {
    // ターゲット要素を移動
    if el.id == target_id {
      return { ..el, x: new_x, y: new_y }
    }
    // 子要素を移動
    if child_ids.contains(el.id) {
      return { ..el, x: el.x + dx, y: el.y + dy }
    }
    // 接続ラインを更新
    for update in line_updates {
      if el.id == update.line_id {
        return {
          ..el,
          x: update.new_x,
          y: update.new_y,
          shape: Line(update.new_x2, update.new_y2),
        }
      }
    }
    el
  })
}

// ===== ユーティリティ関数 =====

///|
/// XML エスケープ
pub fn escape_xml(s : String) -> String {
  s
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
}

///|
/// 数値を文字列に変換
pub fn num_str(value : Double) -> String {
  value.to_string()
}
