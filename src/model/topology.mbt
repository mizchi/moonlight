// Moonlight - トポロジー解析
// 要素間の接続グラフ構築・パス探索・接続距離計算

// ============================================================
// グラフ構造
// ============================================================

///|
/// グラフのエッジ（接続）
pub(all) struct Edge {
  from_id : String // 接続元要素 ID
  to_id : String // 接続先要素 ID
  line_id : String // この接続を表す Line 要素の ID
  from_anchor : Anchor // 接続元のアンカー
  to_anchor : Anchor // 接続先のアンカー
} derive(Show, Eq)

///|
/// 接続グラフ（隣接リスト形式）
pub(all) struct ConnectionGraph {
  // element_id -> 接続しているエッジのリスト
  adjacency : Map[String, Array[Edge]]
  // 全エッジリスト
  edges : Array[Edge]
  // Line 要素 ID -> その Line が表すエッジ
  line_to_edge : Map[String, Edge]
} derive(Show)

///|
/// 空のグラフを作成
pub fn ConnectionGraph::new() -> ConnectionGraph {
  { adjacency: {}, edges: [], line_to_edge: {} }
}

///|
/// 要素配列からグラフを構築
pub fn build_connection_graph(elements : Array[Element]) -> ConnectionGraph {
  let graph = ConnectionGraph::new()
  for el in elements {
    // Line または Path 要素のみ処理
    let is_connectable = match el.shape {
      Line(_, _) => true
      Path(_, _, _, _, _) => true
      _ => false
    }
    guard is_connectable else { continue }
    guard el.connections is Some(conns) else { continue }

    // 始点と終点の両方に接続がある場合、エッジを作成
    match (conns.start, conns.end) {
      (Some(start_conn), Some(end_conn)) => {
        // 双方向のエッジを作成
        let edge1 : Edge = {
          from_id: start_conn.element_id,
          to_id: end_conn.element_id,
          line_id: el.id,
          from_anchor: start_conn.anchor,
          to_anchor: end_conn.anchor,
        }
        let edge2 : Edge = {
          from_id: end_conn.element_id,
          to_id: start_conn.element_id,
          line_id: el.id,
          from_anchor: end_conn.anchor,
          to_anchor: start_conn.anchor,
        }

        // 隣接リストに追加
        add_edge_to_adjacency(graph.adjacency, edge1)
        add_edge_to_adjacency(graph.adjacency, edge2)

        // エッジリストに追加（一方向のみ）
        graph.edges.push(edge1)

        // Line ID -> Edge マッピング
        graph.line_to_edge[el.id] = edge1
      }
      _ => ()
    }
  }
  graph
}

///|
fn add_edge_to_adjacency(
  adjacency : Map[String, Array[Edge]],
  edge : Edge,
) -> Unit {
  match adjacency.get(edge.from_id) {
    Some(edges) => edges.push(edge)
    None => adjacency[edge.from_id] = [edge]
  }
}

// ============================================================
// 接続検出
// ============================================================

///|
/// 指定要素に直接接続している要素の ID リストを取得
pub fn ConnectionGraph::get_neighbors(
  self : ConnectionGraph,
  element_id : String,
) -> Array[String] {
  match self.adjacency.get(element_id) {
    Some(edges) => {
      let ids : Array[String] = []
      for edge in edges {
        if not(ids.contains(edge.to_id)) {
          ids.push(edge.to_id)
        }
      }
      ids
    }
    None => []
  }
}

///|
/// 2つの要素が直接接続されているか判定
pub fn ConnectionGraph::are_directly_connected(
  self : ConnectionGraph,
  id1 : String,
  id2 : String,
) -> Bool {
  self.get_neighbors(id1).contains(id2)
}

///|
/// 指定要素に接続している全ての Line ID を取得
pub fn ConnectionGraph::get_connected_lines(
  self : ConnectionGraph,
  element_id : String,
) -> Array[String] {
  match self.adjacency.get(element_id) {
    Some(edges) => {
      let line_ids : Array[String] = []
      for edge in edges {
        if not(line_ids.contains(edge.line_id)) {
          line_ids.push(edge.line_id)
        }
      }
      line_ids
    }
    None => []
  }
}

///|
/// 連結成分を検出（同じグループに属する要素を取得）
pub fn ConnectionGraph::get_connected_component(
  self : ConnectionGraph,
  start_id : String,
) -> Array[String] {
  let visited : Array[String] = []
  let queue : Array[String] = [start_id]
  while queue.length() > 0 {
    let current = queue.remove(0)
    if visited.contains(current) {
      continue
    }
    visited.push(current)
    for neighbor in self.get_neighbors(current) {
      if not(visited.contains(neighbor)) {
        queue.push(neighbor)
      }
    }
  }
  visited
}

///|
/// グラフ内の全ての連結成分を取得
pub fn ConnectionGraph::get_all_components(
  self : ConnectionGraph,
) -> Array[Array[String]] {
  let components : Array[Array[String]] = []
  let visited : Array[String] = []
  for node_id in self.adjacency.keys() {
    if not(visited.contains(node_id)) {
      let component = self.get_connected_component(node_id)
      for id in component {
        if not(visited.contains(id)) {
          visited.push(id)
        }
      }
      components.push(component)
    }
  }
  components
}

// ============================================================
// パス探索（BFS）
// ============================================================

///|
/// パス（経路）情報
pub(all) struct Path {
  nodes : Array[String] // 経路上のノード ID（開始から終了まで）
  edges : Array[Edge] // 経路上のエッジ
  total_distance : Double // 合計距離
} derive(Show, Eq)

///|
/// 2点間の最短パスを探索（BFS）
/// 見つからない場合は None
pub fn ConnectionGraph::find_shortest_path(
  self : ConnectionGraph,
  from_id : String,
  to_id : String,
  elements : Array[Element],
) -> Path? {
  if from_id == to_id {
    return Some({ nodes: [from_id], edges: [], total_distance: 0.0 })
  }

  // BFS で探索
  // 各ノードへの親情報を記録
  let parent : Map[String, (String, Edge)] = {} // node_id -> (parent_id, edge)
  let visited : Array[String] = []
  let queue : Array[String] = [from_id]
  visited.push(from_id)
  while queue.length() > 0 {
    let current = queue.remove(0)
    if current == to_id {
      // パスが見つかった - 経路を再構築
      return Some(reconstruct_path(from_id, to_id, parent, elements))
    }
    match self.adjacency.get(current) {
      Some(edges) =>
        for edge in edges {
          if not(visited.contains(edge.to_id)) {
            visited.push(edge.to_id)
            parent[edge.to_id] = (current, edge)
            queue.push(edge.to_id)
          }
        }
      None => ()
    }
  }
  None // パスが見つからない
}

///|
fn reconstruct_path(
  from_id : String,
  to_id : String,
  parent : Map[String, (String, Edge)],
  elements : Array[Element],
) -> Path {
  let nodes : Array[String] = []
  let edges : Array[Edge] = []
  let mut current = to_id

  // to_id から from_id まで逆順にたどる
  while current != from_id {
    nodes.push(current)
    match parent.get(current) {
      Some((prev, edge)) => {
        edges.push(edge)
        current = prev
      }
      None => break
    }
  }
  nodes.push(from_id)

  // 逆順にする
  nodes.rev_in_place()
  edges.rev_in_place()

  // 距離を計算
  let total_distance = calc_path_distance(nodes, elements)
  { nodes, edges, total_distance }
}

///|
/// パスの合計距離を計算（ユークリッド距離）
fn calc_path_distance(
  node_ids : Array[String],
  elements : Array[Element],
) -> Double {
  if node_ids.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  for i = 0; i < node_ids.length() - 1; i = i + 1 {
    let p1 = get_element_center(elements, node_ids[i])
    let p2 = get_element_center(elements, node_ids[i + 1])
    match (p1, p2) {
      (Some(c1), Some(c2)) => {
        let dx = c2.x - c1.x
        let dy = c2.y - c1.y
        total = total + (dx * dx + dy * dy).sqrt()
      }
      _ => ()
    }
  }
  total
}

///|
fn get_element_center(elements : Array[Element], id : String) -> Point? {
  for el in elements {
    if el.id == id {
      let bbox = el.bounding_box()
      return Some({
        x: bbox.x + bbox.width / 2.0,
        y: bbox.y + bbox.height / 2.0,
      })
    }
  }
  None
}

// ============================================================
// 接続距離
// ============================================================

///|
/// 2点間の接続距離（エッジ数）
/// 接続されていない場合は -1
pub fn ConnectionGraph::connection_distance(
  self : ConnectionGraph,
  from_id : String,
  to_id : String,
) -> Int {
  if from_id == to_id {
    return 0
  }

  // BFS でホップ数をカウント
  let distance : Map[String, Int] = {}
  distance[from_id] = 0
  let queue : Array[String] = [from_id]
  while queue.length() > 0 {
    let current = queue.remove(0)
    let current_dist = distance.get(current).unwrap_or(0)
    if current == to_id {
      return current_dist
    }
    for neighbor in self.get_neighbors(current) {
      if distance.get(neighbor) is None {
        distance[neighbor] = current_dist + 1
        queue.push(neighbor)
      }
    }
  }
  -1 // 接続されていない
}

///|
/// 指定要素から各要素への接続距離マップを取得
pub fn ConnectionGraph::distance_map_from(
  self : ConnectionGraph,
  start_id : String,
) -> Map[String, Int] {
  let distances : Map[String, Int] = {}
  distances[start_id] = 0
  let queue : Array[String] = [start_id]
  while queue.length() > 0 {
    let current = queue.remove(0)
    let current_dist = distances.get(current).unwrap_or(0)
    for neighbor in self.get_neighbors(current) {
      if distances.get(neighbor) is None {
        distances[neighbor] = current_dist + 1
        queue.push(neighbor)
      }
    }
  }
  distances
}

// ============================================================
// 部分移動時の再計算
// ============================================================

///|
/// 移動対象の情報
pub(all) struct MoveTarget {
  id : String
  new_x : Double
  new_y : Double
} derive(Show, Eq)

///|
/// 再計算結果
pub(all) struct RecalculationResult {
  // 更新が必要な要素の新座標
  element_updates : Array[MoveTarget]
  // 更新が必要な Line の新座標
  line_updates : Array[LineCoords]
} derive(Show, Eq)

///|
/// 部分移動時の全体再計算
/// moved_targets: 移動した要素のリスト
/// elements: 全要素
/// 戻り値: 接続されている他の要素・ラインの更新情報
pub fn recalculate_on_partial_move(
  moved_targets : Array[MoveTarget],
  elements : Array[Element],
) -> RecalculationResult {
  let element_updates : Array[MoveTarget] = []
  let line_updates : Array[LineCoords] = []

  // 移動した要素の ID セット
  let moved_ids : Array[String] = moved_targets.map(fn(t) { t.id })

  // 移動後の座標マップを作成
  let new_positions : Map[String, (Double, Double)] = {}
  for target in moved_targets {
    new_positions[target.id] = (target.new_x, target.new_y)
  }

  // 仮想的な更新後要素を作成
  let updated_elements = elements.map(fn(el) {
    match new_positions.get(el.id) {
      Some((nx, ny)) => { ..el, x: nx, y: ny }
      None => el
    }
  })

  // 各 Line 要素を確認
  for el in elements {
    guard el.shape is Line(x2, y2) else { continue }
    guard el.connections is Some(conns) else { continue }

    // この Line 自体が移動対象の場合はスキップ
    if moved_ids.contains(el.id) {
      continue
    }
    let mut new_x = el.x
    let mut new_y = el.y
    let mut new_x2 = x2
    let mut new_y2 = y2
    let mut needs_update = false

    // 始点の接続先が移動した場合
    match conns.start {
      Some(conn) if moved_ids.contains(conn.element_id) =>
        // 更新後の要素からアンカー位置を取得
        for updated_el in updated_elements {
          if updated_el.id == conn.element_id {
            let p = updated_el.get_anchor_point(conn.anchor)
            new_x = p.x
            new_y = p.y
            needs_update = true
            break
          }
        }
      _ => ()
    }

    // 終点の接続先が移動した場合
    match conns.end {
      Some(conn) if moved_ids.contains(conn.element_id) =>
        for updated_el in updated_elements {
          if updated_el.id == conn.element_id {
            let p = updated_el.get_anchor_point(conn.anchor)
            new_x2 = p.x
            new_y2 = p.y
            needs_update = true
            break
          }
        }
      _ => ()
    }
    if needs_update {
      line_updates.push({
        id: el.id,
        x: new_x,
        y: new_y,
        x2: new_x2,
        y2: new_y2,
      })
    }
  }

  // 子要素の更新（parent_id が移動対象の場合）
  for el in elements {
    guard el.parent_id is Some(parent_id) else { continue }

    // 親が移動対象の場合
    if moved_ids.contains(parent_id) {
      // 親の移動差分を計算
      let mut dx = 0.0
      let mut dy = 0.0
      for old_el in elements {
        if old_el.id == parent_id {
          match new_positions.get(parent_id) {
            Some((nx, ny)) => {
              dx = nx - old_el.x
              dy = ny - old_el.y
            }
            None => ()
          }
          break
        }
      }

      // 子要素自体が移動対象でない場合のみ更新
      if not(moved_ids.contains(el.id)) {
        element_updates.push({ id: el.id, new_x: el.x + dx, new_y: el.y + dy })
      }
    }
  }
  { element_updates, line_updates }
}

// ============================================================
// トポロジー解析ユーティリティ
// ============================================================

///|
/// 要素が「ハブ」（3つ以上の接続を持つ）かどうか判定
pub fn ConnectionGraph::is_hub(
  self : ConnectionGraph,
  element_id : String,
) -> Bool {
  self.get_neighbors(element_id).length() >= 3
}

///|
/// 要素が「リーフ」（1つの接続のみ持つ）かどうか判定
pub fn ConnectionGraph::is_leaf(
  self : ConnectionGraph,
  element_id : String,
) -> Bool {
  self.get_neighbors(element_id).length() == 1
}

///|
/// 要素が「孤立」（接続なし）かどうか判定
pub fn ConnectionGraph::is_isolated(
  self : ConnectionGraph,
  element_id : String,
) -> Bool {
  self.get_neighbors(element_id).length() == 0
}

///|
/// グラフの統計情報
pub(all) struct GraphStats {
  node_count : Int // ノード数
  edge_count : Int // エッジ数（Line の数）
  component_count : Int // 連結成分数
  hub_count : Int // ハブノード数
  leaf_count : Int // リーフノード数
  isolated_count : Int // 孤立ノード数
} derive(Show, Eq)

///|
/// グラフの統計を取得
pub fn ConnectionGraph::get_stats(
  self : ConnectionGraph,
  all_element_ids : Array[String],
) -> GraphStats {
  let mut hub_count = 0
  let mut leaf_count = 0
  let mut isolated_count = 0
  for id in all_element_ids {
    let neighbor_count = self.get_neighbors(id).length()
    if neighbor_count >= 3 {
      hub_count = hub_count + 1
    } else if neighbor_count == 1 {
      leaf_count = leaf_count + 1
    } else if neighbor_count == 0 {
      isolated_count = isolated_count + 1
    }
  }
  {
    node_count: self.adjacency.length(),
    edge_count: self.edges.length(),
    component_count: self.get_all_components().length(),
    hub_count,
    leaf_count,
    isolated_count,
  }
}

///|
/// 循環（サイクル）検出
/// グラフに循環がある場合 true
pub fn ConnectionGraph::has_cycle(self : ConnectionGraph) -> Bool {
  let visited : Array[String] = []
  for start_id in self.adjacency.keys() {
    if visited.contains(start_id) {
      continue
    }

    // DFS でサイクル検出
    let stack : Array[(String, String?)] = [(start_id, None)] // (node, parent)
    while stack.length() > 0 {
      let (current, parent) = stack.unsafe_pop()
      if visited.contains(current) {
        return true // サイクル検出
      }
      visited.push(current)
      for neighbor in self.get_neighbors(current) {
        // 親ノードへの戻りは無視
        match parent {
          Some(p) if p == neighbor => continue
          _ => ()
        }
        if not(visited.contains(neighbor)) {
          stack.push((neighbor, Some(current)))
        } else {
          return true // サイクル検出
        }
      }
    }
  }
  false
}

///|
/// 2点間の全パスを探索（制限付き）
/// max_paths: 最大パス数
pub fn ConnectionGraph::find_all_paths(
  self : ConnectionGraph,
  from_id : String,
  to_id : String,
  elements : Array[Element],
  max_paths : Int,
) -> Array[Path] {
  let paths : Array[Path] = []
  if from_id == to_id {
    paths.push({ nodes: [from_id], edges: [], total_distance: 0.0 })
    return paths
  }

  // DFS で全パス探索
  fn dfs(
    current : String,
    target : String,
    visited : Array[String],
    current_nodes : Array[String],
    current_edges : Array[Edge],
    graph : ConnectionGraph,
    elements : Array[Element],
    paths : Array[Path],
    max_paths : Int,
  ) -> Unit {
    if paths.length() >= max_paths {
      return
    }
    if current == target {
      let total_distance = calc_path_distance(current_nodes, elements)
      paths.push({
        nodes: current_nodes.copy(),
        edges: current_edges.copy(),
        total_distance,
      })
      return
    }
    match graph.adjacency.get(current) {
      Some(edges) =>
        for edge in edges {
          if not(visited.contains(edge.to_id)) {
            visited.push(edge.to_id)
            current_nodes.push(edge.to_id)
            current_edges.push(edge)
            dfs(
              edge.to_id,
              target,
              visited,
              current_nodes,
              current_edges,
              graph,
              elements,
              paths,
              max_paths,
            )
            ignore(visited.pop())
            ignore(current_nodes.pop())
            ignore(current_edges.pop())
          }
        }
      None => ()
    }
  }

  let visited : Array[String] = [from_id]
  let current_nodes : Array[String] = [from_id]
  let current_edges : Array[Edge] = []
  dfs(
    from_id, to_id, visited, current_nodes, current_edges, self, elements, paths,
    max_paths,
  )
  paths
}
