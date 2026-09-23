// 実アプリに対する断線の網羅チェック
//
// セマンティックモデルの網羅チェック（interaction/sweep_test.mbt）と同じシーンを、
// 実際の UI が通る関数で動かす。
//   - ポインタ操作は pointerdown / move / up の各ハンドラが呼ぶ順番どおりに
//     （履歴の記録 record_*_end も含めて）呼ぶ
//   - キーボード・貼り付け・複製・削除・パネル編集・名前変更は、ショートカットや
//     入力欄が呼ぶ関数そのものを呼ぶ
// 各操作のあと Undo を一段ずつ戻し（そのつど距離を確かめる）、戻りきったら
// 元のシーンと突き合わせ、Redo でやり直して操作後のシーンと突き合わせる。

///|
priv struct AppOp {
  kind : String
  label : String
  run : (@core.EditorState, @model.History) -> Unit
  /// 張り替わってよい端点
  released : Array[(String, @interaction.Endpoint)]
  /// 名前を変える操作なら (旧, 新)
  renamed : (String, String)?
}

///|
/// ドラッグ中の各コマで見つかった断線（操作ごとに集め直す）
let during_gesture : Ref[Array[@interaction.JointViolation]] = { val: [], }

///|
/// 掴んでいる端点がある操作なら、その端点（離すまで張り替わらない）
let gripped_endpoint : Ref[(String, @interaction.Endpoint)?] = { val: None, }

///|
/// ドラッグ中のコマを確かめる
fn app_probe(state : @core.EditorState) -> Unit {
  for v in @interaction.Scene::of(state.elements.get()).joint_violations() {
    match gripped_endpoint.val {
      Some((line_id, ep)) =>
        if v.joint.line_id == line_id && v.joint.endpoint == ep {
          continue
        }
      None => ()
    }
    during_gesture.val.push(v)
  }
}

///|
fn app_num(v : Double) -> String {
  @model.num_str(v)
}

///|
fn app_handle_name(handle : @model.HandlePosition) -> String {
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
/// 本体を掴んで動かす（pointerdown -> move -> move -> pointerup）
fn app_drag(
  state : @core.EditorState,
  history : @model.History,
  id : String,
  grab : @model.Point,
  dx : Double,
  dy : Double,
) -> Unit {
  state.select(Some(id))
  state.start_drag(id, grab.x, grab.y)
  state.drag_move(grab.x + dx / 2.0, grab.y + dy / 2.0)
  app_probe(state)
  state.drag_move(grab.x + dx, grab.y + dy)
  app_probe(state)
  finish_pointer_gesture(state, history)
}

///|
/// 複数選択を掴んで動かす
fn app_multi_drag(
  state : @core.EditorState,
  history : @model.History,
  ids : Array[String],
  dx : Double,
  dy : Double,
) -> Unit {
  state.selected_ids.set(ids)
  state.start_multi_drag(0.0, 0.0)
  state.multi_drag_move(dx / 2.0, dy / 2.0)
  app_probe(state)
  state.multi_drag_move(dx, dy)
  app_probe(state)
  finish_pointer_gesture(state, history)
}

///|
/// ハンドル（図形の角・線の端点）を掴んで運ぶ
fn app_resize(
  state : @core.EditorState,
  history : @model.History,
  id : String,
  handle : @model.HandlePosition,
  from : @model.Point,
  to : @model.Point,
) -> Unit {
  state.select(Some(id))
  state.start_resize(id, handle, from.x, from.y)
  gripped_endpoint.val = match @interaction.endpoint_of_handle(handle) {
    Some(ep) => Some((id, ep))
    None => None
  }
  state.resize_move((from.x + to.x) / 2.0, (from.y + to.y) / 2.0)
  app_probe(state)
  state.resize_move(to.x, to.y)
  app_probe(state)
  gripped_endpoint.val = None
  finish_pointer_gesture(state, history)
}

///|
/// 1 個以上の要素の組をすべて（並び順は元の順）
fn app_subsets(ids : Array[String]) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  let n = ids.length()
  for mask in 1..<(1 << n) {
    let subset : Array[String] = []
    for i in 0..<n {
      if ((mask >> i) & 1) == 1 {
        subset.push(ids[i])
      }
    }
    out.push(subset)
  }
  out
}

///|
/// 端点を落とす先として、別の要素のアンカーをひとつ選ぶ
fn app_drop_target(
  scene : @interaction.Scene,
  line_id : String,
  current : @model.Point,
  other_end : @model.Point?,
) -> @model.Point? {
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
      let (_, q) = pair
      if !far_from(q, current) {
        continue
      }
      match other_end {
        Some(o) => if !far_from(q, o) { continue }
        None => ()
      }
      return Some(q)
    }
  }
  None
}

///|
/// シーンに当てる操作を並べる
fn app_operations(scene : @interaction.Scene) -> Array[AppOp] {
  let ops : Array[AppOp] = []
  let ids = scene.elements.map(fn(e) { e.id })
  let deltas = [(37.0, 53.0), (-41.3, 17.7)]
  for el in scene.elements {
    let id = el.id
    let is_line = el.shape is @model.Line(_, _)
    let what = if is_line { "line" } else { "shape" }
    let grab : @model.Point = { x: el.x + 1.0, y: el.y + 1.0, }
    for d in deltas {
      let (dx, dy) = d
      ops.push({
        kind: "drag \{what}",
        label: "drag \{id} by (\{app_num(dx)}, \{app_num(dy)})",
        run: fn(state, history) { app_drag(state, history, id, grab, dx, dy) },
        released: [],
        renamed: None,
      })
    }
    // 掴んで離すだけ（動かさない）
    ops.push({
      kind: "click \{what}",
      label: "press and release \{id}",
      run: fn(state, history) { app_drag(state, history, id, grab, 0.0, 0.0) },
      released: [],
      renamed: None,
    })
    // 矢印キー（移動 / Shift でリサイズ）
    for key in ["ArrowRight", "ArrowUp"] {
      ops.push({
        kind: "arrow key on \{what}",
        label: "select \{id}, press \{key}",
        run: fn(state, history) {
          state.selected_ids.set([id])
          @lib.handle_arrow_key(state, history, key, false)
        },
        released: [],
        renamed: None,
      })
    }
    for key in ["ArrowRight", "ArrowLeft", "ArrowDown", "ArrowUp"] {
      // 線を Shift+矢印で伸縮すると端点がひとつ動く。その端点の張り替えは許す。
      let moved_end : Array[(String, @interaction.Endpoint)] = if is_line {
        match key {
          "ArrowRight" | "ArrowDown" => [(id, @interaction.End)]
          _ => [(id, @interaction.Start)]
        }
      } else {
        []
      }
      ops.push({
        kind: "shift+arrow on \{what}",
        label: "select \{id}, press Shift+\{key}",
        run: fn(state, history) {
          state.selected_ids.set([id])
          @lib.handle_arrow_key(state, history, key, true)
        },
        released: moved_end,
        renamed: None,
      })
    }
    // プロパティパネルの x 欄
    ops.push({
      kind: "panel x on \{what}",
      label: "type x = \{app_num(el.x + 17.0)} for \{id}",
      run: fn(state, history) {
        guard state.find_element(id) is Some(now) else { return }
        @core.execute_command(
          history,
          state,
          @model.MoveElement(id, now.x, now.y, now.x + 17.0, now.y),
        )
      },
      released: [],
      renamed: None,
    })
    // ID の変更
    let new_name = id + "-renamed"
    ops.push({
      kind: "rename \{what}",
      label: "rename \{id} to \{new_name}",
      run: fn(state, history) {
        @core.execute_command(
          history,
          state,
          @model.RenameElement(id, new_name),
        )
      },
      released: [],
      renamed: Some((id, new_name)),
    })
    if is_line {
      for
        ep in (
          [@interaction.Start, @interaction.End] : Array[@interaction.Endpoint]) {
        guard scene.endpoint_point(id, ep) is Some(p) else { continue }
        let handle = ep.handle()
        let other = scene.endpoint_point(
          id,
          match ep {
            @interaction.Start => @interaction.End
            @interaction.End => @interaction.Start
          },
        )
        // 端点のハンドルを掴んで離すだけ（ジョイントはそのままのはず）
        ops.push({
          kind: "click endpoint handle",
          label: "press and release \{id}.\{@interaction.endpoint_name(ep)} handle",
          run: fn(state, history) {
            state.select(Some(id))
            state.start_resize(id, handle, p.x, p.y)
            finish_pointer_gesture(state, history)
          },
          released: [],
          renamed: None,
        })
        let targets : Array[(String, @model.Point)] = [
          ("wiggle endpoint", { x: p.x + 3.0, y: p.y + 2.0, }),
          ("pull endpoint away", { x: 720.0, y: 560.0, }),
        ]
        match app_drop_target(scene, id, p, other) {
          Some(q) => targets.push(("drop endpoint on another anchor", q))
          None => ()
        }
        for t in targets {
          let (kind, to) = t
          ops.push({
            kind,
            label: "\{kind}: \{id}.\{@interaction.endpoint_name(ep)} to (\{app_num(to.x)}, \{app_num(to.y)})",
            run: fn(state, history) {
              app_resize(state, history, id, handle, p, to)
            },
            released: [(id, ep)],
            renamed: None,
          })
        }
      }
    } else {
      for handle in [@model.NW, @model.NE, @model.SW, @model.SE] {
        for d in [(23.0, 31.0), (-17.4, 12.6)] {
          let (dx, dy) = d
          ops.push({
            kind: "resize shape",
            label: "resize \{id} \{app_handle_name(handle)} by (\{app_num(dx)}, \{app_num(dy)})",
            run: fn(state, history) {
              app_resize(state, history, id, handle, { x: 0.0, y: 0.0, }, {
                x: dx,
                y: dy,
              })
            },
            released: [],
            renamed: None,
          })
        }
      }
    }
  }
  // 要素の組ごとの操作
  for subset in app_subsets(ids) {
    let names = subset.join(",")
    let reversed = subset.copy()
    reversed.rev_inplace()
    if subset.length() >= 2 {
      for order in [subset, reversed] {
        let order_name = order.join(",")
        ops.push({
          kind: "multi-drag",
          label: "select [\{order_name}], drag by (-41.3, 17.7)",
          run: fn(state, history) {
            app_multi_drag(state, history, order, -41.3, 17.7)
          },
          released: [],
          renamed: None,
        })
        ops.push({
          kind: "arrow key on selection",
          label: "select [\{order_name}], press ArrowRight",
          run: fn(state, history) {
            state.selected_ids.set(order)
            @lib.handle_arrow_key(state, history, "ArrowRight", false)
          },
          released: [],
          renamed: None,
        })
      }
    }
    ops.push({
      kind: "copy + paste",
      label: "select [\{names}], copy, paste",
      run: fn(state, history) {
        state.selected_ids.set(subset)
        @lib.copy_selection(state)
        let counter : Ref[Int] = { val: 0, }
        @lib.paste_clipboard(state, history, fn() {
          counter.val = counter.val + 1
          "p\{counter.val}"
        })
      },
      released: [],
      renamed: None,
    })
    ops.push({
      kind: "duplicate",
      label: "select [\{names}], duplicate",
      run: fn(state, history) {
        state.selected_ids.set(subset)
        let counter : Ref[Int] = { val: 0, }
        @lib.duplicate_selection(state, history, fn() {
          counter.val = counter.val + 1
          "d\{counter.val}"
        })
      },
      released: [],
      renamed: None,
    })
    ops.push({
      kind: "delete",
      label: "select [\{names}], delete",
      run: fn(state, history) {
        state.selected_ids.set(subset)
        @lib.delete_selection(state, history)
      },
      released: [],
      renamed: None,
    })
  }
  ops
}

///|
/// シーンの ID をひとつ付け替えたもの（名前変更の期待値）
fn app_rename_scene(
  scene : @interaction.Scene,
  old_id : String,
  new_id : String,
) -> @interaction.Scene {
  let swap = fn(id : String) -> String {
    if id == old_id {
      new_id
    } else {
      id
    }
  }
  let swap_conn = fn(c : @model.Connection?) -> @model.Connection? {
    match c {
      Some(conn) => Some({ ..conn, element_id: swap(conn.element_id), })
      None => None
    }
  }
  @interaction.Scene::of(
    scene.elements.map(fn(e) {
      {
        ..e,
        id: swap(e.id),
        parent_id: match e.parent_id {
          Some(p) => Some(swap(p))
          None => None
        },
        connections: match e.connections {
          Some(conns) =>
            Some({ start: swap_conn(conns.start), end: swap_conn(conns.end), })
          None => None
        },
      }
    }),
  )
}

///|
/// 二つの要素列の違い（座標は tol まで同じとみなす）
fn app_scene_diff(
  expected : Array[@model.Element],
  actual : Array[@model.Element],
  tol : Double,
) -> Array[String] {
  let out : Array[String] = []
  let close = fn(a : Double, b : Double) -> Bool { (a - b).abs() <= tol }
  for e in expected {
    match actual.iter().find_first(fn(a) { a.id == e.id }) {
      None => out.push("\{e.id} is missing")
      Some(a) => {
        let same_shape = match (e.shape, a.shape) {
          (@model.Line(ex2, ey2), @model.Line(ax2, ay2)) =>
            close(ex2, ax2) && close(ey2, ay2)
          (@model.Rect(ew, eh, _, _), @model.Rect(aw, ah, _, _)) =>
            close(ew, aw) && close(eh, ah)
          (@model.Circle(er), @model.Circle(ar)) => close(er, ar)
          (@model.Ellipse(erx, ery), @model.Ellipse(arx, ary)) =>
            close(erx, arx) && close(ery, ary)
          _ => e.shape == a.shape
        }
        if !close(e.x, a.x) || !close(e.y, a.y) || !same_shape {
          out.push(
            "\{e.id} should be \{@interaction.describe_element(e)} but is \{@interaction.describe_element(a)}",
          )
        }
        if e.connections != a.connections {
          out.push("\{e.id} connections differ")
        }
        if e.parent_id != a.parent_id {
          out.push("\{e.id} parent differs")
        }
      }
    }
  }
  for a in actual {
    if !expected.iter().any(fn(e) { e.id == a.id }) {
      out.push("\{a.id} is unexpected")
    }
  }
  out
}

///|
priv struct AppReport {
  mut runs : Int
  mut scenes : Int
  counts : Map[String, Int]
  examples : Map[String, String]
}

///|
fn AppReport::new() -> AppReport {
  { runs: 0, scenes: 0, counts: {}, examples: {}, }
}

///|
fn AppReport::add(
  self : AppReport,
  key : String,
  op : AppOp,
  scene : @interaction.Scene,
  details : Array[String],
) -> Unit {
  self.counts[key] = self.counts.get(key).unwrap_or(0) + 1
  if !self.examples.contains(key) {
    self.examples[key] = "  op: \{op.label}\n  scene:\n    " +
      scene
      .describe()
      .split("\n")
      .map(fn(s) { s.to_string() })
      .collect()
      .join("\n    ") +
      "\n  problems:\n    " +
      details.join("\n    ")
  }
}

///|
fn AppReport::summary(self : AppReport, title : String) -> String {
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
fn app_problem_class(problem : @interaction.JointProblem) -> String {
  match problem {
    @interaction.Broken(v) =>
      match v.fault {
        @interaction.MissingTarget => "target missing"
        @interaction.NotALine => "not a line"
        @interaction.Detached =>
          if v.distance <= 1.5 {
            "endpoint off its anchor by <= 1.5px (rounding-sized)"
          } else {
            "endpoint off its anchor by > 1.5px (visible)"
          }
      }
    @interaction.Lost(_) => "joint lost"
    @interaction.Gained(_) => "joint gained"
  }
}

///|
/// 問題を分類ごとにまとめて報告する
fn AppReport::record_problems(
  self : AppReport,
  stage : String,
  op : AppOp,
  grid_name : String,
  scene : @interaction.Scene,
  problems : Array[@interaction.JointProblem],
) -> Unit {
  let classes : Array[String] = []
  for p in problems {
    let class = app_problem_class(p)
    if !classes.contains(class) {
      classes.push(class)
    }
  }
  for class in classes {
    let details = problems
      .filter(fn(p) { app_problem_class(p) == class })
      .map(fn(p) { p.describe() })
    self.add(
      "\{op.kind} [\{grid_name}] \{stage} -> \{class}",
      op,
      scene,
      details,
    )
  }
}

///|
/// ひとつのシーンに全操作を当てる
fn app_sweep_scene(report : AppReport, base : @interaction.Scene) -> Unit {
  report.scenes = report.scenes + 1
  for grid in [false, true] {
    let grid_name = if grid { "grid 10" } else { "no grid" }
    for op in app_operations(base) {
      let state = @core.EditorState::new(800, 600)
      state.grid_enabled.set(grid)
      state.grid_size.set(10)
      state.elements.set(base.elements.copy())
      let history = @model.History::new()
      during_gesture.val = []
      (op.run)(state, history)
      report.runs = report.runs + 1
      if during_gesture.val.length() > 0 {
        report.record_problems(
          "while dragging",
          op,
          grid_name,
          base,
          during_gesture.val.map(fn(v) { @interaction.Broken(v) }),
        )
      }
      let before = base
      let after = @interaction.Scene::of(state.elements.get())
      // 操作直後: 距離とトポロジー
      let expected_before = match op.renamed {
        Some((old_id, new_id)) => app_rename_scene(before, old_id, new_id)
        None => before
      }
      let new_ids = after.elements
        .filter(fn(e) { !before.elements.iter().any(fn(b) { b.id == e.id }) })
        .map(fn(e) { e.id })
      let gone_ids = before.elements
        .filter(fn(b) { !after.elements.iter().any(fn(e) { e.id == b.id }) })
        .map(fn(e) { e.id })
      let problems = @interaction.check_joints(
        expected_before,
        after,
        released=op.released,
      ).filter(fn(p) {
        match p {
          // 貼り付け・複製で増えた線のジョイントは「増えて」よい
          @interaction.Gained(key) =>
            !new_ids.iter().any(fn(id) { key.has_prefix(id + ".") })
          // 削除で消えた線のジョイントは「無くなって」よい
          @interaction.Lost(key) =>
            !gone_ids.iter().any(fn(id) { key.has_prefix(id + ".") })
          // 削除した要素への参照は、Undo で繋ぎ直せるようわざと残してある。
          // 振り直しで別の要素を指さないよう、取り込み時に外す（import 側）。
          @interaction.Broken(v) =>
            !(v.fault is @interaction.MissingTarget &&
            gone_ids.contains(v.joint.target_id))
          _ => true
        }
      })
      if problems.length() > 0 {
        report.record_problems("after op", op, grid_name, base, problems)
      }
      // Undo を一段ずつ戻す。途中の画面も利用者が見る画面なので距離を確かめる
      let after_elements = state.elements.get().copy()
      let steps = history.undo_stack.length()
      for step in 0..<steps {
        let _ = @core.undo_command(history, state)
        let mid = @interaction.Scene::of(state.elements.get())
        let broken = mid
          .joint_violations()
          .map(fn(v) { @interaction.Broken(v) })
        if broken.length() > 0 && step < steps - 1 {
          report.record_problems(
            "after undo step \{step + 1}/\{steps}",
            op,
            grid_name,
            base,
            broken,
          )
        }
      }
      // 戻りきったら元のシーンに一致するはず
      let undone = @interaction.Scene::of(state.elements.get())
      let undo_problems = @interaction.check_joints(before, undone)
      if undo_problems.length() > 0 {
        report.record_problems(
          "after full undo", op, grid_name, base, undo_problems,
        )
      }
      let undo_diff = app_scene_diff(before.elements, undone.elements, 0.5)
      if undo_diff.length() > 0 {
        report.add(
          "\{op.kind} [\{grid_name}] after full undo -> scene not restored",
          op,
          base,
          undo_diff,
        )
      }
      // Redo をすべてやり直すと、操作直後のシーンに一致するはず
      for _ in 0..<steps {
        let _ = @core.redo_command(history, state)
      }
      let redone = @interaction.Scene::of(state.elements.get())
      let redo_diff = app_scene_diff(after_elements, redone.elements, 0.5)
      if redo_diff.length() > 0 {
        report.add(
          "\{op.kind} [\{grid_name}] after full redo -> scene differs from after op",
          op,
          base,
          redo_diff,
        )
      }
    }
  }
}

///|
/// 一件でも壊れていれば、分類ごとの件数と最小の例を添えて失敗させる
fn AppReport::assert_clean(self : AppReport, title : String) -> Unit raise {
  if self.counts.length() > 0 {
    fail(self.summary(title))
  }
}

///|
/// 図形の種類 × アンカー × どちらの端 × 寸法の偶奇、を一つずつ
fn app_sweep_single_joints(report : AppReport) -> Unit {
  for size in [(90.0, 70.0), (91.0, 71.0)] {
    let (w, h) = size
    for kind in @interaction.all_shape_kinds() {
      let shape = kind.make("s0", 200.0, 150.0, w, h)
      let anchors = shape.shape.config().anchor_types
      for anchor in anchors {
        for
          ep in (
            [@interaction.Start, @interaction.End] :
            Array[@interaction.Endpoint]) {
          let scene = @interaction.Scene::of([
            shape,
            @interaction.line("l0", 40.0, 40.0, 420.0, 380.0),
          ]).connect("l0", ep, "s0", anchor)
          if scene.has_degenerate_line() {
            continue
          }
          app_sweep_scene(report, scene)
        }
      }
    }
  }
}

///|
/// 図形 n 個・線 m 本の張り方すべて
fn app_sweep_topologies(
  report : AppReport,
  n_shapes : Int,
  n_lines : Int,
) -> Unit {
  for code in 0..<@interaction.topology_count(n_shapes, n_lines) {
    let scene = @interaction.build_topology(n_shapes, n_lines, code)
    if scene.has_degenerate_line() {
      continue
    }
    app_sweep_scene(report, scene)
  }
}

///|
/// 実アプリの操作（ポインタ・キーボード・パネル・名前変更・貼り付け・複製・削除）
/// のどれをしても、Undo / Redo を挟んでも、接続が切れない
test "every app operation keeps every anchor jointed, through undo and redo" {
  let report = AppReport::new()
  app_sweep_single_joints(report)
  report.assert_clean("app: single joints")
}

///|
/// 図形 2 個・線 2 本の張り方すべてで、実アプリの操作が接続を切らない
test "every app operation keeps every topology of 2 shapes and 2 lines jointed" {
  let report = AppReport::new()
  app_sweep_topologies(report, 2, 2)
  report.assert_clean("app: 2 shapes x 2 lines")
}

///|
/// 図形 3 個・線 2 本の張り方すべて（時間がかかるので既定では飛ばす。
/// `moon test --include-skipped -p mizchi/moonlight` で走る）
#skip("slow exhaustive sweep: ~575k operations with undo/redo")
test "every app operation keeps every topology of 3 shapes and 2 lines jointed" {
  let report = AppReport::new()
  app_sweep_topologies(report, 3, 2)
  report.assert_clean("app: 3 shapes x 2 lines")
}

// =============================================================================
// 網羅チェックが見つけた断線の最小例（実アプリの経路）
// =============================================================================

///|
/// 矩形 s0 の右辺に始点を結合した線 l0 を持つエディタ
fn app_jointed_state() -> @core.EditorState {
  let state = @core.EditorState::new(800, 600)
  let scene = @interaction.Scene::of([
    @interaction.rect("s0", 100.0, 100.0, 80.0, 60.0),
    @interaction.line("l0", 0.0, 0.0, 400.0, 300.0),
  ]).connect("l0", @interaction.Start, "s0", @model.Right)
  state.elements.set(scene.elements)
  state
}

///|
fn app_assert_jointed(state : @core.EditorState, joints : Int) -> Unit raise {
  let scene = @interaction.Scene::of(state.elements.get())
  let violations = scene.joint_violations()
  if violations.length() > 0 {
    fail(violations[0].describe())
  }
  assert_eq(scene.joints().length(), joints)
}

///|
/// ID を変えても、その要素に付いていた線は付いたまま
test "renaming a shape keeps the lines attached to it" {
  let state = app_jointed_state()
  let history = @model.History::new()
  @core.execute_command(history, state, @model.RenameElement("s0", "box"))
  app_assert_jointed(state, 1)
  // 名前を変えた図形を動かしても線が追随する
  app_drag(state, history, "box", { x: 101.0, y: 101.0, }, 40.0, 30.0)
  app_assert_jointed(state, 1)
}

///|
/// 結合した線を矢印キーで動かすと、単独ドラッグと同じく結合先を連れて動く
test "nudging a jointed line with an arrow key keeps it attached" {
  let state = app_jointed_state()
  let history = @model.History::new()
  state.selected_ids.set(["l0"])
  @lib.handle_arrow_key(state, history, "ArrowRight", false)
  app_assert_jointed(state, 1)
  // Undo 一回で元の位置に戻る
  let _ = @core.undo_command(history, state)
  assert_eq(state.find_element("s0").unwrap().x, 100.0)
  app_assert_jointed(state, 1)
}

///|
/// Shift+矢印で線の結合した端点を動かすと、その結合は外れる（浮いたまま繋がって
/// いることにはならない）
test "shift+arrow on a jointed endpoint releases that joint" {
  let state = app_jointed_state()
  let history = @model.History::new()
  state.selected_ids.set(["l0"])
  // ArrowLeft は始点を動かす
  @lib.handle_arrow_key(state, history, "ArrowLeft", true)
  app_assert_jointed(state, 0)
  let _ = @core.undo_command(history, state)
  app_assert_jointed(state, 1)
}

///|
/// 線だけを複製・貼り付けしても、元の図形には繋がらない
test "a pasted or duplicated line is not bound to the original shape" {
  let state = app_jointed_state()
  let history = @model.History::new()
  let counter : Ref[Int] = { val: 0, }
  let new_id = fn() {
    counter.val = counter.val + 1
    "n\{counter.val}"
  }
  state.selected_ids.set(["l0"])
  @lib.copy_selection(state)
  @lib.paste_clipboard(state, history, new_id)
  state.selected_ids.set(["l0"])
  @lib.duplicate_selection(state, history, new_id)
  // 元の線のジョイントだけが残り、写しはどこにも繋がっていない
  app_assert_jointed(state, 1)
  // 図形と線をまとめて写すと、写し同士で繋がる
  state.selected_ids.set(["s0", "l0"])
  @lib.duplicate_selection(state, history, new_id)
  app_assert_jointed(state, 2)
}

///|
/// 複数選択のドラッグでは、選択した線に結合している（選択外の）線も追随する
test "multi-drag moves the lines attached to a selected line" {
  let state = @core.EditorState::new(800, 600)
  let scene = @interaction.Scene::of([
      @interaction.rect("s0", 60.0, 80.0, 91.0, 71.0),
      @interaction.circle("s1", 305.5, 165.5, 35.5),
      @interaction.line("l1", 0.0, 0.0, 260.0, 440.0),
      @interaction.line("l0", 0.0, 0.0, 110.0, 440.0),
    ])
    .connect("l1", @interaction.Start, "s0", @model.TopRight)
    .connect("l0", @interaction.Start, "l1", @model.LineEnd)
  state.elements.set(scene.elements)
  // ドラッグ中（離す前）から追随していること
  state.selected_ids.set(["s1", "l1"])
  state.start_multi_drag(0.0, 0.0)
  state.multi_drag_move(-41.3, 17.7)
  app_assert_jointed(state, 2)
  finish_pointer_gesture(state, @model.History::new())
  app_assert_jointed(state, 2)
}

///|
/// 結合先を連れて動かした線のドラッグは、Undo / Redo 一回ずつで行き来でき、
/// Redo で結合先が二重に動くこともない
test "undo and redo of a line drag move its jointed shape exactly once" {
  let state = app_jointed_state()
  let history = @model.History::new()
  app_drag(state, history, "l0", { x: 181.0, y: 131.0, }, 40.0, 30.0)
  let after = state.elements.get()
  assert_eq(history.undo_stack.length(), 1)
  let _ = @core.undo_command(history, state)
  assert_eq(state.find_element("s0").unwrap().x, 100.0)
  let _ = @core.redo_command(history, state)
  assert_true(state.elements.get() == after)
  app_assert_jointed(state, 1)
}

///|
/// 端点を引き離して外したジョイントは、Undo で繋がった状態に戻る
test "undo of pulling an endpoint away restores the joint" {
  let state = app_jointed_state()
  let history = @model.History::new()
  let p : @model.Point = { x: 180.0, y: 130.0, }
  app_resize(state, history, "l0", @model.LineStart, p, { x: 700.0, y: 560.0, })
  app_assert_jointed(state, 0)
  let _ = @core.undo_command(history, state)
  app_assert_jointed(state, 1)
  // 戻ったジョイントは生きている: 図形を動かすと線が追随する
  app_drag(state, history, "s0", { x: 101.0, y: 101.0, }, 30.0, 40.0)
  app_assert_jointed(state, 1)
}
