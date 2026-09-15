// 操作セッションの振る舞い

///|
/// 掴んだ点と要素基準点の差分が保たれたまま動く
test "drag moves the element by the pointer delta" {
  let scene = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)])
  let after = scene.play([
    Press(Body("r1"), { x: 140.0, y: 130.0, }),
    MoveTo({ x: 200.0, y: 180.0, }),
    Release,
  ])
  let moved = after.find("r1").unwrap()
  assert_eq(moved.x, 160.0)
  assert_eq(moved.y, 150.0)
}

///|
test "drag selects the element it grabbed" {
  let scene = Scene::of([
    rect("r1", 0.0, 0.0, 10.0, 10.0),
    rect("r2", 50.0, 0.0, 10.0, 10.0),
  ])
  let after = scene.play([Press(Body("r2"), { x: 55.0, y: 5.0, }), Release])
  @debug.debug_inspect(after.selection, content="[\"r2\"]")
}

///|
test "drag snaps to the grid when the grid is on" {
  let scene = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)]).with_grid(
    Grid::of(20.0),
  )
  let after = scene.play([
    Press(Body("r1"), { x: 100.0, y: 100.0, }),
    MoveTo({ x: 147.0, y: 133.0, }),
    Release,
  ])
  let moved = after.find("r1").unwrap()
  assert_eq(moved.x, 140.0)
  assert_eq(moved.y, 140.0)
}

///|
test "cancel rewinds a drag to where it started" {
  let scene = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)])
  let session = Session::start(scene).run([
    Press(Body("r1"), { x: 100.0, y: 100.0, }),
    MoveTo({ x: 300.0, y: 300.0, }),
  ])
  // ドラッグ中は動いている
  assert_eq(session.scene.find("r1").unwrap().x, 300.0)
  let cancelled = session.step(Cancel)
  assert_eq(cancelled.scene.find("r1").unwrap().x, 100.0)
  assert_eq(cancelled.gesture.name(), "idle")
}

///|
test "release ends the gesture" {
  let scene = Scene::of([rect("r1", 0.0, 0.0, 10.0, 10.0)])
  let session = Session::start(scene).step(
    Press(Body("r1"), { x: 0.0, y: 0.0, }),
  )
  assert_true(session.is_active())
  assert_eq(session.gesture.name(), "moving")
  assert_false(session.step(Release).is_active())
}

///|
test "dragging a missing element does nothing" {
  let scene = Scene::of([rect("r1", 0.0, 0.0, 10.0, 10.0)])
  let after = scene.play([
    Press(Body("ghost"), { x: 0.0, y: 0.0, }),
    MoveTo({ x: 100.0, y: 100.0, }),
    Release,
  ])
  assert_eq(after.find("r1").unwrap().x, 0.0)
  @debug.debug_inspect(after.selection, content="[]")
}

///|
test "resizing a rect from SE keeps the top-left corner fixed" {
  let scene = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)])
  let after = scene.play([
    Press(Handle("r1", @model.SE), { x: 180.0, y: 160.0, }),
    MoveTo({ x: 220.0, y: 200.0, }),
    Release,
  ])
  let r = after.find("r1").unwrap()
  assert_eq(r.x, 100.0)
  assert_eq(r.y, 100.0)
  guard r.shape is @model.Rect(w, h, _, _) else { abort("expected Rect") }
  assert_eq(w, 120.0)
  assert_eq(h, 100.0)
}

///|
test "resizing a rect from NW keeps the bottom-right corner fixed" {
  let scene = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)])
  let after = scene.play([
    Press(Handle("r1", @model.NW), { x: 100.0, y: 100.0, }),
    MoveTo({ x: 120.0, y: 130.0, }),
    Release,
  ])
  let r = after.find("r1").unwrap()
  let bbox = r.bounding_box()
  assert_eq(bbox.x + bbox.width, 180.0)
  assert_eq(bbox.y + bbox.height, 160.0)
}

///|
test "a rect cannot be resized below the minimum size" {
  let scene = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)])
  let after = scene.play([
    Press(Handle("r1", @model.SE), { x: 180.0, y: 160.0, }),
    MoveTo({ x: 0.0, y: 0.0, }),
    Release,
  ])
  guard after.find("r1").unwrap().shape is @model.Rect(w, h, _, _) else {
    abort("expected Rect")
  }
  assert_eq(w, min_element_size)
  assert_eq(h, min_element_size)
}

///|
test "a circle keeps its centre while being resized" {
  let scene = Scene::of([circle("c1", 200.0, 200.0, 50.0)])
  let after = scene.play([
    Press(Handle("c1", @model.SE), { x: 250.0, y: 250.0, }),
    MoveTo({ x: 280.0, y: 280.0, }),
    Release,
  ])
  let c = after.find("c1").unwrap()
  assert_eq(c.x, 200.0)
  assert_eq(c.y, 200.0)
  guard c.shape is @model.Circle(r) else { abort("expected Circle") }
  assert_eq(r, 80.0)
}

///|
test "an ellipse resized from NW moves its centre" {
  let scene = Scene::of([ellipse("e1", 200.0, 200.0, 60.0, 40.0)])
  let after = scene.play([
    Press(Handle("e1", @model.NW), { x: 140.0, y: 160.0, }),
    MoveTo({ x: 160.0, y: 180.0, }),
    Release,
  ])
  let e = after.find("e1").unwrap()
  guard e.shape is @model.Ellipse(rx, ry) else { abort("expected Ellipse") }
  assert_eq(rx, 50.0)
  assert_eq(ry, 30.0)
  assert_eq(e.x, 210.0)
  assert_eq(e.y, 210.0)
}

///|
test "box select picks up every shape inside the box" {
  let scene = Scene::of([
    rect("r1", 10.0, 10.0, 20.0, 20.0),
    rect("r2", 50.0, 50.0, 20.0, 20.0),
    rect("far", 400.0, 400.0, 20.0, 20.0),
  ])
  let after = scene.play([
    Press(Canvas, { x: 0.0, y: 0.0, }),
    MoveTo({ x: 100.0, y: 100.0, }),
    Release,
  ])
  @debug.debug_inspect(after.selection, content="[\"r1\", \"r2\"]")
}

///|
test "pressing empty canvas clears the selection" {
  let scene = Scene::of([rect("r1", 10.0, 10.0, 20.0, 20.0)]).with_selection([
    "r1",
  ])
  let session = Session::start(scene).step(
    Press(Canvas, { x: 300.0, y: 300.0, }),
  )
  @debug.debug_inspect(session.scene.selection, content="[]")
}

///|
test "a new press commits the gesture already in flight" {
  let scene = Scene::of([
    rect("r1", 0.0, 0.0, 20.0, 20.0),
    rect("r2", 100.0, 0.0, 20.0, 20.0),
  ])
  let session = Session::start(scene)
    .run([Press(Body("r1"), { x: 0.0, y: 0.0, }), MoveTo({ x: 40.0, y: 40.0, })])
    .step(Press(Body("r2"), { x: 100.0, y: 0.0, }))
  // r1 の移動は確定し、r2 のドラッグが始まっている
  assert_eq(session.scene.find("r1").unwrap().x, 40.0)
  assert_eq(session.gesture.name(), "moving")
  @debug.debug_inspect(session.scene.selection, content="[\"r2\"]")
}

///|
test "coordinates are rounded when the drag is released" {
  let scene = Scene::of([rect("r1", 0.0, 0.0, 20.0, 20.0)])
  let session = Session::start(scene).run([
    Press(Body("r1"), { x: 0.0, y: 0.0, }),
    MoveTo({ x: 10.4, y: 20.6, }),
  ])
  assert_eq(session.scene.find("r1").unwrap().x, 10.4)
  let after = session.step(Release).scene
  assert_eq(after.find("r1").unwrap().x, 10.0)
  assert_eq(after.find("r1").unwrap().y, 21.0)
}
