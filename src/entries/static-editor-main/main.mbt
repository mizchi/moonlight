// Static Editor Main Entry - サイズ計測用

///|
fn main {
  // import 機能を使用
  let new_id = @editor.create_id_generator()
  let svg_str = "<svg><rect x=\"10\" y=\"10\" width=\"100\" height=\"50\"/></svg>"
  let elements = @editor.import_svg(svg_str, new_id)

  // 要素を追加
  let style = @editor.default_style()
  let circle = @editor.circle("c1", 200.0, 100.0, 30.0, style)
  elements.push(circle)

  // SVG 出力
  let output = @editor.to_svg(elements, 400, 300)
  println(output)
}
