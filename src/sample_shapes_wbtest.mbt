// 起動時のデモ（sample_elements）の見た目の約束
//
// vlmkit の contrast ゲートは HTML の文字と CSS の背景しか測らず、キャンバスの
// SVG の文字が図形の塗りの上で読めるかは見ない。ここで配色と配置を直接確かめる。

///|
fn demo() -> Array[@model.Element] {
  let counter : Ref[Int] = { val: 0, }
  sample_elements(fn() {
    counter.val = counter.val + 1
    "el-\{counter.val}"
  })
}

///|
/// "#rrggbb" の 1 チャンネル（0..255）
fn demo_channel(hex : String, at : Int) -> Int {
  let digit = fn(c : Char) -> Int {
    let code = c.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      code - '0'.to_int()
    } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
      code - 'a'.to_int() + 10
    } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
      code - 'A'.to_int() + 10
    } else {
      abort("not a hex colour: \{hex}")
    }
  }
  let chars = hex.to_array()
  digit(chars[at]) * 16 + digit(chars[at + 1])
}

///|
/// WCAG 2.x の相対輝度
fn demo_luminance(hex : String) -> Double {
  guard hex.length() == 7 && hex.has_prefix("#") else {
    abort("expected #rrggbb, got \{hex}")
  }
  let linear = fn(c : Int) -> Double {
    let v = c.to_double() / 255.0
    if v <= 0.03928 {
      v / 12.92
    } else {
      @math.pow((v + 0.055) / 1.055, 2.4)
    }
  }
  0.2126 * linear(demo_channel(hex, 1)) +
  0.7152 * linear(demo_channel(hex, 3)) +
  0.0722 * linear(demo_channel(hex, 5))
}

///|
/// WCAG 2.x のコントラスト比
fn demo_contrast(a : String, b : String) -> Double {
  let la = demo_luminance(a)
  let lb = demo_luminance(b)
  let (hi, lo) = if la > lb { (la, lb) } else { (lb, la) }
  (hi + 0.05) / (lo + 0.05)
}

///|
/// 図形の中のラベルは親の線の色で描かれる。親の塗りの上で WCAG AA（4.5:1）を満たす。
test "every label in the demo is readable on its shape" {
  let elements = demo()
  let mut labels = 0
  for el in elements {
    guard el.parent_id is Some(pid) else { continue }
    let parent = elements.iter().find_first(fn(e) { e.id == pid }).unwrap()
    let text_color = @model.get_text_fill_color(el.style, parent.style.stroke)
    let fill = parent.style.fill.unwrap()
    let ratio = demo_contrast(text_color, fill)
    if ratio < 4.5 {
      fail(
        "label of \{parent.id} (\{text_color} on \{fill}) has contrast \{ratio}, below 4.5",
      )
    }
    labels = labels + 1
  }
  assert_eq(labels, 3)
}

///|
/// ラベルは図形の内側に収まる（端から 4 以上離れる）
test "every label in the demo fits inside its shape" {
  let elements = demo()
  for el in elements {
    guard el.parent_id is Some(pid) else { continue }
    let parent = elements.iter().find_first(fn(e) { e.id == pid }).unwrap()
    let label = el.bounding_box()
    let shape = parent.bounding_box()
    let slack = shape.width - label.width
    if slack < 8.0 {
      fail(
        "label of \{parent.id} is \{label.width} wide in a \{shape.width} shape",
      )
    }
  }
}

///|
/// どの要素も既定のドキュメント（400 × 300）に収まる。上端はデスクトップで
/// ツールバーが少し重なるので 20 空ける。
test "the demo fits in the default document" {
  for el in demo() {
    let b = el.bounding_box()
    if b.x < 8.0 ||
      b.y < 20.0 ||
      b.x + b.width > 392.0 ||
      b.y + b.height > 296.0 {
      fail(
        "\{el.id} at (\{b.x}, \{b.y}) size \{b.width}x\{b.height} leaves the document",
      )
    }
  }
}

///|
/// 図形・パス・図の外の文字は互いに重ならない（線とラベルは除く）
test "the shapes and texts of the demo do not overlap" {
  let items = demo().filter(fn(el) {
    el.parent_id is None && !(el.shape is @model.Line(_, _))
  })
  for i in 0..<items.length() {
    for j in (i + 1)..<items.length() {
      let a = items[i].bounding_box()
      let b = items[j].bounding_box()
      let apart = a.x + a.width <= b.x ||
        b.x + b.width <= a.x ||
        a.y + a.height <= b.y ||
        b.y + b.height <= a.y
      if !apart {
        fail("\{items[i].id} overlaps \{items[j].id}")
      }
    }
  }
}

///|
/// 矢印は 3 本とも両端がアンカーに結合し、その上に載っている
test "the arrows of the demo sit on their anchors" {
  let scene = @interaction.Scene::of(demo())
  assert_eq(scene.joints().length(), 6)
  let violations = scene.joint_violations()
  if violations.length() > 0 {
    fail(violations[0].describe())
  }
}
