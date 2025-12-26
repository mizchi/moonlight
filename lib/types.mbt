// Moonlight - Pure Calculation Functions
// Signal や DOM に依存しない純粋な計算関数

///|
/// 2D 座標点
pub struct Point {
  x : Double
  y : Double
} derive(Show, Eq)

///|
/// バウンディングボックス
pub struct BoundingBox {
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
pub enum HandlePosition {
  NW // 左上
  NE // 右上
  SW // 左下
  SE // 右下
} derive(Show, Eq)

///|
/// HandlePosition コンストラクタ関数（外部パッケージから呼び出し用）
pub fn handle_nw() -> HandlePosition { NW }

///|
pub fn handle_ne() -> HandlePosition { NE }

///|
pub fn handle_sw() -> HandlePosition { SW }

///|
pub fn handle_se() -> HandlePosition { SE }

///|
/// 矩形のリサイズ計算結果
pub struct RectResizeResult {
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
    SE => (start_x, start_y, start_w + dx, start_h + dy)
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
    SE => (dx + dy) / 2.0
    NW => -(dx + dy) / 2.0
    NE => (dx - dy) / 2.0
    SW => (-dx + dy) / 2.0
  }
  let new_r = start_r + dist
  if new_r < min_r { min_r } else { new_r }
}

///|
/// Viewport (表示領域) 座標変換
pub struct Viewport {
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
