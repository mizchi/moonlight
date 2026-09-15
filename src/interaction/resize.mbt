// リサイズと線端点ドラッグの純粋計算
//
// 図形 × ハンドルの組み合わせごとに「どの点が固定され、どの点が動くか」が違う。
// ここに一箇所だけ定義し、Signal 層はこの結果を適用するだけにする。

///|
/// リサイズ計算の結果
pub(all) struct ResizeOutcome {
  /// 更新後の対象要素
  element : @model.Element
  /// 子要素を置き直す中心（None なら子要素は動かさない）
  child_center : @model.Point?
  /// 線の端点がスナップした接続先（線の端点ドラッグ時のみ）
  joint : PendingJoint?
} derive(Debug, Eq)

///|
/// ハンドルをドラッグしたときの新しい形状を計算する。
/// 対応しない図形 × ハンドルの組み合わせでは None を返す。
pub fn resize(
  scene : Scene,
  gesture : ResizeGesture,
  mouse : @model.Point,
) -> ResizeOutcome? {
  guard scene.find(gesture.element_id) is Some(el) else { return None }
  let dx = mouse.x - gesture.mouse_start.x
  let dy = mouse.y - gesture.mouse_start.y
  let grid = scene.grid
  match gesture.start_shape {
    @model.Rect(w, h, rx, ry) =>
      Some(resize_rect(el, gesture, grid, dx, dy, w, h, rx, ry))
    @model.Circle(r) => Some(resize_circle(el, gesture, grid, dx, dy, r))
    @model.Ellipse(erx, ery) =>
      Some(resize_ellipse(el, gesture, grid, dx, dy, erx, ery))
    @model.Line(x2, y2) => resize_line(scene, el, gesture, dx, dy, x2, y2)
    _ => None
  }
}

///|
/// 矩形: ドラッグ中の隅をスナップし、対角の隅を固定する
fn resize_rect(
  el : @model.Element,
  gesture : ResizeGesture,
  grid : Grid,
  dx : Double,
  dy : Double,
  w : Double,
  h : Double,
  rx : Double?,
  ry : Double?,
) -> ResizeOutcome {
  let x1 = gesture.start_x
  let y1 = gesture.start_y
  let x2 = gesture.start_x + w
  let y2 = gesture.start_y + h
  let (nx1, ny1, nx2, ny2) = match gesture.handle {
    @model.SE => (x1, y1, grid.snap(x2 + dx), grid.snap(y2 + dy))
    @model.NW => (grid.snap(x1 + dx), grid.snap(y1 + dy), x2, y2)
    @model.NE => (x1, grid.snap(y1 + dy), grid.snap(x2 + dx), y2)
    @model.SW => (grid.snap(x1 + dx), y1, x2, grid.snap(y2 + dy))
    _ => (x1, y1, x2 + dx, y2 + dy)
  }
  // 最小サイズを保証する。潰れた側は、掴んでいない隅を固定したまま押し戻す。
  let (fx1, fx2) = if nx2 - nx1 < min_element_size {
    match gesture.handle {
      @model.NW | @model.SW => (nx2 - min_element_size, nx2)
      _ => (nx1, nx1 + min_element_size)
    }
  } else {
    (nx1, nx2)
  }
  let (fy1, fy2) = if ny2 - ny1 < min_element_size {
    match gesture.handle {
      @model.NW | @model.NE => (ny2 - min_element_size, ny2)
      _ => (ny1, ny1 + min_element_size)
    }
  } else {
    (ny1, ny2)
  }
  let width = fx2 - fx1
  let height = fy2 - fy1
  {
    element: {
      ..el,
      x: fx1,
      y: fy1,
      shape: @model.Rect(width, height, rx, ry),
    },
    child_center: Some({ x: fx1 + width / 2.0, y: fy1 + height / 2.0, }),
    joint: None,
  }
}

///|
/// 円: 中心を固定し、ドラッグした辺の位置から半径を決める
fn resize_circle(
  el : @model.Element,
  gesture : ResizeGesture,
  grid : Grid,
  dx : Double,
  dy : Double,
  r : Double,
) -> ResizeOutcome {
  let cx = gesture.start_x
  let cy = gesture.start_y
  let (edge_x, edge_y) = match gesture.handle {
    @model.NW => (cx - r + dx, cy - r + dy)
    @model.NE => (cx + r + dx, cy - r + dy)
    @model.SW => (cx - r + dx, cy + r + dy)
    _ => (cx + r + dx, cy + r + dy)
  }
  let dist_x = (grid.snap(edge_x) - cx).abs()
  let dist_y = (grid.snap(edge_y) - cy).abs()
  let new_r = (dist_x + dist_y) / 2.0
  let final_r = if new_r < min_radius { min_radius } else { new_r }
  {
    element: { ..el, shape: @model.Circle(final_r), },
    child_center: Some({ x: cx, y: cy, }),
    joint: None,
  }
}

///|
/// 楕円: バウンディングボックスの隅をドラッグし、中心と半径を再計算する
fn resize_ellipse(
  el : @model.Element,
  gesture : ResizeGesture,
  grid : Grid,
  dx : Double,
  dy : Double,
  rx : Double,
  ry : Double,
) -> ResizeOutcome {
  let cx = gesture.start_x
  let cy = gesture.start_y
  let x1 = cx - rx
  let y1 = cy - ry
  let x2 = cx + rx
  let y2 = cy + ry
  let (nx1, ny1, nx2, ny2) = match gesture.handle {
    @model.SE => (x1, y1, grid.snap(x2 + dx), grid.snap(y2 + dy))
    @model.NW => (grid.snap(x1 + dx), grid.snap(y1 + dy), x2, y2)
    @model.NE => (x1, grid.snap(y1 + dy), grid.snap(x2 + dx), y2)
    @model.SW => (grid.snap(x1 + dx), y1, x2, grid.snap(y2 + dy))
    _ => (x1, y1, x2 + dx, y2 + dy)
  }
  let new_cx = (nx1 + nx2) / 2.0
  let new_cy = (ny1 + ny2) / 2.0
  let new_rx = (nx2 - nx1) / 2.0
  let new_ry = (ny2 - ny1) / 2.0
  let final_rx = if new_rx < min_radius { min_radius } else { new_rx }
  let final_ry = if new_ry < min_radius { min_radius } else { new_ry }
  {
    element: {
      ..el,
      x: new_cx,
      y: new_cy,
      shape: @model.Ellipse(final_rx, final_ry),
    },
    child_center: Some({ x: new_cx, y: new_cy, }),
    joint: None,
  }
}

///|
/// 線の端点: 近くにアンカーがあればそこへ吸着し、なければグリッドに丸める。
/// アンカースナップはグリッドスナップより優先する。
fn resize_line(
  scene : Scene,
  el : @model.Element,
  gesture : ResizeGesture,
  dx : Double,
  dy : Double,
  x2 : Double,
  y2 : Double,
) -> ResizeOutcome? {
  guard endpoint_of_handle(gesture.handle) is Some(endpoint) else {
    return None
  }
  let raw : @model.Point = match endpoint {
    Start => { x: gesture.start_x + dx, y: gesture.start_y + dy, }
    End => { x: x2 + dx, y: y2 + dy, }
  }
  let snapped = @model.find_nearest_connection(
    scene.elements,
    raw,
    [gesture.element_id],
    anchor_snap_threshold,
  )
  let (point, joint) : (@model.Point, PendingJoint?) = match snapped {
    Some(found) => {
      let joint : PendingJoint = {
        target_id: found.element.id,
        anchor: found.anchor,
        point: found.point,
      }
      (found.point, Some(joint))
    }
    None => (scene.grid.snap_point(raw), None)
  }
  let element = match endpoint {
    Start => { ..el, x: point.x, y: point.y, }
    End => { ..el, shape: @model.Line(point.x, point.y), }
  }
  Some({ element, child_center: None, joint, })
}

///|
/// 線の長さ（線でなければ None）
pub fn line_length(el : @model.Element) -> Double? {
  guard el.shape is @model.Line(x2, y2) else { return None }
  let dx = x2 - el.x
  let dy = y2 - el.y
  Some((dx * dx + dy * dy).sqrt())
}
