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
/// SVG要素では dataset が動作しないため getAttribute を使用
pub extern "js" fn get_target_id(e : @js.Any) -> String =
  #| (e) => {
  #|   let target = e.target;
  #|   while (target && target !== e.currentTarget) {
  #|     const id = target.getAttribute && target.getAttribute('data-id');
  #|     if (id) {
  #|       return id;
  #|     }
  #|     target = target.parentElement;
  #|   }
  #|   return '';
  #| }

///|
/// イベントターゲットからアンカー情報を取得
/// 結果はグローバル変数に保存（FFIタプル問題の回避）
/// SVG要素では dataset が動作しないため getAttribute を使用
extern "js" fn get_anchor_info_ffi(e : @js.Any) =
  #| (e) => {
  #|   const target = e.target;
  #|   globalThis.__moonlight_anchor_type = '';
  #|   globalThis.__moonlight_anchor_element = '';
  #|   globalThis.__moonlight_anchor_x = 0;
  #|   globalThis.__moonlight_anchor_y = 0;
  #|   if (target && target.classList && target.classList.contains('anchor-point')) {
  #|     globalThis.__moonlight_anchor_type = target.getAttribute('data-anchor') || '';
  #|     globalThis.__moonlight_anchor_element = target.getAttribute('data-anchor-element') || '';
  #|     globalThis.__moonlight_anchor_x = parseFloat(target.getAttribute('cx')) || 0;
  #|     globalThis.__moonlight_anchor_y = parseFloat(target.getAttribute('cy')) || 0;
  #|   }
  #| }

///|
/// アンカータイプを取得
extern "js" fn get_anchor_type_ffi() -> String =
  #| () => globalThis.__moonlight_anchor_type || ''

///|
/// アンカー要素IDを取得
extern "js" fn get_anchor_element_ffi() -> String =
  #| () => globalThis.__moonlight_anchor_element || ''

///|
/// アンカーX座標を取得
extern "js" fn get_anchor_x_ffi() -> Double =
  #| () => globalThis.__moonlight_anchor_x || 0

///|
/// アンカーY座標を取得
extern "js" fn get_anchor_y_ffi() -> Double =
  #| () => globalThis.__moonlight_anchor_y || 0

///|
/// アンカー情報を取得
fn get_anchor_info(e : @js.Any) -> (String, String, Double, Double) {
  get_anchor_info_ffi(e)
  (
    get_anchor_type_ffi(),
    get_anchor_element_ffi(),
    get_anchor_x_ffi(),
    get_anchor_y_ffi(),
  )
}

///|
/// 要素の位置を更新
fn update_element_position(
  state : @core.EditorState,
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
/// Line の端点を更新
fn update_line_endpoint(
  state : @core.EditorState,
  id : String,
  anchor_type : @core.AnchorType,
  new_x : Double,
  new_y : Double,
) -> Unit {
  let elements = state.elements.get()
  let new_elements : Array[@model.Element] = []
  for el in elements {
    if el.id == id {
      match el.shape {
        @model.Line(x2, y2) => {
          let new_shape = match anchor_type {
            @core.LineStart => {
              // 始点を移動: x, y を更新
              new_elements.push({ ..el, x: new_x, y: new_y })
              continue
            }
            @core.LineEnd =>
              // 終点を移動: Line(x2, y2) を更新
              @model.Line(new_x, new_y)
            _ => @model.Line(x2, y2)
          }
          new_elements.push({ ..el, shape: new_shape })
        }
        _ => new_elements.push(el)
      }
    } else {
      new_elements.push(el)
    }
  }
  state.elements.set(new_elements)
}

///|
/// 指定IDの要素がLine要素かどうかチェック
fn is_line_element(state : @core.EditorState, id : String) -> Bool {
  for el in state.elements.get() {
    if el.id == id {
      return el.shape is @model.Line(_, _)
    }
  }
  false
}

///|
/// Line要素の端点アンカーかどうかチェック（Line端点の移動操作に使用）
fn is_line_endpoint_anchor(
  state : @core.EditorState,
  anchor_type : @core.AnchorType,
  element_id : String,
) -> Bool {
  (anchor_type is @core.LineStart || anchor_type is @core.LineEnd) &&
  is_line_element(state, element_id)
}

///|
/// pointerdown ハンドラをセットアップ（タッチ/マウス/ペン統一）
pub extern "js" fn add_pointerdown_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('pointerdown', handler)

///|
/// pointermove ハンドラをセットアップ
pub extern "js" fn add_pointermove_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('pointermove', handler)

///|
/// pointerup ハンドラをセットアップ
pub extern "js" fn add_pointerup_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('pointerup', handler)

///|
/// pointerleave ハンドラをセットアップ
pub extern "js" fn add_pointerleave_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('pointerleave', handler)

///|
/// pointercancel ハンドラをセットアップ（タッチキャンセル対応）
pub extern "js" fn add_pointercancel_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (svg, handler) => svg.addEventListener('pointercancel', handler)

///|
/// インタラクションをセットアップ
pub fn setup_interaction(
  state : @core.EditorState,
  drag_state : DragState,
) -> Unit {
  let svg = state.svg_el.get()
  // SVG が null なら何もしない
  if is_js_null(svg) {
    return
  }
  // pointerdown: 要素をクリック/タッチしたらドラッグ開始、アンカーをクリックしたら線ドラッグ開始
  add_pointerdown_handler(svg, fn(e) {
    // 右クリックは無視（コンテキストメニュー用）
    if is_right_click(e) {
      return
    }
    let (mx, my) = get_mouse_coords_from_event(e)
    // まずアンカーポイントがクリックされたかチェック（フリードローより優先）
    let (anchor_type_str, anchor_element_id, anchor_x, anchor_y) = get_anchor_info(
      e,
    )
    if anchor_type_str != "" && anchor_element_id != "" {
      // アンカーポイントからのドラッグ開始
      match parse_anchor_type(anchor_type_str) {
        Some(anchor_type) => {
          // Line要素のline-start/line-endアンカーの場合は端点移動モード
          let is_line_anchor = is_line_endpoint_anchor(
            state, anchor_type, anchor_element_id,
          )
          state.anchor_drag_state.set(
            Some({
              source_element_id: anchor_element_id,
              source_anchor_type: anchor_type,
              source_x: anchor_x,
              source_y: anchor_y,
              current_x: anchor_x,
              current_y: anchor_y,
            }),
          )
          // Line端点移動の場合はプレビュー線を使わない（リアルタイム更新するため）
          if not(is_line_anchor) {
            // 新規Line作成のプレビュー用
          }
          prevent_default_ffi(e)
          return
        }
        None => ()
      }
    }
    // フリードローモードの場合（アンカーポイント以外の場所をクリック）
    if state.tool_mode.get() == @core.FreeDraw {
      start_free_draw(state, mx, my)
      prevent_default_ffi(e)
      return
    }
    let target_id = get_target_id(e)
    if target_id != "" {
      // 要素を選択
      set_selected_id(state, Some(target_id))
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
      set_selected_id(state, None)
    }
  })
  // pointermove: ドラッグ中なら要素を移動、またはプレビュー線を更新
  add_pointermove_handler(svg, fn(e) {
    let (mx, my) = get_mouse_coords_from_event(e)
    // フリードロー中の場合
    if is_drawing(state) {
      continue_free_draw(state, mx, my)
      // プレビュー描画
      let preview_points = get_preview_points(state)
      draw_free_draw_preview(svg, preview_points)
      return
    }
    // アンカードラッグ中
    match state.anchor_drag_state.get() {
      Some(anchor_state) => {
        let anchor_type = anchor_state.source_anchor_type
        let is_line_anchor = is_line_endpoint_anchor(
          state, anchor_type, anchor_state.source_element_id,
        )
        if is_line_anchor {
          // Line端点のドラッグ: リアルタイムで位置を更新
          update_line_endpoint(
            state,
            anchor_state.source_element_id,
            anchor_type,
            mx,
            my,
          )
          state.anchor_drag_state.set(
            Some({ ..anchor_state, current_x: mx, current_y: my }),
          )
        } else {
          // 新規Line作成のプレビュー線を描画
          state.anchor_drag_state.set(
            Some({ ..anchor_state, current_x: mx, current_y: my }),
          )
          draw_preview_line_ffi(
            svg,
            anchor_state.source_x,
            anchor_state.source_y,
            mx,
            my,
          )
        }
        return
      }
      None => ()
    }
    // 通常のドラッグ
    if not(drag_state.is_dragging.get()) {
      return
    }
    match drag_state.dragging_id.get() {
      None => ()
      Some(id) => {
        let dx = mx - drag_state.start_x.val
        let dy = my - drag_state.start_y.val
        let new_x = drag_state.element_start_x.val + dx
        let new_y = drag_state.element_start_y.val + dy
        update_element_position(state, id, new_x, new_y)
        // ドラッグ中は選択UIとアンカーポイントも同期して更新
        update_selection_ui(state)
        render_anchor_points(state)
      }
    }
  })
  // pointerup: ドラッグ終了
  add_pointerup_handler(svg, fn(e) {
    // フリードロー終了
    if is_drawing(state) {
      // プレビューを削除
      remove_free_draw_preview(svg)
      finish_free_draw(state, fn() { "path-" + get_timestamp_id_ffi() })
      return
    }
    // アンカードラッグ終了
    match state.anchor_drag_state.get() {
      Some(anchor_state) => {
        let (mx, my) = get_mouse_coords_from_event(e)
        let anchor_type = anchor_state.source_anchor_type
        let is_line_anchor = is_line_endpoint_anchor(
          state, anchor_type, anchor_state.source_element_id,
        )
        if is_line_anchor {
          // Line端点の移動完了: 最終位置を設定
          update_line_endpoint(
            state,
            anchor_state.source_element_id,
            anchor_type,
            mx,
            my,
          )
          state.anchor_drag_state.set(None)
          return
        }
        // 新規Line作成モード
        // プレビュー線を削除
        remove_preview_line_ffi(svg)
        // 最小距離チェック（10px以上離れていないと作成しない）
        let dx = mx - anchor_state.source_x
        let dy = my - anchor_state.source_y
        let dist = (dx * dx + dy * dy).sqrt()
        if dist > 10.0 {
          // 新しい線要素を作成
          let line_id = "line-" + get_timestamp_id_ffi()
          let new_line : @model.Element = {
            id: line_id,
            x: anchor_state.source_x,
            y: anchor_state.source_y,
            shape: @model.Line(mx, my),
            style: {
              fill: None,
              stroke: Some("#000000"),
              stroke_width: Some(2.0),
              opacity: None,
              stroke_dasharray: None,
              marker_start: None,
              marker_end: None,
              font_family: None,
            },
            transform: None,
            parent_id: None,
            connections: None,
          }
          let elements = state.elements.get()
          let new_elements = elements.copy()
          new_elements.push(new_line)
          state.elements.set(new_elements)
          // 新しい線を選択
          set_selected_id(state, Some(line_id))
        }
        state.anchor_drag_state.set(None)
        return
      }
      None => ()
    }
    drag_state.is_dragging.set(false)
    drag_state.dragging_id.set(None)
  })
  // pointerleave: ドラッグ終了
  add_pointerleave_handler(svg, fn(_e) {
    // フリードローをキャンセル
    if is_drawing(state) {
      remove_free_draw_preview(svg)
      state.free_draw_state.set(None)
    }
    // アンカードラッグをキャンセル
    if state.anchor_drag_state.get() is Some(_) {
      remove_preview_line_ffi(svg)
      state.anchor_drag_state.set(None)
    }
    drag_state.is_dragging.set(false)
    drag_state.dragging_id.set(None)
  })
}

///|
/// タイムスタンプベースのIDを生成
extern "js" fn get_timestamp_id_ffi() -> String =
  #| () => Date.now().toString(36) + Math.random().toString(36).substr(2, 5)

///|
/// preventDefault を呼ぶ
extern "js" fn prevent_default_ffi(e : @js.Any) =
  #| (e) => e.preventDefault()

///|
/// 右クリックかどうかチェック
extern "js" fn is_right_click(e : @js.Any) -> Bool =
  #| (e) => e.button === 2

///|
/// プレビュー線を描画
extern "js" fn draw_preview_line_ffi(
  svg : @js.Any,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) =
  #| (svg, x1, y1, x2, y2) => {
  #|   // 既存のプレビュー線を削除
  #|   const existing = svg.querySelector('.preview-line');
  #|   if (existing) existing.remove();
  #|   // 新しいプレビュー線を描画
  #|   const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
  #|   line.setAttribute('class', 'preview-line');
  #|   line.setAttribute('x1', x1);
  #|   line.setAttribute('y1', y1);
  #|   line.setAttribute('x2', x2);
  #|   line.setAttribute('y2', y2);
  #|   line.setAttribute('stroke', '#0066ff');
  #|   line.setAttribute('stroke-width', '2');
  #|   line.setAttribute('stroke-dasharray', '4,2');
  #|   line.setAttribute('pointer-events', 'none');
  #|   svg.appendChild(line);
  #| }

///|
/// プレビュー線を削除
extern "js" fn remove_preview_line_ffi(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelector('.preview-line');
  #|   if (existing) existing.remove();
  #| }

///|
/// 選択枠を描画（要素が選択されている場合）
/// render.mbt の共通関数を使用
/// Line 要素はハンドルとハイライト線で選択を表現するため、選択枠は描画しない
pub fn update_selection_ui(state : @core.EditorState) -> Unit {
  let svg = state.svg_el.get()
  // SVG が null なら何もしない
  if is_js_null(svg) {
    return
  }
  // 既存の選択枠とハンドルを削除
  remove_selection_rect(svg)
  remove_resize_handles(svg)
  // 選択された要素があれば選択枠を描画
  match state.get_selected_id() {
    None => ()
    Some(id) =>
      for el in state.elements.get() {
        if el.id == id {
          // Line 要素は選択枠を描画しない（ハイライト線とアンカーで選択を表現）
          match el.shape {
            @model.Line(x2, y2) => {
              // Line はハンドルを描画
              let _ = render_line_handle(svg, el.x, el.y, "line-start", el.id)
              let _ = render_line_handle(svg, x2, y2, "line-end", el.id)
            }
            @model.Path(_, _, _, _, _) => {
              // Path は選択枠のみ（リサイズハンドルなし）
              let (x, y, w, h) = get_element_bounds(el)
              let _ = create_selection_rect(svg, x, y, w, h)
            }
            _ => {
              // 他の要素は選択枠を描画
              let (x, y, w, h) = get_element_bounds(el)
              let _ = create_selection_rect(svg, x, y, w, h)
              // リサイズハンドルを描画
              render_resize_handles(svg, el)
            }
          }
          break
        }
      }
  }
}

///|
/// リサイズハンドルを描画
fn render_resize_handles(svg : @js.Any, el : @model.Element) -> Unit {
  let (x, y, w, h) = get_element_bounds(el)
  // 四隅にハンドルを配置
  let _ = render_resize_handle(svg, x, y, "nw", el.id, "nw-resize")
  let _ = render_resize_handle(svg, x + w, y, "ne", el.id, "ne-resize")
  let _ = render_resize_handle(svg, x, y + h, "sw", el.id, "sw-resize")
  let _ = render_resize_handle(svg, x + w, y + h, "se", el.id, "se-resize")

}
