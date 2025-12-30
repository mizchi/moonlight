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
  if is_js_null(svg) {
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
/// 要素用メニューをレンダリング（FFI ベース、詳細パネルと同じUI）
fn render_element_menu(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  id : String,
) -> Unit {
  // 要素を取得
  let el_opt = state.find_element(id)
  // Stroke セクション（現在の色 + カラーピッカー）
  let stroke_row = create_color_picker_row("Stroke", false, el_opt)
  set_color_picker_handler(stroke_row, fn(color) {
    update_element_stroke(state, id, color)
    redraw_svg(state)
  })
  append_child(menu, stroke_row)
  // Fill セクション（現在の色 + カラーピッカー + 透明ボタン）
  let fill_row = create_color_picker_row("Fill", true, el_opt)
  set_color_picker_handler(fill_row, fn(color) {
    let fill_value = if color == "transparent" { None } else { Some(color) }
    update_element_fill(state, id, fill_value)
    redraw_svg(state)
  })
  append_child(menu, fill_row)
  // 要素タイプ別オプション（Text: フォント、Line: 破線・矢印）
  match el_opt {
    Some(el) => render_element_type_options(state, context_menu, menu, id, el)
    None => ()
  }
  // Layer セクション
  let layer_header = create_menu_header("Layer")
  append_child(menu, layer_header)
  let front_btn = create_menu_button("Bring to Front", "#333333")
  add_click_handler(front_btn, fn(_) {
    bring_to_front(state, id)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, front_btn)
  let forward_btn = create_menu_button("Bring Forward", "#333333")
  add_click_handler(forward_btn, fn(_) {
    bring_forward(state, id)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, forward_btn)
  let backward_btn = create_menu_button("Send Backward", "#333333")
  add_click_handler(backward_btn, fn(_) {
    send_backward(state, id)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, backward_btn)
  let back_btn = create_menu_button("Send to Back", "#333333")
  add_click_handler(back_btn, fn(_) {
    send_to_back(state, id)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, back_btn)
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
/// 要素タイプ別オプションをレンダリング
fn render_element_type_options(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  id : String,
  el : @model.Element,
) -> Unit {
  match el.shape {
    @model.Line(_, _) => render_line_menu_options(state, context_menu, menu, id, el)
    @model.Text(_, _) => render_text_menu_options(state, context_menu, menu, id, el)
    _ => ()
  }
}

///|
/// Line 用メニューオプション（破線、矢印）
fn render_line_menu_options(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  id : String,
  el : @model.Element,
) -> Unit {
  // 破線ヘッダー
  let line_header = create_menu_header("Line Style")
  append_child(menu, line_header)
  // 破線パターン
  let dash_row = create_menu_row("Style:")
  let dash_presets : Array[(String, String?)] = [
    ("―", None),
    ("--", Some("8,4")),
    ("··", Some("2,4")),
    ("-·", Some("8,4,2,4")),
  ]
  for preset in dash_presets {
    let (label, dash_value) = preset
    let is_selected = el.style.stroke_dasharray == dash_value
    let btn = create_toggle_button(label, is_selected)
    add_click_handler(btn, fn(_) {
      update_element_dasharray(state, id, dash_value)
      context_menu.hide()
      hide_context_menu_element(menu)
      redraw_svg(state)
    })
    append_child(dash_row, btn)
  }
  append_child(menu, dash_row)
  // 矢印
  let arrow_row = create_menu_row("Arrow:")
  let start_selected = el.style.marker_start is Some(@model.Arrow)
  let start_btn = create_toggle_button("<", start_selected)
  add_click_handler(start_btn, fn(_) {
    let new_marker = if start_selected { None } else { Some(@model.Arrow) }
    update_element_marker_start(state, id, new_marker)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(arrow_row, start_btn)
  let end_selected = el.style.marker_end is Some(@model.Arrow)
  let end_btn = create_toggle_button(">", end_selected)
  add_click_handler(end_btn, fn(_) {
    let new_marker = if end_selected { None } else { Some(@model.Arrow) }
    update_element_marker_end(state, id, new_marker)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(arrow_row, end_btn)
  append_child(menu, arrow_row)
}

///|
/// Text 用メニューオプション（フォント選択）
fn render_text_menu_options(
  state : @core.EditorState,
  context_menu : ContextMenuState,
  menu : @js.Any,
  id : String,
  el : @model.Element,
) -> Unit {
  let font_header = create_menu_header("Font")
  append_child(menu, font_header)
  let font_row = create_menu_row("Family:")
  let font_presets : Array[(String, String?)] = [
    ("Sans", None),
    ("Serif", Some("serif")),
    ("Mono", Some("monospace")),
  ]
  for preset in font_presets {
    let (label, font_value) = preset
    let is_selected = el.style.font_family == font_value
    let btn = create_toggle_button(label, is_selected)
    add_click_handler(btn, fn(_) {
      update_element_font_family(state, id, font_value)
      context_menu.hide()
      hide_context_menu_element(menu)
      redraw_svg(state)
    })
    append_child(font_row, btn)
  }
  append_child(menu, font_row)
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
    let el = create_rect_element(
      new_id(),
      svg_coords.0 - 40.0,
      svg_coords.1 - 30.0,
      80.0,
      60.0,
    )
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
    let el = create_ellipse_element(
      new_id(),
      svg_coords.0,
      svg_coords.1,
      60.0,
      35.0,
    )
    add_element_to_state(state, el)
    context_menu.hide()
    hide_context_menu_element(menu)
    redraw_svg(state)
  })
  append_child(menu, ellipse_btn)
  // Line
  let line_btn = create_menu_button("Line", "#333333")
  add_click_handler(line_btn, fn(_) {
    let el = create_line_element(
      new_id(),
      svg_coords.0 - 50.0,
      svg_coords.1,
      svg_coords.0 + 50.0,
      svg_coords.1,
    )
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
  match state.get_selected_id() {
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

///|
/// トグルボタンを作成
extern "js" fn create_toggle_button(text : String, selected : Bool) -> @js.Any =
  #| (text, selected) => {
  #|   const btn = document.createElement('button');
  #|   btn.textContent = text;
  #|   const baseStyle = 'padding: 2px 6px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 10px;';
  #|   if (selected) {
  #|     btn.style.cssText = baseStyle + ' background: #e3f2fd; border-color: #2196f3;';
  #|   } else {
  #|     btn.style.cssText = baseStyle + ' background: white;';
  #|   }
  #|   return btn;
  #| }

///|
/// 要素の stroke-dasharray を更新
fn update_element_dasharray(
  state : @core.EditorState,
  id : String,
  dasharray : String?,
) -> Unit {
  state.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: { ..el.style, stroke_dasharray: dasharray } }
      } else {
        el
      }
    })
  })
}

///|
/// 要素の marker_start を更新
fn update_element_marker_start(
  state : @core.EditorState,
  id : String,
  marker : @model.ArrowType?,
) -> Unit {
  state.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: { ..el.style, marker_start: marker } }
      } else {
        el
      }
    })
  })
}

///|
/// 要素の marker_end を更新
fn update_element_marker_end(
  state : @core.EditorState,
  id : String,
  marker : @model.ArrowType?,
) -> Unit {
  state.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: { ..el.style, marker_end: marker } }
      } else {
        el
      }
    })
  })
}

///|
/// 要素の font_family を更新
fn update_element_font_family(
  state : @core.EditorState,
  id : String,
  font_family : String?,
) -> Unit {
  state.elements.update(fn(els) {
    els.map(fn(el) {
      if el.id == id {
        { ..el, style: { ..el.style, font_family: font_family } }
      } else {
        el
      }
    })
  })
}

///|
/// 要素を最前面に移動
fn bring_to_front(state : @core.EditorState, id : String) -> Unit {
  state.elements.update(fn(els) {
    let target : @model.Element? = els.iter().find_first(fn(el) { el.id == id })
    match target {
      Some(el) => {
        let others = els.filter(fn(e) { e.id != id })
        others.push(el)
        others
      }
      None => els
    }
  })
}

///|
/// 配列内の要素のインデックスを検索
fn find_element_index(els : Array[@model.Element], id : String) -> Int? {
  for i, el in els {
    if el.id == id {
      return Some(i)
    }
  }
  None
}

///|
/// 要素を一つ前面に移動
fn bring_forward(state : @core.EditorState, id : String) -> Unit {
  state.elements.update(fn(els) {
    match find_element_index(els, id) {
      Some(i) if i < els.length() - 1 => {
        let result = els.copy()
        let tmp = result[i]
        result[i] = result[i + 1]
        result[i + 1] = tmp
        result
      }
      _ => els
    }
  })
}

///|
/// 要素を一つ背面に移動
fn send_backward(state : @core.EditorState, id : String) -> Unit {
  state.elements.update(fn(els) {
    match find_element_index(els, id) {
      Some(i) if i > 0 => {
        let result = els.copy()
        let tmp = result[i]
        result[i] = result[i - 1]
        result[i - 1] = tmp
        result
      }
      _ => els
    }
  })
}

///|
/// 要素を最背面に移動
fn send_to_back(state : @core.EditorState, id : String) -> Unit {
  state.elements.update(fn(els) {
    let target : @model.Element? = els.iter().find_first(fn(el) { el.id == id })
    match target {
      Some(el) => {
        let others = els.filter(fn(e) { e.id != id })
        let result : Array[@model.Element] = [el]
        for e in others {
          result.push(e)
        }
        result
      }
      None => els
    }
  })
}

///|
/// カラーピッカー行を作成（現在の色ボタン + ネイティブカラーピッカー）
fn create_color_picker_row(
  label : String,
  is_fill : Bool,
  el_opt : @model.Element?,
) -> @js.Any {
  let current_color = match el_opt {
    Some(el) =>
      if is_fill {
        el.style.fill.unwrap_or("transparent")
      } else {
        el.style.stroke.unwrap_or("#000000")
      }
    None => if is_fill { "transparent" } else { "#000000" }
  }
  create_color_picker_row_ffi(label, current_color, is_fill)
}

///|
/// カラーピッカー行を作成（FFI）
extern "js" fn create_color_picker_row_ffi(
  label : String,
  current_color : String,
  is_fill : Bool,
) -> @js.Any =
  #| (label, currentColor, isFill) => {
  #|   const row = document.createElement('div');
  #|   row.style.cssText = 'padding: 6px 12px; display: flex; align-items: center; gap: 8px;';
  #|
  #|   // ラベル
  #|   const labelSpan = document.createElement('span');
  #|   labelSpan.textContent = label;
  #|   labelSpan.style.cssText = 'font-size: 11px; color: #666; min-width: 40px;';
  #|   row.appendChild(labelSpan);
  #|
  #|   // 現在の色ボタン
  #|   const colorBtn = document.createElement('button');
  #|   colorBtn.className = 'current-color-btn';
  #|   colorBtn.style.cssText = 'width: 28px; height: 22px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer;';
  #|   if (currentColor === 'transparent') {
  #|     colorBtn.style.background = 'linear-gradient(45deg, #ccc 25%, transparent 25%), linear-gradient(-45deg, #ccc 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #ccc 75%), linear-gradient(-45deg, transparent 75%, #ccc 75%)';
  #|     colorBtn.style.backgroundSize = '6px 6px';
  #|     colorBtn.style.backgroundPosition = '0 0, 0 3px, 3px -3px, -3px 0px';
  #|   } else {
  #|     colorBtn.style.background = currentColor;
  #|   }
  #|   row.appendChild(colorBtn);
  #|
  #|   // ネイティブカラーピッカー
  #|   const colorInput = document.createElement('input');
  #|   colorInput.type = 'color';
  #|   colorInput.className = 'color-picker-input';
  #|   colorInput.style.cssText = 'width: 22px; height: 22px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer;';
  #|   // transparent の場合はデフォルト色を設定
  #|   colorInput.value = (currentColor === 'transparent' || !currentColor.startsWith('#'))
  #|     ? (isFill ? '#ffffff' : '#000000')
  #|     : currentColor;
  #|   row.appendChild(colorInput);
  #|
  #|   // Fill の場合は透明ボタンを追加
  #|   if (isFill) {
  #|     const transparentBtn = document.createElement('button');
  #|     transparentBtn.className = 'transparent-btn';
  #|     transparentBtn.textContent = '∅';
  #|     transparentBtn.title = 'Transparent';
  #|     transparentBtn.style.cssText = 'width: 22px; height: 22px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 12px; background: white;';
  #|     row.appendChild(transparentBtn);
  #|   }
  #|
  #|   return row;
  #| }

///|
/// カラーピッカーのハンドラを設定
extern "js" fn set_color_picker_handler(
  row : @js.Any,
  handler : (String) -> Unit,
) =
  #| (row, handler) => {
  #|   const colorInput = row.querySelector('.color-picker-input');
  #|   const transparentBtn = row.querySelector('.transparent-btn');
  #|
  #|   if (colorInput) {
  #|     colorInput.addEventListener('input', (e) => {
  #|       e.stopPropagation();
  #|       handler(e.target.value);
  #|     });
  #|   }
  #|
  #|   if (transparentBtn) {
  #|     transparentBtn.addEventListener('click', (e) => {
  #|       e.stopPropagation();
  #|       handler('transparent');
  #|     });
  #|   }
  #| }
