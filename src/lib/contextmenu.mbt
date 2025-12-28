// 共通ライブラリ - コンテキストメニュー
// 埋め込みモード用のシンプルなコンテキストメニュー

///|
/// コンテキストメニュー状態
pub struct ContextMenuState {
  visible : @luna.Signal[Bool]
  x : @luna.Signal[Double]
  y : @luna.Signal[Double]
  target_id : @luna.Signal[String?]
  menu_el : Ref[@js.Any]
}

///|
/// コンテキストメニュー状態を作成
pub fn ContextMenuState::new() -> ContextMenuState {
  {
    visible: @luna.signal(false),
    x: @luna.signal(0.0),
    y: @luna.signal(0.0),
    target_id: @luna.signal(None),
    menu_el: { val: js_null() },
  }
}

///|
/// コンテキストメニューを表示
pub fn ContextMenuState::show(
  self : ContextMenuState,
  x : Double,
  y : Double,
  target_id : String?,
) -> Unit {
  self.x.set(x)
  self.y.set(y)
  self.target_id.set(target_id)
  self.visible.set(true)
}

///|
/// コンテキストメニューを非表示
pub fn ContextMenuState::hide(self : ContextMenuState) -> Unit {
  self.visible.set(false)
  self.target_id.set(None)
}

///|
/// コンテキストメニューをセットアップ
pub fn setup_context_menu(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  new_id : () -> String,
) -> Unit {
  let svg = state.svg_el.get()
  if is_svg_null(svg) {
    return
  }
  // コンテキストメニューを作成
  let menu = create_context_menu_element()
  context_menu.menu_el.val = menu
  // コンテナに追加
  append_menu_to_body(menu)
  // 右クリックイベントを追加
  add_contextmenu_handler(svg, fn(e) {
    // 読み取り専用モードでは無視
    if state.is_readonly.get() {
      return
    }
    prevent_default_ffi(e)
    let (mx, my) = get_context_menu_coords(e)
    let target_id = get_target_id(e)
    let target = if target_id == "" { None } else { Some(target_id) }
    context_menu.show(mx, my, target)
    update_context_menu_position(menu, mx, my)
    show_context_menu_element(menu)
    render_context_menu_content(state, context_menu, menu, new_id)
  })
  // メニュー外クリックで非表示
  add_document_click_handler(fn(_) {
    if context_menu.visible.get() {
      context_menu.hide()
      hide_context_menu_element(menu)
    }
  })
}

///|
/// コンテキストメニューの内容をレンダリング
fn render_context_menu_content(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  new_id : () -> String,
) -> Unit {
  clear_container_ffi(menu)
  let target_id = context_menu.target_id.get()
  match target_id {
    Some(id) => render_element_menu(state, context_menu, menu, id)
    None => render_insert_menu(state, context_menu, menu, new_id)
  }
}

///|
/// 要素用メニューをレンダリング
fn render_element_menu(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  id : String,
) -> Unit {
  // 色変更セクション
  let colors_header = create_menu_header("Colors")
  append_child(menu, colors_header)
  // Stroke 色
  let stroke_row = create_menu_row("Stroke:")
  let stroke_colors = ["#000000", "#666666", "#e53e3e", "#38a169", "#3182ce"]
  for color in stroke_colors {
    let btn = create_color_button(color)
    add_click_handler(btn, fn(_) {
      update_element_stroke(state, id, color)
      context_menu.hide()
      hide_context_menu_element(menu)
      redraw_svg(state)
    })
    append_child(stroke_row, btn)
  }
  append_child(menu, stroke_row)
  // Fill 色
  let fill_row = create_menu_row("Fill:")
  let fill_colors = [
    "transparent", "#ffffff", "#4CAF50", "#2196F3", "#FFC107",
  ]
  for color in fill_colors {
    let btn = create_color_button(color)
    add_click_handler(btn, fn(_) {
      let fill_value = if color == "transparent" { None } else { Some(color) }
      update_element_fill(state, id, fill_value)
      context_menu.hide()
      hide_context_menu_element(menu)
      redraw_svg(state)
    })
    append_child(fill_row, btn)
  }
  append_child(menu, fill_row)
  // 削除ボタン
  let delete_btn = create_menu_button("Delete", "#e53e3e")
  add_click_handler(delete_btn, fn(_) {
    delete_element(state, id)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
    update_selection_ui(state)
  })
  append_child(menu, delete_btn)
}

///|
/// 挿入メニューをレンダリング
fn render_insert_menu(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  new_id : () -> String,
) -> Unit {
  let x = context_menu.x.get()
  let y = context_menu.y.get()
  // SVG 座標に変換（簡易版）
  let svg_coords = screen_to_svg_coords(state.svg_el.get(), x, y)
  let header = create_menu_header("Insert")
  append_child(menu, header)
  // Rectangle
  let rect_btn = create_menu_button("Rectangle", "#333333")
  add_click_handler(rect_btn, fn(_) {
    let el = create_rect_element(new_id(), svg_coords.0 - 40.0, svg_coords.1 - 30.0, 80.0, 60.0)
    add_element_to_state(state, el)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, rect_btn)
  // Circle
  let circle_btn = create_menu_button("Circle", "#333333")
  add_click_handler(circle_btn, fn(_) {
    let el = create_circle_element(new_id(), svg_coords.0, svg_coords.1, 40.0)
    add_element_to_state(state, el)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, circle_btn)
  // Ellipse
  let ellipse_btn = create_menu_button("Ellipse", "#333333")
  add_click_handler(ellipse_btn, fn(_) {
    let el = create_ellipse_element(new_id(), svg_coords.0, svg_coords.1, 60.0, 35.0)
    add_element_to_state(state, el)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, ellipse_btn)
  // Line
  let line_btn = create_menu_button("Line", "#333333")
  add_click_handler(line_btn, fn(_) {
    let el = create_line_element(new_id(), svg_coords.0 - 50.0, svg_coords.1, svg_coords.0 + 50.0, svg_coords.1)
    add_element_to_state(state, el)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, line_btn)
  // Text
  let text_btn = create_menu_button("Text", "#333333")
  add_click_handler(text_btn, fn(_) {
    let el = create_text_element(new_id(), svg_coords.0, svg_coords.1, "Text")
    add_element_to_state(state, el)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, text_btn)
}

///|
/// 要素を状態に追加
fn add_element_to_state(state : @core.EditorState, el : @model.Element) -> Unit {
  state.elements.update(fn(els) {
    let new_els = els.copy()
    new_els.push(el)
    new_els
  })
}

///|
/// 要素を削除
fn delete_element(state : @core.EditorState, id : String) -> Unit {
  state.elements.update(fn(els) { els.filter(fn(el) { el.id != id }) })
  match get_selected_id(state) {
    Some(sel_id) if sel_id == id => set_selected_id(state, None)
    _ => ()
  }
}

///|
/// 要素のストロークを更新
fn update_element_stroke(
  state : @core.EditorState,
  id : String,
  color : String,
) -> Unit {
  state.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: { ..el.style, stroke: Some(color) } }
      } else {
        el
      }
    })
  })
}

///|
/// 要素のフィルを更新
fn update_element_fill(
  state : @core.EditorState,
  id : String,
  color : String?,
) -> Unit {
  state.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: { ..el.style, fill: color } }
      } else {
        el
      }
    })
  })
}

// === FFI 関数 ===

///|
/// コンテキストメニュー要素を作成
extern "js" fn create_context_menu_element() -> @js.Any =
  #| () => {
  #|   const menu = document.createElement('div');
  #|   menu.style.cssText = 'position: fixed; display: none; background: white; border: 1px solid #ccc; border-radius: 4px; box-shadow: 2px 2px 10px rgba(0,0,0,0.1); min-width: 140px; z-index: 10000; padding: 4px 0;';
  #|   return menu;
  #| }

///|
/// メニューを body に追加
extern "js" fn append_menu_to_body(menu : @js.Any) =
  #| (menu) => document.body.appendChild(menu)

///|
/// コンテキストメニュー座標を計算（グローバル変数に保存）
extern "js" fn compute_context_menu_coords_ffi(e : @js.Any) =
  #| (e) => {
  #|   globalThis.__moonlight_ctx_x = e.clientX || 0;
  #|   globalThis.__moonlight_ctx_y = e.clientY || 0;
  #| }

///|
/// コンテキストメニュー X 座標を取得
extern "js" fn get_ctx_x_ffi() -> Double =
  #| () => globalThis.__moonlight_ctx_x || 0

///|
/// コンテキストメニュー Y 座標を取得
extern "js" fn get_ctx_y_ffi() -> Double =
  #| () => globalThis.__moonlight_ctx_y || 0

///|
/// コンテキストメニュー座標を取得
fn get_context_menu_coords(e : @js.Any) -> (Double, Double) {
  compute_context_menu_coords_ffi(e)
  (get_ctx_x_ffi(), get_ctx_y_ffi())
}

///|
/// contextmenu イベントハンドラを追加
extern "js" fn add_contextmenu_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('contextmenu', handler)

///|
/// document click ハンドラを追加
extern "js" fn add_document_click_handler(handler : (@js.Any) -> Unit) =
  #| (handler) => document.addEventListener('click', handler)

///|
/// メニュー位置を更新
extern "js" fn update_context_menu_position(
  menu : @js.Any,
  x : Double,
  y : Double,
) =
  #| (menu, x, y) => {
  #|   menu.style.left = x + 'px';
  #|   menu.style.top = y + 'px';
  #| }

///|
/// メニューを表示
extern "js" fn show_context_menu_element(menu : @js.Any) =
  #| (menu) => { menu.style.display = 'block'; }

///|
/// メニューを非表示
extern "js" fn hide_context_menu_element(menu : @js.Any) =
  #| (menu) => { menu.style.display = 'none'; }

///|
/// メニューヘッダーを作成
extern "js" fn create_menu_header(text : String) -> @js.Any =
  #| (text) => {
  #|   const header = document.createElement('div');
  #|   header.textContent = text;
  #|   header.style.cssText = 'padding: 4px 12px; color: #666; font-size: 11px; border-bottom: 1px solid #eee;';
  #|   return header;
  #| }

///|
/// メニュー行を作成
extern "js" fn create_menu_row(label : String) -> @js.Any =
  #| (label) => {
  #|   const row = document.createElement('div');
  #|   row.style.cssText = 'padding: 4px 12px; display: flex; align-items: center; gap: 4px; font-size: 12px;';
  #|   const span = document.createElement('span');
  #|   span.textContent = label;
  #|   span.style.width = '40px';
  #|   row.appendChild(span);
  #|   return row;
  #| }

///|
/// 色ボタンを作成
extern "js" fn create_color_button(color : String) -> @js.Any =
  #| (color) => {
  #|   const btn = document.createElement('button');
  #|   btn.style.cssText = 'width: 18px; height: 18px; border: 1px solid #999; border-radius: 2px; cursor: pointer; padding: 0;';
  #|   if (color === 'transparent') {
  #|     btn.style.background = 'linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%), linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%)';
  #|     btn.style.backgroundSize = '8px 8px';
  #|     btn.style.backgroundPosition = '0 0, 4px 4px';
  #|   } else {
  #|     btn.style.background = color;
  #|   }
  #|   return btn;
  #| }

///|
/// メニューボタンを作成
extern "js" fn create_menu_button(text : String, color : String) -> @js.Any =
  #| (text, color) => {
  #|   const btn = document.createElement('button');
  #|   btn.textContent = text;
  #|   btn.style.cssText = 'display: block; width: 100%; padding: 6px 12px; text-align: left; background: none; border: none; cursor: pointer; font-size: 12px; color: ' + color + ';';
  #|   btn.onmouseenter = () => btn.style.background = '#f0f0f0';
  #|   btn.onmouseleave = () => btn.style.background = 'none';
  #|   return btn;
  #| }

///|
/// クリックハンドラを追加
extern "js" fn add_click_handler(el : @js.Any, handler : (@js.Any) -> Unit) =
  #| (el, handler) => el.addEventListener('click', (e) => { e.stopPropagation(); handler(e); })

///|
/// スクリーン座標を SVG 座標に変換（グローバル変数に保存）
extern "js" fn compute_screen_to_svg_coords_ffi(
  svg : @js.Any,
  x : Double,
  y : Double,
) =
  #| (svg, x, y) => {
  #|   if (!svg || !svg.getBoundingClientRect) {
  #|     globalThis.__moonlight_svg_x = x;
  #|     globalThis.__moonlight_svg_y = y;
  #|     return;
  #|   }
  #|   const rect = svg.getBoundingClientRect();
  #|   const viewBox = svg.viewBox?.baseVal;
  #|   if (viewBox && viewBox.width > 0 && rect.width > 0) {
  #|     const scaleX = viewBox.width / rect.width;
  #|     const scaleY = viewBox.height / rect.height;
  #|     globalThis.__moonlight_svg_x = (x - rect.left) * scaleX + viewBox.x;
  #|     globalThis.__moonlight_svg_y = (y - rect.top) * scaleY + viewBox.y;
  #|   } else {
  #|     globalThis.__moonlight_svg_x = x - rect.left;
  #|     globalThis.__moonlight_svg_y = y - rect.top;
  #|   }
  #| }

///|
/// SVG X 座標を取得
extern "js" fn get_svg_x_ffi() -> Double =
  #| () => globalThis.__moonlight_svg_x || 0

///|
/// SVG Y 座標を取得
extern "js" fn get_svg_y_ffi() -> Double =
  #| () => globalThis.__moonlight_svg_y || 0

///|
/// スクリーン座標を SVG 座標に変換
fn screen_to_svg_coords(
  svg : @js.Any,
  x : Double,
  y : Double,
) -> (Double, Double) {
  compute_screen_to_svg_coords_ffi(svg, x, y)
  (get_svg_x_ffi(), get_svg_y_ffi())
}
