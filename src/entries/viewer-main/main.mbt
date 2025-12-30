// Viewer Main Entry - サイズ計測用

///|
fn main {
  // 依存関係を強制的に含める（tree-shaking 回避）
  let style = @viewer.default_style()
  let el = @viewer.rect("test", 0.0, 0.0, 100.0, 100.0, style)
  let svg = @viewer.to_svg([el], 400, 300)
  println(svg)
}
