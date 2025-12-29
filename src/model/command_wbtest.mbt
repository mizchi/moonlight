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
