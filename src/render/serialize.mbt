// SVG 直列化の唯一の実装。
//
// 以前はこれが 3 箇所にコピペされていた（src/render.mbt、src/render/svg.mbt、
// src/lib/render.mbt）。同じ 103 行を 3 回書けば必ず片方だけ直る日が来る。
// 実際、Text の text-anchor / dominant-baseline が片方にだけ入り、同じシーン
// なのにエディタと viewer でラベルの位置がずれていた。
//
// 出力の違いは 2 点しかないので、それを SvgFlavor で表して実装は 1 本にする。

///|
/// SVG 出力の種類
priv enum SvgFlavor {
  /// 標準 SVG。他のツールでそのまま開ける。
  /// 矢印は context-stroke で線の色を継承する。
  Plain
  /// Moonlight SVG。data-* に id・親子・接続を載せて再編集できるようにする。
  Moonlight
}

///|
/// 矢印マーカー id の接尾辞。defs 側の id と必ず対にすること
fn SvgFlavor::marker_suffix(self : SvgFlavor) -> String {
  match self {
    Plain => "-context"
    Moonlight => ""
  }
}

///|
/// 要素を SVG タグ 1 つに直列化する
fn serialize_element(
  el : @model.Element,
  parent_stroke : String?,
  flavor : SvgFlavor,
) -> String {
  let style = el.style
  let attrs = StringBuilder()

  // 再編集用メタデータ（Moonlight 形式のみ）
  if flavor is Moonlight {
    attrs.write_string(" data-id=\"\{el.id}\"")
    if el.parent_id is Some(pid) {
      attrs.write_string(" data-parent-id=\"\{pid}\"")
    }
    if el.connections is Some(conns) {
      if conns.start is Some(start_conn) {
        attrs.write_string(
          " data-connection-start=\"\{connection_to_string(start_conn)}\"",
        )
      }
      if conns.end is Some(end_conn) {
        attrs.write_string(
          " data-connection-end=\"\{connection_to_string(end_conn)}\"",
        )
      }
    }
  }

  // transform を落とすと図形の位置そのものが変わる
  if el.transform is Some(t) {
    attrs.write_string(" transform=\"\{t}\"")
  }

  // 塗り。テキストは親があれば親の stroke 色を継ぐ
  let is_text = el.shape is @model.Text(_, _)
  if is_text {
    attrs.write_string(
      " fill=\"\{@model.get_text_fill_color(style, parent_stroke)}\"",
    )
  } else {
    attrs.write_string(" fill=\"\{style.fill.unwrap_or("none")}\"")
  }
  // 縁取り。文字は縁取りを指定したときだけ付ける。エディタで置く文字には
  // 縁取りが無く、既定の黒い 1px を付けると太く滲み、色の付いたラベルは黒く
  // 縁取られる（統合前のエディタ側の書き出しもこうしていた）
  if !is_text || style.stroke is Some(_) {
    attrs.write_string(" stroke=\"\{style.stroke.unwrap_or("#000000")}\"")
    attrs.write_string(
      " stroke-width=\"\{@model.num_str(style.stroke_width.unwrap_or(1.0))}\"",
    )
  }
  if style.opacity is Some(v) {
    attrs.write_string(" opacity=\"\{@model.num_str(v)}\"")
  }
  if style.stroke_dasharray is Some(v) {
    attrs.write_string(" stroke-dasharray=\"\{v}\"")
  }
  let sfx = flavor.marker_suffix()
  if style.marker_start is Some(@model.Arrow) {
    attrs.write_string(" marker-start=\"url(#arrow-start\{sfx})\"")
  }
  if style.marker_end is Some(@model.Arrow) {
    attrs.write_string(" marker-end=\"url(#arrow-end\{sfx})\"")
  }
  let a = attrs.to_string()
  let n = @model.num_str
  match el.shape {
    @model.Rect(w, h, rx, ry) => {
      let rx_attr = match rx {
        Some(v) => " rx=\"\{n(v)}\""
        None => ""
      }
      let ry_attr = match ry {
        Some(v) => " ry=\"\{n(v)}\""
        None => ""
      }
      "<rect x=\"\{n(el.x)}\" y=\"\{n(el.y)}\" width=\"\{n(w)}\" height=\"\{n(h)}\"\{rx_attr}\{ry_attr}\{a}/>"
    }
    @model.Circle(r) =>
      "<circle cx=\"\{n(el.x)}\" cy=\"\{n(el.y)}\" r=\"\{n(r)}\"\{a}/>"
    @model.Ellipse(rx, ry) =>
      "<ellipse cx=\"\{n(el.x)}\" cy=\"\{n(el.y)}\" rx=\"\{n(rx)}\" ry=\"\{n(ry)}\"\{a}/>"
    @model.Line(x2, y2) =>
      "<line x1=\"\{n(el.x)}\" y1=\"\{n(el.y)}\" x2=\"\{n(x2)}\" y2=\"\{n(y2)}\"\{a}/>"
    @model.Polyline(points) => {
      let points_str = points.map(fn(p) { "\{n(p.x)},\{n(p.y)}" }).join(" ")
      "<polyline points=\"\{points_str}\"\{a}/>"
    }
    @model.Path(d, _, _, _, _) => "<path d=\"\{d}\"\{a}/>"
    @model.Text(content, font_size) => serialize_text(el, content, font_size, a)
  }
}

///|
/// テキスト。改行入りは tspan に割って、(x, y) を中心に上下対称に置く
fn serialize_text(
  el : @model.Element,
  content : String,
  font_size : Double?,
  attrs : String,
) -> String {
  let size = font_size.unwrap_or(16.0)
  let n = @model.num_str
  let fs_attr = " font-size=\"\{n(size)}\""
  let ff_attr = match el.style.font_family {
    Some(ff) => " font-family=\"\{ff}\""
    None => ""
  }
  // text-anchor / dominant-baseline を落とすと (x, y) が中心でなく
  // 左下基準になり、ラベルが右上にずれる
  let open = "<text x=\"\{n(el.x)}\" y=\"\{n(el.y)}\"\{fs_attr}\{ff_attr} text-anchor=\"middle\" dominant-baseline=\"middle\"\{attrs}>"
  if content.contains("\n") {
    let lines : Array[String] = content
      .split("\n")
      .map(fn(sv) { sv.to_owned() })
      .collect()
    let line_height = size * 1.2
    let start_offset = -((lines.length() - 1).to_double() * line_height) / 2.0
    let tspans : Array[String] = []
    for i, line in lines {
      let dy = if i == 0 { start_offset } else { line_height }
      tspans.push(
        "<tspan x=\"\{n(el.x)}\" dy=\"\{n(dy)}\">\{@model.escape_xml(line)}</tspan>",
      )
    }
    "\{open}\{tspans.join("")}</text>"
  } else {
    "\{open}\{@model.escape_xml(content)}</text>"
  }
}
