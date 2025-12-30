// テスト用ヘルパー関数
// topology_test.mbt と validation_test.mbt で共有

///|
pub fn test_make_rect(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Element {
  Element::new(id, x, y, Rect(w, h, None, None))
}

///|
pub fn test_make_circle(
  id : String,
  x : Double,
  y : Double,
  r : Double,
) -> Element {
  Element::new(id, x, y, Circle(r))
}

///|
pub fn test_make_line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Element {
  { ..Element::new(id, x1, y1, Line(x2, y2)), connections: None }
}

///|
pub fn test_make_connected_line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  start_conn : Connection?,
  end_conn : Connection?,
) -> Element {
  {
    ..Element::new(id, x1, y1, Line(x2, y2)),
    connections: Some({ start: start_conn, end: end_conn }),
  }
}

///|
pub fn test_make_text(
  id : String,
  x : Double,
  y : Double,
  content : String,
) -> Element {
  Element::new(id, x, y, Text(content, None))
}

///|
pub fn test_count_issues_by_code(
  issues : Array[ValidationIssue],
  code : String,
) -> Int {
  issues.iter().filter(fn(i) { i.code == code }).count()
}
