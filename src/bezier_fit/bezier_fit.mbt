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
