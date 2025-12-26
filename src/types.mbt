// Moonlight - SVG Element Data Model
// SVG 仕様に準拠した最小限のデータモデル

///|
/// 2D 座標点
pub struct Point {
  x : Double
  y : Double
} derive(Show, Eq)

///|
/// 共通スタイル属性
pub struct Style {
  fill : String? // 塗りつぶし色 (e.g., "#ff0000", "none")
  stroke : String? // 線の色
  stroke_width : Double? // 線の太さ
  opacity : Double? // 不透明度 (0.0 - 1.0)
} derive(Show, Eq)

///|
/// デフォルトスタイル
pub fn Style::default() -> Style {
  {
    fill: None,
    stroke: Some("#000000"),
    stroke_width: Some(1.0),
    opacity: None,
  }
}

///|
/// 図形の種類
pub enum ShapeType {
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
pub struct Element {
  id : String // 一意な識別子
  x : Double // 基準 X 座標
  y : Double // 基準 Y 座標
  shape : ShapeType // 図形タイプ
  style : Style // スタイル属性
  transform : String? // SVG transform 属性
} derive(Show, Eq)

///|
/// 新しい要素を作成
pub fn Element::new(
  id : String,
  x : Double,
  y : Double,
  shape : ShapeType,
) -> Element {
  { id, x, y, shape, style: Style::default(), transform: None }
}

///|
/// スタイルを設定した要素を作成
pub fn Element::with_style(self : Element, style : Style) -> Element {
  { ..self, style, }
}

///|
/// 要素のバウンディングボックス
pub struct BoundingBox {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Show, Eq)

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
    Text(_, font_size) => {
      let size = font_size.unwrap_or(16.0)
      // テキストのバウンディングボックスは概算
      { x: self.x, y: self.y - size, width: 100.0, height: size }
    }
  }
}

///|
/// ポイントがバウンディングボックス内にあるか判定
pub fn BoundingBox::contains(self : BoundingBox, p : Point) -> Bool {
  p.x >= self.x &&
  p.x <= self.x + self.width &&
  p.y >= self.y &&
  p.y <= self.y + self.height
}

///|
/// ポイントが要素上にあるか判定
pub fn Element::hit_test(self : Element, p : Point) -> Bool {
  self.bounding_box().contains(p)
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
/// HandlePosition を lib 形式に変換
pub fn HandlePosition::to_lib(self : HandlePosition) -> @lib.HandlePosition {
  match self {
    NW => @lib.handle_nw()
    NE => @lib.handle_ne()
    SW => @lib.handle_sw()
    SE => @lib.handle_se()
  }
}
