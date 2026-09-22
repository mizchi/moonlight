// ジョイントの不変条件
//
// 「線の端点は結合先アンカーの上に載り続ける」がこの層の中心的な約束。
// 図形の種類 × アンカー位置 × 動かす側、の組み合わせで確かめる。

///|
/// 図形と、その右辺に端点を結合した線からなるシーン
fn jointed_scene(kind : ShapeKind, anchor : @model.Anchor) -> Scene {
  let shape = kind.make("target", 100.0, 100.0, 80.0, 80.0)
  let l = line("l1", 300.0, 300.0, 320.0, 320.0)
  Scene::of([shape, l]).connect("l1", End, "target", anchor)
}

///|
test "connect puts the endpoint exactly on the anchor" {
  let scene = jointed_scene(RectKind, @model.Right)
  let target = scene.find("target").unwrap()
  let expected = target.get_anchor_point(@model.Right)
  let actual = scene.endpoint_point("l1", End).unwrap()
  assert_eq(actual.x, expected.x)
  assert_eq(actual.y, expected.y)
  assert_true(scene.joints_are_consistent())
}

///|
test "joints are listed for both endpoints" {
  let scene = Scene::of([
      rect("a", 0.0, 0.0, 40.0, 40.0),
      rect("b", 200.0, 0.0, 40.0, 40.0),
      line("l1", 0.0, 0.0, 0.0, 0.0),
    ])
    .connect("l1", Start, "a", @model.Right)
    .connect("l1", End, "b", @model.Left)
  let joints = scene.joints()
  assert_eq(joints.length(), 2)
  @debug.debug_inspect(
    joints.map(fn(j) { j.target_id }),
    content="[\"a\", \"b\"]",
  )
  assert_true(scene.joints_are_consistent())
}

///|
/// 図形の種類 × アンカー位置すべてで、図形をドラッグしても端点が追随する
test "dragging a jointed shape keeps every anchor attached" {
  for kind in all_shape_kinds() {
    for anchor in kind.perimeter_anchors() {
      let scene = jointed_scene(kind, anchor)
      let before = scene.find("target").unwrap()
      let after = scene.play([
        Press(Body("target"), { x: before.x, y: before.y, }),
        MoveTo({ x: before.x + 120.0, y: before.y + 90.0, }),
        Release,
      ])
      let violations = after.joint_violations()
      if violations.length() > 0 {
        abort(
          "\{kind.name()} / \{@model.anchor_to_string(anchor)}: \{violations[0].describe()}",
        )
      }
    }
  }
}

///|
/// 図形をリサイズするとアンカーが動く。端点もそこへ追随しなければならない。
test "resizing a jointed shape keeps every anchor attached" {
  for kind in all_shape_kinds() {
    for anchor in kind.perimeter_anchors() {
      let scene = jointed_scene(kind, anchor)
      let after = scene.play([
        Press(Handle("target", @model.SE), { x: 180.0, y: 180.0, }),
        MoveTo({ x: 240.0, y: 230.0, }),
        Release,
      ])
      let violations = after.joint_violations()
      if violations.length() > 0 {
        abort(
          "\{kind.name()} / \{@model.anchor_to_string(anchor)}: \{violations[0].describe()}",
        )
      }
    }
  }
}

///|
/// 線の端点をアンカーの近くまで運ぶと吸着してジョイントが生まれる
test "dropping a line endpoint near an anchor creates a joint" {
  let target = rect("target", 200.0, 200.0, 80.0, 60.0)
  let anchor_point = target.get_anchor_point(@model.Left)
  let scene = Scene::of([target, line("l1", 20.0, 20.0, 60.0, 60.0)])
  // スナップ距離の内側で離す
  let drop : @model.Point = {
    x: anchor_point.x + 8.0,
    y: anchor_point.y + 6.0,
  }
  let after = scene.play([
    Press(Handle("l1", @model.LineEnd), { x: 60.0, y: 60.0, }),
    MoveTo({ x: 60.0 + (drop.x - 60.0), y: 60.0 + (drop.y - 60.0), }),
    Release,
  ])
  let joints = after.joints()
  assert_eq(joints.length(), 1)
  assert_eq(joints[0].target_id, "target")
  @debug.debug_inspect(joints[0].anchor, content="Left")
  assert_true(after.joints_are_consistent())
}

///|
/// スナップ距離の外で離したらジョイントは生まれない
test "dropping a line endpoint far from any anchor creates no joint" {
  let scene = Scene::of([
    rect("target", 200.0, 200.0, 80.0, 60.0),
    line("l1", 20.0, 20.0, 60.0, 60.0),
  ])
  let after = scene.play([
    Press(Handle("l1", @model.LineEnd), { x: 60.0, y: 60.0, }),
    MoveTo({ x: 100.0, y: 100.0, }),
    Release,
  ])
  assert_eq(after.joints().length(), 0)
}

///|
/// 結合済みの端点を遠くへ運ぶとジョイントは外れる
test "dragging a jointed endpoint away releases the joint" {
  let scene = jointed_scene(RectKind, @model.Right)
  let endpoint = scene.endpoint_point("l1", End).unwrap()
  let after = scene.play([
    Press(Handle("l1", @model.LineEnd), endpoint),
    MoveTo({ x: endpoint.x + 400.0, y: endpoint.y + 400.0, }),
    Release,
  ])
  assert_eq(after.joints().length(), 0)
  assert_true(after.joints_are_consistent())
}

///|
/// 端点ドラッグ中はアンカースナップがグリッドスナップより優先される
test "anchor snapping wins over grid snapping" {
  let target = rect("target", 200.0, 200.0, 80.0, 60.0)
  let anchor_point = target.get_anchor_point(@model.Left)
  let scene = Scene::of([target, line("l1", 20.0, 20.0, 60.0, 60.0)]).with_grid(
    Grid::of(50.0),
  )
  let session = Session::start(scene).run([
    Press(Handle("l1", @model.LineEnd), { x: 60.0, y: 60.0, }),
    MoveTo({
      x: 60.0 + (anchor_point.x + 7.0 - 60.0),
      y: 60.0 + (anchor_point.y + 3.0 - 60.0),
    }),
  ])
  let moved = session.scene.endpoint_point("l1", End).unwrap()
  // グリッド (50) に丸められず、アンカー座標そのものに載る
  assert_eq(moved.x, anchor_point.x)
  assert_eq(moved.y, anchor_point.y)
  assert_true(session.pending is Some(_))
}

///|
/// 両端を別々の図形に結合した線は、どちらを動かしても繋がったままになる
test "a line bridging two shapes follows whichever shape moves" {
  let scene = Scene::of([
      rect("a", 0.0, 0.0, 60.0, 60.0),
      rect("b", 300.0, 0.0, 60.0, 60.0),
      line("l1", 0.0, 0.0, 0.0, 0.0),
    ])
    .connect("l1", Start, "a", @model.Right)
    .connect("l1", End, "b", @model.Left)
  let after_a = scene.play([
    Press(Body("a"), { x: 0.0, y: 0.0, }),
    MoveTo({ x: 40.0, y: 120.0, }),
    Release,
  ])
  assert_true(after_a.joints_are_consistent())
  let after_b = after_a.play([
    Press(Body("b"), { x: 340.0, y: 120.0, }),
    MoveTo({ x: 500.0, y: 200.0, }),
    Release,
  ])
  assert_true(after_b.joints_are_consistent())
  assert_eq(after_b.joints().length(), 2)
}

///|
/// 線から線へのジョイントも多段で追随する
test "a chain of jointed lines propagates through every hop" {
  let scene = Scene::of([
      rect("a", 0.0, 0.0, 60.0, 60.0),
      line("l1", 0.0, 0.0, 200.0, 200.0),
      line("l2", 0.0, 0.0, 400.0, 400.0),
    ])
    .connect("l1", Start, "a", @model.Right)
    .connect("l2", Start, "l1", @model.LineEnd)
  let after = scene.play([
    Press(Body("a"), { x: 0.0, y: 0.0, }),
    MoveTo({ x: 100.0, y: 100.0, }),
    Release,
  ])
  let violations = after.joint_violations()
  if violations.length() > 0 {
    abort(violations[0].describe())
  }
}

///|
/// 結合先を消したジョイントは違反として報告される
test "a joint to a deleted element is reported" {
  let scene = jointed_scene(RectKind, @model.Right)
  let orphaned = {
    ..scene,
    elements: scene.elements.filter(fn(e) { e.id != "target" }),
  }
  let violations = orphaned.joint_violations()
  assert_eq(violations.length(), 1)
  @debug.debug_inspect(violations[0].fault, content="MissingTarget")
}

///|
/// 端点をずらしたシーンは違反として報告される（検査そのものの健全性）
test "a detached endpoint is reported" {
  let scene = jointed_scene(RectKind, @model.Right)
  let broken = {
    ..scene,
    elements: scene.elements.map(fn(e) {
      if e.id == "l1" {
        { ..e, shape: @model.Line(999.0, 999.0), }
      } else {
        e
      }
    }),
  }
  let violations = broken.joint_violations()
  assert_eq(violations.length(), 1)
  @debug.debug_inspect(violations[0].fault, content="Detached")
  assert_true(violations[0].distance > 100.0)
}

///|
/// 潰れた線はリサイズ確定時に捨てられる
test "a line collapsed to nothing is dropped on release" {
  let scene = Scene::of([line("l1", 100.0, 100.0, 160.0, 100.0)])
  let after = scene.play([
    Press(Handle("l1", @model.LineEnd), { x: 160.0, y: 100.0, }),
    MoveTo({ x: 101.0, y: 100.0, }),
    Release,
  ])
  assert_eq(after.elements.length(), 0)
  @debug.debug_inspect(after.selection, content="[]")
}

///|
/// disconnect は座標を動かさずに結合だけ外す
test "disconnect leaves the geometry alone" {
  let scene = jointed_scene(RectKind, @model.Right)
  let before = scene.endpoint_point("l1", End).unwrap()
  let after = scene.disconnect("l1", End)
  let now = after.endpoint_point("l1", End).unwrap()
  assert_eq(now.x, before.x)
  assert_eq(now.y, before.y)
  assert_eq(after.joints().length(), 0)
  assert_true(after.find("l1").unwrap().connections is None)
}

// =============================================================================
// 鎖（a — b — c）を掴む場所を変えても接続が残るか
// =============================================================================

///|
/// 図形 a — 線 l1 — 図形 b — 線 l2 — 図形 c の鎖
fn chain_scene() -> Scene {
  Scene::of([
    rect("a", 40.0, 40.0, 80.0, 60.0),
    circle("b", 300.0, 70.0, 40.0),
    ellipse("c", 520.0, 70.0, 60.0, 40.0),
    line("l1", 0.0, 0.0, 0.0, 0.0),
    line("l2", 0.0, 0.0, 0.0, 0.0),
  ])
  .connect("l1", Start, "a", @model.Right)
  .connect("l1", End, "b", @model.Left)
  .connect("l2", Start, "b", @model.Right)
  .connect("l2", End, "c", @model.Left)
}

///|
/// 端点が結合している図形は、線の胴体を掴むと一緒に動く
test "dragging a line body carries the shapes it joins" {
  let scene = chain_scene()
  let after = scene.play([
    Press(Body("l2"), { x: 400.0, y: 70.0, }),
    MoveTo({ x: 400.0, y: 270.0, }),
    Release,
  ])
  // l2 が繋いでいる b と c が同じ差分だけ動く
  let b = after.find("b").unwrap()
  let c = after.find("c").unwrap()
  assert_eq(b.x, 300.0)
  assert_eq(b.y, 270.0)
  assert_eq(c.x, 520.0)
  assert_eq(c.y, 270.0)
  // a は掴んだ線と繋がっていないので動かない
  let a = after.find("a").unwrap()
  assert_eq(a.x, 40.0)
  assert_eq(a.y, 40.0)
}

///|
/// b — c 間の線を掴むと b も動く。このとき a — b 間の線が取り残されてはいけない。
/// （連れて動いた図形にぶら下がる線へ伝播が漏れると、鎖の手前側が切れて見える）
test "dragging the b-c line keeps the a-b line jointed" {
  let scene = chain_scene()
  let after = scene.play([
    Press(Body("l2"), { x: 400.0, y: 70.0, }),
    MoveTo({ x: 400.0, y: 270.0, }),
    Release,
  ])
  let violations = after.joint_violations()
  if violations.length() > 0 {
    abort(violations[0].describe())
  }
  // a — b 間の線は a に残ったまま、b の新しいアンカーまで伸びる
  let b_left = after.find("b").unwrap().get_anchor_point(@model.Left)
  let l1_end = after.endpoint_point("l1", End).unwrap()
  assert_eq(l1_end.x, b_left.x)
  assert_eq(l1_end.y, b_left.y)
  let a_right = after.find("a").unwrap().get_anchor_point(@model.Right)
  let l1_start = after.endpoint_point("l1", Start).unwrap()
  assert_eq(l1_start.x, a_right.x)
  assert_eq(l1_start.y, a_right.y)
  assert_eq(after.joints().length(), 4)
}

///|
/// 鎖の手前側の線を掴んでも、奥側の線が取り残されない（向きを変えても同じ）
test "dragging the a-b line keeps the b-c line jointed" {
  let scene = chain_scene()
  let after = scene.play([
    Press(Body("l1"), { x: 190.0, y: 70.0, }),
    MoveTo({ x: 190.0, y: 270.0, }),
    Release,
  ])
  let violations = after.joint_violations()
  if violations.length() > 0 {
    abort(violations[0].describe())
  }
  // b が連れて動いたので、b — c 間の線の始点も追随する
  let b_right = after.find("b").unwrap().get_anchor_point(@model.Right)
  let l2_start = after.endpoint_point("l2", Start).unwrap()
  assert_eq(l2_start.x, b_right.x)
  assert_eq(l2_start.y, b_right.y)
  // c は掴んだ線と繋がっていないので動かず、l2 が伸びる
  let c = after.find("c").unwrap()
  assert_eq(c.x, 520.0)
  assert_eq(c.y, 70.0)
  assert_eq(after.joints().length(), 4)
}

///|
/// 鎖のどこを掴んでも、すべてのジョイントが満たされたままであること
test "every grab point in the chain leaves the joints satisfied" {
  for id in ["a", "b", "c", "l1", "l2"] {
    let scene = chain_scene()
    let grab = match scene.find(id) {
      Some(el) => el.get_anchor_point(@model.Center)
      None => abort("missing \{id}")
    }
    let after = scene.play([
      Press(Body(id), grab),
      MoveTo({ x: grab.x + 60.0, y: grab.y + 200.0, }),
      Release,
    ])
    let violations = after.joint_violations()
    if violations.length() > 0 {
      abort("grabbing \{id}: \{violations[0].describe()}")
    }
    // 接続そのものが消えていないこと
    assert_eq(after.joints().length(), 4)
  }
}

///|
/// 線から線へのジョイントでも、掴んだ線に結合先の端点が追随する。
/// 相手の線はもう一方の端点を図形に預けたまま伸縮する。
test "dragging a line carries the endpoint of the line it joins" {
  let scene = Scene::of([
      rect("a", 40.0, 40.0, 80.0, 60.0),
      ellipse("c", 520.0, 70.0, 60.0, 40.0),
      line("l1", 120.0, 70.0, 260.0, 70.0),
      line("l2", 0.0, 0.0, 0.0, 0.0),
    ])
    .connect("l1", Start, "a", @model.Right)
    .connect("l2", Start, "l1", @model.LineEnd)
    .connect("l2", End, "c", @model.Left)
  let after = scene.play([
    Press(Body("l2"), { x: 330.0, y: 70.0, }),
    MoveTo({ x: 330.0, y: 270.0, }),
    Release,
  ])
  let violations = after.joint_violations()
  if violations.length() > 0 {
    abort(violations[0].describe())
  }
  // l1 の終点が l2 の始点についてくる
  let l1_end = after.endpoint_point("l1", End).unwrap()
  let l2_start = after.endpoint_point("l2", Start).unwrap()
  assert_eq(l1_end.x, l2_start.x)
  assert_eq(l1_end.y, l2_start.y)
  // l1 の始点は動いていない a のアンカーに残る
  let a_right = after.find("a").unwrap().get_anchor_point(@model.Right)
  let l1_start = after.endpoint_point("l1", Start).unwrap()
  assert_eq(l1_start.x, a_right.x)
  assert_eq(l1_start.y, a_right.y)
  assert_eq(after.joints().length(), 3)
}
