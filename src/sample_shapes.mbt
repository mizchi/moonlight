///|
/// サンプル図形を追加
pub fn add_sample_shapes(
  state : @core.EditorState,
  new_id : () -> String,
) -> Unit {
  let text_style = state.get_text_style()
  let arrow_style = state.get_arrow_style()

  // カスタムスタイル
  let magenta_fill : @model.Style = {
    fill: Some("#e040e0"),
    stroke: Some("#c030c0"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let blue_stroke : @model.Style = {
    fill: Some("transparent"),
    stroke: Some("#3355aa"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let yellow_fill : @model.Style = {
    fill: Some("#ffee44"),
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let yellow_stroke : @model.Style = {
    fill: Some("transparent"),
    stroke: Some("#ddcc00"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let brown_fill : @model.Style = {
    fill: Some("#8b7080"),
    stroke: Some("#6b5060"),
    stroke_width: Some(2.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }
  let default_rect : @model.Style = {
    fill: Some("transparent"),
    stroke: Some(@model.css_var_stroke),
    stroke_width: Some(1.0),
    opacity: None,
    stroke_dasharray: None,
    marker_start: None,
    marker_end: None,
    font_family: None,
  }

  // 行1: Moonbit → Luna → JS
  // Moonbit (マゼンタの円)
  let moonbit_id = new_id()
  let moonbit = @model.Element::new(moonbit_id, 55.0, 65.0, @model.Circle(35.0)).with_style(
    magenta_fill,
  )
  let moonbit_text_id = new_id()
  let moonbit_text = @model.Element::new(
      moonbit_text_id,
      55.0,
      65.0,
      @model.Text("Moonbit", Some(14.0)),
    )
    .with_style(text_style)
    .with_parent(moonbit_id)

  // Luna (青い枠の矩形)
  let luna_id = new_id()
  let luna = @model.Element::new(
    luna_id,
    130.0,
    40.0,
    @model.Rect(100.0, 50.0, None, None),
  ).with_style(blue_stroke)
  let luna_text_id = new_id()
  let luna_text = @model.Element::new(
      luna_text_id,
      180.0,
      65.0,
      @model.Text("Luna", Some(16.0)),
    )
    .with_style(text_style)
    .with_parent(luna_id)

  // JS (黄色背景の矩形)
  let js_id = new_id()
  let js = @model.Element::new(
    js_id,
    280.0,
    40.0,
    @model.Rect(70.0, 50.0, None, None),
  ).with_style(yellow_fill)
  let js_text_id = new_id()
  let js_text = @model.Element::new(
      js_text_id,
      315.0,
      65.0,
      @model.Text("JS", Some(18.0)),
    )
    .with_style(text_style)
    .with_parent(js_id)

  // 矢印: Moonbit → Luna
  let arrow1_id = new_id()
  let arrow1 = @model.Element::new(
    arrow1_id,
    90.0,
    65.0,
    @model.Line(130.0, 65.0),
  ).with_style(arrow_style)
  let arrow1_conn = {
    ..arrow1,
    connections: Some({
      start: Some({ element_id: moonbit_id, anchor: @model.Right }),
      end: Some({ element_id: luna_id, anchor: @model.Left }),
    }),
  }

  // 矢印: Luna → JS
  let arrow2_id = new_id()
  let arrow2 = @model.Element::new(
    arrow2_id,
    230.0,
    65.0,
    @model.Line(280.0, 65.0),
  ).with_style(arrow_style)
  let arrow2_conn = {
    ..arrow2,
    connections: Some({
      start: Some({ element_id: luna_id, anchor: @model.Right }),
      end: Some({ element_id: js_id, anchor: @model.Left }),
    }),
  }

  // 行2: Excalidraw → Moonlight → Svg
  // Excalidraw (黄色い枠の楕円)
  let excalidraw_id = new_id()
  let excalidraw = @model.Element::new(
    excalidraw_id,
    55.0,
    200.0,
    @model.Ellipse(50.0, 28.0),
  ).with_style(yellow_stroke)
  let excalidraw_text_id = new_id()
  let excalidraw_text = @model.Element::new(
      excalidraw_text_id,
      55.0,
      200.0,
      @model.Text("Excalidraw", Some(12.0)),
    )
    .with_style(text_style)
    .with_parent(excalidraw_id)

  // Moonlight (茶色の塗りつぶし矩形)
  let moonlight_id = new_id()
  let moonlight = @model.Element::new(
    moonlight_id,
    150.0,
    160.0,
    @model.Rect(100.0, 70.0, None, None),
  ).with_style(brown_fill)
  let moonlight_text_id = new_id()
  let moonlight_text = @model.Element::new(
      moonlight_text_id,
      200.0,
      195.0,
      @model.Text("Moonlight", Some(14.0)),
    )
    .with_style(text_style)
    .with_parent(moonlight_id)

  // Svg (白い矩形)
  let svg_id = new_id()
  let svg = @model.Element::new(
    svg_id,
    300.0,
    165.0,
    @model.Rect(70.0, 60.0, None, None),
  ).with_style(default_rect)
  let svg_text_id = new_id()
  let svg_text = @model.Element::new(
      svg_text_id,
      335.0,
      195.0,
      @model.Text("Svg", Some(16.0)),
    )
    .with_style(text_style)
    .with_parent(svg_id)

  // 矢印: Luna → Moonlight (下向き)
  let arrow3_id = new_id()
  let arrow3 = @model.Element::new(
    arrow3_id,
    180.0,
    90.0,
    @model.Line(200.0, 160.0),
  ).with_style(arrow_style)
  let arrow3_conn = {
    ..arrow3,
    connections: Some({
      start: Some({ element_id: luna_id, anchor: @model.Bottom }),
      end: Some({ element_id: moonlight_id, anchor: @model.Top }),
    }),
  }

  // 矢印: Excalidraw → Moonlight
  let arrow4_id = new_id()
  let arrow4 = @model.Element::new(
    arrow4_id,
    105.0,
    200.0,
    @model.Line(150.0, 195.0),
  ).with_style(arrow_style)
  let arrow4_conn = {
    ..arrow4,
    connections: Some({
      start: Some({ element_id: excalidraw_id, anchor: @model.Right }),
      end: Some({ element_id: moonlight_id, anchor: @model.Left }),
    }),
  }

  // 矢印: Moonlight → Svg
  let arrow5_id = new_id()
  let arrow5 = @model.Element::new(
    arrow5_id,
    250.0,
    195.0,
    @model.Line(300.0, 195.0),
  ).with_style(arrow_style)
  let arrow5_conn = {
    ..arrow5,
    connections: Some({
      start: Some({ element_id: moonlight_id, anchor: @model.Right }),
      end: Some({ element_id: svg_id, anchor: @model.Left }),
    }),
  }

  // 要素を追加
  state.add_element_raw(moonbit)
  state.add_element_raw(moonbit_text)
  state.add_element_raw(luna)
  state.add_element_raw(luna_text)
  state.add_element_raw(js)
  state.add_element_raw(js_text)
  state.add_element_raw(excalidraw)
  state.add_element_raw(excalidraw_text)
  state.add_element_raw(moonlight)
  state.add_element_raw(moonlight_text)
  state.add_element_raw(svg)
  state.add_element_raw(svg_text)
  // 矢印は最後に追加（最前面に表示）
  state.add_element_raw(arrow1_conn)
  state.add_element_raw(arrow2_conn)
  state.add_element_raw(arrow3_conn)
  state.add_element_raw(arrow4_conn)
  state.add_element_raw(arrow5_conn)
}
