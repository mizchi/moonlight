// Bezier Fit モジュールのテスト

// ============================================================
// Point テスト
// ============================================================

///|
test "Point::new" {
  let p = Point::new(1.0, 2.0)
  inspect(p.x, content="1")
  inspect(p.y, content="2")
}

///|
test "Point::distance" {
  let p1 = Point::new(0.0, 0.0)
  let p2 = Point::new(3.0, 4.0)
  let result = p1.distance(p2)
  inspect(result, content="5")
}

// ============================================================
// リサンプリング テスト
// ============================================================

///|
test "resample: empty input" {
  let points : Array[Point] = []
  let result = resample(points, 2.0)
  inspect(result.length(), content="0")
}

///|
test "resample: single point" {
  let points = [Point::new(0.0, 0.0)]
  let result = resample(points, 2.0)
  inspect(result.length(), content="1")
}

///|
test "resample: filters close points" {
  let points = [
    Point::new(0.0, 0.0),
    Point::new(0.5, 0.0), // 距離 0.5 < 2.0、除外
    Point::new(1.0, 0.0), // 距離 1.0 < 2.0、除外
    Point::new(3.0, 0.0), // 距離 3.0 >= 2.0、含む
    Point::new(6.0, 0.0), // 距離 3.0 >= 2.0、含む
  ]
  let result = resample(points, 2.0)
  inspect(result.length(), content="3")
  inspect(result[0].x, content="0")
  inspect(result[1].x, content="3")
  inspect(result[2].x, content="6")
}

// ============================================================
// RDP テスト
// ============================================================

///|
test "rdp_simplify: two points unchanged" {
  let points = [Point::new(0.0, 0.0), Point::new(10.0, 0.0)]
  let result = rdp_simplify(points, 1.0)
  inspect(result.length(), content="2")
}

///|
test "rdp_simplify: straight line simplified" {
  // 直線上の点は除去される
  let points = [
    Point::new(0.0, 0.0),
    Point::new(5.0, 0.0),
    Point::new(10.0, 0.0),
  ]
  let result = rdp_simplify(points, 1.0)
  inspect(result.length(), content="2")
}

///|
test "rdp_simplify: keeps corner" {
  // 角の点は保持される
  let points = [
    Point::new(0.0, 0.0),
    Point::new(5.0, 5.0), // 角
    Point::new(10.0, 0.0),
  ]
  let result = rdp_simplify(points, 1.0)
  inspect(result.length(), content="3")
}

///|
test "rdp_simplify: large epsilon removes more" {
  let points = [
    Point::new(0.0, 0.0),
    Point::new(5.0, 2.0), // 少しずれ
    Point::new(10.0, 0.0),
  ]
  // 小さい epsilon では保持
  let result1 = rdp_simplify(points, 1.0)
  inspect(result1.length(), content="3")
  // 大きい epsilon では除去
  let result2 = rdp_simplify(points, 3.0)
  inspect(result2.length(), content="2")
}

// ============================================================
// ベジェフィット テスト
// ============================================================

///|
test "fit_bezier: two points" {
  let points = [Point::new(0.0, 0.0), Point::new(100.0, 0.0)]
  let segments = fit_bezier(points, 4.0)
  inspect(segments.length(), content="1")
  // 始点と終点を確認
  inspect(segments[0].p0.x, content="0")
  inspect(segments[0].p3.x, content="100")
}

///|
test "fit_bezier: straight line" {
  let points = [
    Point::new(0.0, 0.0),
    Point::new(50.0, 0.0),
    Point::new(100.0, 0.0),
  ]
  let segments = fit_bezier(points, 4.0)
  inspect(segments.length(), content="1")
}

///|
test "fit_bezier: curve" {
  // 曲線状の点列
  let points = [
    Point::new(0.0, 0.0),
    Point::new(25.0, 50.0),
    Point::new(50.0, 70.0),
    Point::new(75.0, 50.0),
    Point::new(100.0, 0.0),
  ]
  let segments = fit_bezier(points, 4.0)
  // 1つ以上のセグメントが生成される
  inspect(segments.length() >= 1, content="true")
}

// ============================================================
// ベジェポイント テスト
// ============================================================

///|
test "bezier_point: t=0 returns p0" {
  let seg : BezierSegment = {
    p0: Point::new(0.0, 0.0),
    c1: Point::new(25.0, 50.0),
    c2: Point::new(75.0, 50.0),
    p3: Point::new(100.0, 0.0),
  }
  let result = bezier_point(seg, 0.0)
  inspect(result.x, content="0")
  inspect(result.y, content="0")
}

///|
test "bezier_point: t=1 returns p3" {
  let seg : BezierSegment = {
    p0: Point::new(0.0, 0.0),
    c1: Point::new(25.0, 50.0),
    c2: Point::new(75.0, 50.0),
    p3: Point::new(100.0, 0.0),
  }
  let result = bezier_point(seg, 1.0)
  inspect(result.x, content="100")
  inspect(result.y, content="0")
}

///|
test "bezier_point: t=0.5 on symmetric curve" {
  // 対称的な曲線の中点
  let seg : BezierSegment = {
    p0: Point::new(0.0, 0.0),
    c1: Point::new(0.0, 100.0),
    c2: Point::new(100.0, 100.0),
    p3: Point::new(100.0, 0.0),
  }
  let result = bezier_point(seg, 0.5)
  // 中点は x=50, y は中間値
  inspect(result.x, content="50")
}

// ============================================================
// SVG Path 生成 テスト
// ============================================================

///|
test "to_svg_path: empty" {
  let segments : Array[BezierSegment] = []
  let result = to_svg_path(segments)
  inspect(result, content="")
}

///|
test "to_svg_path: single segment" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = to_svg_path(segments)
  inspect(result.has_prefix("M 0 0"), content="true")
  inspect(result.contains("C"), content="true")
}

///|
test "to_svg_path_closed: adds Z" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = to_svg_path_closed(segments)
  inspect(result.has_suffix("Z"), content="true")
}

// ============================================================
// 統合関数 テスト
// ============================================================

///|
test "approximate: empty input" {
  let points : Array[Point] = []
  let result = approximate(points, Options::default())
  inspect(result, content="")
}

///|
test "approximate: single point" {
  let points = [Point::new(0.0, 0.0)]
  let result = approximate(points, Options::default())
  inspect(result, content="")
}

///|
test "approximate: two points" {
  let points = [Point::new(0.0, 0.0), Point::new(100.0, 100.0)]
  let result = approximate(points, Options::default())
  inspect(result.has_prefix("M"), content="true")
  inspect(result.contains("C"), content="true")
}

///|
test "approximate: wave pattern" {
  // 波形パターン
  let points : Array[Point] = []
  for i = 0; i < 20; i = i + 1 {
    let x = i.to_double() * 10.0
    let y = @math.sin(i.to_double() * 0.5) * 50.0 + 50.0
    points.push(Point::new(x, y))
  }
  let result = approximate(points, Options::default())
  inspect(result != "", content="true")
  inspect(result.has_prefix("M"), content="true")
}

// ============================================================
// 閉路判定 テスト
// ============================================================

///|
test "is_closed_path: too few points" {
  let points = [Point::new(0.0, 0.0), Point::new(100.0, 0.0)]
  let result = is_closed_path(points, 10.0)
  inspect(result, content="false")
}

///|
test "is_closed_path: open path" {
  let points = [
    Point::new(0.0, 0.0),
    Point::new(100.0, 0.0),
    Point::new(100.0, 100.0),
  ]
  let result = is_closed_path(points, 10.0)
  inspect(result, content="false")
}

///|
test "is_closed_path: closed path" {
  let points = [
    Point::new(0.0, 0.0),
    Point::new(100.0, 0.0),
    Point::new(100.0, 100.0),
    Point::new(5.0, 5.0), // 始点に近い
  ]
  let result = is_closed_path(points, 10.0)
  inspect(result, content="true")
}

// ============================================================
// segments_to_points テスト
// ============================================================

///|
test "segments_to_points: converts back to points" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let points = segments_to_points(segments, 10)
  // 10サンプル + 終点
  inspect(points.length(), content="11")
  // 始点
  inspect(points[0].x, content="0")
  // 終点
  inspect(points[points.length() - 1].x, content="100")
}

// ============================================================
// Options テスト
// ============================================================

///|
test "Options::default" {
  let opts = Options::default()
  inspect(opts.min_resample_dist, content="2")
  inspect(opts.epsilon, content="1")
  inspect(opts.max_error, content="4")
}
