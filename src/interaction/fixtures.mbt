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
/// 矢印（終点に矢じりの付いた線）
pub fn arrow(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> @model.Element {
  let el = line(id, x1, y1, x2, y2)
  el.with_style({ ..el.style, marker_end: Some(@model.Arrow), })
}

///|
/// 文字のスタイル。エディタで置く文字と同じく、縁取りはしない（縁取りがあると
/// 太く滲んで見える）。色はテーマの文字色、ラベルなら親の線の色になる。
let text_style : @model.Style = {
  fill: Some(@model.css_var_text),
  stroke: None,
  stroke_width: None,
  opacity: None,
  stroke_dasharray: None,
  marker_start: None,
  marker_end: None,
  font_family: None,
}

///|
/// テキスト（x, y は文字の中心）
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
) -> @model.Element {
  @model.Element::new(id, x, y, @model.Text(content, Some(16.0))).with_style(
    text_style,
  )
}

///|
/// 図形のラベル。図形の中央に置き、図形に結び付ける（図形を動かすと付いてくる）
pub fn label(
  id : String,
  parent : @model.Element,
  content : String,
) -> @model.Element {
  let b = parent.bounding_box()
  text(id, b.x + b.width / 2.0, b.y + b.height / 2.0, content).with_parent(
    parent.id,
  )
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
