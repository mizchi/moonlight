// インタラクション - マウスイベント処理

///|
/// ドラッグ状態
pub struct DragState {
  is_dragging : @luna.Signal[Bool]
  dragging_id : @luna.Signal[String?]
  start_x : Ref[Double]
  start_y : Ref[Double]
  element_start_x : Ref[Double]
  element_start_y : Ref[Double]
}

///|
/// ドラッグ状態を作成
pub fn DragState::new() -> DragState {
  {
    is_dragging: @luna.signal(false),
    dragging_id: @luna.signal(None),
    start_x: { val: 0.0 },
    start_y: { val: 0.0 },
    element_start_x: { val: 0.0 },
    element_start_y: { val: 0.0 },
  }
}

///|
/// マウス座標を取得（SVG 座標系に変換）
/// イベントの currentTarget から SVG を取得
pub fn get_mouse_coords_from_event(e : @js.Any) -> (Double, Double) {
  get_mouse_coords_ffi(e)
  (get_mouse_x_ffi(), get_mouse_y_ffi())
}

///|
/// マウス座標計算の FFI（結果をグローバルに保存）
extern "js" fn get_mouse_coords_ffi(e : @js.Any) =
  #| (e) => {
  #|   const svg = e.currentTarget;
  #|   let x = 0, y = 0;
  #|   if (svg && svg.getBoundingClientRect && typeof e.clientX === 'number') {
  #|     const rect = svg.getBoundingClientRect();
  #|     const screenX = e.clientX - rect.left;
  #|     const screenY = e.clientY - rect.top;
  #|     const viewBox = svg.viewBox?.baseVal;
  #|     if (viewBox && viewBox.width > 0 && rect.width > 0) {
  #|       const scaleX = viewBox.width / rect.width;
  #|       const scaleY = viewBox.height / rect.height;
  #|       x = screenX * scaleX + viewBox.x;
  #|       y = screenY * scaleY + viewBox.y;
  #|     } else {
  #|       x = screenX;
  #|       y = screenY;
  #|     }
  #|   }
  #|   // グローバル変数に座標を保存
  #|   globalThis.__moonlight_mouse_x = x;
  #|   globalThis.__moonlight_mouse_y = y;
  #| }

///|
/// マウスX座標を取得
extern "js" fn get_mouse_x_ffi() -> Double =
  #| () => globalThis.__moonlight_mouse_x || 0

///|
/// マウスY座標を取得
extern "js" fn get_mouse_y_ffi() -> Double =
  #| () => globalThis.__moonlight_mouse_y || 0


///|
/// イベントターゲットから data-id を取得
pub extern "js" fn get_target_id(e : @js.Any) -> String =
  #| (e) => {
  #|   let target = e.target;
  #|   while (target && target !== e.currentTarget) {
  #|     if (target.dataset && target.dataset.id) {
  #|       return target.dataset.id;
  #|     }
  #|     target = target.parentElement;
  #|   }
  #|   return '';
  #| }

///|
/// 要素の位置を更新
fn update_element_position(
  state : SimpleEditorState,
  id : String,
  new_x : Double,
  new_y : Double,
) -> Unit {
  let elements = state.elements.get()
  let new_elements : Array[@model.Element] = []
  for el in elements {
    if el.id == id {
      new_elements.push({ ..el, x: new_x, y: new_y })
    } else {
      new_elements.push(el)
    }
  }
  state.elements.set(new_elements)
}

///|
/// mousedown ハンドラをセットアップ
pub extern "js" fn add_mousedown_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('mousedown', handler)

///|
/// mousemove ハンドラをセットアップ
pub extern "js" fn add_mousemove_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('mousemove', handler)

///|
/// mouseup ハンドラをセットアップ
pub extern "js" fn add_mouseup_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('mouseup', handler)

///|
/// mouseleave ハンドラをセットアップ
pub extern "js" fn add_mouseleave_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('mouseleave', handler)

///|
/// インタラクションをセットアップ
pub fn setup_interaction(
  state : SimpleEditorState,
  drag_state : DragState,
) -> Unit {
  let svg = state.svg_el
  // SVG が null なら何もしない
  if is_svg_null(svg) {
    return
  }
  // mousedown: 要素をクリックしたらドラッグ開始
  add_mousedown_handler(
    svg,
    fn(e) {
      let (mx, my) = get_mouse_coords_from_event(e)
      let target_id = get_target_id(e)
      if target_id != "" {
        // 要素を選択
        state.selected_id.set(Some(target_id))
        // ドラッグ開始
        drag_state.is_dragging.set(true)
        drag_state.dragging_id.set(Some(target_id))
        drag_state.start_x.val = mx
        drag_state.start_y.val = my
        // 要素の現在位置を保存
        for el in state.elements.get() {
          if el.id == target_id {
            drag_state.element_start_x.val = el.x
            drag_state.element_start_y.val = el.y
            break
          }
        }
        prevent_default_ffi(e)
      } else {
        // 背景クリック: 選択解除
        state.selected_id.set(None)
      }
    },
  )
  // mousemove: ドラッグ中なら要素を移動
  add_mousemove_handler(
    svg,
    fn(e) {
      if not(drag_state.is_dragging.get()) {
        return
      }
      match drag_state.dragging_id.get() {
        None => ()
        Some(id) => {
          let (mx, my) = get_mouse_coords_from_event(e)
          let dx = mx - drag_state.start_x.val
          let dy = my - drag_state.start_y.val
          let new_x = drag_state.element_start_x.val + dx
          let new_y = drag_state.element_start_y.val + dy
          update_element_position(state, id, new_x, new_y)
        }
      }
    },
  )
  // mouseup: ドラッグ終了
  add_mouseup_handler(
    svg,
    fn(_e) {
      drag_state.is_dragging.set(false)
      drag_state.dragging_id.set(None)
    },
  )
  // mouseleave: ドラッグ終了
  add_mouseleave_handler(
    svg,
    fn(_e) {
      drag_state.is_dragging.set(false)
      drag_state.dragging_id.set(None)
    },
  )
}

///|
/// preventDefault を呼ぶ
extern "js" fn prevent_default_ffi(e : @js.Any) =
  #| (e) => e.preventDefault()


///|
/// SVG が null かどうかチェック
extern "js" fn is_svg_null(svg : @js.Any) -> Bool =
  #| (svg) => svg === null || svg === undefined

///|
/// 選択枠を描画（要素が選択されている場合）
pub fn render_selection_rect(state : SimpleEditorState) -> Unit {
  let svg = state.svg_el
  // SVG が null なら何もしない
  if is_svg_null(svg) {
    return
  }
  // 既存の選択枠を削除
  remove_selection_rect_ffi(svg)
  // 選択された要素があれば選択枠を描画
  match state.selected_id.get() {
    None => ()
    Some(id) =>
      for el in state.elements.get() {
        if el.id == id {
          let (x, y, w, h) = get_element_bounds(el)
          draw_selection_rect_ffi(svg, x, y, w, h)
          break
        }
      }
  }
}

///|
/// 要素の境界を取得
fn get_element_bounds(el : @model.Element) -> (Double, Double, Double, Double) {
  match el.shape {
    @model.Rect(w, h, _, _) => (el.x, el.y, w, h)
    @model.Circle(r) => (el.x - r, el.y - r, r * 2.0, r * 2.0)
    @model.Ellipse(rx, ry) => (el.x - rx, el.y - ry, rx * 2.0, ry * 2.0)
    @model.Line(x2, y2) => {
      let min_x = if el.x < x2 { el.x } else { x2 }
      let min_y = if el.y < y2 { el.y } else { y2 }
      let max_x = if el.x > x2 { el.x } else { x2 }
      let max_y = if el.y > y2 { el.y } else { y2 }
      (min_x, min_y, max_x - min_x, max_y - min_y)
    }
    @model.Text(_, _) => (el.x, el.y - 16.0, 100.0, 20.0) // 概算
    _ => (el.x, el.y, 50.0, 50.0)
  }
}

///|
/// 選択枠を削除
extern "js" fn remove_selection_rect_ffi(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelector('.selection-rect');
  #|   if (existing) existing.remove();
  #| }

///|
/// 選択枠を描画
extern "js" fn draw_selection_rect_ffi(
  svg : @js.Any,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) =
  #| (svg, x, y, w, h) => {
  #|   const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
  #|   rect.setAttribute('class', 'selection-rect');
  #|   rect.setAttribute('x', x - 2);
  #|   rect.setAttribute('y', y - 2);
  #|   rect.setAttribute('width', w + 4);
  #|   rect.setAttribute('height', h + 4);
  #|   rect.setAttribute('fill', 'none');
  #|   rect.setAttribute('stroke', '#0066ff');
  #|   rect.setAttribute('stroke-width', '2');
  #|   rect.setAttribute('stroke-dasharray', '4,2');
  #|   rect.setAttribute('pointer-events', 'none');
  #|   svg.appendChild(rect);
  #| }
