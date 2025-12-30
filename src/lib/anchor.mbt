// 共通ライブラリ - アンカーポイント表示
// 選択された要素のアンカーポイントを可視化

///|
/// アンカーポイントを描画
pub fn render_anchor_points(state : @core.EditorState) -> Unit {
  let svg = state.svg_el.get()
  if is_js_null(svg) {
    return
  }
  // 既存のアンカーポイントを削除
  remove_anchor_points_ffi(svg)
  // 選択された要素があればアンカーポイントを描画
  match state.get_selected_id() {
    None => ()
    Some(id) =>
      for el in state.elements.get() {
        if el.id == id {
          let anchors = get_element_anchors_with_type(el)
          for anchor in anchors {
            let (x, y, anchor_type) = anchor
            draw_anchor_point_ffi(
              svg,
              x,
              y,
              el.id,
              anchor_type_to_string(anchor_type),
            )
          }
          break
        }
      }
  }
}

///|
/// 要素のアンカーポイントを取得（タイプ付き）
fn get_element_anchors_with_type(
  el : @model.Element,
) -> Array[(Double, Double, @core.AnchorType)] {
  match el.shape {
    @model.Rect(w, h, _, _) => {
      let cx = el.x + w / 2.0
      let cy = el.y + h / 2.0
      [
        (cx, el.y, @core.Top), // Top
        (cx, el.y + h, @core.Bottom), // Bottom
        (el.x, cy, @core.Left), // Left
        (el.x + w, cy, @core.Right), // Right
        (cx, cy, @core.Center),
      ]
    } // Center
    @model.Circle(r) =>
      [
        (el.x, el.y - r, @core.Top), // Top
        (el.x, el.y + r, @core.Bottom), // Bottom
        (el.x - r, el.y, @core.Left), // Left
        (el.x + r, el.y, @core.Right), // Right
        (el.x, el.y, @core.Center),
      ] // Center
    @model.Ellipse(rx, ry) =>
      [
        (el.x, el.y - ry, @core.Top), // Top
        (el.x, el.y + ry, @core.Bottom), // Bottom
        (el.x - rx, el.y, @core.Left), // Left
        (el.x + rx, el.y, @core.Right), // Right
        (el.x, el.y, @core.Center),
      ] // Center
    @model.Line(x2, y2) =>
      [
        (el.x, el.y, @core.LineStart), // Start
        (x2, y2, @core.LineEnd), // End
        ((el.x + x2) / 2.0, (el.y + y2) / 2.0, @core.Center),
      ] // Center
    @model.Path(_, start_x, start_y, end_x, end_y) => {
      // Path は el.x, el.y が始点の実際の位置
      // 実際の終点は el.x + (end_x - start_x), el.y + (end_y - start_y)
      let actual_end_x = el.x + (end_x - start_x)
      let actual_end_y = el.y + (end_y - start_y)
      [
        (el.x, el.y, @core.LineStart), // Start
        (actual_end_x, actual_end_y, @core.LineEnd),
      ]
    } // End
    @model.Text(_, _) => [(el.x, el.y, @core.Center)] // Just the position
    _ => []
  }
}

///|
/// 要素のアンカーポイントを取得（後方互換）
fn get_element_anchors(el : @model.Element) -> Array[(Double, Double)] {
  get_element_anchors_with_type(el).map(fn(a) { (a.0, a.1) })
}

// === FFI 関数 ===

///|
/// アンカーポイントを削除
extern "js" fn remove_anchor_points_ffi(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelectorAll('.anchor-point');
  #|   existing.forEach(el => el.remove());
  #| }

///|
/// アンカーポイントを描画
extern "js" fn draw_anchor_point_ffi(
  svg : @js.Any,
  x : Double,
  y : Double,
  element_id : String,
  anchor_type : String,
) =
  #| (svg, x, y, elementId, anchorType) => {
  #|   const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
  #|   circle.setAttribute('class', 'anchor-point');
  #|   circle.setAttribute('cx', x);
  #|   circle.setAttribute('cy', y);
  #|   circle.setAttribute('r', '6');
  #|   circle.setAttribute('fill', '#0066ff');
  #|   circle.setAttribute('stroke', '#ffffff');
  #|   circle.setAttribute('stroke-width', '2');
  #|   circle.setAttribute('cursor', 'crosshair');
  #|   circle.setAttribute('data-anchor', anchorType);
  #|   circle.setAttribute('data-anchor-element', elementId);
  #|   svg.appendChild(circle);
  #| }
