// シナリオ DSL

///|
fn scene_of(source : String) -> Scene {
  match play_scenario(source) {
    Ok(scene) => scene
    Err(e) => abort(e.describe())
  }
}

///|
test "a scenario builds shapes and runs the gesture" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|press body r1 140 130
      #|move 200 180
      #|release
    ),
  )
  let r = scene.find("r1").unwrap()
  assert_eq(r.x, 160.0)
  assert_eq(r.y, 150.0)
}

///|
test "comments and blank lines are ignored" {
  let scene = scene_of(
    (
      #|# ふたつ置くだけ
      #|rect r1 0 0 10 10
      #|
      #|circle c1 50 50 20
    ),
  )
  assert_eq(scene.elements.length(), 2)
}

///|
test "join wires a line endpoint to an anchor" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|line l1 300 300 320 320
      #|join l1 end r1 right
    ),
  )
  let joints = scene.joints()
  assert_eq(joints.length(), 1)
  assert_eq(joints[0].target_id, "r1")
  @debug.debug_inspect(joints[0].anchor, content="Right")
  assert_true(scene.joints_are_consistent())
}

///|
test "a jointed shape stays jointed after a drag written in the DSL" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|circle c1 400 200 40
      #|line l1 180 130 360 200
      #|join l1 start r1 right
      #|join l1 end c1 left
      #|press body r1 140 130
      #|move 240 330
      #|release
    ),
  )
  let violations = scene.joint_violations()
  if violations.length() > 0 {
    abort(violations[0].describe())
  }
  assert_eq(scene.joints().length(), 2)
}

///|
test "grid applies to gestures declared after it" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|grid 25
      #|press body r1 100 100
      #|move 143 118
      #|release
    ),
  )
  let r = scene.find("r1").unwrap()
  assert_eq(r.x, 150.0)
  assert_eq(r.y, 125.0)
}

///|
test "cancel in a scenario rewinds the gesture" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|press body r1 100 100
      #|move 400 400
      #|cancel
    ),
  )
  assert_eq(scene.find("r1").unwrap().x, 100.0)
}

///|
test "handle presses reach the resize path" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|press handle r1 se 180 160
      #|move 220 200
      #|release
    ),
  )
  guard scene.find("r1").unwrap().shape is @model.Rect(w, h, _, _) else {
    abort("expected Rect")
  }
  assert_eq(w, 120.0)
  assert_eq(h, 100.0)
}

///|
test "an unknown command is reported with its line number" {
  let result = parse_scenario(
    (
      #|rect r1 0 0 10 10
      #|wobble r1
    ),
  )
  match result {
    Ok(_) => abort("expected a parse error")
    Err(e) => {
      assert_eq(e.line, 2)
      inspect(e.describe(), content="line 2: unknown command 'wobble'")
    }
  }
}

///|
test "joining an unknown element is reported" {
  let result = parse_scenario(
    (
      #|line l1 0 0 10 10
      #|join l1 end ghost right
    ),
  )
  match result {
    Ok(_) => abort("expected a parse error")
    Err(e) => inspect(e.describe(), content="line 2: no such element 'ghost'")
  }
}

///|
test "a scene describes itself" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|line l1 180 130 300 130
      #|join l1 start r1 right
    ),
  )
  inspect(
    scene.describe(),
    content=(
      #|Shapes:
      #|- rectangle r1 at (100, 100) size 80x60
      #|- line l1 from (180, 130) to (300, 130)
      #|Connections:
      #|- the start of line l1 is attached to the right anchor of rect r1
    ),
  )
}

///|
test "visual claims describe what the picture must show" {
  let scene = scene_of(
    (
      #|rect r1 100 100 80 60
      #|line l1 180 130 300 130
      #|join l1 start r1 right
    ),
  )
  let claims = scene.visual_claims()
  assert_eq(claims.length(), 3)
  assert_true(claims.iter().any(fn(c) { c.contains("right edge") }))
}

///|
fn parse_error_of(source : String) -> String {
  match @interaction.parse_scenario(source) {
    Ok(_) => abort("expected a parse error")
    Err(e) => e.describe()
  }
}

///|
test "label centres a text in its shape and binds it there" {
  let scene = scene_of(
    (
      #|rect box 100 100 80 60
      #|label box Start here
    ),
  )
  let label = scene.find("box-label").unwrap()
  assert_eq(label.parent_id, Some("box"))
  assert_eq(label.x, 140.0)
  assert_eq(label.y, 130.0)
  guard label.shape is @model.Text(content, _) else { abort("not a text") }
  assert_eq(content, "Start here")
  // 縁取りの無い文字（エディタで置く文字と同じ）
  assert_eq(label.style.stroke, None)
}

///|
test "a label goes where its shape goes" {
  let scene = scene_of(
    (
      #|circle hub 200 200 40
      #|label hub Hub
      #|press body hub 200 200
      #|move 260 245
      #|release
    ),
  )
  let label = scene.find("hub-label").unwrap()
  assert_eq(label.x, 260.0)
  assert_eq(label.y, 245.0)
}

///|
test "a label needs a shape that exists, can hold one, and has none yet" {
  inspect(
    parse_error_of("label ghost Hi"),
    content="line 1: no such shape 'ghost'",
  )
  inspect(
    parse_error_of(
      (
        #|line l 0 0 10 10
        #|label l Hi
      ),
    ),
    content="line 2: 'l' is a line; only rect, circle and ellipse can carry a label",
  )
  inspect(
    parse_error_of(
      (
        #|rect r 0 0 10 10
        #|label r One
        #|label r Two
      ),
    ),
    content="line 3: 'r' already has a label ('r-label')",
  )
}

///|
test "arrow is a line with an arrowhead at its end, and joins like one" {
  let scene = scene_of(
    (
      #|rect a 0 0 80 60
      #|rect b 200 0 80 60
      #|arrow go 80 30 200 30
      #|join go start a right
      #|join go end b left
    ),
  )
  let go = scene.find("go").unwrap()
  assert_eq(go.style.marker_end, Some(@model.Arrow))
  assert_eq(scene.joints().length(), 2)
  assert_true(scene.joints_are_consistent())
  assert_true(
    scene.describe().contains("- arrow go from (80, 30) to (200, 30)"),
  )
}

///|
test "a word where a number belongs is an error, not a zero" {
  inspect(
    parse_error_of("rect a 10 x 80 60"),
    content="line 1: 'x' is not a number (rect argument 3)",
  )
  inspect(
    parse_error_of(
      (
        #|rect a 0 0 10 10
        #|press body a 5 five
      ),
    ),
    content="line 2: 'five' is not a number (press argument 4)",
  )
}
