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
  except_ids? : Array[String] = [],
) -> Array[Element] {
  // 座標を管理する Map（id -> (x, y, x2, y2)）
  let coords_map : Map[String, (Double, Double, Double, Double)] = Map([])
  // 初期状態を設定
  for e in elements {
    if e.shape is Line(x2, y2) {
      coords_map[e.id] = (e.x, e.y, x2, y2)
    }
  }
  // BFS キュー
  let queue : Array[String] = []
  for id in start_ids {
    if !queue.contains(id) {
      queue.push(id)
    }
  }
  // 線どうしの結合は連鎖するので、一度処理した線でも、あとから座標が変われば
  // もう一度処理して結合先の線に伝え直す（一度きりにすると、深さの違う二つの
  // 経路から動かされた線の先が古い座標のまま残る）。
  // 変化は根（図形のアンカー）から結合をさかのぼる向きにしか伝わらないので
  // いずれ止まるが、念のため回数に上限を置く。
  let mut budget = (elements.length() + 1) * (elements.length() + 1) * 4
  while queue.length() > 0 && budget > 0 {
    budget = budget - 1
    let current_id = queue.remove(0)
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
      let (base_x, base_y, base_x2, base_y2) = coords_map
        .get(el.id)
        .unwrap_or((el.x, el.y, x2, y2))
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
        if !queue.contains(el.id) {
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
          { ..el, x, y, shape: Line(x2, y2), }
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
      { ..e, x: new_x, y: new_y, }
    } else if child_ids.contains(e.id) {
      { ..e, x: e.x + dx, y: e.y + dy, }
    } else {
      e
    }
  })
  // BFS で接続されている全てのラインを更新
  propagate_line_connections_bfs(updated, [id])
}

///|
/// 線の端点が結合をたどった先で、最終的にその座標を決めているもの
priv enum JointRoot {
  /// 図形のアンカー（図形 ID）
  ShapeRoot(String)
  /// 線の端点。自由端ならひとつ、線だけの輪ならその輪の端点すべて
  EndRoots(Array[(String, Anchor)])
  /// 掴んだ線自身に戻ってきた、または結合先が無い
  NoRoot
}

///|
/// 結合 conn から、線どうしの結合をたどって根を探す。
///
/// 線の端点に結合した端点の座標は、その端点がさらに結合している先が決める。
/// たどった先が図形ならその図形、自由端ならその端点、線だけの輪なら輪全体が根。
fn joint_root(
  elements : Array[Element],
  conn : Connection,
  dragged_id : String,
) -> JointRoot {
  let path : Array[(String, Anchor)] = []
  let mut current = conn
  for _ in 0..<=(elements.length() * 2) {
    guard elements.iter().find_first(fn(e) { e.id == current.element_id })
      is Some(target) else {
      return NoRoot
    }
    // 線以外（図形・パス・テキスト）ならそれが根
    guard target.shape is Line(_, _) else { return ShapeRoot(target.id) }
    // 掴んだ線に戻ってきた: その端点は BFS で掴んだ線に追随する
    if target.id == dragged_id {
      return NoRoot
    }
    let here = (target.id, current.anchor)
    for i in 0..<path.length() {
      if path[i] == here {
        return EndRoots(path[i:].to_array())
      }
    }
    path.push(here)
    let next = match (target.connections, current.anchor) {
      (Some(conns), LineStart) => conns.start
      (Some(conns), LineEnd) => conns.end
      // 線の中点などへの結合は UI からは作れない。端点としては扱わない。
      (_, LineStart) | (_, LineEnd) => None
      _ => return NoRoot
    }
    match next {
      Some(n) => current = n
      None => return EndRoots([here])
    }
  }
  NoRoot
}

///|
/// Line 要素を移動（接続グラフを更新）
///
/// 掴んだ線は差分だけ平行移動し、端点が結合している先を連れて動く。
/// 連れて動かすのは、結合をたどった先の「根」:
///   - 図形なら同じ差分で平行移動する（子要素も一緒）
///   - 線の自由端なら、その端点だけを動かす（その線は伸縮する）
///   - 線だけの輪なら、輪をなす端点すべてを動かす
/// 途中の線の端点や、連れて動いた要素にぶら下がる別の線は、最後に BFS で
/// 追随させる。これをしないと a — b — c の鎖で b — c 間の線を掴んだとき、
/// b が動いても a — b 間の線が取り残されて接続が切れて見える。
fn move_line_with_topology(
  elements : Array[Element],
  id : String,
  new_x : Double,
  new_y : Double,
  dx : Double,
  dy : Double,
  el : Element,
) -> Array[Element] {
  // 平行移動する図形の ID と、動かす線の端点
  let carried_shapes : Array[String] = []
  let carried_ends : Array[(String, Anchor)] = []
  if el.connections is Some(conns) {
    for conn in [conns.start, conns.end] {
      guard conn is Some(c) else { continue }
      match joint_root(elements, c, id) {
        ShapeRoot(shape_id) =>
          if !carried_shapes.contains(shape_id) {
            carried_shapes.push(shape_id)
          }
        EndRoots(ends) =>
          for end in ends {
            if !carried_ends.contains(end) {
              carried_ends.push(end)
            }
          }
        NoRoot => ()
      }
    }
  }
  // 連れて動く図形の子要素
  let carried_children : Array[String] = []
  for shape_id in carried_shapes {
    for e in elements {
      if e.parent_id == Some(shape_id) && !carried_children.contains(e.id) {
        carried_children.push(e.id)
      }
    }
  }
  let moved = elements.map(fn(e) {
    // 掴んだ線そのもの
    if e.id == id {
      return match e.shape {
        Line(x2, y2) =>
          { ..e, x: new_x, y: new_y, shape: Line(x2 + dx, y2 + dy), }
        _ => { ..e, x: new_x, y: new_y, }
      }
    }
    // 連れて動く図形とその子要素
    if carried_shapes.contains(e.id) || carried_children.contains(e.id) {
      return { ..e, x: e.x + dx, y: e.y + dy, }
    }
    // 根になっている線の端点
    if e.shape is Line(x2, y2) {
      let move_start = carried_ends.contains((e.id, LineStart))
      let move_end = carried_ends.contains((e.id, LineEnd))
      if move_start || move_end {
        let (sx, sy) = if move_start {
          (e.x + dx, e.y + dy)
        } else {
          (e.x, e.y)
        }
        let (ex, ey) = if move_end { (x2 + dx, y2 + dy) } else { (x2, y2) }
        return { ..e, x: sx, y: sy, shape: Line(ex, ey), }
      }
    }
    e
  })
  // 動いたものにぶら下がる線（掴んだ線に結合した線も含む）を BFS で追随させる。
  // 掴んだ線自身はドラッグの位置が正なので、更新対象から外す。
  let starts : Array[String] = [id]
  for shape_id in carried_shapes {
    starts.push(shape_id)
  }
  for child_id in carried_children {
    starts.push(child_id)
  }
  for end in carried_ends {
    if !starts.contains(end.0) {
      starts.push(end.0)
    }
  }
  propagate_line_connections_bfs(moved, starts, except_ids=[id])
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
  let updated_el = { ..el, shape: new_shape, }
  // 新しいバウンディングボックスの中央を計算
  let bbox = updated_el.bounding_box()
  let center_x = bbox.x + bbox.width / 2.0
  let center_y = bbox.y + bbox.height / 2.0
  // まず対象要素と子要素を更新
  let updated = elements.map(fn(e) {
    if e.id == id {
      { ..e, shape: new_shape, }
    } else if e.parent_id == Some(id) {
      { ..e, x: center_x, y: center_y, }
    } else {
      e
    }
  })
  // BFS で接続されている全てのラインを更新
  propagate_line_connections_bfs(updated, [id])
}

///|
/// 要素の座標を整数に丸める。ただしジョイントはアンカーの上に保つ（純粋関数）
///
/// 丸めは書き出す SVG を読みやすくするためのもので、接続より優先しない。
///   - 線: 結合している端点は丸めずに結合先アンカーの上へ戻す（自由端だけ丸まる）
///   - 図形: 丸めてずれたアンカーへ、結合している線を BFS で追随させる
/// 丸めた要素だけを見て周りを放っておくと、.5 の座標にあるアンカーから
/// 端点が最大 √2 px ほど浮く。
pub fn round_element_keeping_joints(
  elements : Array[Element],
  id : String,
) -> Array[Element] {
  let rounded = elements.map(fn(e) {
    if e.id == id {
      round_element_coords(e)
    } else {
      e
    }
  })
  let anchor_of = fn(conn : Connection?) -> Point? {
    guard conn is Some(c) else { return None }
    guard rounded.iter().find_first(fn(e) { e.id == c.element_id })
      is Some(target) else {
      return None
    }
    Some(target.get_anchor_point(c.anchor))
  }
  let pinned = rounded.map(fn(e) {
    guard e.id == id else { return e }
    guard e.shape is Line(x2, y2) else { return e }
    guard e.connections is Some(conns) else { return e }
    let start = anchor_of(conns.start).unwrap_or({ x: e.x, y: e.y, })
    let end = anchor_of(conns.end).unwrap_or({ x: x2, y: y2, })
    { ..e, x: start.x, y: start.y, shape: Line(end.x, end.y), }
  })
  propagate_line_connections_bfs(pinned, [id])
}

///|
/// 要素の ID を付け替え、その ID を指している参照も一緒に付け替える（純粋関数）
///
/// 線の接続先（connections）と子要素の親（parent_id）は ID で相手を指している。
/// 要素の ID だけを変えると、そこに付いていた線はすべて存在しない要素を指し、
/// 図形を動かしても追随しなくなる。
pub fn rename_element(
  elements : Array[Element],
  old_id : String,
  new_id : String,
) -> Array[Element] {
  let swap = fn(id : String) -> String {
    if id == old_id {
      new_id
    } else {
      id
    }
  }
  let swap_conn = fn(conn : Connection?) -> Connection? {
    match conn {
      Some(c) => Some({ ..c, element_id: swap(c.element_id), })
      None => None
    }
  }
  elements.map(fn(el) {
    {
      ..el,
      id: swap(el.id),
      parent_id: match el.parent_id {
        Some(pid) => Some(swap(pid))
        None => None
      },
      connections: match el.connections {
        Some(conns) =>
          Some({ start: swap_conn(conns.start), end: swap_conn(conns.end), })
        None => None
      },
    }
  })
}

///|
/// 選択した要素の組を平行移動する（純粋関数）
///
/// 複数選択のドラッグと、複数選択を矢印キーで動かすときに使う。
///   - 選択した要素はちょうど一度だけ動く（子要素は親と一緒に動く）。
///     移動先は要素ごとに snap で丸める（グリッド）。
///   - 選択した線の端点が結合している先が選択に入っていれば、端点も一緒に動く。
///     入っていなければ端点はその場に残り、線が伸びる。
///   - 選択に入っていない線は、動いたものに結合していれば追随する。
/// 要素を一つずつ動かして周りを追随させると、動かす順番によって線が二重に
/// 動いたり、線に結合した線へ伝わらなかったりする。ここでは全員を先に動かし、
/// 結合はあとから一度にアンカーへ合わせる。
pub fn move_selection(
  elements : Array[Element],
  ids : Array[String],
  dx : Double,
  dy : Double,
  snap? : (Double) -> Double = fn(v) { v },
) -> Array[Element] {
  // 要素ごとの移動量（選択した要素）
  let deltas : Map[String, (Double, Double)] = {}
  for e in elements {
    if ids.contains(e.id) {
      deltas[e.id] = (snap(e.x + dx) - e.x, snap(e.y + dy) - e.y)
    }
  }
  // 子要素は親と同じだけ動く
  for e in elements {
    match e.parent_id {
      Some(pid) =>
        match deltas.get(pid) {
          Some(d) => deltas[e.id] = d
          None => ()
        }
      None => ()
    }
  }
  let moved = elements.map(fn(e) {
    guard deltas.get(e.id) is Some((ex, ey)) else { return e }
    match e.shape {
      Line(x2, y2) =>
        { ..e, x: e.x + ex, y: e.y + ey, shape: Line(x2 + ex, y2 + ey), }
      _ => { ..e, x: e.x + ex, y: e.y + ey, }
    }
  })
  // 動いたものと、選択した線の結合先を起点に結合をアンカーへ合わせる。
  // 結合先が動いていなければ、選択した線の端点はそこへ戻る（線が伸びる）。
  let starts : Array[String] = []
  for e in moved {
    if deltas.contains(e.id) {
      starts.push(e.id)
    }
  }
  for e in moved {
    guard ids.contains(e.id) else { continue }
    guard e.connections is Some(conns) else { continue }
    for conn in [conns.start, conns.end] {
      match conn {
        Some(c) =>
          if !starts.contains(c.element_id) {
            starts.push(c.element_id)
          }
        None => ()
      }
    }
  }
  propagate_line_connections_bfs(moved, starts)
}
