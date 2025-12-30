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

// ============================================================
// セグメント分割 テスト (de Casteljau)
// ============================================================

///|
test "split_segment: t=0.5 preserves endpoints" {
  let seg : BezierSegment = {
    p0: Point::new(0.0, 0.0),
    c1: Point::new(0.0, 100.0),
    c2: Point::new(100.0, 100.0),
    p3: Point::new(100.0, 0.0),
  }
  let (left, right) = split_segment(seg, 0.5)
  // 左の始点 = 元の始点
  inspect(left.p0.x, content="0")
  inspect(left.p0.y, content="0")
  // 右の終点 = 元の終点
  inspect(right.p3.x, content="100")
  inspect(right.p3.y, content="0")
  // 分割点は共有
  inspect(left.p3.x == right.p0.x, content="true")
  inspect(left.p3.y == right.p0.y, content="true")
}

///|
test "split_segment: midpoint matches bezier_point" {
  let seg : BezierSegment = {
    p0: Point::new(0.0, 0.0),
    c1: Point::new(0.0, 100.0),
    c2: Point::new(100.0, 100.0),
    p3: Point::new(100.0, 0.0),
  }
  let t = 0.3
  let expected = bezier_point(seg, t)
  let (left, _) = split_segment(seg, t)
  // 分割点は bezier_point と一致
  inspect((left.p3.x - expected.x).abs() < 0.001, content="true")
  inspect((left.p3.y - expected.y).abs() < 0.001, content="true")
}

///|
test "split_segment: curve continuity" {
  let seg : BezierSegment = {
    p0: Point::new(0.0, 0.0),
    c1: Point::new(50.0, 100.0),
    c2: Point::new(50.0, 100.0),
    p3: Point::new(100.0, 0.0),
  }
  let (left, right) = split_segment(seg, 0.5)
  // 分割後の曲線上の点を確認
  let mid_left = bezier_point(left, 0.5)
  let mid_right = bezier_point(right, 0.5)
  // 曲線内の点がある
  inspect(mid_left.x > 0.0 && mid_left.x < 50.0, content="true")
  inspect(mid_right.x > 50.0 && mid_right.x < 100.0, content="true")
}

// ============================================================
// アンカー挿入 テスト
// ============================================================

///|
test "insert_anchor: increases segment count" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = insert_anchor(segments, 0, 0.5)
  inspect(result.length(), content="2")
}

///|
test "insert_anchor: preserves path endpoints" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = insert_anchor(segments, 0, 0.5)
  // 始点
  inspect(result[0].p0.x, content="0")
  // 終点
  inspect(result[result.length() - 1].p3.x, content="100")
}

///|
test "insert_anchor: invalid index returns copy" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = insert_anchor(segments, 5, 0.5)
  inspect(result.length(), content="1")
}

// ============================================================
// アンカー削除 テスト
// ============================================================

///|
test "delete_anchor: decreases segment count" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 25.0),
      c2: Point::new(40.0, 25.0),
      p3: Point::new(50.0, 0.0),
    },
    {
      p0: Point::new(50.0, 0.0),
      c1: Point::new(60.0, 25.0),
      c2: Point::new(75.0, 25.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = delete_anchor(segments, 1)
  inspect(result.length(), content="1")
}

///|
test "delete_anchor: preserves path endpoints" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 25.0),
      c2: Point::new(40.0, 25.0),
      p3: Point::new(50.0, 0.0),
    },
    {
      p0: Point::new(50.0, 0.0),
      c1: Point::new(60.0, 25.0),
      c2: Point::new(75.0, 25.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = delete_anchor(segments, 1)
  inspect(result[0].p0.x, content="0")
  inspect(result[0].p3.x, content="100")
}

///|
test "delete_anchor: boundary index returns copy" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  // インデックス 0 は先頭なので削除不可
  let result = delete_anchor(segments, 0)
  inspect(result.length(), content="1")
}

// ============================================================
// パスマージ テスト
// ============================================================

///|
test "merge_paths: combines segments" {
  let path_a : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let path_b : Array[BezierSegment] = [
    {
      p0: Point::new(100.0, 0.0),
      c1: Point::new(125.0, 50.0),
      c2: Point::new(175.0, 50.0),
      p3: Point::new(200.0, 0.0),
    },
  ]
  let result = merge_paths(path_a, path_b)
  // 終点と始点が一致するのでコネクタなし
  inspect(result.length(), content="2")
}

///|
test "merge_paths: adds connector when not touching" {
  let path_a : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let path_b : Array[BezierSegment] = [
    {
      p0: Point::new(150.0, 0.0), // gap of 50
      c1: Point::new(175.0, 50.0),
      c2: Point::new(225.0, 50.0),
      p3: Point::new(250.0, 0.0),
    },
  ]
  let result = merge_paths(path_a, path_b)
  // コネクタが追加される
  inspect(result.length(), content="3")
}

///|
test "merge_paths: empty path_a" {
  let path_a : Array[BezierSegment] = []
  let path_b : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let result = merge_paths(path_a, path_b)
  inspect(result.length(), content="1")
}

// ============================================================
// パス分割 テスト
// ============================================================

///|
test "split_path: splits at index" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
    {
      p0: Point::new(100.0, 0.0),
      c1: Point::new(125.0, 50.0),
      c2: Point::new(175.0, 50.0),
      p3: Point::new(200.0, 0.0),
    },
  ]
  let (left, right) = split_path(segments, 1)
  inspect(left.length(), content="1")
  inspect(right.length(), content="1")
}

///|
test "split_path: index 0 returns all in right" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let (left, right) = split_path(segments, 0)
  inspect(left.length(), content="0")
  inspect(right.length(), content="1")
}

///|
test "disconnect_at_anchor: same as split_path" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
    {
      p0: Point::new(100.0, 0.0),
      c1: Point::new(125.0, 50.0),
      c2: Point::new(175.0, 50.0),
      p3: Point::new(200.0, 0.0),
    },
  ]
  let (left, right) = disconnect_at_anchor(segments, 1)
  inspect(left.length(), content="1")
  inspect(right.length(), content="1")
}

// ============================================================
// 再計算 テスト
// ============================================================

///|
test "refit: produces valid segments" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
  ]
  let options : Options = { min_resample_dist: 2.0, epsilon: 1.0, max_error: 4.0 }
  let result = refit(segments, 20, options)
  inspect(result.length() >= 1, content="true")
  // 始点と終点は近い位置に
  inspect(result[0].p0.distance(Point::new(0.0, 0.0)) < 5.0, content="true")
  inspect(
    result[result.length() - 1].p3.distance(Point::new(100.0, 0.0)) < 5.0,
    content="true",
  )
}

///|
test "refit: empty returns empty" {
  let segments : Array[BezierSegment] = []
  let options = Options::default()
  let result = refit(segments, 20, options)
  inspect(result.length(), content="0")
}

///|
test "refit_range: only affects range" {
  let segments : Array[BezierSegment] = [
    {
      p0: Point::new(0.0, 0.0),
      c1: Point::new(25.0, 50.0),
      c2: Point::new(75.0, 50.0),
      p3: Point::new(100.0, 0.0),
    },
    {
      p0: Point::new(100.0, 0.0),
      c1: Point::new(125.0, 50.0),
      c2: Point::new(175.0, 50.0),
      p3: Point::new(200.0, 0.0),
    },
    {
      p0: Point::new(200.0, 0.0),
      c1: Point::new(225.0, 50.0),
      c2: Point::new(275.0, 50.0),
      p3: Point::new(300.0, 0.0),
    },
  ]
  let options : Options = { min_resample_dist: 2.0, epsilon: 1.0, max_error: 4.0 }
  let result = refit_range(segments, 1, 2, 20, options)
  // 最初と最後のセグメントの始点・終点は変わらない
  inspect(result[0].p0.x, content="0")
  inspect(result[result.length() - 1].p3.x, content="300")
}
