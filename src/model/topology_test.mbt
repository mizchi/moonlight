// Topology モジュールのテスト
// ヘルパー関数は test_helpers.mbt を使用

// ============================================================
// グラフ構築テスト
// ============================================================

///|
test "build_connection_graph: empty elements" {
  let elements : Array[Element] = []
  let graph = build_connection_graph(elements)
  inspect(graph.edges.length(), content="0")
  inspect(graph.adjacency.length(), content="0")
}

///|
test "build_connection_graph: no connections" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_line("line1", 100.0, 50.0, 200.0, 50.0),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.edges.length(), content="0")
}

///|
test "build_connection_graph: single connection" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.edges.length(), content="1")
  inspect(graph.adjacency.length(), content="2")
}

///|
test "build_connection_graph: multiple connections" {
  // rect1 -- line1 -- rect2 -- line2 -- rect3
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 400.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      50.0,
      400.0,
      50.0,
      Some({ element_id: "rect2", anchor: Right }),
      Some({ element_id: "rect3", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.edges.length(), content="2")
}

// ============================================================
// 接続検出テスト
// ============================================================

///|
test "get_neighbors: connected nodes" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let neighbors = graph.get_neighbors("rect1")
  inspect(neighbors.length(), content="1")
  inspect(neighbors[0], content="rect2")
}

///|
test "get_neighbors: no connections" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let graph = build_connection_graph(elements)
  let neighbors = graph.get_neighbors("rect1")
  inspect(neighbors.length(), content="0")
}

///|
test "are_directly_connected: true" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.are_directly_connected("rect1", "rect2"), content="true")
  inspect(graph.are_directly_connected("rect2", "rect1"), content="true")
}

///|
test "are_directly_connected: false" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.are_directly_connected("rect1", "rect2"), content="false")
}

///|
test "get_connected_lines" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let lines = graph.get_connected_lines("rect1")
  inspect(lines.length(), content="1")
  inspect(lines[0], content="line1")
}

// ============================================================
// 連結成分テスト
// ============================================================

///|
test "get_connected_component: single component" {
  // rect1 -- rect2 -- rect3
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 400.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      50.0,
      400.0,
      50.0,
      Some({ element_id: "rect2", anchor: Right }),
      Some({ element_id: "rect3", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let component = graph.get_connected_component("rect1")
  inspect(component.length(), content="3")
  inspect(component.contains("rect1"), content="true")
  inspect(component.contains("rect2"), content="true")
  inspect(component.contains("rect3"), content="true")
}

///|
test "get_all_components: two components" {
  // rect1 -- rect2    rect3 -- rect4
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 0.0, 200.0, 100.0, 100.0),
    test_make_rect("rect4", 200.0, 200.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      100.0,
      250.0,
      200.0,
      250.0,
      Some({ element_id: "rect3", anchor: Right }),
      Some({ element_id: "rect4", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let components = graph.get_all_components()
  inspect(components.length(), content="2")
}

// ============================================================
// 接続距離テスト
// ============================================================

///|
test "connection_distance: same node" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let graph = build_connection_graph(elements)
  inspect(graph.connection_distance("rect1", "rect1"), content="0")
}

///|
test "connection_distance: directly connected" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.connection_distance("rect1", "rect2"), content="1")
}

///|
test "connection_distance: two hops" {
  // rect1 -- rect2 -- rect3
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 400.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      50.0,
      400.0,
      50.0,
      Some({ element_id: "rect2", anchor: Right }),
      Some({ element_id: "rect3", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.connection_distance("rect1", "rect3"), content="2")
}

///|
test "connection_distance: not connected" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.connection_distance("rect1", "rect2"), content="-1")
}

///|
test "distance_map_from" {
  // rect1 -- rect2 -- rect3
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 400.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      50.0,
      400.0,
      50.0,
      Some({ element_id: "rect2", anchor: Right }),
      Some({ element_id: "rect3", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let dist_map = graph.distance_map_from("rect1")
  inspect(dist_map.get("rect1"), content="Some(0)")
  inspect(dist_map.get("rect2"), content="Some(1)")
  inspect(dist_map.get("rect3"), content="Some(2)")
}

// ============================================================
// パス探索テスト
// ============================================================

///|
test "find_shortest_path: same node" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let graph = build_connection_graph(elements)
  let path = graph.find_shortest_path("rect1", "rect1", elements)
  inspect(path is Some(_), content="true")
  match path {
    Some(p) => {
      inspect(p.nodes.length(), content="1")
      inspect(p.edges.length(), content="0")
    }
    None => inspect("should not be None", content="")
  }
}

///|
test "find_shortest_path: direct connection" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let path = graph.find_shortest_path("rect1", "rect2", elements)
  match path {
    Some(p) => {
      inspect(p.nodes.length(), content="2")
      inspect(p.nodes[0], content="rect1")
      inspect(p.nodes[1], content="rect2")
    }
    None => inspect("should not be None", content="")
  }
}

///|
test "find_shortest_path: no path" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
  ]
  let graph = build_connection_graph(elements)
  let path = graph.find_shortest_path("rect1", "rect2", elements)
  inspect(path is None, content="true")
}

// ============================================================
// トポロジー分類テスト
// ============================================================

///|
test "is_hub: true for 3+ connections" {
  // rect1, rect2, rect3 all connected to center
  let elements = [
    test_make_rect("center", 200.0, 200.0, 100.0, 100.0),
    test_make_rect("rect1", 0.0, 200.0, 100.0, 100.0),
    test_make_rect("rect2", 400.0, 200.0, 100.0, 100.0),
    test_make_rect("rect3", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      250.0,
      200.0,
      250.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "center", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      250.0,
      400.0,
      250.0,
      Some({ element_id: "center", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line3",
      250.0,
      100.0,
      250.0,
      200.0,
      Some({ element_id: "rect3", anchor: Bottom }),
      Some({ element_id: "center", anchor: Top }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.is_hub("center"), content="true")
  inspect(graph.is_leaf("rect1"), content="true")
}

///|
test "is_isolated: no connections" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let graph = build_connection_graph(elements)
  inspect(graph.is_isolated("rect1"), content="true")
}

// ============================================================
// サイクル検出テスト
// ============================================================

///|
test "has_cycle: linear graph" {
  // rect1 -- rect2 -- rect3 (no cycle)
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 400.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      50.0,
      400.0,
      50.0,
      Some({ element_id: "rect2", anchor: Right }),
      Some({ element_id: "rect3", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.has_cycle(), content="false")
}

///|
test "has_cycle: triangle" {
  // rect1 -- rect2
  //   \      /
  //    rect3
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 100.0, 200.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      250.0,
      100.0,
      200.0,
      200.0,
      Some({ element_id: "rect2", anchor: Bottom }),
      Some({ element_id: "rect3", anchor: TopRight }),
    ),
    test_make_connected_line(
      "line3",
      50.0,
      100.0,
      100.0,
      200.0,
      Some({ element_id: "rect1", anchor: Bottom }),
      Some({ element_id: "rect3", anchor: TopLeft }),
    ),
  ]
  let graph = build_connection_graph(elements)
  inspect(graph.has_cycle(), content="true")
}

// ============================================================
// 部分移動時の再計算テスト
// ============================================================

///|
test "recalculate_on_partial_move: line update" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]

  // rect1 を (0, 100) に移動
  let moved_targets : Array[@model.MoveTarget] = [
    { id: "rect1", new_x: 0.0, new_y: 100.0 },
  ]
  let result = recalculate_on_partial_move(moved_targets, elements)

  // line1 の始点が更新されるはず
  inspect(result.line_updates.length(), content="1")
  match result.line_updates.iter().find_first(fn(l) { l.id == "line1" }) {
    Some(update) => {
      // 新しい始点は rect1 の Right アンカー (100, 150)
      inspect(update.x, content="100")
      inspect(update.y, content="150")
    }
    None => inspect("line1 should be updated", content="")
  }
}

///|
test "recalculate_on_partial_move: child element update" {
  let rect1 = test_make_rect("rect1", 100.0, 100.0, 100.0, 100.0)
  let text1 = {
    ..test_make_rect("text1", 150.0, 150.0, 50.0, 20.0),
    parent_id: Some("rect1"),
  }
  let elements = [rect1, text1]

  // rect1 を (200, 200) に移動
  let moved_targets : Array[@model.MoveTarget] = [
    { id: "rect1", new_x: 200.0, new_y: 200.0 },
  ]
  let result = recalculate_on_partial_move(moved_targets, elements)

  // text1 (子要素) も移動
  inspect(result.element_updates.length(), content="1")
  match result.element_updates.iter().find_first(fn(e) { e.id == "text1" }) {
    Some(update) => {
      // dx=100, dy=100 なので text1 は (250, 250)
      inspect(update.new_x, content="250")
      inspect(update.new_y, content="250")
    }
    None => inspect("text1 should be updated", content="")
  }
}

// ============================================================
// グラフ統計テスト
// ============================================================

///|
test "get_stats" {
  // center is hub (3 connections), rect1-3 are leaves
  let elements = [
    test_make_rect("center", 200.0, 200.0, 100.0, 100.0),
    test_make_rect("rect1", 0.0, 200.0, 100.0, 100.0),
    test_make_rect("rect2", 400.0, 200.0, 100.0, 100.0),
    test_make_rect("rect3", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("isolated", 500.0, 500.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      250.0,
      200.0,
      250.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "center", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      300.0,
      250.0,
      400.0,
      250.0,
      Some({ element_id: "center", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line3",
      250.0,
      100.0,
      250.0,
      200.0,
      Some({ element_id: "rect3", anchor: Bottom }),
      Some({ element_id: "center", anchor: Top }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let all_ids = ["center", "rect1", "rect2", "rect3", "isolated"]
  let stats = graph.get_stats(all_ids)
  inspect(stats.edge_count, content="3")
  inspect(stats.hub_count, content="1")
  inspect(stats.leaf_count, content="3")
  inspect(stats.isolated_count, content="1")
}

// ============================================================
// find_all_paths テスト
// ============================================================

///|
test "find_all_paths: single path" {
  // rect1 -- rect2
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let paths = graph.find_all_paths("rect1", "rect2", elements, 10)
  inspect(paths.length(), content="1")
}

///|
test "find_all_paths: multiple paths" {
  // rect1 -- rect2
  //   \      /
  //    rect3
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_rect("rect3", 100.0, 200.0, 100.0, 100.0),
    test_make_connected_line(
      "line1",
      100.0,
      50.0,
      200.0,
      50.0,
      Some({ element_id: "rect1", anchor: Right }),
      Some({ element_id: "rect2", anchor: Left }),
    ),
    test_make_connected_line(
      "line2",
      250.0,
      100.0,
      200.0,
      200.0,
      Some({ element_id: "rect2", anchor: Bottom }),
      Some({ element_id: "rect3", anchor: TopRight }),
    ),
    test_make_connected_line(
      "line3",
      50.0,
      100.0,
      100.0,
      200.0,
      Some({ element_id: "rect1", anchor: Bottom }),
      Some({ element_id: "rect3", anchor: TopLeft }),
    ),
  ]
  let graph = build_connection_graph(elements)
  let paths = graph.find_all_paths("rect1", "rect2", elements, 10)
  // Direct path: rect1 -> rect2
  // Indirect path: rect1 -> rect3 -> rect2
  inspect(paths.length(), content="2")
}
