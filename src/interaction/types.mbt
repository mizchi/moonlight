// セマンティックなインタラクションモデル
//
// 「操作が何を意味するか」だけを表す層。ピクセル・Signal・DOM に依存しない。
// UI 層は DOM イベントを Input に変換して Session::step に渡すだけでよく、
// 図形 × ジョイントの組み合わせはこのパッケージで一度だけ定義される。
//
// 同じ Session をそのままユニットテストでも、SVG レンダリングを経由した
// 視覚テストでも駆動できるので、意味と見た目のずれを検出できる。

// =============================================================================
// 定数
// =============================================================================

///|
/// 要素の最小サイズ（リサイズ時の下限）
pub let min_element_size : Double = 10.0

///|
/// 円・楕円の最小半径
pub let min_radius : Double = 5.0

///|
/// アンカースナップ距離（線の端点がジョイントに吸着する距離）
pub let anchor_snap_threshold : Double = 20.0

///|
/// この長さ未満の線は無効とみなして破棄する
pub let min_line_length : Double = 5.0

// =============================================================================
// グリッド
// =============================================================================

///|
/// グリッドスナップ設定
pub(all) struct Grid {
  enabled : Bool
  size : Double
} derive(Debug, Eq)

///|
/// スナップ無効のグリッド
pub fn Grid::off() -> Grid {
  { enabled: false, size: 10.0, }
}

///|
/// 指定サイズのスナップ有効グリッド
pub fn Grid::of(size : Double) -> Grid {
  { enabled: true, size, }
}

///|
/// 座標をグリッドに丸める（無効時は素通し）
pub fn Grid::snap(self : Grid, v : Double) -> Double {
  if self.enabled && self.size > 0.0 {
    (v / self.size).round() * self.size
  } else {
    v
  }
}

///|
/// 点をグリッドに丸める
pub fn Grid::snap_point(self : Grid, p : @model.Point) -> @model.Point {
  { x: self.snap(p.x), y: self.snap(p.y), }
}

// =============================================================================
// ジョイント（線の端点と図形のアンカーの結合）
// =============================================================================

///|
/// 線のどちらの端点か
pub(all) enum Endpoint {
  Start
  End
} derive(Debug, Eq)

///|
/// 端点に対応するリサイズハンドル
pub fn Endpoint::handle(self : Endpoint) -> @model.HandlePosition {
  match self {
    Start => @model.LineStart
    End => @model.LineEnd
  }
}

///|
/// リサイズハンドルが線の端点なら対応する Endpoint を返す
pub fn endpoint_of_handle(handle : @model.HandlePosition) -> Endpoint? {
  match handle {
    @model.LineStart => Some(Start)
    @model.LineEnd => Some(End)
    _ => None
  }
}

///|
/// ジョイント: 「線 line_id の endpoint 側が、要素 target_id の anchor に結合している」
pub(all) struct Joint {
  line_id : String
  endpoint : Endpoint
  target_id : String
  anchor : @model.Anchor
} derive(Debug, Eq)

///|
/// 線の端点がスナップ中の接続先（ドラッグ中のプレビュー）
pub(all) struct PendingJoint {
  target_id : String
  anchor : @model.Anchor
  point : @model.Point
} derive(Debug, Eq)

// =============================================================================
// シーン
// =============================================================================

///|
/// シーン: 操作が読み書きする状態すべて。Signal を含まない純粋な値。
pub(all) struct Scene {
  elements : Array[@model.Element]
  selection : Array[String]
  grid : Grid
} derive(Debug, Eq)

///|
/// 空のシーン
pub fn Scene::empty() -> Scene {
  { elements: [], selection: [], grid: Grid::off(), }
}

///|
/// 要素からシーンを作る
pub fn Scene::of(elements : Array[@model.Element]) -> Scene {
  { elements, selection: [], grid: Grid::off(), }
}

///|
/// グリッド設定を差し替えたシーン
pub fn Scene::with_grid(self : Scene, grid : Grid) -> Scene {
  { ..self, grid, }
}

///|
/// 選択を差し替えたシーン
pub fn Scene::with_selection(self : Scene, selection : Array[String]) -> Scene {
  { ..self, selection, }
}

///|
/// ID で要素を引く
pub fn Scene::find(self : Scene, id : String) -> @model.Element? {
  self.elements.iter().find_first(fn(e) { e.id == id })
}

///|
/// 点の上にある最前面の要素（描画順の後ろほど手前）
pub fn Scene::hit(self : Scene, p : @model.Point) -> @model.Element? {
  @model.find_element_at(self.elements, p)
}

// =============================================================================
// 入力とジェスチャ
// =============================================================================

///|
/// ポインタが掴んだもの。DOM ではなく意味で表す。
pub(all) enum Target {
  /// 何もない場所
  Canvas
  /// 要素の本体
  Body(String)
  /// リサイズハンドル（線の端点ハンドルを含む）
  Handle(String, @model.HandlePosition)
} derive(Debug, Eq)

///|
/// 入力イベント
pub(all) enum Input {
  /// ポインタを押した
  Press(Target, @model.Point)
  /// ポインタを動かした
  MoveTo(@model.Point)
  /// ポインタを離した
  Release
  /// 操作を取り消した（Escape）
  Cancel
} derive(Debug, Eq)

///|
/// 単一要素のドラッグ移動
pub(all) struct MoveGesture {
  element_id : String
  /// 掴んだ点と要素基準点の差分
  offset_x : Double
  offset_y : Double
} derive(Debug, Eq)

///|
/// リサイズ / 線の端点ドラッグ
pub(all) struct ResizeGesture {
  element_id : String
  handle : @model.HandlePosition
  start_x : Double
  start_y : Double
  start_shape : @model.ShapeType
  mouse_start : @model.Point
} derive(Debug, Eq)

///|
/// 進行中のジェスチャ
pub(all) enum Gesture {
  Idle
  Moving(MoveGesture)
  Resizing(ResizeGesture)
  BoxSelecting(@model.BoxSelectState)
} derive(Debug, Eq)

///|
/// ジェスチャ名（テスト・デバッグ用）
pub fn Gesture::name(self : Gesture) -> String {
  match self {
    Idle => "idle"
    Moving(_) => "moving"
    Resizing(_) => "resizing"
    BoxSelecting(_) => "box-selecting"
  }
}

// =============================================================================
// セッション
// =============================================================================

///|
/// 操作セッション: シーン + 進行中のジェスチャ。
/// `step` は純粋関数なので、入力列を与えれば結果は常に同じになる。
pub(all) struct Session {
  scene : Scene
  gesture : Gesture
  /// 線の端点がスナップ中の接続先（ドラッグ中のみ）
  pending : PendingJoint?
  /// ジェスチャ開始時の要素スナップショット（Cancel で巻き戻す）
  snapshot : Array[@model.Element]?
} derive(Debug, Eq)

///|
/// シーンから操作セッションを開始する
pub fn Session::start(scene : Scene) -> Session {
  { scene, gesture: Idle, pending: None, snapshot: None, }
}

///|
/// ジェスチャが進行中か
pub fn Session::is_active(self : Session) -> Bool {
  !(self.gesture is Idle)
}
