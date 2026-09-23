// 断線の網羅チェック
//
// 小さなシーンを「ジョイントの張り方」ごとにすべて作り、そこへあらゆる操作を
// 当てて、二つの物差しで確かめる。
//
//   距離       各ジョイントの端点が、結合先アンカーの上に載っているか
//              （joint_violations。ずれ・結合先の消失を拾う）
//   トポロジー  どの線のどの端が、どの要素のどのアンカーに付いているか、という
//              組が操作の前後で変わっていないか（joint_signature）
//
// 大きなシーンで起きる伝播漏れも、たいていは図形数個・線数本で再現する
// （small scope hypothesis）。ここではその小さな範囲を取りこぼしなく並べる。

///|
/// ジョイントの組を一行ずつの文字列にして並べたもの（トポロジーの指紋）。
/// 並び順に依存しないよう整列してある。
pub fn Scene::joint_signature(self : Scene) -> Array[String] {
  let out = self.joints().map(fn(j) { joint_key(j) })
  out.sort()
  out
}

///|
fn joint_key(j : Joint) -> String {
  "\{j.line_id}.\{endpoint_name(j.endpoint)}->\{j.target_id}.\{@model.anchor_to_string(j.anchor)}"
}

///|
/// start / end
pub fn endpoint_name(endpoint : Endpoint) -> String {
  match endpoint {
    Start => "start"
    End => "end"
  }
}

///|
/// 網羅チェックで見つかった問題
pub(all) enum JointProblem {
  /// 距離: 端点がアンカーから離れた、または結合先が消えた
  Broken(JointViolation)
  /// トポロジー: 操作の前にあったジョイントが無くなった
  Lost(String)
  /// トポロジー: 操作の前に無かったジョイントが増えた
  Gained(String)
} derive(Debug, Eq)

///|
/// 問題を一行で説明する
pub fn JointProblem::describe(self : JointProblem) -> String {
  match self {
    Broken(v) => "distance: " + v.describe()
    Lost(key) => "topology: lost \{key}"
    Gained(key) => "topology: gained \{key}"
  }
}

///|
/// 操作の結果を二つの物差しで検査し、見つかった問題を返す。
///
/// released には、操作の意図としてジョイントが張り替わってよい端点を挙げる
/// （線の端点をドラッグしたときのその端点）。それ以外の端点のジョイントが
/// 増えたり減ったりしていれば、トポロジーが壊れている。
pub fn check_joints(
  before : Scene,
  after : Scene,
  released? : Array[(String, Endpoint)] = [],
  tolerance? : Double = 0.5,
) -> Array[JointProblem] {
  let problems : Array[JointProblem] = []
  for v in after.joint_violations(tolerance~) {
    problems.push(Broken(v))
  }
  let is_released = fn(key : String) -> Bool {
    released
    .iter()
    .any(fn(r) { key.has_prefix("\{r.0}.\{endpoint_name(r.1)}->") })
  }
  let expected = before.joint_signature().filter(fn(k) { !is_released(k) })
  let actual = after.joint_signature().filter(fn(k) { !is_released(k) })
  for key in expected {
    if !actual.contains(key) {
      problems.push(Lost(key))
    }
  }
  for key in actual {
    if !expected.contains(key) {
      problems.push(Gained(key))
    }
  }
  problems
}

// =============================================================================
// 張り方の列挙
// =============================================================================

///|
/// 端点ひとつが取りうる結合先の数（自由・図形 n 個・他の線 m-1 本の両端）
pub fn endpoint_choice_count(n_shapes : Int, n_lines : Int) -> Int {
  1 + n_shapes + 2 * (n_lines - 1)
}

///|
/// 図形 n 個・線 m 本で作れる張り方の総数
pub fn topology_count(n_shapes : Int, n_lines : Int) -> Int {
  let k = endpoint_choice_count(n_shapes, n_lines)
  let mut total = 1
  for _ in 0..<(2 * n_lines) {
    total = total * k
  }
  total
}

///|
/// 列挙用の結合先
priv enum SweepTarget {
  Free
  OnShape(Int, @model.Anchor)
  /// 相手の端点の通し番号（線 l の始点が 2l、終点が 2l+1）
  OnLine(Int)
}

///|
/// 図形が線の端点に差し出すアンカー
fn shape_anchor_choices(el : @model.Element) -> Array[@model.Anchor] {
  el.shape.config().anchor_types.filter(fn(a) {
    !(a is @model.LineStart) && !(a is @model.LineEnd)
  })
}

///|
/// code 番目の張り方のシーンを作る。
///
/// 端点 j（線 l の始点が 2l、終点が 2l+1）の結合先は、code を k 進数で
/// 読んだときの j 桁目で決める:
///
///   0         自由
///   1..n      図形 s(d-1)（アンカーは端点と図形ごとにずらして選ぶ）
///   n+1..     別の線の始点か終点
///
/// 線から線への結合は連鎖にも輪にもなる。繋がった端点の集まりごとに
/// 根（図形のアンカーか自由端。線だけの輪なら輪の中の最小番号）を決め、
/// 全員をその座標に置く。だから作ったシーンは最初から全ジョイントを満たす。
///
/// 図形の寸法は既定で奇数にしてあり、アンカーが .5 の座標に来る。
/// 丸めの漏れを拾うため。
pub fn build_topology(
  n_shapes : Int,
  n_lines : Int,
  code : Int,
  width? : Double = 91.0,
  height? : Double = 71.0,
) -> Scene {
  let kinds = all_shape_kinds()
  let shapes : Array[@model.Element] = []
  for i in 0..<n_shapes {
    let kind = kinds[i % kinds.length()]
    shapes.push(
      kind.make(
        "s\{i}",
        60.0 + 200.0 * i.to_double(),
        80.0 + 50.0 * (i % 2).to_double(),
        width,
        height,
      ),
    )
  }
  let k = endpoint_choice_count(n_shapes, n_lines)
  let n_ends = 2 * n_lines
  let targets : Array[SweepTarget] = []
  let mut rest = code
  for j in 0..<n_ends {
    let d = rest % k
    rest = rest / k
    let own_line = j / 2
    let target = if d == 0 {
      Free
    } else if d <= n_shapes {
      let s = d - 1
      let anchors = shape_anchor_choices(shapes[s])
      OnShape(s, anchors[(j * 3 + s) % anchors.length()])
    } else {
      let idx = d - n_shapes - 1
      let other = idx / 2
      let other_line = if other >= own_line { other + 1 } else { other }
      OnLine(other_line * 2 + idx % 2)
    }
    targets.push(target)
  }
  // 自由端の既定位置（線ごとに離しておく）
  let default_point = fn(j : Int) -> @model.Point {
    let l = (j / 2).to_double()
    if j % 2 == 0 {
      { x: 40.0 + 150.0 * l, y: 380.0, }
    } else {
      { x: 110.0 + 150.0 * l, y: 440.0, }
    }
  }
  // 端点から結合をたどって根の座標を得る
  let resolve = fn(from : Int) -> @model.Point {
    let path : Array[Int] = []
    let mut j = from
    for _ in 0..<=n_ends {
      match targets[j] {
        Free => return default_point(j)
        OnShape(s, anchor) => return shapes[s].get_anchor_point(anchor)
        OnLine(next) => {
          let mut seen_at = -1
          for i in 0..<path.length() {
            if path[i] == j {
              seen_at = i
              break
            }
          }
          if seen_at >= 0 {
            // 線だけの輪: 輪の中で一番小さい番号の端点に集める
            let mut lowest = j
            for i in seen_at..<path.length() {
              if path[i] < lowest {
                lowest = path[i]
              }
            }
            return default_point(lowest)
          }
          path.push(j)
          j = next
        }
      }
    }
    default_point(from)
  }
  let connection_of = fn(t : SweepTarget) -> @model.Connection? {
    match t {
      Free => None
      OnShape(s, anchor) => Some({ element_id: shapes[s].id, anchor, })
      OnLine(e) =>
        Some({
          element_id: "l\{e / 2}",
          anchor: if e % 2 == 0 {
            @model.LineStart
          } else {
            @model.LineEnd
          },
        })
    }
  }
  let elements = shapes.copy()
  for l in 0..<n_lines {
    let p = resolve(2 * l)
    let q = resolve(2 * l + 1)
    let start = connection_of(targets[2 * l])
    let end = connection_of(targets[2 * l + 1])
    let connections : @model.LineConnections? = if start is None && end is None {
      None
    } else {
      Some({ start, end, })
    }
    elements.push({ ..line("l\{l}", p.x, p.y, q.x, q.y), connections, })
  }
  Scene::of(elements)
}

///|
/// 線の長さが min_line_length に満たないものがあるか。
///
/// 両端が同じ点に集まる張り方（同じアンカーに両端、互いの端点どうしなど）は
/// 実際の操作では作れない（潰れた線は確定時に捨てられる）ので、列挙から外す。
pub fn Scene::has_degenerate_line(self : Scene) -> Bool {
  self.elements
  .iter()
  .any(fn(el) { line_length(el) is Some(len) && len < min_line_length })
}
