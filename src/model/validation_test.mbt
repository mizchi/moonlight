// Validation モジュールのテスト
// ヘルパー関数は test_helpers.mbt を使用

// ============================================================
// 基本検証テスト
// ============================================================

///|
test "validate_elements: empty array is valid" {
  let elements : Array[Element] = []
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(result.issues.length(), content="0")
}

///|
test "validate_elements: valid single element" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(result.issues.length(), content="0")
}

///|
test "validate_elements: multiple valid elements" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    test_make_line("line1", 100.0, 50.0, 200.0, 50.0),
  ]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
}

// ============================================================
// ID 検証テスト
// ============================================================

///|
test "validate_elements: empty ID is error" {
  let elements = [test_make_rect("", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="false")
  inspect(
    test_count_issues_by_code(result.issues, issue_invalid_id),
    content="1",
  )
}

///|
test "validate_elements: duplicate ID is error" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    test_make_rect("rect1", 200.0, 0.0, 100.0, 100.0),
  ]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="false")
  // 両方の要素で重複が検出される
  inspect(
    test_count_issues_by_code(result.issues, issue_duplicate_id),
    content="2",
  )
}

// ============================================================
// 親子関係検証テスト
// ============================================================

///|
test "validate_elements: invalid parent is warning" {
  let rect = {
    ..test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    parent_id: Some("nonexistent"),
  }
  let elements = [rect]
  let result = validate_elements(elements)
  // 警告なので is_valid は true
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_invalid_parent),
    content="1",
  )
}

///|
test "validate_elements: valid parent relationship" {
  let parent = test_make_rect("parent", 0.0, 0.0, 200.0, 200.0)
  let child = {
    ..test_make_rect("child", 50.0, 50.0, 100.0, 100.0),
    parent_id: Some("parent"),
  }
  let elements = [parent, child]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_invalid_parent),
    content="0",
  )
}

///|
test "validate_elements: circular parent is error" {
  // rect1 -> rect2 -> rect1 (循環)
  let rect1 = {
    ..test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0),
    parent_id: Some("rect2"),
  }
  let rect2 = {
    ..test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0),
    parent_id: Some("rect1"),
  }
  let elements = [rect1, rect2]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="false")
  inspect(
    test_count_issues_by_code(result.issues, issue_circular_parent) > 0,
    content="true",
  )
}

// ============================================================
// 接続検証テスト
// ============================================================

///|
test "validate_elements: orphan connection is warning" {
  let line = test_make_connected_line(
    "line1",
    0.0,
    0.0,
    100.0,
    100.0,
    Some({ element_id: "nonexistent", anchor: Right }),
    None,
  )
  let elements = [line]
  let result = validate_elements(elements)
  // 警告なので is_valid は true
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_orphan_connection),
    content="1",
  )
}

///|
test "validate_elements: valid connection" {
  let rect = test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)
  let line = test_make_connected_line(
    "line1",
    100.0,
    50.0,
    200.0,
    50.0,
    Some({ element_id: "rect1", anchor: Right }),
    None,
  )
  let elements = [rect, line]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_orphan_connection),
    content="0",
  )
}

///|
test "validate_elements: self connection is warning" {
  let rect = test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)
  let line = test_make_connected_line(
    "line1",
    100.0,
    50.0,
    0.0,
    50.0,
    Some({ element_id: "rect1", anchor: Right }),
    Some({ element_id: "rect1", anchor: Left }),
  )
  let elements = [rect, line]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_self_connection),
    content="1",
  )
}

// ============================================================
// 形状固有検証テスト
// ============================================================

///|
test "validate_elements: negative rect dimension is error" {
  let rect = Element::new("rect1", 0.0, 0.0, Rect(-100.0, 100.0, None, None))
  let elements = [rect]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="false")
  inspect(
    test_count_issues_by_code(result.issues, issue_negative_dimension),
    content="1",
  )
}

///|
test "validate_elements: negative circle radius is error" {
  let circle = Element::new("circle1", 0.0, 0.0, Circle(-50.0))
  let elements = [circle]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="false")
  inspect(
    test_count_issues_by_code(result.issues, issue_negative_dimension),
    content="1",
  )
}

///|
test "validate_elements: line same points is warning" {
  let line = Element::new("line1", 100.0, 100.0, Line(100.0, 100.0))
  let elements = [line]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_line_same_points),
    content="1",
  )
}

///|
test "validate_elements: empty text is info" {
  let text = test_make_text("text1", 0.0, 0.0, "")
  let elements = [text]
  let result = validate_elements(elements)
  inspect(result.is_valid, content="true")
  inspect(
    test_count_issues_by_code(result.issues, issue_text_empty),
    content="1",
  )
}

// ============================================================
// 操作権限テスト
// ============================================================

///|
test "capability: full for valid element" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  let cap = get_element_capability(result, "rect1")
  inspect(cap.can_move, content="true")
  inspect(cap.can_resize, content="true")
  inspect(cap.can_edit, content="true")
  inspect(cap.can_delete, content="true")
  inspect(cap.can_add_child, content="true")
}

///|
test "capability: move and delete only for error element" {
  // 空のID（エラー）- 問題のある要素は削除可能にする
  let elements = [test_make_rect("", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  let cap = get_element_capability(result, "")
  inspect(cap.can_move, content="true")
  inspect(cap.can_resize, content="false")
  inspect(cap.can_edit, content="false")
  inspect(cap.can_delete, content="true") // エラー要素でも削除は可能
}

///|
test "capability: line cannot add child" {
  let elements = [test_make_line("line1", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  let cap = get_element_capability(result, "line1")
  inspect(cap.can_add_child, content="false")
  inspect(cap.can_connect, content="true")
}

///|
test "capability: text cannot connect" {
  let elements = [test_make_text("text1", 0.0, 0.0, "Hello")]
  let result = validate_elements(elements)
  let cap = get_element_capability(result, "text1")
  inspect(cap.can_connect, content="false")
  inspect(cap.can_add_child, content="false")
}

// ============================================================
// ヘルパー関数テスト
// ============================================================

///|
test "is_element_operable: true for valid" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  inspect(is_element_operable(result, "rect1"), content="true")
}

///|
test "is_element_operable: true for move only" {
  let elements = [test_make_rect("", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  inspect(is_element_operable(result, ""), content="true")
}

///|
test "is_element_operable: false for nonexistent" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let result = validate_elements(elements)
  inspect(is_element_operable(result, "nonexistent"), content="false")
}

///|
test "get_element_issues: returns only matching" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, -100.0, 100.0), // エラー
    test_make_rect("rect2", 0.0, 0.0, 100.0, 100.0), // 正常
  ]
  let result = validate_elements(elements)
  let issues1 = get_element_issues(result, "rect1")
  let issues2 = get_element_issues(result, "rect2")
  inspect(issues1.length() > 0, content="true")
  inspect(issues2.length(), content="0")
}

///|
test "get_errors: filters errors only" {
  let elements = [
    test_make_rect("rect1", 0.0, 0.0, -100.0, 100.0), // Error
    test_make_text("text1", 0.0, 0.0, ""), // Info
  ]
  let result = validate_elements(elements)
  let errors = get_errors(result)
  let all_are_errors = errors.iter().all(fn(e) { e.level == Error })
  inspect(all_are_errors, content="true")
}

// ============================================================
// 増分検証テスト
// ============================================================

///|
test "can_add_element: success for new element" {
  let existing = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let new_el = test_make_rect("rect2", 200.0, 0.0, 100.0, 100.0)
  let (can_add, issues) = can_add_element(new_el, existing)
  inspect(can_add, content="true")
  inspect(issues.length(), content="0")
}

///|
test "can_add_element: fail for duplicate id" {
  let existing = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let new_el = test_make_rect("rect1", 200.0, 0.0, 100.0, 100.0)
  let (can_add, issues) = can_add_element(new_el, existing)
  inspect(can_add, content="false")
  inspect(test_count_issues_by_code(issues, issue_duplicate_id), content="1")
}

///|
test "can_delete_element: success with no dependencies" {
  let elements = [test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)]
  let (can_delete, issues) = can_delete_element("rect1", elements)
  inspect(can_delete, content="true")
  inspect(issues.length(), content="0")
}

///|
test "can_delete_element: warning with children" {
  let parent = test_make_rect("parent", 0.0, 0.0, 200.0, 200.0)
  let child = {
    ..test_make_rect("child", 50.0, 50.0, 100.0, 100.0),
    parent_id: Some("parent"),
  }
  let elements = [parent, child]
  let (can_delete, issues) = can_delete_element("parent", elements)
  // 警告だが削除可能
  inspect(can_delete, content="true")
  inspect(issues.length() > 0, content="true")
}

///|
test "can_delete_element: warning with connections" {
  let rect = test_make_rect("rect1", 0.0, 0.0, 100.0, 100.0)
  let line = test_make_connected_line(
    "line1",
    100.0,
    50.0,
    200.0,
    50.0,
    Some({ element_id: "rect1", anchor: Right }),
    None,
  )
  let elements = [rect, line]
  let (can_delete, issues) = can_delete_element("rect1", elements)
  inspect(can_delete, content="true")
  inspect(issues.length() > 0, content="true")
}

// ============================================================
// 修復提案テスト
// ============================================================

///|
test "suggest_repairs: orphan connection" {
  let issues : Array[ValidationIssue] = [
    {
      level: Warning,
      element_id: Some("line1"),
      code: issue_orphan_connection,
      message: "test",
    },
  ]
  let repairs = suggest_repairs(issues)
  inspect(repairs.length(), content="1")
  match repairs[0] {
    RemoveConnection(id, _) => inspect(id, content="line1")
    _ => inspect("wrong action", content="")
  }
}

///|
test "suggest_repairs: invalid parent" {
  let issues : Array[ValidationIssue] = [
    {
      level: Warning,
      element_id: Some("child1"),
      code: issue_invalid_parent,
      message: "test",
    },
  ]
  let repairs = suggest_repairs(issues)
  inspect(repairs.length(), content="1")
  match repairs[0] {
    RemoveParent(id) => inspect(id, content="child1")
    _ => inspect("wrong action", content="")
  }
}

///|
test "suggest_repairs: duplicate id" {
  let issues : Array[ValidationIssue] = [
    {
      level: Error,
      element_id: Some("dup1"),
      code: issue_duplicate_id,
      message: "test",
    },
  ]
  let repairs = suggest_repairs(issues)
  inspect(repairs.length(), content="1")
  match repairs[0] {
    RegenerateId(old_id, new_id) => {
      inspect(old_id, content="dup1")
      inspect(new_id, content="dup1_copy")
    }
    _ => inspect("wrong action", content="")
  }
}
