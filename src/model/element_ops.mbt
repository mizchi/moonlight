// element_ops.mbt - 要素操作の純粋関数
// 座標と接続情報をアトミックに更新する

///|
/// 要素移動の結果
pub(all) struct MoveResult {
  elements : Array[Element]
}

///|
/// 要素を移動し、関連する全ての更新を行う（純粋関数）
/// - 対象要素の座標を更新
/// - 子要素を同じ差分で移動
/// - 接続されているラインの端点を更新
pub fn move_element_with_relations(
  elements : Array[Element],
  id : String,
  new_x : Double,
  new_y : Double,
) -> Array[Element] {
  // 対象要素を見つける
  let mut target_el : Element? = None
  for e in elements {
    if e.id == id {
      target_el = Some(e)
      break
    }
  }
  guard target_el is Some(el) else { return elements }
  let dx = new_x - el.x
  let dy = new_y - el.y
  // Line の場合は特別な処理、それ以外は共通処理
  match el.shape {
    Line(_, _) =>
      move_line_with_topology(elements, id, new_x, new_y, dx, dy, el)
    // Path も他の図形と同様に接続ラインを更新
    _ => move_shape_with_relations(elements, id, new_x, new_y, dx, dy, el)
  }
}

///|
/// Line 以外の要素を移動（子要素と接続ラインも更新）
fn move_shape_with_relations(
  elements : Array[Element],
  id : String,
  new_x : Double,
  new_y : Double,
  dx : Double,
  dy : Double,
  el : Element,
) -> Array[Element] {
  // 子要素のIDを収集
  let child_ids : Array[String] = []
  for e in elements {
    if e.parent_id == Some(id) {
      child_ids.push(e.id)
    }
  }
  // 全ての更新を適用
  elements.map(fn(e) {
    // 対象要素を移動
    if e.id == id {
      return { ..e, x: new_x, y: new_y }
    }
    // 子要素を移動
    if child_ids.contains(e.id) {
      return { ..e, x: e.x + dx, y: e.y + dy }
    }
    // 接続されているラインを更新
    guard e.shape is Line(x2, y2) else { return e }
    guard e.connections is Some(conns) else { return e }
    let mut new_ex = e.x
    let mut new_ey = e.y
    let mut new_ex2 = x2
    let mut new_ey2 = y2
    // 始点の接続を確認
    match conns.start {
      Some(conn) if conn.element_id == id => {
        // 移動後のターゲット要素でアンカー位置を計算
        let moved_target = { ..el, x: new_x, y: new_y }
        let anchor_point = moved_target.get_anchor_point(conn.anchor)
        new_ex = anchor_point.x
        new_ey = anchor_point.y
      }
      _ => ()
    }
    // 終点の接続を確認
    match conns.end {
      Some(conn) if conn.element_id == id => {
        let moved_target = { ..el, x: new_x, y: new_y }
        let anchor_point = moved_target.get_anchor_point(conn.anchor)
        new_ex2 = anchor_point.x
        new_ey2 = anchor_point.y
      }
      _ => ()
    }
    if new_ex != e.x || new_ey != e.y || new_ex2 != x2 || new_ey2 != y2 {
      { ..e, x: new_ex, y: new_ey, shape: Line(new_ex2, new_ey2) }
    } else {
      e
    }
  })
}

///|
/// Line 要素を移動（接続グラフを更新）
fn move_line_with_topology(
  elements : Array[Element],
  id : String,
  new_x : Double,
  new_y : Double,
  dx : Double,
  dy : Double,
  el : Element,
) -> Array[Element] {
  // モデル層の純粋関数でトポロジー計算
  let line_updates = compute_line_move_topology(
    elements, id, new_x, new_y, dx, dy,
  )
  // 接続されている非 Line 要素のIDを収集
  let connected_non_line_ids : Array[String] = []
  match el.connections {
    Some(conns) => {
      match conns.start {
        Some(conn) => {
          let is_line = elements
            .iter()
            .any(fn(e) { e.id == conn.element_id && e.shape is Line(_, _) })
          if not(is_line) &&
            not(connected_non_line_ids.contains(conn.element_id)) {
            connected_non_line_ids.push(conn.element_id)
          }
        }
        None => ()
      }
      match conns.end {
        Some(conn) => {
          let is_line = elements
            .iter()
            .any(fn(e) { e.id == conn.element_id && e.shape is Line(_, _) })
          if not(is_line) &&
            not(connected_non_line_ids.contains(conn.element_id)) {
            connected_non_line_ids.push(conn.element_id)
          }
        }
        None => ()
      }
    }
    None => ()
  }
  // 子要素を収集
  let connected_children_ids : Array[String] = []
  for connected_id in connected_non_line_ids {
    for e in elements {
      if e.parent_id == Some(connected_id) {
        connected_children_ids.push(e.id)
      }
    }
  }
  // 全ての更新を適用
  elements.map(fn(e) {
    // 更新対象の Line
    for coords in line_updates {
      if e.id == coords.id {
        return {
          ..e,
          x: coords.x,
          y: coords.y,
          shape: Line(coords.x2, coords.y2),
        }
      }
    }
    // 接続された非 Line 要素を移動
    if connected_non_line_ids.contains(e.id) {
      return { ..e, x: e.x + dx, y: e.y + dy }
    }
    // 接続要素の子要素を移動
    if connected_children_ids.contains(e.id) {
      return { ..e, x: e.x + dx, y: e.y + dy }
    }
    e
  })
}

///|
/// 要素のサイズ変更後に関連要素を更新（純粋関数）
/// - 子要素を親の中央に再配置
/// - 接続されているラインの端点を更新
pub fn resize_element_with_relations(
  elements : Array[Element],
  id : String,
  new_shape : ShapeType,
) -> Array[Element] {
  // 対象要素を見つける
  let mut target_el : Element? = None
  for e in elements {
    if e.id == id {
      target_el = Some(e)
      break
    }
  }
  guard target_el is Some(el) else { return elements }
  // 新しい形状で要素を更新
  let updated_el = { ..el, shape: new_shape }
  // 新しいバウンディングボックスの中央を計算
  let bbox = updated_el.bounding_box()
  let center_x = bbox.x + bbox.width / 2.0
  let center_y = bbox.y + bbox.height / 2.0
  // 全ての更新を適用
  elements.map(fn(e) {
    // 対象要素の形状を更新
    if e.id == id {
      return { ..e, shape: new_shape }
    }
    // 子要素を親の中央に配置
    if e.parent_id == Some(id) {
      return { ..e, x: center_x, y: center_y }
    }
    // 接続されているラインを更新
    guard e.shape is Line(x2, y2) else { return e }
    guard e.connections is Some(conns) else { return e }
    let mut new_ex = e.x
    let mut new_ey = e.y
    let mut new_ex2 = x2
    let mut new_ey2 = y2
    // 始点の接続を確認
    match conns.start {
      Some(conn) if conn.element_id == id => {
        let anchor_point = updated_el.get_anchor_point(conn.anchor)
        new_ex = anchor_point.x
        new_ey = anchor_point.y
      }
      _ => ()
    }
    // 終点の接続を確認
    match conns.end {
      Some(conn) if conn.element_id == id => {
        let anchor_point = updated_el.get_anchor_point(conn.anchor)
        new_ex2 = anchor_point.x
        new_ey2 = anchor_point.y
      }
      _ => ()
    }
    if new_ex != e.x || new_ey != e.y || new_ex2 != x2 || new_ey2 != y2 {
      { ..e, x: new_ex, y: new_ey, shape: Line(new_ex2, new_ey2) }
    } else {
      e
    }
  })
}
