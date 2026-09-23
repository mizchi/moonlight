// 起動時のサンプル（デモ）
//
// 最初に開いた人が、何ができるエディタなのかを一目でつかめる図にする。
// 図そのものが Moonlight の使い方を表している:
//
//   Draw ──▶ Plain SVG
//     ▲          │
//     └ ─ ─ Embed anywhere     （破線の矢印: 書き出した SVG をまた開いて直せる。
//                                中央の手描きの ↻ と「Round trip」がその往復を表す）
//
// 同時に、ひとつひとつの要素が機能の実例になっている:
//   - 楕円・角丸矩形・矩形と、その中のラベル（ダブルクリックで編集できる）
//   - アンカーに結合した矢印（図形を動かしても付いてくる）と、破線のスタイル
//   - 手描きの線をベジェ曲線に直したパス（中央の ↻）
//   - 画面の下に操作のヒント
//
// ラベルの文字色は親図形の線の色になる（get_text_fill_color）。塗りは淡く、線は
// 濃くして、ラベルが塗りの上で読めるようにする。塗りは固定色なのでダークモード
// でも読める。矢印とヒントは CSS 変数でテーマに追随する。

///|
/// サンプルの図形ひとつの配色（塗りは淡く、線とラベルは濃く）
priv struct SampleTint {
  fill : String
  stroke : String
}

///|
/// 紫: Draw
let tint_draw : SampleTint = { fill: "#f5f3ff", stroke: "#6d28d9", }

///|
/// 琥珀: Plain SVG
let tint_svg : SampleTint = { fill: "#fffbeb", stroke: "#b45309", }

///|
/// 緑: Embed anywhere
let tint_embed : SampleTint = { fill: "#ecfdf5", stroke: "#047857", }

///|
fn sample_node_style(tint : SampleTint) -> @model.Style {
  {
    fill: Some(tint.fill),
    stroke: Some(tint.stroke),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
fn sample_arrow_style(dashed : Bool) -> @model.Style {
  {
    fill: None,
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.5),
    opacity: None,
    stroke_dasharray: if dashed {
      Some("6,4")
    } else {
      None
    },
    marker_start: None,
    marker_end: Some(@model.Arrow),
    font_family: None,
  }
}

///|
/// 図形の中のラベル・図の外のヒントに使う文字のスタイル
fn sample_text_style(opacity : Double?) -> @model.Style {
  {
    fill: Some(@model.css_var_text),
    stroke: None,
    stroke_width: None,
    opacity,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
}

///|
/// サンプル（デモ）の要素を作る（純粋関数）
///
/// ドキュメントの既定の大きさ（400 × 300）に収まるように置いてある。
/// 上端はデスクトップでツールバーが少し重なるので、20 ほど空けてある。
pub fn sample_elements(new_id : () -> String) -> Array[@model.Element] {
  let elements : Array[@model.Element] = []
  // 図形と、その中央に置くラベル
  let node = fn(
    shape : @model.ShapeType,
    x : Double,
    y : Double,
    tint : SampleTint,
    label : String,
    size : Double,
  ) -> String {
    let id = new_id()
    let el = @model.Element::new(id, x, y, shape).with_style(
      sample_node_style(tint),
    )
    elements.push(el)
    let bbox = el.bounding_box()
    let label_el = @model.Element::new(
        new_id(),
        bbox.x + bbox.width / 2.0,
        bbox.y + bbox.height / 2.0,
        @model.Text(label, Some(size)),
      )
      .with_style(sample_text_style(None))
      .with_parent(id)
    elements.push(label_el)
    id
  }
  let draw = node(
    @model.Ellipse(56.0, 30.0),
    90.0,
    78.0,
    tint_draw,
    "Draw",
    16.0,
  )
  let svg = node(
    @model.Rect(116.0, 56.0, Some(10.0), Some(10.0)),
    252.0,
    50.0,
    tint_svg,
    "Plain SVG",
    15.0,
  )
  let embed = node(
    @model.Rect(130.0, 52.0, None, None),
    135.0,
    178.0,
    tint_embed,
    "Embed anywhere",
    15.0,
  )
  // 手描きの ↻（ベジェ曲線に直したフリーハンドの線）。一周して戻ってくる流れを表す。
  // 矢じりも手描きの一部として同じパスに描く（キャンバスはパスにマーカーを付けない）。
  // 端点は描き始めと描き終わり（Path の bounding box は端点から決まる）。
  let loop_d = "M 178 125 C 177.5 112 188 101.5 201 102 C 214 102.5 223.5 113 223 125.5 C 222.5 138 212 147.5 199.5 147 M 207.5 140.5 L 199 147 L 208 153.5"
  elements.push(
    @model.Element::new(
      new_id(),
      178.0,
      125.0,
      @model.Path(loop_d, 178.0, 125.0, 208.0, 153.5),
    ).with_style({
      ..sample_arrow_style(false),
      stroke_width: Some(2.0),
      marker_end: None,
    }),
  )
  elements.push(
    @model.Element::new(
      new_id(),
      200.0,
      165.0,
      @model.Text("Round trip", Some(12.0)),
    ).with_style(sample_text_style(Some(0.7))),
  )
  // 操作のヒント（図の下）
  elements.push(
    @model.Element::new(
      new_id(),
      200.0,
      258.0,
      @model.Text("Drag a shape: its arrows stay attached", Some(13.0)),
    ).with_style(sample_text_style(Some(0.7))),
  )
  elements.push(
    @model.Element::new(
      new_id(),
      200.0,
      280.0,
      @model.Text(
        "Double-click to edit  ·  Ctrl+Shift+C copies SVG",
        Some(13.0),
      ),
    ).with_style(sample_text_style(Some(0.7))),
  )
  // 矢印は最後に置いて最前面に描く。端点はアンカーに結合し、座標もそこに合わせる。
  let arrow = fn(from : String, from_anchor, to : String, to_anchor, dashed) {
    let anchor_of = fn(id : String, anchor : @model.Anchor) -> @model.Point {
      match elements.iter().find_first(fn(e) { e.id == id }) {
        Some(e) => e.get_anchor_point(anchor)
        None => { x: 0.0, y: 0.0, }
      }
    }
    let p = anchor_of(from, from_anchor)
    let q = anchor_of(to, to_anchor)
    elements.push({
      ..@model.Element::new(new_id(), p.x, p.y, @model.Line(q.x, q.y)).with_style(
        sample_arrow_style(dashed),
      ),
      connections: Some({
        start: Some({ element_id: from, anchor: from_anchor, }),
        end: Some({ element_id: to, anchor: to_anchor, }),
      }),
    })
  }
  arrow(draw, @model.Right, svg, @model.Left, false)
  arrow(svg, @model.Bottom, embed, @model.Right, false)
  // 書き出した SVG をまた開いて直す（往復）
  arrow(embed, @model.Left, draw, @model.Bottom, true)
  elements
}

///|
/// サンプル図形を追加
pub fn add_sample_shapes(
  state : @core.EditorState,
  new_id : () -> String,
) -> Unit {
  for el in sample_elements(new_id) {
    state.add_element_raw(el)
  }
}
