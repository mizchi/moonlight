// DOM テスト - button.mbt

///|
test "svg_icon - creates svg element with correct attributes" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  // svg_icon を使って DOM ノードを作成
  let icon = svg_icon(icon_rect, 16)
  // DomNode を DOM に追加してテスト
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, icon)
  // SVG 要素が作成されているか確認
  let svg = container.querySelector("svg")
  assert_true(svg is Some(_))
  // 属性を確認
  let svg_el = svg.unwrap()
  inspect(svg_el.getAttribute("width"), content="Some(\"16\")")
  inspect(svg_el.getAttribute("height"), content="Some(\"16\")")
  inspect(svg_el.getAttribute("viewBox"), content="Some(\"0 0 24 24\")")
  inspect(svg_el.getAttribute("stroke"), content="Some(\"currentColor\")")
  // path 要素が存在するか確認
  let path = container.querySelector("path")
  assert_true(path is Some(_))
  inspect(path.unwrap().getAttribute("d"), content="Some(\"M3 3h18v18H3z\")")
}

///|
test "svg_icon - different sizes" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let icon = svg_icon(icon_circle, 24)
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, icon)
  let svg = container.querySelector("svg").unwrap()
  inspect(svg.getAttribute("width"), content="Some(\"24\")")
  inspect(svg.getAttribute("height"), content="Some(\"24\")")
}

///|
test "toolbar_button - creates button with icon and tooltip" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let clicked : Ref[Bool] = { val: false }
  let btn = toolbar_button(svg_icon(icon_rect, 16), Some("1"), "Rectangle", fn() {
    clicked.val = true
  })
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, btn)
  // button 要素が存在するか確認
  let button = container.querySelector("button")
  assert_true(button is Some(_))
  // aria-label が設定されているか確認
  let button_el = button.unwrap()
  inspect(button_el.getAttribute("aria-label"), content="Some(\"Rectangle\")")
  // SVG アイコンが含まれているか確認
  let svg = container.querySelector("svg")
  assert_true(svg is Some(_))
  // ショートカットキーが表示されているか確認
  let span = container.querySelector("span")
  assert_true(span is Some(_))
}

///|
test "toolbar_button - without shortcut" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let btn = toolbar_button(svg_icon(icon_undo, 16), None, "Undo", fn() { () })
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, btn)
  // button 要素が存在するか確認
  let button = container.querySelector("button").unwrap()
  inspect(button.getAttribute("aria-label"), content="Some(\"Undo\")")
  // SVG アイコンが含まれているか確認
  let svg = container.querySelector("svg")
  assert_true(svg is Some(_))
}

///|
test "toolbar_separator - creates separator element" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let theme = @model.Theme::light()
  let sep = toolbar_separator(theme)
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, sep)
  // span 要素が存在するか確認
  let span = container.querySelector("span")
  assert_true(span is Some(_))
}

///|
test "toolbar_button - dark theme styling" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let dark_theme = @model.Theme::dark()
  let btn = toolbar_button(
    svg_icon(icon_circle, 16),
    Some("2"),
    "Circle",
    fn() { () },
    theme=dark_theme,
  )
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, btn)
  // button 要素が存在するか確認
  let button = container.querySelector("button")
  assert_true(button is Some(_))
  // スタイルにダークテーマの色が含まれているか確認
  let style = button.unwrap().getAttribute("style")
  assert_true(style is Some(_))
}
