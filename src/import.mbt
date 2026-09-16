// SVG Import
//
// 実装は mizchi/moonlight/import に一本化してある。ここはその入口で、
// エディタ本体が今までどおりの名前で呼べるようにするだけ。パーサを二つ
// 持っていた頃は、片方だけ直して片方を忘れる事故があった。

///|
/// SVG文字列をパースして、要素と出どころを返す
pub fn import_svg_validated(
  svg_str : String,
  new_id : () -> String,
) -> @import.ImportResult {
  @import.import_svg_validated(svg_str, new_id)
}

///|
/// SVG文字列をパースして Element 配列を返す
pub fn import_svg_elements(
  svg_str : String,
  new_id : () -> String,
) -> Array[@model.Element] {
  @import.import_svg_elements(svg_str, new_id)
}
