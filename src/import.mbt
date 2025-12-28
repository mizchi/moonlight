// SVG Import 機能

///|
/// SVG文字列をパースして Element 配列を返す
pub fn import_svg_elements(
  svg_str : String,
  new_id : () -> String,
) -> Array[@model.Element] {
  let svg_el = parse_svg_string(svg_str)
  if @js.is_nullish(svg_el) {
    return []
  }
  // Moonlight形式かチェック
  let is_moonlight = not(@js.is_nullish(get_attribute(svg_el, "data-moonlight")))
  let children = get_svg_children(svg_el)
  let elements : Array[@model.Element] = []
  let id_map : Array[(String, String)] = [] // (old_id, new_id) for Moonlight format
  // 子要素をパース
  let children_array : Array[@js.Any] = children.cast()
  for child in children_array {
    let tag = get_tag_name(child)
    // defs, rect(背景) はスキップ
    if tag == "defs" {
      continue
    }
    let el_opt = if is_moonlight {
      parse_moonlight_element(child, new_id, id_map)
    } else {
      parse_plain_svg_element(child, new_id)
    }
    if el_opt is Some(el) {
      elements.push(el)
    }
  }
  // Moonlight形式の場合、接続情報のIDを更新
  if is_moonlight {
    update_connection_ids(elements, id_map)
  }
  elements
}

///|
/// Moonlight形式の要素をパース
fn parse_moonlight_element(
  el : @js.Any,
  new_id : () -> String,
  id_map : Array[(String, String)],
) -> @model.Element? {
  let tag = get_tag_name(el)
  // 基本属性
  let old_id_raw = get_attribute(el, "data-id")
  let old_id = if @js.is_nullish(old_id_raw) {
    ""
  } else {
    let s : String = old_id_raw.cast()
    s
  }
  // 新しいIDを生成してマップに追加
  let el_id = new_id()
  if old_id != "" {
    id_map.push((old_id, el_id))
  }
  // parent_id
  let parent_id_raw = get_attribute(el, "data-parent-id")
  let parent_id : String? = if @js.is_nullish(parent_id_raw) {
    None
  } else {
    let s : String = parent_id_raw.cast()
    if s == "" { None } else { Some(s) }
  }
  // 接続情報
  let connections = parse_connections(el)
  // スタイル
  let style = parse_style(el)
  // 図形をパース
  let shape_opt = parse_shape(el, tag)
  match shape_opt {
    Some(shape_data) => {
      let (shape, x, y) = shape_data
      Some({
        id: el_id,
        x,
        y,
        shape,
        style,
        transform: None,
        parent_id,
        connections,
      })
    }
    None => None
  }
}

///|
/// プレーンSVG要素をパース
fn parse_plain_svg_element(
  el : @js.Any,
  new_id : () -> String,
) -> @model.Element? {
  let tag = get_tag_name(el)
  let el_id = new_id()
  let style = parse_style(el)
  let shape_opt = parse_shape(el, tag)
  match shape_opt {
    Some(shape_data) => {
      let (shape, x, y) = shape_data
      Some({
        id: el_id,
        x,
        y,
        shape,
        style,
        transform: None,
        parent_id: None,
        connections: None,
      })
    }
    None => None
  }
}

///|
/// 図形をパース（タグ名に基づいて）
fn parse_shape(el : @js.Any, tag : String) -> ((@model.ShapeType, Double, Double))? {
  match tag {
    "rect" => {
      // 背景用rect（data-idがなく、width/height が 100%）はスキップ
      let width_raw = get_attribute(el, "width")
      if not(@js.is_nullish(width_raw)) {
        let width_str : String = width_raw.cast()
        if width_str == "100%" {
          return None
        }
      }
      let x = parse_attr_double(el, "x", 0.0)
      let y = parse_attr_double(el, "y", 0.0)
      let w = parse_attr_double(el, "width", 100.0)
      let h = parse_attr_double(el, "height", 100.0)
      let rx = parse_attr_double_opt(el, "rx")
      let ry = parse_attr_double_opt(el, "ry")
      Some((@model.Rect(w, h, rx, ry), x, y))
    }
    "circle" => {
      let cx = parse_attr_double(el, "cx", 0.0)
      let cy = parse_attr_double(el, "cy", 0.0)
      let r = parse_attr_double(el, "r", 50.0)
      Some((@model.Circle(r), cx, cy))
    }
    "ellipse" => {
      let cx = parse_attr_double(el, "cx", 0.0)
      let cy = parse_attr_double(el, "cy", 0.0)
      let rx = parse_attr_double(el, "rx", 50.0)
      let ry = parse_attr_double(el, "ry", 30.0)
      Some((@model.Ellipse(rx, ry), cx, cy))
    }
    "line" => {
      let x1 = parse_attr_double(el, "x1", 0.0)
      let y1 = parse_attr_double(el, "y1", 0.0)
      let x2 = parse_attr_double(el, "x2", 100.0)
      let y2 = parse_attr_double(el, "y2", 100.0)
      Some((@model.Line(x2, y2), x1, y1))
    }
    "text" => {
      let x = parse_attr_double(el, "x", 0.0)
      let y = parse_attr_double(el, "y", 0.0)
      let content = get_text_content(el)
      let font_size = parse_attr_double_opt(el, "font-size")
      Some((@model.Text(content, font_size), x, y))
    }
    "polyline" => {
      let points_raw = get_attribute(el, "points")
      if @js.is_nullish(points_raw) {
        return None
      }
      let points_str : String = points_raw.cast()
      let points = parse_points(points_str)
      if points.length() == 0 {
        return None
      }
      let first = points[0]
      Some((@model.Polyline(points), first.x, first.y))
    }
    "path" => {
      let d_raw = get_attribute(el, "d")
      if @js.is_nullish(d_raw) {
        return None
      }
      let d : String = d_raw.cast()
      // pathの開始座標を取得（簡易実装）
      Some((@model.Path(d), 0.0, 0.0))
    }
    _ => None
  }
}

///|
/// 属性から Double をパース
fn parse_attr_double(el : @js.Any, name : String, default : Double) -> Double {
  let raw = get_attribute(el, name)
  if @js.is_nullish(raw) {
    return default
  }
  let s : String = raw.cast()
  match parse_double(s) {
    Some(v) => v
    None => default
  }
}

///|
/// 属性から Double をパース（オプション）
fn parse_attr_double_opt(el : @js.Any, name : String) -> Double? {
  let raw = get_attribute(el, name)
  if @js.is_nullish(raw) {
    return None
  }
  let s : String = raw.cast()
  parse_double(s)
}

///|
/// スタイル属性をパース
fn parse_style(el : @js.Any) -> @model.Style {
  let fill_raw = get_attribute(el, "fill")
  let fill : String? = if @js.is_nullish(fill_raw) {
    None
  } else {
    let s : String = fill_raw.cast()
    if s == "none" { None } else { Some(s) }
  }
  let stroke_raw = get_attribute(el, "stroke")
  let stroke : String? = if @js.is_nullish(stroke_raw) {
    None
  } else {
    Some(stroke_raw.cast())
  }
  let stroke_width = parse_attr_double_opt(el, "stroke-width")
  let opacity = parse_attr_double_opt(el, "opacity")
  let dasharray_raw = get_attribute(el, "stroke-dasharray")
  let stroke_dasharray : String? = if @js.is_nullish(dasharray_raw) {
    None
  } else {
    Some(dasharray_raw.cast())
  }
  // マーカー
  let marker_start_raw = get_attribute(el, "marker-start")
  let marker_start : @model.ArrowType? = if @js.is_nullish(marker_start_raw) {
    None
  } else {
    Some(@model.Arrow)
  }
  let marker_end_raw = get_attribute(el, "marker-end")
  let marker_end : @model.ArrowType? = if @js.is_nullish(marker_end_raw) {
    None
  } else {
    Some(@model.Arrow)
  }
  {
    fill,
    stroke,
    stroke_width,
    opacity,
    stroke_dasharray,
    marker_start,
    marker_end,
  }
}

///|
/// 接続情報をパース
fn parse_connections(el : @js.Any) -> @model.LineConnections? {
  let start_raw = get_attribute(el, "data-connection-start")
  let end_raw = get_attribute(el, "data-connection-end")
  if @js.is_nullish(start_raw) && @js.is_nullish(end_raw) {
    return None
  }
  let start = if @js.is_nullish(start_raw) {
    None
  } else {
    let s : String = start_raw.cast()
    parse_connection_string(s)
  }
  let end_ = if @js.is_nullish(end_raw) {
    None
  } else {
    let s : String = end_raw.cast()
    parse_connection_string(s)
  }
  Some({ start, end: end_ })
}

///|
/// 接続文字列をパース (format: "element-id:anchor")
fn parse_connection_string(s : String) -> @model.Connection? {
  // "element-id:anchor" 形式
  let parts : Array[String] = s.split(":").map(fn(sv) { sv.to_string() }).collect()
  if parts.length() != 2 {
    return None
  }
  let element_id = parts[0]
  let anchor_str = parts[1]
  match @model.parse_anchor(anchor_str) {
    Some(anchor) => Some({ element_id, anchor })
    None => None
  }
}

///|
/// points 属性をパース
fn parse_points(s : String) -> Array[@model.Point] {
  let points : Array[@model.Point] = []
  let pairs : Array[String] = s.split(" ").map(fn(sv) { sv.to_string() }).collect()
  for pair in pairs {
    let coords : Array[String] = pair.split(",").map(fn(sv) { sv.to_string() }).collect()
    if coords.length() == 2 {
      if parse_double(coords[0]) is Some(x) {
        if parse_double(coords[1]) is Some(y) {
          points.push({ x, y })
        }
      }
    }
  }
  points
}

///|
/// 接続情報のIDを更新（古いID → 新しいID）
fn update_connection_ids(
  elements : Array[@model.Element],
  id_map : Array[(String, String)],
) -> Unit {
  // IDマップから新しいIDを検索
  let find_new_id = fn(old_id : String) -> String {
    for mapping in id_map {
      let (o, n) = mapping
      if o == old_id {
        return n
      }
    }
    old_id
  }
  // 各要素の接続情報とparent_idを更新
  for i = 0; i < elements.length(); i = i + 1 {
    let el = elements[i]
    // parent_id を更新
    let new_parent_id = match el.parent_id {
      Some(pid) => Some(find_new_id(pid))
      None => None
    }
    // connections を更新
    let new_connections = match el.connections {
      Some(conns) => {
        let new_start : @model.Connection? = match conns.start {
          Some(conn) => {
            let c : @model.Connection = {
              element_id: find_new_id(conn.element_id),
              anchor: conn.anchor,
            }
            Some(c)
          }
          None => None
        }
        let new_end : @model.Connection? = match conns.end {
          Some(conn) => {
            let c : @model.Connection = {
              element_id: find_new_id(conn.element_id),
              anchor: conn.anchor,
            }
            Some(c)
          }
          None => None
        }
        let lc : @model.LineConnections = { start: new_start, end: new_end }
        Some(lc)
      }
      None => None
    }
    elements[i] = { ..el, parent_id: new_parent_id, connections: new_connections }
  }
}
