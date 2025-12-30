// Bezier Fit - フリーハンド描画のベジェ曲線近似
// 依存なしの独立モジュール

// ============================================================
// 型定義
// ============================================================

///|
/// 2D 座標点
pub(all) struct Point {
  x : Double
  y : Double
} derive(Show, Eq)

///|
/// ベジェセグメント（3次ベジェ曲線）
/// p0: 始点, c1: 制御点1, c2: 制御点2, p3: 終点
pub(all) struct BezierSegment {
  p0 : Point
  c1 : Point
  c2 : Point
  p3 : Point
} derive(Show, Eq)

///|
/// 近似オプション
pub(all) struct Options {
  min_resample_dist : Double // リサンプリング最小距離（デフォルト: 2.0）
  epsilon : Double // RDP 簡略化の許容誤差（デフォルト: 1.0）
  max_error : Double // ベジェフィットの最大誤差（デフォルト: 4.0）
} derive(Show, Eq)

///|
/// デフォルトオプション
pub fn Options::default() -> Options {
  { min_resample_dist: 2.0, epsilon: 1.0, max_error: 4.0 }
}

// ============================================================
// ベクトル演算
// ============================================================

///|
pub fn Point::new(x : Double, y : Double) -> Point {
  { x, y }
}

///|
fn zero() -> Point {
  { x: 0.0, y: 0.0 }
}

///|
fn Point::add(self : Point, other : Point) -> Point {
  { x: self.x + other.x, y: self.y + other.y }
}

///|
fn Point::sub(self : Point, other : Point) -> Point {
  { x: self.x - other.x, y: self.y - other.y }
}

///|
fn Point::scale(self : Point, s : Double) -> Point {
  { x: self.x * s, y: self.y * s }
}

///|
fn Point::dot(self : Point, other : Point) -> Double {
  self.x * other.x + self.y * other.y
}

///|
fn Point::length_squared(self : Point) -> Double {
  self.x * self.x + self.y * self.y
}

///|
fn Point::length(self : Point) -> Double {
  self.length_squared().sqrt()
}

///|
fn Point::normalize(self : Point) -> Point {
  let len = self.length()
  if len < 1.0e-10 {
    zero()
  } else {
    self.scale(1.0 / len)
  }
}

///|
pub fn Point::distance(self : Point, other : Point) -> Double {
  self.sub(other).length()
}

///|
fn Point::negate(self : Point) -> Point {
  { x: -self.x, y: -self.y }
}

// ============================================================
// Step 1: リサンプリング
// ============================================================

///|
/// 点列を一定距離でリサンプリング
/// pointermove の取得頻度のバラつきを均一化
pub fn resample(points : Array[Point], min_dist : Double) -> Array[Point] {
  if points.length() == 0 {
    return []
  }
  let result : Array[Point] = [points[0]]
  let min_dist_sq = min_dist * min_dist
  for i = 1; i < points.length(); i = i + 1 {
    let p = points[i]
    let last = result[result.length() - 1]
    let dist_sq = p.sub(last).length_squared()
    if dist_sq >= min_dist_sq {
      result.push(p)
    }
  }

  // 最後の点を必ず含める
  if result.length() > 1 {
    let last_input = points[points.length() - 1]
    let last_result = result[result.length() - 1]
    if last_input.x != last_result.x || last_input.y != last_result.y {
      result.push(last_input)
    }
  }
  result
}

// ============================================================
// Step 2: RDP（Ramer-Douglas-Peucker）簡略化
// ============================================================

///|
/// 点と線分の垂直距離を計算
fn perpendicular_distance(p : Point, a : Point, b : Point) -> Double {
  let d = b.sub(a)
  let len_sq = d.length_squared()
  if len_sq < 1.0e-10 {
    return p.distance(a)
  }
  let t = p.sub(a).dot(d) / len_sq
  let proj = a.add(d.scale(t))
  p.distance(proj)
}

///|
/// Ramer-Douglas-Peucker アルゴリズムで点列を簡略化
pub fn rdp_simplify(points : Array[Point], epsilon : Double) -> Array[Point] {
  if points.length() <= 2 {
    return points.copy()
  }
  rdp_recursive(points, 0, points.length() - 1, epsilon)
}

///|
fn rdp_recursive(
  points : Array[Point],
  start : Int,
  end : Int,
  epsilon : Double,
) -> Array[Point] {
  if end - start <= 1 {
    return [points[start], points[end]]
  }
  let mut max_dist = 0.0
  let mut max_index = start
  for i = start + 1; i < end; i = i + 1 {
    let d = perpendicular_distance(points[i], points[start], points[end])
    if d > max_dist {
      max_dist = d
      max_index = i
    }
  }
  if max_dist > epsilon {
    let left = rdp_recursive(points, start, max_index, epsilon)
    let right = rdp_recursive(points, max_index, end, epsilon)
    let result : Array[Point] = []
    for i = 0; i < left.length() - 1; i = i + 1 {
      result.push(left[i])
    }
    for p in right {
      result.push(p)
    }
    result
  } else {
    [points[start], points[end]]
  }
}

// ============================================================
// Step 3: ベジェ曲線フィット（Schneider Algorithm）
// ============================================================

///|
/// 点列にベジェ曲線をフィット
pub fn fit_bezier(
  points : Array[Point],
  max_error : Double,
) -> Array[BezierSegment] {
  if points.length() < 2 {
    return []
  }
  if points.length() == 2 {
    return [create_line_segment(points[0], points[1])]
  }
  let left_tangent = compute_left_tangent(points, 0)
  let right_tangent = compute_right_tangent(points, points.length() - 1)
  fit_cubic(
    points,
    0,
    points.length() - 1,
    left_tangent,
    right_tangent,
    max_error,
  )
}

///|
fn create_line_segment(p0 : Point, p3 : Point) -> BezierSegment {
  let d = p3.sub(p0)
  { p0, c1: p0.add(d.scale(1.0 / 3.0)), c2: p0.add(d.scale(2.0 / 3.0)), p3 }
}

///|
fn compute_left_tangent(points : Array[Point], index : Int) -> Point {
  if index + 1 < points.length() {
    points[index + 1].sub(points[index]).normalize()
  } else {
    Point::new(1.0, 0.0)
  }
}

///|
fn compute_right_tangent(points : Array[Point], index : Int) -> Point {
  if index > 0 {
    points[index - 1].sub(points[index]).normalize()
  } else {
    Point::new(-1.0, 0.0)
  }
}

///|
fn compute_center_tangent(points : Array[Point], index : Int) -> Point {
  let v1 = if index > 0 { points[index].sub(points[index - 1]) } else { zero() }
  let v2 = if index + 1 < points.length() {
    points[index + 1].sub(points[index])
  } else {
    zero()
  }
  v1.add(v2).normalize()
}

///|
fn fit_cubic(
  points : Array[Point],
  first : Int,
  last : Int,
  left_tangent : Point,
  right_tangent : Point,
  max_error : Double,
) -> Array[BezierSegment] {
  let n_points = last - first + 1
  if n_points == 2 {
    return [create_line_segment(points[first], points[last])]
  }
  let u = chord_length_parameterize(points, first, last)
  let bezier = generate_bezier(
    points, first, last, u, left_tangent, right_tangent,
  )
  let (max_err, split_point) = compute_max_error(points, first, last, bezier, u)
  if max_err < max_error {
    return [bezier]
  }
  if max_err < max_error * 4.0 {
    let new_u = reparameterize(points, first, last, u, bezier)
    let new_bezier = generate_bezier(
      points, first, last, new_u, left_tangent, right_tangent,
    )
    let (new_err, new_split) = compute_max_error(
      points, first, last, new_bezier, new_u,
    )
    if new_err < max_error {
      return [new_bezier]
    }
    if new_err < max_err {
      return split_and_fit(
        points, first, last, new_split, left_tangent, right_tangent, max_error,
      )
    }
  }
  split_and_fit(
    points, first, last, split_point, left_tangent, right_tangent, max_error,
  )
}

///|
fn split_and_fit(
  points : Array[Point],
  first : Int,
  last : Int,
  split_point : Int,
  left_tangent : Point,
  right_tangent : Point,
  max_error : Double,
) -> Array[BezierSegment] {
  let center_tangent = compute_center_tangent(points, split_point)
  let left_segs = fit_cubic(
    points,
    first,
    split_point,
    left_tangent,
    center_tangent.negate(),
    max_error,
  )
  let right_segs = fit_cubic(
    points, split_point, last, center_tangent, right_tangent, max_error,
  )
  let result : Array[BezierSegment] = []
  for seg in left_segs {
    result.push(seg)
  }
  for seg in right_segs {
    result.push(seg)
  }
  result
}

///|
fn chord_length_parameterize(
  points : Array[Point],
  first : Int,
  last : Int,
) -> Array[Double] {
  let n = last - first + 1
  let u : Array[Double] = Array::make(n, 0.0)
  for i = 1; i < n; i = i + 1 {
    let dist = points[first + i].distance(points[first + i - 1])
    u[i] = u[i - 1] + dist
  }
  let total = u[n - 1]
  if total > 1.0e-10 {
    for i = 1; i < n; i = i + 1 {
      u[i] = u[i] / total
    }
  }
  u
}

///|
fn generate_bezier(
  points : Array[Point],
  first : Int,
  last : Int,
  u : Array[Double],
  left_tangent : Point,
  right_tangent : Point,
) -> BezierSegment {
  let n = last - first + 1
  let p0 = points[first]
  let p3 = points[last]
  let mut c00 = 0.0
  let mut c01 = 0.0
  let mut c11 = 0.0
  let mut x0 = 0.0
  let mut x1 = 0.0
  for i = 0; i < n; i = i + 1 {
    let t = u[i]
    let t2 = t * t
    let t3 = t2 * t
    let mt = 1.0 - t
    let mt2 = mt * mt
    let mt3 = mt2 * mt
    let b0 = mt3
    let b1 = 3.0 * mt2 * t
    let b2 = 3.0 * mt * t2
    let b3 = t3
    let a1 = left_tangent.scale(b1)
    let a2 = right_tangent.scale(b2)
    c00 = c00 + a1.dot(a1)
    c01 = c01 + a1.dot(a2)
    c11 = c11 + a2.dot(a2)
    let p = points[first + i]
    let tmp = p.sub(p0.scale(b0 + b1)).sub(p3.scale(b2 + b3))
    x0 = x0 + a1.dot(tmp)
    x1 = x1 + a2.dot(tmp)
  }
  let det = c00 * c11 - c01 * c01
  let (alpha_l, alpha_r) = if det.abs() < 1.0e-10 {
    let seg_length = p0.distance(p3)
    (seg_length / 3.0, seg_length / 3.0)
  } else {
    let al = (c11 * x0 - c01 * x1) / det
    let ar = (c00 * x1 - c01 * x0) / det
    let seg_length = p0.distance(p3)
    let epsilon = 1.0e-6 * seg_length
    if al < epsilon || ar < epsilon {
      (seg_length / 3.0, seg_length / 3.0)
    } else {
      (al, ar)
    }
  }
  {
    p0,
    c1: p0.add(left_tangent.scale(alpha_l)),
    c2: p3.add(right_tangent.scale(alpha_r)),
    p3,
  }
}

///|
/// ベジェ曲線上の点を計算
pub fn bezier_point(seg : BezierSegment, t : Double) -> Point {
  let mt = 1.0 - t
  let mt2 = mt * mt
  let mt3 = mt2 * mt
  let t2 = t * t
  let t3 = t2 * t
  seg.p0
  .scale(mt3)
  .add(seg.c1.scale(3.0 * mt2 * t))
  .add(seg.c2.scale(3.0 * mt * t2))
  .add(seg.p3.scale(t3))
}

///|
fn compute_max_error(
  points : Array[Point],
  first : Int,
  last : Int,
  bezier : BezierSegment,
  u : Array[Double],
) -> (Double, Int) {
  let mut max_dist = 0.0
  let mut split_point = (last - first + 1) / 2 + first
  for i = 1; i < last - first; i = i + 1 {
    let p = points[first + i]
    let b = bezier_point(bezier, u[i])
    let dist = p.distance(b)
    if dist > max_dist {
      max_dist = dist
      split_point = first + i
    }
  }
  (max_dist, split_point)
}

///|
fn reparameterize(
  points : Array[Point],
  first : Int,
  last : Int,
  u : Array[Double],
  bezier : BezierSegment,
) -> Array[Double] {
  let n = last - first + 1
  let new_u = u.copy()
  for i = 0; i < n; i = i + 1 {
    new_u[i] = newton_raphson_root(bezier, points[first + i], u[i])
  }
  new_u
}

///|
fn newton_raphson_root(bezier : BezierSegment, p : Point, u : Double) -> Double {
  let d = bezier_point(bezier, u).sub(p)
  let q1 = bezier_derivative(bezier, u, 1)
  let q2 = bezier_derivative(bezier, u, 2)
  let numerator = d.dot(q1)
  let denominator = q1.dot(q1) + d.dot(q2)
  if denominator.abs() < 1.0e-10 {
    return u
  }
  let new_u = u - numerator / denominator
  if new_u < 0.0 {
    0.0
  } else if new_u > 1.0 {
    1.0
  } else {
    new_u
  }
}

///|
fn bezier_derivative(bezier : BezierSegment, t : Double, order : Int) -> Point {
  if order == 1 {
    let mt = 1.0 - t
    let mt2 = mt * mt
    let t2 = t * t
    let d0 = bezier.c1.sub(bezier.p0).scale(3.0 * mt2)
    let d1 = bezier.c2.sub(bezier.c1).scale(6.0 * mt * t)
    let d2 = bezier.p3.sub(bezier.c2).scale(3.0 * t2)
    d0.add(d1).add(d2)
  } else {
    let mt = 1.0 - t
    let d0 = bezier.c2.sub(bezier.c1.scale(2.0)).add(bezier.p0).scale(6.0 * mt)
    let d1 = bezier.p3.sub(bezier.c2.scale(2.0)).add(bezier.c1).scale(6.0 * t)
    d0.add(d1)
  }
}

// ============================================================
// Step 4: SVG Path 生成
// ============================================================

///|
/// ベジェセグメント列を SVG path 文字列に変換
pub fn to_svg_path(segments : Array[BezierSegment]) -> String {
  if segments.length() == 0 {
    return ""
  }
  let parts : Array[String] = []
  let first = segments[0]
  parts.push("M \{first.p0.x.to_int()} \{first.p0.y.to_int()}")
  for seg in segments {
    parts.push(
      "C \{seg.c1.x.to_int()} \{seg.c1.y.to_int()} \{seg.c2.x.to_int()} \{seg.c2.y.to_int()} \{seg.p3.x.to_int()} \{seg.p3.y.to_int()}",
    )
  }
  parts.join(" ")
}

///|
/// ベジェセグメント列を閉じた SVG path 文字列に変換
pub fn to_svg_path_closed(segments : Array[BezierSegment]) -> String {
  let path = to_svg_path(segments)
  if path == "" {
    ""
  } else {
    path + " Z"
  }
}

// ============================================================
// 統合関数
// ============================================================

///|
/// 点列をベジェ曲線に近似して SVG path を生成（メイン関数）
pub fn approximate(raw_points : Array[Point], options : Options) -> String {
  if raw_points.length() < 2 {
    return ""
  }

  // Step 1: リサンプリング
  let sampled = resample(raw_points, options.min_resample_dist)
  if sampled.length() < 2 {
    return ""
  }

  // Step 2: RDP 簡略化
  let simplified = rdp_simplify(sampled, options.epsilon)
  if simplified.length() < 2 {
    return ""
  }

  // Step 3: ベジェフィット
  let segments = fit_bezier(simplified, options.max_error)

  // Step 4: SVG Path 生成
  to_svg_path(segments)
}

///|
/// ベジェセグメントを点列に変換（サンプリング）
pub fn segments_to_points(
  segments : Array[BezierSegment],
  samples_per_segment : Int,
) -> Array[Point] {
  let result : Array[Point] = []
  for seg in segments {
    for i = 0; i < samples_per_segment; i = i + 1 {
      let t = i.to_double() / samples_per_segment.to_double()
      let p = bezier_point(seg, t)
      result.push(p)
    }
  }
  if segments.length() > 0 {
    let last = segments[segments.length() - 1]
    result.push(last.p3)
  }
  result
}

// ============================================================
// 閉路判定
// ============================================================

///|
/// 始点と終点が近いか判定（ループ判定用）
pub fn is_closed_path(points : Array[Point], threshold : Double) -> Bool {
  if points.length() < 3 {
    return false
  }
  let first = points[0]
  let last = points[points.length() - 1]
  first.distance(last) < threshold
}

// ============================================================
// セグメント操作
// ============================================================

///|
/// de Casteljau アルゴリズムでベジェ曲線を t で分割
/// 1つのセグメントを2つに分割して返す
pub fn split_segment(
  seg : BezierSegment,
  t : Double,
) -> (BezierSegment, BezierSegment) {
  // Level 1: 線形補間
  let p01 = seg.p0.add(seg.c1.sub(seg.p0).scale(t))
  let p12 = seg.c1.add(seg.c2.sub(seg.c1).scale(t))
  let p23 = seg.c2.add(seg.p3.sub(seg.c2).scale(t))

  // Level 2: 線形補間
  let p012 = p01.add(p12.sub(p01).scale(t))
  let p123 = p12.add(p23.sub(p12).scale(t))

  // Level 3: 分割点
  let p0123 = p012.add(p123.sub(p012).scale(t))

  // 左側セグメント: p0 -> p01 -> p012 -> p0123
  let left : BezierSegment = { p0: seg.p0, c1: p01, c2: p012, p3: p0123 }

  // 右側セグメント: p0123 -> p123 -> p23 -> p3
  let right : BezierSegment = { p0: p0123, c1: p123, c2: p23, p3: seg.p3 }

  (left, right)
}

///|
/// セグメント列の指定位置にアンカーポイントを挿入
/// seg_idx: 分割するセグメントのインデックス
/// t: セグメント内の分割位置 (0.0 ~ 1.0)
pub fn insert_anchor(
  segments : Array[BezierSegment],
  seg_idx : Int,
  t : Double,
) -> Array[BezierSegment] {
  if seg_idx < 0 || seg_idx >= segments.length() {
    return segments.copy()
  }
  let (left, right) = split_segment(segments[seg_idx], t)
  let result : Array[BezierSegment] = []
  for i = 0; i < seg_idx; i = i + 1 {
    result.push(segments[i])
  }
  result.push(left)
  result.push(right)
  for i = seg_idx + 1; i < segments.length(); i = i + 1 {
    result.push(segments[i])
  }
  result
}

///|
/// アンカーポイントを削除し、隣接セグメントを直線で再接続
/// anchor_idx: 削除するアンカーのインデックス（セグメント境界）
/// 注: anchor_idx=0 は先頭、anchor_idx=segments.length() は末尾
pub fn delete_anchor(
  segments : Array[BezierSegment],
  anchor_idx : Int,
) -> Array[BezierSegment] {
  if segments.length() <= 1 {
    return segments.copy()
  }
  // anchor_idx は 1 ~ segments.length()-1 の範囲（内部アンカーのみ削除可能）
  if anchor_idx <= 0 || anchor_idx >= segments.length() {
    return segments.copy()
  }
  let left_seg = segments[anchor_idx - 1]
  let right_seg = segments[anchor_idx]

  // 2つのセグメントを1つにマージ（単純な直線接続）
  let merged : BezierSegment = {
    p0: left_seg.p0,
    c1: left_seg.c1,
    c2: right_seg.c2,
    p3: right_seg.p3,
  }

  let result : Array[BezierSegment] = []
  for i = 0; i < anchor_idx - 1; i = i + 1 {
    result.push(segments[i])
  }
  result.push(merged)
  for i = anchor_idx + 1; i < segments.length(); i = i + 1 {
    result.push(segments[i])
  }
  result
}

// ============================================================
// パス操作
// ============================================================

///|
/// 2つのパスをマージ（path_a の終点と path_b の始点を接続）
pub fn merge_paths(
  path_a : Array[BezierSegment],
  path_b : Array[BezierSegment],
) -> Array[BezierSegment] {
  if path_a.length() == 0 {
    return path_b.copy()
  }
  if path_b.length() == 0 {
    return path_a.copy()
  }
  let result : Array[BezierSegment] = []
  for seg in path_a {
    result.push(seg)
  }

  // 接続セグメントを生成（終点と始点が異なる場合）
  let last_a = path_a[path_a.length() - 1]
  let first_b = path_b[0]
  if last_a.p3.distance(first_b.p0) > 1.0e-6 {
    // 接続用の直線セグメントを追加
    let connector = create_line_segment(last_a.p3, first_b.p0)
    result.push(connector)
  }

  for seg in path_b {
    result.push(seg)
  }
  result
}

///|
/// パスを指定セグメントで分割（2つのパスに）
/// split_idx: 分割位置（このインデックスのセグメントから後ろが新しいパスになる）
pub fn split_path(
  segments : Array[BezierSegment],
  split_idx : Int,
) -> (Array[BezierSegment], Array[BezierSegment]) {
  if split_idx <= 0 {
    return ([], segments.copy())
  }
  if split_idx >= segments.length() {
    return (segments.copy(), [])
  }
  let left : Array[BezierSegment] = []
  let right : Array[BezierSegment] = []
  for i = 0; i < split_idx; i = i + 1 {
    left.push(segments[i])
  }
  for i = split_idx; i < segments.length(); i = i + 1 {
    right.push(segments[i])
  }
  (left, right)
}

///|
/// アンカーポイントでパスを切り離し（セグメント境界で分割）
/// anchor_idx: 分割するアンカーのインデックス
pub fn disconnect_at_anchor(
  segments : Array[BezierSegment],
  anchor_idx : Int,
) -> (Array[BezierSegment], Array[BezierSegment]) {
  split_path(segments, anchor_idx)
}

// ============================================================
// 再計算
// ============================================================

///|
/// セグメント列を点列に戻してベジェ近似をやり直す
pub fn refit(
  segments : Array[BezierSegment],
  samples_per_segment : Int,
  options : Options,
) -> Array[BezierSegment] {
  if segments.length() == 0 {
    return []
  }
  let points = segments_to_points(segments, samples_per_segment)
  if points.length() < 2 {
    return segments.copy()
  }
  let simplified = rdp_simplify(points, options.epsilon)
  fit_bezier(simplified, options.max_error)
}

///|
/// 指定範囲のセグメントのみ再計算
pub fn refit_range(
  segments : Array[BezierSegment],
  start_idx : Int,
  end_idx : Int,
  samples_per_segment : Int,
  options : Options,
) -> Array[BezierSegment] {
  let start = if start_idx < 0 { 0 } else { start_idx }
  let end = if end_idx > segments.length() { segments.length() } else { end_idx }
  if start >= end {
    return segments.copy()
  }

  // 範囲のセグメントを抽出
  let range_segments : Array[BezierSegment] = []
  for i = start; i < end; i = i + 1 {
    range_segments.push(segments[i])
  }

  // 再計算
  let refitted = refit(range_segments, samples_per_segment, options)

  // 結果を構築
  let result : Array[BezierSegment] = []
  for i = 0; i < start; i = i + 1 {
    result.push(segments[i])
  }
  for seg in refitted {
    result.push(seg)
  }
  for i = end; i < segments.length(); i = i + 1 {
    result.push(segments[i])
  }
  result
}
