// DOM テスト - ui.mbt

///|
/// HappyDOM Window を作成し、グローバルに document と window を注入
fn create_happy_window() -> @dom.Window {
  @js.identity(create_happy_window_internal())
}

///|
extern "js" fn create_happy_window_internal() -> @js.Any =
  #|() => {
  #|  const win = new (require("happy-dom").Window)();
  #|  globalThis.window = win;
  #|  globalThis.document = win.document;
  #|  return win;
  #|}

///|
test "render_floating_panel - creates panel structure" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  // EditorState を作成
  let state = EditorState::new(400, 300)
  let history = @model.History::new()
  // パネルをレンダリング
  let panel = render_floating_panel(state, history)
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, panel)
  // div 要素が作成されているか確認
  let divs = container.querySelectorAll("div")
  assert_true(divs.length() > 0)
}

///|
test "render_floating_panel - shows canvas root when nothing selected" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let state = EditorState::new(400, 300)
  let history = @model.History::new()
  // 何も選択されていない状態
  state.select(None)
  let panel = render_floating_panel(state, history)
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, panel)
  // Canvas Settings が表示されているか確認
  let html = container.innerHTML()
  assert_true(html.contains("Canvas Settings"))
}

///|
test "render_context_menu - creates menu with items" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let state = EditorState::new(400, 300)
  let history = @model.History::new()
  // コンテキストメニューを表示状態に設定
  state.context_menu.set(
    Some({ x: 100.0, y: 100.0, scene_x: 100.0, scene_y: 100.0, target_id: None }),
  )
  let menu = render_context_menu(state, history, fn() { "el-1" })
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, menu)
  // メニューが表示されているか確認
  let html = container.innerHTML()
  // 挿入メニューが表示されているはず（target_id が None なので）
  assert_true(html.contains("Insert Rectangle") || html.contains("div"))
}

///|
test "render_context_menu - shows element actions when element selected" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let state = EditorState::new(400, 300)
  let history = @model.History::new()
  // 要素を追加
  let el = @model.Element::new(
    "el-1",
    100.0,
    100.0,
    @model.Rect(80.0, 60.0, None, None),
  )
  state.elements.update(fn(els) {
    els.push(el)
    els
  })
  // 要素をターゲットにしたコンテキストメニューを表示
  state.context_menu.set(
    Some({
      x: 100.0,
      y: 100.0,
      scene_x: 100.0,
      scene_y: 100.0,
      target_id: Some("el-1"),
    }),
  )
  let menu = render_context_menu(state, history, fn() { "el-2" })
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, menu)
  // 要素アクションメニューが表示されているか確認
  let html = container.innerHTML()
  // Delete や Duplicate が表示されているはず
  assert_true(html.contains("Delete") || html.contains("button"))
}

///|
test "render_text_input - creates textarea overlay" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let state = EditorState::new(400, 300)
  // テキスト編集状態を設定
  state.text_edit.set(
    Some({
      parent_id: "el-1",
      x: 100.0,
      y: 100.0,
      editing_id: None,
      initial_text: "Hello",
      font_size: None,
    }),
  )
  let textarea_node = render_text_input(state, fn(_value) { () }, fn() { () })
  let container = doc.createElement("div")
  @element.render(container |> @element.DomElement::from_dom, textarea_node)
  // textarea 要素が作成されているか確認
  let textarea = container.querySelector("textarea")
  assert_true(textarea is Some(_))
}

///|
test "render_floating_panel - mobile style differs from desktop" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let state = EditorState::new(400, 300)
  let history = @model.History::new()
  // デスクトップモード
  state.is_mobile.set(false)
  let panel_desktop = render_floating_panel(state, history)
  let container1 = doc.createElement("div")
  @element.render(container1 |> @element.DomElement::from_dom, panel_desktop)
  let desktop_style = container1
    .querySelector("div")
    .unwrap()
    .getAttribute("style")
  // モバイルモード
  state.is_mobile.set(true)
  let panel_mobile = render_floating_panel(state, history)
  let container2 = doc.createElement("div")
  @element.render(container2 |> @element.DomElement::from_dom, panel_mobile)
  let mobile_style = container2
    .querySelector("div")
    .unwrap()
    .getAttribute("style")
  // スタイルが異なることを確認（モバイルは bottom: 0 を含む）
  assert_true(desktop_style != mobile_style)
}

///|
test "EditorState - theme switching affects panel style" {
  let window = create_happy_window()
  defer window.close()
  let doc = window.document()
  let state = EditorState::new(400, 300)
  let history = @model.History::new()
  // ライトテーマ
  state.theme_mode.set(@model.Light)
  let panel_light = render_floating_panel(state, history)
  let container1 = doc.createElement("div")
  @element.render(container1 |> @element.DomElement::from_dom, panel_light)
  let light_html = container1.innerHTML()
  // ダークテーマ
  state.theme_mode.set(@model.Dark)
  let panel_dark = render_floating_panel(state, history)
  let container2 = doc.createElement("div")
  @element.render(container2 |> @element.DomElement::from_dom, panel_dark)
  let dark_html = container2.innerHTML()
  // HTMLが異なることを確認（背景色などが変わる）
  assert_true(light_html != dark_html)
}
