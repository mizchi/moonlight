// ジョイントの列挙と不変条件検査
//
// 「線の端点が図形のアンカーに結合している」という関係はデータ上 Element.connections
// に入っているが、そこに書かれた結合が実際の座標と一致しているとは限らない。
// ドラッグやリサイズの正しさはほぼこの一致で決まるので、ここで検査可能にする。

///|
/// シーン中の全ジョイントを列挙する（線の張られている順）
pub fn Scene::joints(self : Scene) -> Array[Joint] {
  let out : Array[Joint] = []
  for el in self.elements {
    guard el.connections is Some(conns) else { continue }
    if conns.start is Some(conn) {
      out.push({
        line_id: el.id,
        endpoint: Start,
        target_id: conn.element_id,
        anchor: conn.anchor,
      })
    }
    if conns.end is Some(conn) {
      out.push({
        line_id: el.id,
        endpoint: End,
        target_id: conn.element_id,
        anchor: conn.anchor,
      })
    }
  }
  out
}

///|
/// 指定要素に（線側からでも図形側からでも）繋がっているジョイント
pub fn Scene::joints_of(self : Scene, id : String) -> Array[Joint] {
  self.joints().filter(fn(j) { j.line_id == id || j.target_id == id })
}

///|
/// 線 line_id の endpoint 側の現在座標
pub fn Scene::endpoint_point(
  self : Scene,
  line_id : String,
  endpoint : Endpoint,
) -> @model.Point? {
  guard self.find(line_id) is Some(el) else { return None }
  match (el.shape, endpoint) {
    (@model.Line(_, _), Start) => Some({ x: el.x, y: el.y, })
    (@model.Line(x2, y2), End) => Some({ x: x2, y: y2, })
    (@model.Path(_, _, _, _, _), Start) => Some({ x: el.x, y: el.y, })
    (@model.Path(_, sx, sy, ex, ey), End) =>
      Some({ x: el.x + (ex - sx), y: el.y + (ey - sy), })
    _ => None
  }
}

///|
/// ジョイントが期待する座標（結合先アンカーの現在位置）
pub fn Scene::joint_anchor_point(self : Scene, joint : Joint) -> @model.Point? {
  guard self.find(joint.target_id) is Some(target) else { return None }
  Some(target.get_anchor_point(joint.anchor))
}

///|
/// ジョイントが満たされない理由
pub(all) enum JointFault {
  /// 端点座標が結合先アンカーからずれている
  Detached
  /// 結合先の要素が存在しない
  MissingTarget
  /// 接続情報が線以外の要素に付いている
  NotALine
} derive(Debug, Eq)

///|
/// ジョイント違反
pub(all) struct JointViolation {
  joint : Joint
  fault : JointFault
  /// 結合先アンカーの座標（MissingTarget のときは意味を持たない）
  expected : @model.Point
  /// 端点の実座標（NotALine のときは意味を持たない）
  actual : @model.Point
  /// expected と actual の距離（Detached のときのみ意味を持つ）
  distance : Double
} derive(Debug, Eq)

///|
/// 違反の理由を一行で説明する
pub fn JointViolation::describe(self : JointViolation) -> String {
  let end_name = match self.joint.endpoint {
    Start => "start"
    End => "end"
  }
  let anchor_name = @model.anchor_to_string(self.joint.anchor)
  let head = "line \{self.joint.line_id} \{end_name}"
  match self.fault {
    MissingTarget =>
      "\{head} is connected to \{self.joint.target_id}.\{anchor_name}, but that element does not exist"
    NotALine =>
      "\{head} carries a connection, but \{self.joint.line_id} is not a line"
    Detached =>
      "\{head} should sit on \{self.joint.target_id}.\{anchor_name} at (\{@model.num_str(self.expected.x)}, \{@model.num_str(self.expected.y)}) but is at (\{@model.num_str(self.actual.x)}, \{@model.num_str(self.actual.y)}), off by \{@model.num_str(self.distance)}"
  }
}

///|
/// 結合先が存在しない、または端点座標がアンカーからずれているジョイントを列挙する。
///
/// これがシーンの中心的な不変条件。ドラッグ・リサイズ・削除のあとで
/// 空でなければ、どこかで接続の伝播が漏れている。
pub fn Scene::joint_violations(
  self : Scene,
  tolerance? : Double = 0.5,
) -> Array[JointViolation] {
  let zero : @model.Point = { x: 0.0, y: 0.0, }
  let out : Array[JointViolation] = []
  for joint in self.joints() {
    guard self.endpoint_point(joint.line_id, joint.endpoint) is Some(actual) else {
      out.push({
        joint,
        fault: NotALine,
        expected: zero,
        actual: zero,
        distance: 0.0,
      })
      continue
    }
    guard self.joint_anchor_point(joint) is Some(expected) else {
      out.push({
        joint,
        fault: MissingTarget,
        expected: zero,
        actual,
        distance: 0.0,
      })
      continue
    }
    let dx = actual.x - expected.x
    let dy = actual.y - expected.y
    let distance = (dx * dx + dy * dy).sqrt()
    if distance > tolerance {
      out.push({ joint, fault: Detached, expected, actual, distance, })
    }
  }
  out
}

///|
/// 全ジョイントが幾何的に満たされているか
pub fn Scene::joints_are_consistent(
  self : Scene,
  tolerance? : Double = 0.5,
) -> Bool {
  self.joint_violations(tolerance~).length() == 0
}

///|
/// ジョイントを張る（線の端点を図形のアンカーに結合し、座標も合わせる）
pub fn Scene::connect(
  self : Scene,
  line_id : String,
  endpoint : Endpoint,
  target_id : String,
  anchor : @model.Anchor,
) -> Scene {
  guard self.find(target_id) is Some(target) else { return self }
  let point = target.get_anchor_point(anchor)
  let conn : @model.Connection = { element_id: target_id, anchor, }
  let elements = self.elements.map(fn(el) {
    guard el.id == line_id else { return el }
    let conns = el.connections.unwrap_or(@model.LineConnections::none())
    match endpoint {
      Start =>
        {
          ..el,
          x: point.x,
          y: point.y,
          connections: Some({ ..conns, start: Some(conn), }),
        }
      End => {
        let shape = match el.shape {
          @model.Line(_, _) => @model.Line(point.x, point.y)
          other => other
        }
        { ..el, shape, connections: Some({ ..conns, end: Some(conn), }), }
      }
    }
  })
  { ..self, elements, }
}

///|
/// ジョイントを外す（座標はそのまま）
pub fn Scene::disconnect(
  self : Scene,
  line_id : String,
  endpoint : Endpoint,
) -> Scene {
  let elements = self.elements.map(fn(el) {
    guard el.id == line_id else { return el }
    guard el.connections is Some(conns) else { return el }
    let next : @model.LineConnections = match endpoint {
      Start => { ..conns, start: None, }
      End => { ..conns, end: None, }
    }
    if next.start is None && next.end is None {
      { ..el, connections: None, }
    } else {
      { ..el, connections: Some(next), }
    }
  })
  { ..self, elements, }
}
