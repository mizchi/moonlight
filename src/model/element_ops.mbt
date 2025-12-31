// element_ops.mbt - 要素操作の純粋関数
// 座標と接続情報をアトミックに更新する

///|
/// 要素移動の結果
pub(all) struct MoveResult {
  elements : Array[Element]
}

// ============================================================
// BFS による接続ライン更新（共通関数）
// ============================================================

///|
/// BFS で接続された全てのラインを更新（純粋関数）
/// 指定した要素群から開始して、接続されている全てのラインを再帰的に更新する
/// except_ids に含まれる要素は更新対象から除外される
pub fn propagate_line_connections_bfs(
  elements : Array[Element],
  start_ids : Array[String],
  except_ids~ : Array[String] = [],
) -> Array[Element] {
  // 座標を管理する Map（id -> (x, y, x2, y2)）
  let coords_map : Map[String, (Double, Double, Double, Double)] = {}
  // 初期状態を設定
  for e in elements {
    if e.shape is Line(x2, y2) {
      coords_map[e.id] = (e.x, e.y, x2, y2)
    }
  }
  // BFS キュー
  let queue : Array[String] = []
  for id in start_ids {
    queue.push(id)
  }
  let processed : Array[String] = []
  while queue.length() > 0 {
    let current_id = queue.remove(0)
    if processed.contains(current_id) {
      continue
    }
    processed.push(current_id)
    // current_id の最新座標を取得
    let current_el = elements.iter().find_first(fn(e) { e.id == current_id })
    guard current_el is Some(target) else { continue }
    // current_id に接続している Line を探して更新
    for el in elements {
      // 除外対象はスキップ
      if except_ids.contains(el.id) {
        continue
      }
      guard el.shape is Line(x2, y2) else { continue }
      guard el.connections is Some(conns) else { continue }
      // 既存の座標を取得
      let (base_x, base_y, base_x2, base_y2) = coords_map.get(el.id).unwrap_or(
        (el.x, el.y, x2, y2),
      )
      let mut new_x = base_x
      let mut new_y = base_y
      let mut new_x2 = base_x2
      let mut new_y2 = base_y2
      let mut changed = false
      // 始点が current_id に接続している場合
      if conns.start is Some(conn) && conn.element_id == current_id {
        let anchor_point = target.get_anchor_point(conn.anchor)
        // Line の場合は更新された座標を使用
        let p = if target.shape is Line(_, _) {
          match coords_map.get(current_id) {
            Some((cx, cy, cx2, cy2)) =>
              get_anchor_from_line_coords(cx, cy, cx2, cy2, conn.anchor)
            None => anchor_point
          }
        } else {
          anchor_point
        }
        if p.x != new_x || p.y != new_y {
          new_x = p.x
          new_y = p.y
          changed = true
        }
      }
      // 終点が current_id に接続している場合
      if conns.end is Some(conn) && conn.element_id == current_id {
        let anchor_point = target.get_anchor_point(conn.anchor)
        // Line の場合は更新された座標を使用
        let p = if target.shape is Line(_, _) {
          match coords_map.get(current_id) {
            Some((cx, cy, cx2, cy2)) =>
              get_anchor_from_line_coords(cx, cy, cx2, cy2, conn.anchor)
            None => anchor_point
          }
        } else {
          anchor_point
        }
        if p.x != new_x2 || p.y != new_y2 {
          new_x2 = p.x
          new_y2 = p.y
          changed = true
        }
      }
      if changed {
        coords_map[el.id] = (new_x, new_y, new_x2, new_y2)
        // この Line に接続している Line も更新が必要
        if not(queue.contains(el.id)) && not(processed.contains(el.id)) {
          queue.push(el.id)
        }
      }
    }
  }
  // 更新を適用
  elements.map(fn(el) {
    guard el.shape is Line(_, _) else { return el }
    match coords_map.get(el.id) {
      Some((x, y, x2, y2)) =>
        if x != el.x ||
          y != el.y ||
          (el.shape is Line(ox2, oy2) && (x2 != ox2 || y2 != oy2)) {
          { ..el, x, y, shape: Line(x2, y2) }
        } else {
          el
        }
      None => el
    }
  })
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
/// Line 以外の要素を移動（子要素と接続ラインも更新、BFS で全ホップを伝播）
fn move_shape_with_relations(
  elements : Array[Element],
  id : String,
  new_x : Double,
  new_y : Double,
  dx : Double,
  dy : Double,
  _el : Element,
) -> Array[Element] {
  // 子要素のIDを収集
  let child_ids : Array[String] = []
  for e in elements {
    if e.parent_id == Some(id) {
      child_ids.push(e.id)
    }
  }
  // まず対象要素と子要素を移動
  let updated = elements.map(fn(e) {
    if e.id == id {
      { ..e, x: new_x, y: new_y }
    } else if child_ids.contains(e.id) {
      { ..e, x: e.x + dx, y: e.y + dy }
    } else {
      e
    }
  })
  // BFS で接続されている全てのラインを更新
  propagate_line_connections_bfs(updated, [id])
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
/// 要素のサイズ変更後に関連要素を更新（純粋関数、BFS で全ホップを伝播）
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
  // まず対象要素と子要素を更新
  let updated = elements.map(fn(e) {
    if e.id == id {
      { ..e, shape: new_shape }
    } else if e.parent_id == Some(id) {
      { ..e, x: center_x, y: center_y }
    } else {
      e
    }
  })
  // BFS で接続されている全てのラインを更新
  propagate_line_connections_bfs(updated, [id])
}
