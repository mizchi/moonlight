// Command パターンのユニットテスト

// ============================================================
// History のテスト
// ============================================================

///|
test "History::new - creates empty stacks" {
  let history = History::new()
  assert_eq(history.undo_stack.length(), 0)
  assert_eq(history.redo_stack.length(), 0)
}

///|
test "History::can_undo - empty stack" {
  let history = History::new()
  assert_false(history.can_undo())
}

///|
test "History::can_redo - empty stack" {
  let history = History::new()
  assert_false(history.can_redo())
}

///|
test "History::can_undo - with item" {
  let element = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let history : History = { undo_stack: [AddElement(element)], redo_stack: [] }
  assert_true(history.can_undo())
}

///|
test "History::can_redo - with item" {
  let element = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let history : History = { undo_stack: [], redo_stack: [AddElement(element)] }
  assert_true(history.can_redo())
}

// ============================================================
// Command 構造のテスト
// ============================================================

///|
test "Command - AddElement" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let cmd = AddElement(element)
  assert_true(cmd is AddElement(_))
}

///|
test "Command - RemoveElement" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let cmd = RemoveElement(element)
  assert_true(cmd is RemoveElement(_))
}

///|
test "Command - MoveElement" {
  let cmd : Command = MoveElement("el-1", 100.0, 100.0, 200.0, 200.0)
  match cmd {
    MoveElement(id, from_x, from_y, to_x, to_y) => {
      assert_eq(id, "el-1")
      assert_eq(from_x, 100.0)
      assert_eq(from_y, 100.0)
      assert_eq(to_x, 200.0)
      assert_eq(to_y, 200.0)
    }
    _ => fail("Expected MoveElement")
  }
}

///|
test "Command - ResizeElement" {
  let old_shape = Rect(80.0, 60.0, None, None)
  let new_shape = Rect(100.0, 80.0, None, None)
  let cmd : Command = ResizeElement("el-1", old_shape, new_shape)
  match cmd {
    ResizeElement(id, old, new) => {
      assert_eq(id, "el-1")
      assert_eq(old, old_shape)
      assert_eq(new, new_shape)
    }
    _ => fail("Expected ResizeElement")
  }
}

///|
test "Command - ReorderElement" {
  let cmd : Command = ReorderElement("el-1", 0, 2)
  match cmd {
    ReorderElement(id, from_idx, to_idx) => {
      assert_eq(id, "el-1")
      assert_eq(from_idx, 0)
      assert_eq(to_idx, 2)
    }
    _ => fail("Expected ReorderElement")
  }
}

///|
test "Command - UpdateStyle" {
  let old_style = Style::default()
  let new_style : Style = {
    fill: Some("#ff0000"),
    stroke: Some("#00ff00"),
    stroke_width: Some(3.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
  }
  let cmd : Command = UpdateStyle("el-1", old_style, new_style)
  match cmd {
    UpdateStyle(id, old, new) => {
      assert_eq(id, "el-1")
      assert_eq(old.stroke, Some("#000000"))
      assert_eq(new.fill, Some("#ff0000"))
    }
    _ => fail("Expected UpdateStyle")
  }
}

///|
test "Command - RenameElement" {
  let cmd : Command = RenameElement("old-id", "new-id")
  match cmd {
    RenameElement(old_id, new_id) => {
      assert_eq(old_id, "old-id")
      assert_eq(new_id, "new-id")
    }
    _ => fail("Expected RenameElement")
  }
}

///|
test "Command - UpdateText" {
  let cmd : Command = UpdateText("text-1", "Hello", "World")
  match cmd {
    UpdateText(id, old_content, new_content) => {
      assert_eq(id, "text-1")
      assert_eq(old_content, "Hello")
      assert_eq(new_content, "World")
    }
    _ => fail("Expected UpdateText")
  }
}

// ============================================================
// Command equality tests
// ============================================================

///|
test "Command equality - same AddElement" {
  let el1 = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let el2 = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let cmd1 = AddElement(el1)
  let cmd2 = AddElement(el2)
  assert_eq(cmd1, cmd2)
}

///|
test "Command equality - different AddElement" {
  let el1 = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let el2 = Element::new("el-2", 100.0, 100.0, Circle(50.0))
  let cmd1 = AddElement(el1)
  let cmd2 = AddElement(el2)
  assert_true(cmd1 != cmd2)
}

///|
test "Command equality - MoveElement same" {
  let cmd1 : Command = MoveElement("el-1", 0.0, 0.0, 100.0, 100.0)
  let cmd2 : Command = MoveElement("el-1", 0.0, 0.0, 100.0, 100.0)
  assert_eq(cmd1, cmd2)
}

///|
test "Command equality - MoveElement different" {
  let cmd1 : Command = MoveElement("el-1", 0.0, 0.0, 100.0, 100.0)
  let cmd2 : Command = MoveElement("el-1", 0.0, 0.0, 200.0, 200.0)
  assert_true(cmd1 != cmd2)
}

///|
test "Command equality - UpdateStyle same" {
  let style1 = Style::default()
  let style2 = Style::default()
  let cmd1 : Command = UpdateStyle("el-1", style1, style2)
  let cmd2 : Command = UpdateStyle("el-1", style1, style2)
  assert_eq(cmd1, cmd2)
}

///|
test "Command equality - RenameElement" {
  let cmd1 : Command = RenameElement("old", "new")
  let cmd2 : Command = RenameElement("old", "new")
  assert_eq(cmd1, cmd2)
}

///|
test "Command equality - UpdateText" {
  let cmd1 : Command = UpdateText("id", "old", "new")
  let cmd2 : Command = UpdateText("id", "old", "new")
  assert_eq(cmd1, cmd2)
}

// ============================================================
// apply_command_pure tests
// ============================================================

///|
test "apply_command_pure - AddElement" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let result = apply_command_pure(AddElement(element), [], [])
  assert_eq(result.elements.length(), 1)
  assert_eq(result.elements[0].id, "el-1")
}

///|
test "apply_command_pure - RemoveElement" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let result = apply_command_pure(RemoveElement(element), [element], ["el-1"])
  assert_eq(result.elements.length(), 0)
  assert_eq(result.selected_ids.length(), 0)
}

///|
test "apply_command_pure - RemoveElement with children" {
  let parent = Element::new(
    "parent",
    100.0,
    100.0,
    Rect(80.0, 60.0, None, None),
  )
  let child = Element::new("child", 110.0, 110.0, Text("A", None)).with_parent(
    "parent",
  )
  let result = apply_command_pure(RemoveElement(parent), [parent, child], [])
  // 親と子両方削除される
  assert_eq(result.elements.length(), 0)
}

///|
test "apply_command_pure - MoveElement" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let cmd : Command = MoveElement("el-1", 100.0, 100.0, 200.0, 200.0)
  let result = apply_command_pure(cmd, [element], [])
  assert_eq(result.elements[0].x, 200.0)
  assert_eq(result.elements[0].y, 200.0)
}

///|
test "apply_command_pure - ResizeElement" {
  let element = Element::new("el-1", 100.0, 100.0, Rect(80.0, 60.0, None, None))
  let old_shape = Rect(80.0, 60.0, None, None)
  let new_shape = Rect(120.0, 100.0, None, None)
  let cmd : Command = ResizeElement("el-1", old_shape, new_shape)
  let result = apply_command_pure(cmd, [element], [])
  assert_eq(result.elements[0].shape, new_shape)
}

///|
test "apply_command_pure - ReorderElement" {
  let el1 = Element::new("el-1", 0.0, 0.0, Circle(10.0))
  let el2 = Element::new("el-2", 0.0, 0.0, Circle(10.0))
  let el3 = Element::new("el-3", 0.0, 0.0, Circle(10.0))
  // el-1 を末尾に移動
  let cmd : Command = ReorderElement("el-1", 0, 2)
  let result = apply_command_pure(cmd, [el1, el2, el3], [])
  assert_eq(result.elements[0].id, "el-2")
  assert_eq(result.elements[1].id, "el-3")
  assert_eq(result.elements[2].id, "el-1")
}

///|
test "apply_command_pure - UpdateStyle" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let old_style = Style::default()
  let new_style : Style = { ..Style::default(), fill: Some("#ff0000") }
  let cmd : Command = UpdateStyle("el-1", old_style, new_style)
  let result = apply_command_pure(cmd, [element], [])
  assert_eq(result.elements[0].style.fill, Some("#ff0000"))
}

///|
test "apply_command_pure - RenameElement" {
  let element = Element::new("old-id", 100.0, 100.0, Circle(50.0))
  let cmd : Command = RenameElement("old-id", "new-id")
  let result = apply_command_pure(cmd, [element], ["old-id"])
  assert_eq(result.elements[0].id, "new-id")
  assert_eq(result.selected_ids[0], "new-id")
}

///|
test "apply_command_pure - UpdateText" {
  let element = Element::new("text-1", 100.0, 100.0, Text("Hello", Some(16.0)))
  let cmd : Command = UpdateText("text-1", "Hello", "World")
  let result = apply_command_pure(cmd, [element], [])
  guard result.elements[0].shape is Text(content, _)
  assert_eq(content, "World")
}

// ============================================================
// unapply_command_pure tests
// ============================================================

///|
test "unapply_command_pure - AddElement (reverse = remove)" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let result = unapply_command_pure(AddElement(element), [element], ["el-1"])
  assert_eq(result.elements.length(), 0)
  assert_eq(result.selected_ids.length(), 0)
}

///|
test "unapply_command_pure - RemoveElement (reverse = add)" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let result = unapply_command_pure(RemoveElement(element), [], [])
  assert_eq(result.elements.length(), 1)
  assert_eq(result.elements[0].id, "el-1")
}

///|
test "unapply_command_pure - MoveElement (reverse = move back)" {
  let element = { ..Element::new("el-1", 200.0, 200.0, Circle(50.0)) }
  let cmd : Command = MoveElement("el-1", 100.0, 100.0, 200.0, 200.0)
  let result = unapply_command_pure(cmd, [element], [])
  assert_eq(result.elements[0].x, 100.0)
  assert_eq(result.elements[0].y, 100.0)
}

///|
test "unapply_command_pure - ResizeElement (reverse = old shape)" {
  let old_shape = Rect(80.0, 60.0, None, None)
  let new_shape = Rect(120.0, 100.0, None, None)
  let element = { ..Element::new("el-1", 100.0, 100.0, new_shape) }
  let cmd : Command = ResizeElement("el-1", old_shape, new_shape)
  let result = unapply_command_pure(cmd, [element], [])
  assert_eq(result.elements[0].shape, old_shape)
}

///|
test "unapply_command_pure - ReorderElement (reverse = old position)" {
  let el1 = Element::new("el-1", 0.0, 0.0, Circle(10.0))
  let el2 = Element::new("el-2", 0.0, 0.0, Circle(10.0))
  let el3 = Element::new("el-3", 0.0, 0.0, Circle(10.0))
  // el-1 を位置0に戻す（現在 [el-2, el-3, el-1] → [el-1, el-2, el-3]）
  let cmd : Command = ReorderElement("el-1", 0, 2)
  let result = unapply_command_pure(cmd, [el2, el3, el1], [])
  assert_eq(result.elements[0].id, "el-1")
  assert_eq(result.elements[1].id, "el-2")
  assert_eq(result.elements[2].id, "el-3")
}

///|
test "unapply_command_pure - UpdateStyle (reverse = old style)" {
  let old_style = Style::default()
  let new_style : Style = { ..Style::default(), fill: Some("#ff0000") }
  let element = {
    ..Element::new("el-1", 100.0, 100.0, Circle(50.0)),
    style: new_style,
  }
  let cmd : Command = UpdateStyle("el-1", old_style, new_style)
  let result = unapply_command_pure(cmd, [element], [])
  assert_eq(result.elements[0].style, old_style)
}

///|
test "unapply_command_pure - RenameElement (reverse = old id)" {
  let element = Element::new("new-id", 100.0, 100.0, Circle(50.0))
  let cmd : Command = RenameElement("old-id", "new-id")
  let result = unapply_command_pure(cmd, [element], ["new-id"])
  assert_eq(result.elements[0].id, "old-id")
  assert_eq(result.selected_ids[0], "old-id")
}

///|
test "unapply_command_pure - UpdateText (reverse = old content)" {
  let element = Element::new("text-1", 100.0, 100.0, Text("World", Some(16.0)))
  let cmd : Command = UpdateText("text-1", "Hello", "World")
  let result = unapply_command_pure(cmd, [element], [])
  guard result.elements[0].shape is Text(content, _)
  assert_eq(content, "Hello")
}

// ============================================================
// apply then unapply (roundtrip) tests
// ============================================================

///|
test "apply_command_pure then unapply - roundtrip" {
  let element = Element::new("el-1", 100.0, 100.0, Circle(50.0))
  let cmd : Command = MoveElement("el-1", 100.0, 100.0, 200.0, 200.0)

  // apply
  let after_apply = apply_command_pure(cmd, [element], [])
  assert_eq(after_apply.elements[0].x, 200.0)

  // unapply should restore original
  let after_unapply = unapply_command_pure(cmd, after_apply.elements, [])
  assert_eq(after_unapply.elements[0].x, 100.0)
  assert_eq(after_unapply.elements[0].y, 100.0)
}
