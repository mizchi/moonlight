// テスト用のシーン組み立てヘルパー
//
// 図形 × アンカーの組み合わせを網羅したいので、シーンを一行で作れるようにする。

///|
/// 矩形
pub fn rect(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> @model.Element {
  @model.Element::new(id, x, y, @model.Rect(w, h, None, None))
}

///|
/// 円（x, y は中心）
pub fn circle(
  id : String,
  cx : Double,
  cy : Double,
  r : Double,
) -> @model.Element {
  @model.Element::new(id, cx, cy, @model.Circle(r))
}

///|
/// 楕円（x, y は中心）
pub fn ellipse(
  id : String,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> @model.Element {
  @model.Element::new(id, cx, cy, @model.Ellipse(rx, ry))
}

///|
/// 線
pub fn line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> @model.Element {
  @model.Element::new(id, x1, y1, @model.Line(x2, y2))
}

///|
/// テキスト
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
) -> @model.Element {
  @model.Element::new(id, x, y, @model.Text(content, Some(16.0)))
}

///|
/// 図形の種類（組み合わせテストの軸）
pub(all) enum ShapeKind {
  RectKind
  CircleKind
  EllipseKind
} derive(Debug, Eq)

///|
/// 種類の名前
pub fn ShapeKind::name(self : ShapeKind) -> String {
  match self {
    RectKind => "rect"
    CircleKind => "circle"
    EllipseKind => "ellipse"
  }
}

///|
/// 同じバウンディングボックスを占める図形を種類別に作る。
/// どの種類でもアンカー座標が揃うので、組み合わせテストの比較がしやすい。
pub fn ShapeKind::make(
  self : ShapeKind,
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> @model.Element {
  match self {
    RectKind => rect(id, x, y, w, h)
    CircleKind => {
      // 円は幅と高さの小さいほうに合わせる
      let r = (if w < h { w } else { h }) / 2.0
      circle(id, x + w / 2.0, y + h / 2.0, r)
    }
    EllipseKind => ellipse(id, x + w / 2.0, y + h / 2.0, w / 2.0, h / 2.0)
  }
}

///|
/// 組み合わせテストで使う図形の種類すべて
pub fn all_shape_kinds() -> Array[ShapeKind] {
  [RectKind, CircleKind, EllipseKind]
}

///|
/// その図形が実際に接続先として差し出すアンカー。
/// Center は端点が図形の内部に入ってしまうので視覚テストからは外す。
pub fn connectable_perimeter_anchors(
  el : @model.Element,
) -> Array[@model.Anchor] {
  el.shape.config().anchor_types.filter(fn(a) {
    !(a is @model.Center) && !(a is @model.LineStart) && !(a is @model.LineEnd)
  })
}

///|
/// 図形の種類が差し出す外周アンカー
pub fn ShapeKind::perimeter_anchors(self : ShapeKind) -> Array[@model.Anchor] {
  connectable_perimeter_anchors(self.make("probe", 0.0, 0.0, 10.0, 10.0))
}
