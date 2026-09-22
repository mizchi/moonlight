// エディタの Export（Moonlight 形式）と viewer / static-editor の描画
// （標準 SVG 形式）は、同じ直列化実装を共有していなければならない。
//
// 以前は同じ 103 行が 3 箇所にコピペされていて、案の定それぞれが別々に
// 直されていた。片方にしか無かったもの＝ここで固定する不変条件:
//   - Text の text-anchor / dominant-baseline（Moonlight に無く、ラベルがずれた）
//   - transform（Plain に無く、図形の位置が失われた）
//   - 改行入りテキストの tspan 分割（Plain に無く、複数行が潰れた）
//   - font-family（Moonlight に無かった）
//   - 数値の正規化（Moonlight は生の Double を出していた）

///|
fn elem(
  shape : @model.ShapeType,
  style? : @model.Style = @model.Style::default(),
  transform? : String,
) -> Array[@model.Element] {
  [
    {
      id: "e1",
      x: 100.0,
      y: 50.0,
      shape,
      style,
      transform,
      parent_id: None,
      connections: None,
    },
  ]
}

///|
/// 両方の形式で出力して、共通の不変条件を同じ物差しで見る
fn both(elements : Array[@model.Element]) -> (String, String) {
  (
    elements_to_svg(elements, 200, 100),
    elements_to_moonlight_svg(elements, 200, 100, "#ffffff"),
  )
}

///|
test "テキストは (x, y) を中心に置く（両形式）" {
  let (plain, moonlight) = both(elem(@model.Text("hello", Some(16.0))))
  for svg in [plain, moonlight] {
    assert_true(svg.contains("text-anchor=\"middle\""))
    assert_true(svg.contains("dominant-baseline=\"middle\""))
  }
}

///|
test "transform を落とさない（両形式）" {
  let (plain, moonlight) = both(
    elem(@model.Rect(40.0, 20.0, None, None), transform="rotate(45 100 50)"),
  )
  for svg in [plain, moonlight] {
    assert_true(svg.contains("transform=\"rotate(45 100 50)\""))
  }
}

///|
test "改行入りテキストは tspan に割る（両形式）" {
  let (plain, moonlight) = both(elem(@model.Text("a\nb", Some(16.0))))
  for svg in [plain, moonlight] {
    assert_true(svg.contains("<tspan"))
    assert_true(svg.contains(">a</tspan>"))
    assert_true(svg.contains(">b</tspan>"))
  }
}

///|
test "font-family を落とさない（両形式）" {
  let style = { ..@model.Style::default(), font_family: Some("serif"), }
  let (plain, moonlight) = both(elem(@model.Text("x", Some(16.0)), style~))
  for svg in [plain, moonlight] {
    assert_true(svg.contains("font-family=\"serif\""))
  }
}

///|
test "数値は正規化して出す（両形式）" {
  // 0.1 + 0.2 のような値が 0.30000000000000004 のまま出ていくと、
  // 「可読な SVG」ではなくなるし差分も無意味に汚れる
  let (plain, moonlight) = both(elem(@model.Circle(0.1 + 0.2)))
  for svg in [plain, moonlight] {
    assert_true(svg.contains("r=\"0.3\""))
    assert_false(svg.contains("0.30000000000000004"))
  }
}

///|
test "XML 特殊文字をエスケープする（両形式）" {
  let (plain, moonlight) = both(elem(@model.Text("a<b&c", Some(16.0))))
  for svg in [plain, moonlight] {
    assert_true(svg.contains("a&lt;b&amp;c"))
  }
}

///|
test "矢印マーカーの参照先は、その形式が出す defs の id と一致する" {
  let style = {
    ..@model.Style::default(),
    marker_start: Some(@model.Arrow),
    marker_end: Some(@model.Arrow),
  }
  let (plain, moonlight) = both(elem(@model.Line(180.0, 90.0), style~))
  // 参照だけあって defs が無いと、矢印は黙って消える。
  // 2 つの形式は矢印のデザインが違う（Plain は context-stroke で線の色を継ぐ）
  // ので id も別。参照と defs が対になっていることを形式ごとに確かめる。
  for pair in [(plain, "-context"), (moonlight, "")] {
    let (svg, sfx) = pair
    for end in ["start", "end"] {
      assert_true(svg.contains("marker-\{end}=\"url(#arrow-\{end}\{sfx})\""))
      assert_true(svg.contains("id=\"arrow-\{end}\{sfx}\""))
    }
  }
}

///|
test "Moonlight 形式だけが再編集用メタデータを載せる" {
  let (plain, moonlight) = both(elem(@model.Rect(40.0, 20.0, None, None)))
  assert_true(moonlight.contains("data-id=\"e1\""))
  assert_false(plain.contains("data-id"))
}
