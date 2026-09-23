// セマンティックモデル（Session）に対する断線の網羅チェック

///|
/// シーンに当てる操作ひとつ
priv struct SweepOp {
  /// 集計用の分類（何をしたか）
  kind : String
  /// 表示用の説明
  label : String
  inputs : Array[Input]
  /// 張り替わってよい端点
  released : Array[(String, Endpoint)]
  /// 取り消し操作なら true（元のシーンに厳密に戻ることを確かめる）
  is_cancel : Bool
}

///|
fn num(v : Double) -> String {
  @model.num_str(v)
}

///|
fn handle_name(handle : @model.HandlePosition) -> String {
  match handle {
    @model.NW => "nw"
    @model.NE => "ne"
    @model.SW => "sw"
    @model.SE => "se"
    @model.LineStart => "line-start"
    @model.LineEnd => "line-end"
  }
}

///|
/// 線 line_id の端点を落とす先として、別の要素のアンカーをひとつ選ぶ。
/// 今の位置と反対側の端点の近くは避ける（潰れて捨てられると別の話になる）。
fn drop_target(
  scene : Scene,
  line_id : String,
  current : @model.Point,
  other_end : @model.Point?,
) -> (String, @model.Anchor, @model.Point)? {
  let far_from = fn(a : @model.Point, b : @model.Point) -> Bool {
    let dx = a.x - b.x
    let dy = a.y - b.y
    (dx * dx + dy * dy).sqrt() > 30.0
  }
  for el in scene.elements {
    if el.id == line_id || el.parent_id is Some(_) {
      continue
    }
    for pair in el.get_all_anchors() {
      let (anchor, q) = pair
      if !far_from(q, current) {
        continue
      }
      match other_end {
        Some(o) => if !far_from(q, o) { continue }
        None => ()
      }
      return Some((el.id, anchor, q))
    }
  }
  None
}

///|
/// シーン中の各要素に当てる操作を並べる
fn sweep_operations(scene : Scene) -> Array[SweepOp] {
  let ops : Array[SweepOp] = []
  // 整数の移動量と、端数のある移動量（ズーム中のポインタは端数を持つ）
  let deltas = [(37.0, 53.0), (-41.3, 17.7)]
  for el in scene.elements {
    let is_line = el.shape is @model.Line(_, _)
    let what = if is_line { "line" } else { "shape" }
    let grab : @model.Point = { x: el.x + 1.0, y: el.y + 1.0, }
    for d in deltas {
      let (dx, dy) = d
      ops.push({
        kind: "drag \{what} body",
        label: "drag \{el.id} body by (\{num(dx)}, \{num(dy)})",
        inputs: [
          Press(Body(el.id), grab),
          MoveTo({ x: grab.x + dx / 2.0, y: grab.y + dy / 2.0, }),
          MoveTo({ x: grab.x + dx, y: grab.y + dy, }),
          Release,
        ],
        released: [],
        is_cancel: false,
      })
    }
    // 掴んで離すだけ（動かさない）
    ops.push({
      kind: "click \{what} body",
      label: "press and release \{el.id} body",
      inputs: [Press(Body(el.id), grab), Release],
      released: [],
      is_cancel: false,
    })
    ops.push({
      kind: "cancel \{what} drag",
      label: "drag \{el.id} then cancel",
      inputs: [
        Press(Body(el.id), grab),
        MoveTo({ x: grab.x + 30.0, y: grab.y + 20.0, }),
        Cancel,
      ],
      released: [],
      is_cancel: true,
    })
    if is_line {
      for ep in ([Start, End] : Array[Endpoint]) {
        guard scene.endpoint_point(el.id, ep) is Some(p) else { continue }
        let handle = ep.handle()
        // 端点のハンドルを掴んで離すだけ（ジョイントはそのままのはず）
        ops.push({
          kind: "click endpoint handle",
          label: "press and release \{el.id}.\{endpoint_name(ep)} handle",
          inputs: [Press(Handle(el.id, handle), p), Release],
          released: [],
          is_cancel: false,
        })
        // 少しだけ動かして離す（同じ場所に吸着し直すはず）
        ops.push({
          kind: "wiggle endpoint",
          label: "wiggle \{el.id}.\{endpoint_name(ep)} by (3, 2)",
          inputs: [
            Press(Handle(el.id, handle), p),
            MoveTo({ x: p.x + 3.0, y: p.y + 2.0, }),
            Release,
          ],
          released: [(el.id, ep)],
          is_cancel: false,
        })
        // 何も無いところへ運んで離す（外れるはず）
        ops.push({
          kind: "pull endpoint away",
          label: "pull \{el.id}.\{endpoint_name(ep)} to empty space",
          inputs: [
            Press(Handle(el.id, handle), p),
            MoveTo({ x: (p.x + 720.0) / 2.0, y: (p.y + 560.0) / 2.0, }),
            MoveTo({ x: 720.0, y: 560.0, }),
            Release,
          ],
          released: [(el.id, ep)],
          is_cancel: false,
        })
        // 別の要素のアンカーへ落とす（そこへ張り替わるはず）
        let other_end = scene.endpoint_point(
          el.id,
          match ep {
            Start => End
            End => Start
          },
        )
        match drop_target(scene, el.id, p, other_end) {
          Some((target_id, anchor, q)) =>
            ops.push({
              kind: "drop endpoint on another anchor",
              label: "drop \{el.id}.\{endpoint_name(ep)} on \{target_id}.\{@model.anchor_to_string(anchor)}",
              inputs: [
                Press(Handle(el.id, handle), p),
                MoveTo({ x: (p.x + q.x) / 2.0, y: (p.y + q.y) / 2.0, }),
                MoveTo(q),
                Release,
              ],
              released: [(el.id, ep)],
              is_cancel: false,
            })
          None => ()
        }
      }
    } else {
      for handle in [@model.NW, @model.NE, @model.SW, @model.SE] {
        ops.push({
          kind: "click corner handle",
          label: "press and release \{el.id} \{handle_name(handle)} handle",
          inputs: [Press(Handle(el.id, handle), { x: 0.0, y: 0.0, }), Release],
          released: [],
          is_cancel: false,
        })
        for d in [(23.0, 31.0), (-17.4, 12.6)] {
          let (dx, dy) = d
          ops.push({
            kind: "resize shape",
            label: "resize \{el.id} \{handle_name(handle)} by (\{num(dx)}, \{num(dy)})",
            inputs: [
              Press(Handle(el.id, handle), { x: 0.0, y: 0.0, }),
              MoveTo({ x: dx, y: dy, }),
              Release,
            ],
            released: [],
            is_cancel: false,
          })
        }
      }
    }
  }
  ops
}

///|
/// 見つかった問題の集計
priv struct SweepReport {
  mut runs : Int
  mut scenes : Int
  /// 分類キー -> 件数
  counts : Map[String, Int]
  /// 分類キー -> 最初に見つかった例
  examples : Map[String, String]
}

///|
fn SweepReport::new() -> SweepReport {
  { runs: 0, scenes: 0, counts: {}, examples: {}, }
}

///|
/// 集計用の型。距離のずれは丸め程度（1px 以下）と目に見えるものを分ける。
fn problem_class(problem : JointProblem) -> String {
  match problem {
    Broken(v) =>
      match v.fault {
        MissingTarget => "distance: target missing"
        NotALine => "distance: not a line"
        Detached =>
          if v.distance <= 1.5 {
            "distance: off its anchor by <= 1.5px (rounding-sized)"
          } else {
            "distance: off its anchor by > 1.5px (visible)"
          }
      }
    Lost(key) =>
      if key.has_prefix("!") {
        "cancel: scene not restored"
      } else {
        "topology: joint lost"
      }
    Gained(_) => "topology: joint gained"
  }
}

///|
fn SweepReport::record(
  self : SweepReport,
  op : SweepOp,
  grid : Grid,
  scene : Scene,
  problems : Array[JointProblem],
) -> Unit {
  let grid_name = if grid.enabled {
    "grid \{num(grid.size)}"
  } else {
    "no grid"
  }
  let classes : Array[String] = []
  for p in problems {
    let class = problem_class(p)
    if !classes.contains(class) {
      classes.push(class)
    }
  }
  for class in classes {
    let key = "\{op.kind} [\{grid_name}] -> \{class}"
    self.counts[key] = self.counts.get(key).unwrap_or(0) + 1
    if !self.examples.contains(key) {
      let detail = problems
        .filter(fn(p) { problem_class(p) == class })
        .map(fn(p) { p.describe() })
      self.examples[key] = "  op: \{op.label}\n  scene:\n    " +
        scene
        .describe()
        .split("\n")
        .map(fn(s) { s.to_string() })
        .collect()
        .join("\n    ") +
        "\n  problems:\n    " +
        detail.join("\n    ")
    }
  }
}

///|
fn SweepReport::summary(self : SweepReport, title : String) -> String {
  let lines : Array[String] = [
    "== \{title}: \{self.scenes} scenes, \{self.runs} operations, \{self.counts.length()} failure classes",
  ]
  let keys = self.counts.keys().collect()
  keys.sort()
  for key in keys {
    lines.push("-- \{key}: \{self.counts.get(key).unwrap_or(0)}")
    lines.push(self.examples.get(key).unwrap_or(""))
  }
  lines.join("\n")
}

///|
/// ひとつのシーンに全操作を当てる
fn sweep_scene(report : SweepReport, base : Scene) -> Unit {
  report.scenes = report.scenes + 1
  for grid in [Grid::off(), Grid::of(10.0)] {
    let scene = base.with_grid(grid)
    for op in sweep_operations(scene) {
      // 一コマずつ進め、ドラッグ中の画面でも端点が浮いていないか確かめる
      // （掴んでいる端点そのものは離すまで張り替わらないので除く）
      let mut session = Session::start(scene)
      for input in op.inputs {
        session = session.step(input)
        if input is MoveTo(_) {
          let during = session.scene
            .joint_violations()
            .filter(fn(v) {
              !op.released
              .iter()
              .any(fn(r) { r.0 == v.joint.line_id && r.1 == v.joint.endpoint })
            })
            .map(fn(v) { JointProblem::Broken(v) })
          if during.length() > 0 {
            report.record(
              { ..op, kind: op.kind + " (while dragging)", },
              grid,
              scene,
              during,
            )
          }
        }
      }
      let after = session.scene
      report.runs = report.runs + 1
      let problems = check_joints(scene, after, released=op.released)
      if op.is_cancel && after.elements != scene.elements {
        problems.push(Lost("!scene not restored by cancel"))
      }
      if problems.length() > 0 {
        report.record(op, grid, scene, problems)
      }
    }
  }
}

///|
/// 図形 n 個・線 m 本の張り方をすべて試す
fn sweep_topologies(
  report : SweepReport,
  n_shapes : Int,
  n_lines : Int,
) -> Unit {
  for code in 0..<topology_count(n_shapes, n_lines) {
    let scene = build_topology(n_shapes, n_lines, code)
    if scene.has_degenerate_line() {
      continue
    }
    sweep_scene(report, scene)
  }
}

///|
/// 図形の種類 × アンカー × どちらの端 × 寸法の偶奇、をひとつずつ
fn sweep_single_joints(report : SweepReport) -> Unit {
  for size in [(90.0, 70.0), (91.0, 71.0)] {
    let (w, h) = size
    for kind in all_shape_kinds() {
      let shape = kind.make("s0", 200.0, 150.0, w, h)
      for anchor in shape_anchor_choices_for_test(shape) {
        for ep in ([Start, End] : Array[Endpoint]) {
          let scene = Scene::of([shape, line("l0", 40.0, 40.0, 420.0, 380.0)]).connect(
            "l0", ep, "s0", anchor,
          )
          if scene.has_degenerate_line() {
            continue
          }
          sweep_scene(report, scene)
        }
      }
    }
  }
}

///|
fn shape_anchor_choices_for_test(el : @model.Element) -> Array[@model.Anchor] {
  el.shape.config().anchor_types.filter(fn(a) {
    !(a is @model.LineStart) && !(a is @model.LineEnd)
  })
}

///|
/// 一件でも壊れていれば、分類ごとの件数と最小の例を添えて失敗させる
fn SweepReport::assert_clean(self : SweepReport, title : String) -> Unit raise {
  if self.counts.length() > 0 {
    fail(self.summary(title))
  }
}

///|
/// 図形の種類 × アンカー × どちらの端 × 寸法の偶奇、のすべてで、
/// どの操作をしても端点はアンカーの上に残り、ジョイントの組も変わらない
test "every anchor of every shape kind keeps its joint through every gesture" {
  let report = SweepReport::new()
  sweep_single_joints(report)
  report.assert_clean("single joints")
}

///|
/// 図形 3 個・線 2 本の張り方すべて（鎖・星形・図形をまたぐ線・線から線への結合）
test "every topology of 3 shapes and 2 lines keeps its joints through every gesture" {
  let report = SweepReport::new()
  sweep_topologies(report, 3, 2)
  report.assert_clean("3 shapes x 2 lines")
}

///|
/// 線から線への結合を 3 段まで重ねた張り方すべて（時間がかかるので既定では飛ばす。
/// `moon test --include-skipped -p mizchi/moonlight/interaction` で走る）
#skip("slow exhaustive sweep: ~1.5M gestures")
test "every topology of 1 shape and 3 lines keeps its joints through every gesture" {
  let report = SweepReport::new()
  sweep_topologies(report, 1, 3)
  report.assert_clean("1 shape x 3 lines")
}

///|
/// 図形 2 個・線 3 本の張り方すべて（時間がかかるので既定では飛ばす）
#skip("slow exhaustive sweep: ~7M gestures")
test "every topology of 2 shapes and 3 lines keeps its joints through every gesture" {
  let report = SweepReport::new()
  sweep_topologies(report, 2, 3)
  report.assert_clean("2 shapes x 3 lines")
}
