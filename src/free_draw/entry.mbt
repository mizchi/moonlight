// Free Draw Demo - ベジェ近似デモ

// ============================================================
// State
// ============================================================

///|
priv struct State {
  mut is_drawing : Bool
  mut points : Array[@bezier.Point]
  mut paths : Array[PathData]
  // Drag state
  mut dragging : DragState?
  // Hover state
  mut hovered_path : Int?
  // Options
  mut resample_dist : Double
  mut epsilon : Double
  mut max_error : Double
  mut show_controls : Bool
}

///|
priv struct PathData {
  segments : Array[@bezier.BezierSegment]
}

///|
/// ドラッグ状態
priv enum DragState {
  Point(DragTarget)
  Path(PathDrag)
}

///|
/// ポイントドラッグ対象
priv struct DragTarget {
  path_idx : Int
  seg_idx : Int
  point_type : PointType
}

///|
/// パス全体ドラッグ
priv struct PathDrag {
  path_idx : Int
  start_x : Double
  start_y : Double
}

///|
priv enum PointType {
  P0
  C1
  C2
  P3
}

///|
let state : State = {
  is_drawing: false,
  points: [],
  paths: [],
  dragging: None,
  hovered_path: None,
  resample_dist: 4.0,
  epsilon: 2.0,
  max_error: 8.0,
  show_controls: true,
}

// ============================================================
// FFI
// ============================================================

///|
extern "js" fn get_element_by_id(id : String) -> @js.Any =
  #| (id) => document.getElementById(id)

///|
extern "js" fn get_svg_point_x(svg : @js.Any, e : @js.Any) -> Double =
  #| (svg, e) => {
  #|   const rect = svg.getBoundingClientRect();
  #|   const clientX = e.touches ? e.touches[0].clientX : e.clientX;
  #|   return clientX - rect.left;
  #| }

///|
extern "js" fn get_svg_point_y(svg : @js.Any, e : @js.Any) -> Double =
  #| (svg, e) => {
  #|   const rect = svg.getBoundingClientRect();
  #|   const clientY = e.touches ? e.touches[0].clientY : e.clientY;
  #|   return clientY - rect.top;
  #| }

///|
extern "js" fn set_inner_html(el : @js.Any, html : String) =
  #| (el, html) => { el.innerHTML = html; }

///|
extern "js" fn set_text_content(el : @js.Any, text : String) =
  #| (el, text) => { el.textContent = text; }

///|
extern "js" fn add_event_listener(
  el : @js.Any,
  event : String,
  handler : (@js.Any) -> Unit,
) =
  #| (el, event, handler) => el.addEventListener(event, handler)

///|
extern "js" fn prevent_default(e : @js.Any) =
  #| (e) => e.preventDefault()

///|
extern "js" fn get_input_value_double(el : @js.Any) -> Double =
  #| (el) => parseFloat(el.value) || 0

///|
extern "js" fn get_checkbox_checked(el : @js.Any) -> Bool =
  #| (el) => el.checked

///|
extern "js" fn console_log(msg : String) =
  #| (msg) => console.log(msg)

///|
extern "js" fn get_drag_target(e : @js.Any) -> @js.Any =
  #| (e) => {
  #|   const el = e.target;
  #|   if (!el.classList || !el.classList.contains('draggable')) return null;
  #|   const path = el.dataset.path;
  #|   const seg = el.dataset.seg;
  #|   const type = el.dataset.type;
  #|   if (path === undefined || seg === undefined || type === undefined) return null;
  #|   return { $0: parseInt(path), $1: parseInt(seg), $2: type };
  #| }

///|
extern "js" fn is_null(v : @js.Any) -> Bool =
  #| (v) => v === null

///|
extern "js" fn get_int_field(obj : @js.Any, field : String) -> Int =
  #| (obj, field) => obj[field]

///|
extern "js" fn get_path_at_point(e : @js.Any) -> Int =
  #| (e) => {
  #|   const el = e.target;
  #|   if (!el.classList) return -1;
  #|   if (el.classList.contains('hit-area')) {
  #|     const idx = el.dataset.path;
  #|     return idx !== undefined ? parseInt(idx) : -1;
  #|   }
  #|   return -1;
  #| }

///|
extern "js" fn get_string_field(obj : @js.Any, field : String) -> String =
  #| (obj, field) => obj[field]

// ============================================================
// Rendering
// ============================================================

///|
fn render() -> Unit {
  let svg = get_element_by_id("canvas")
  let mut html = ""

  // 完了した paths を描画
  for path_idx, path in state.paths {
    if path.segments.length() == 0 {
      continue
    }
    let svg_path = @bezier.to_svg_path(path.segments)
    let is_hovered = match state.hovered_path {
      Some(idx) => idx == path_idx
      None => false
    }

    // Hit area (透明な太い線で当たり判定)
    html = html +
      "<path class=\"hit-area\" d=\"\{svg_path}\" data-path=\"\{path_idx}\"/>"

    // Visible bezier path
    let path_class = if is_hovered { "bezier-path hovered" } else { "bezier-path" }
    html = html + "<path class=\"\{path_class}\" d=\"\{svg_path}\"/>"

    // Control points and anchor points (ホバー時 or show_controls 時に表示)
    if state.show_controls || is_hovered {
      for seg_idx, seg in path.segments {
        // Control lines (anchor to control point)
        html = html +
          "<line class=\"control-line\" x1=\"\{seg.p0.x.to_int()}\" y1=\"\{seg.p0.y.to_int()}\" x2=\"\{seg.c1.x.to_int()}\" y2=\"\{seg.c1.y.to_int()}\"/>"
        html = html +
          "<line class=\"control-line\" x1=\"\{seg.p3.x.to_int()}\" y1=\"\{seg.p3.y.to_int()}\" x2=\"\{seg.c2.x.to_int()}\" y2=\"\{seg.c2.y.to_int()}\"/>"
        // Control points (handles) - draggable
        html = html +
          "<circle class=\"control-point draggable\" cx=\"\{seg.c1.x.to_int()}\" cy=\"\{seg.c1.y.to_int()}\" r=\"4\" data-path=\"\{path_idx}\" data-seg=\"\{seg_idx}\" data-type=\"c1\"/>"
        html = html +
          "<circle class=\"control-point draggable\" cx=\"\{seg.c2.x.to_int()}\" cy=\"\{seg.c2.y.to_int()}\" r=\"4\" data-path=\"\{path_idx}\" data-seg=\"\{seg_idx}\" data-type=\"c2\"/>"
        // Anchor points (on curve) - draggable
        html = html +
          "<circle class=\"anchor-point draggable\" cx=\"\{seg.p0.x.to_int()}\" cy=\"\{seg.p0.y.to_int()}\" r=\"5\" data-path=\"\{path_idx}\" data-seg=\"\{seg_idx}\" data-type=\"p0\"/>"
        html = html +
          "<circle class=\"anchor-point draggable\" cx=\"\{seg.p3.x.to_int()}\" cy=\"\{seg.p3.y.to_int()}\" r=\"5\" data-path=\"\{path_idx}\" data-seg=\"\{seg_idx}\" data-type=\"p3\"/>"
      }
    }
  }

  // 描画中の線
  if state.is_drawing && state.points.length() > 1 {
    let d = points_to_polyline(state.points)
    html = html +
      "<path class=\"raw-path\" d=\"\{d}\" stroke=\"rgba(255,255,255,0.6)\"/>"
  }
  set_inner_html(svg, html)
}

///|
fn points_to_polyline(points : Array[@bezier.Point]) -> String {
  if points.length() == 0 {
    return ""
  }
  let mut d = "M \{points[0].x} \{points[0].y}"
  for i = 1; i < points.length(); i = i + 1 {
    d = d + " L \{points[i].x} \{points[i].y}"
  }
  d
}

///|
fn update_info() -> Unit {
  let raw_count = get_element_by_id("rawCount")
  let simplified_count = get_element_by_id("simplifiedCount")
  let segment_count = get_element_by_id("segmentCount")
  let mut total_segments = 0
  for path in state.paths {
    total_segments = total_segments + path.segments.length()
  }
  let drawing_points = state.points.length()
  set_text_content(raw_count, drawing_points.to_string())
  set_text_content(simplified_count, "-")
  set_text_content(segment_count, total_segments.to_string())
}

// ============================================================
// Event Handlers
// ============================================================

///|
fn parse_drag_target(e : @js.Any) -> DragTarget? {
  let target = get_drag_target(e)
  if is_null(target) {
    return None
  }
  let path_idx = get_int_field(target, "$0")
  let seg_idx = get_int_field(target, "$1")
  let type_str = get_string_field(target, "$2")
  let point_type = match type_str {
    "p0" => P0
    "c1" => C1
    "c2" => C2
    "p3" => P3
    _ => return None
  }
  Some({ path_idx, seg_idx, point_type })
}

///|
fn on_pointer_down(e : @js.Any) -> Unit {
  prevent_default(e)
  let svg = get_element_by_id("canvas")
  let x = get_svg_point_x(svg, e)
  let y = get_svg_point_y(svg, e)

  // Check if clicking on a draggable point
  match parse_drag_target(e) {
    Some(target) => {
      state.dragging = Some(Point(target))
      return
    }
    None => ()
  }

  // Check if clicking on a path hit area
  let path_idx = get_path_at_point(e)
  if path_idx >= 0 {
    state.dragging = Some(Path({ path_idx, start_x: x, start_y: y }))
    return
  }

  // Start drawing
  state.is_drawing = true
  state.points = [@bezier.Point::new(x, y)]
  render()
}

///|
fn on_pointer_move(e : @js.Any) -> Unit {
  let svg = get_element_by_id("canvas")
  let x = get_svg_point_x(svg, e)
  let y = get_svg_point_y(svg, e)

  // Handle dragging
  match state.dragging {
    Some(Point(target)) => {
      prevent_default(e)
      update_point(target, x, y)
      render()
      return
    }
    Some(Path(drag)) => {
      prevent_default(e)
      let dx = x - drag.start_x
      let dy = y - drag.start_y
      move_path(drag.path_idx, dx, dy)
      state.dragging = Some(Path({ ..drag, start_x: x, start_y: y }))
      render()
      return
    }
    None => ()
  }

  // Handle hover detection
  let path_idx = get_path_at_point(e)
  let new_hovered : Int? = if path_idx >= 0 { Some(path_idx) } else { None }
  if new_hovered != state.hovered_path {
    state.hovered_path = new_hovered
    render()
  }

  // Handle drawing
  if not(state.is_drawing) {
    return
  }
  prevent_default(e)
  state.points.push(@bezier.Point::new(x, y))
  render()
  update_info()
}

///|
fn update_point(target : DragTarget, x : Double, y : Double) -> Unit {
  if target.path_idx >= state.paths.length() {
    return
  }
  let path = state.paths[target.path_idx]
  if target.seg_idx >= path.segments.length() {
    return
  }
  let seg = path.segments[target.seg_idx]
  let new_point = @bezier.Point::new(x, y)

  // Update the specific point
  let new_seg : @bezier.BezierSegment = match target.point_type {
    P0 => { ..seg, p0: new_point }
    C1 => { ..seg, c1: new_point }
    C2 => { ..seg, c2: new_point }
    P3 => { ..seg, p3: new_point }
  }
  path.segments[target.seg_idx] = new_seg

  // If moving P0 or P3, also update adjacent segments
  match target.point_type {
    P0 =>
      // Update previous segment's P3 if exists
      if target.seg_idx > 0 {
        let prev_seg = path.segments[target.seg_idx - 1]
        path.segments[target.seg_idx - 1] = { ..prev_seg, p3: new_point }
      }
    P3 =>
      // Update next segment's P0 if exists
      if target.seg_idx + 1 < path.segments.length() {
        let next_seg = path.segments[target.seg_idx + 1]
        path.segments[target.seg_idx + 1] = { ..next_seg, p0: new_point }
      }
    _ => ()
  }
}

///|
fn move_path(path_idx : Int, dx : Double, dy : Double) -> Unit {
  if path_idx >= state.paths.length() {
    return
  }
  let path = state.paths[path_idx]
  for i, seg in path.segments {
    let new_seg : @bezier.BezierSegment = {
      p0: @bezier.Point::new(seg.p0.x + dx, seg.p0.y + dy),
      c1: @bezier.Point::new(seg.c1.x + dx, seg.c1.y + dy),
      c2: @bezier.Point::new(seg.c2.x + dx, seg.c2.y + dy),
      p3: @bezier.Point::new(seg.p3.x + dx, seg.p3.y + dy),
    }
    path.segments[i] = new_seg
  }
}

///|
fn on_pointer_up(_e : @js.Any) -> Unit {
  // End dragging
  if state.dragging is Some(_) {
    state.dragging = None
    render()
    return
  }

  // End drawing
  if not(state.is_drawing) {
    return
  }
  state.is_drawing = false
  if state.points.length() >= 2 {
    // ベジェ近似を実行
    let options : @bezier.Options = {
      min_resample_dist: state.resample_dist,
      epsilon: state.epsilon,
      max_error: state.max_error,
    }
    let raw_count = state.points.length()
    let resampled = @bezier.resample(state.points, options.min_resample_dist)
    let resampled_count = resampled.length()
    let simplified = @bezier.rdp_simplify(resampled, options.epsilon)
    let simplified_count = simplified.length()
    let segments = @bezier.fit_bezier(simplified, options.max_error)
    let segment_count = segments.length()

    // 圧縮率をログ出力
    let ratio = if raw_count > 0 {
      (segment_count.to_double() * 4.0 / raw_count.to_double() * 100.0).to_int()
    } else {
      0
    }
    console_log(
      "[Bezier] Raw: \{raw_count} -> Resampled: \{resampled_count} -> RDP: \{simplified_count} -> Segments: \{segment_count} (control points: \{segment_count * 4}) | Compression: \{ratio}%",
    )

    let path_data : PathData = { segments, }
    state.paths.push(path_data)
  }
  state.points = []
  render()
  update_info()
}

///|
fn on_clear() -> Unit {
  state.paths = []
  state.points = []
  render()
  update_info()
}

///|
fn on_resample_change(e : @js.Any) -> Unit {
  state.resample_dist = get_input_value_double(e.cast())
}

///|
fn on_epsilon_change(e : @js.Any) -> Unit {
  state.epsilon = get_input_value_double(e.cast())
}

///|
fn on_max_error_change(e : @js.Any) -> Unit {
  state.max_error = get_input_value_double(e.cast())
}

///|
fn on_show_controls_change(e : @js.Any) -> Unit {
  state.show_controls = get_checkbox_checked(e.cast())
  render()
}

// ============================================================
// Init
// ============================================================

///|
fn main {
  let svg = get_element_by_id("canvas")

  // Pointer events
  add_event_listener(svg, "pointerdown", on_pointer_down)
  add_event_listener(svg, "pointermove", on_pointer_move)
  add_event_listener(svg, "pointerup", on_pointer_up)
  add_event_listener(svg, "pointerleave", on_pointer_up)

  // Touch events (for mobile)
  add_event_listener(svg, "touchstart", on_pointer_down)
  add_event_listener(svg, "touchmove", on_pointer_move)
  add_event_listener(svg, "touchend", on_pointer_up)

  // Controls
  let resample_input = get_element_by_id("resample")
  let epsilon_input = get_element_by_id("epsilon")
  let max_error_input = get_element_by_id("maxError")
  let show_controls_input = get_element_by_id("showControls")
  let clear_btn = get_element_by_id("clear")
  add_event_listener(resample_input, "input", fn(e) { on_resample_change(e) })
  add_event_listener(epsilon_input, "input", fn(e) { on_epsilon_change(e) })
  add_event_listener(max_error_input, "input", fn(e) { on_max_error_change(e) })
  add_event_listener(show_controls_input, "change", fn(e) {
    on_show_controls_change(e)
  })
  add_event_listener(clear_btn, "click", fn(_e) { on_clear() })
  render()
  update_info()
}
