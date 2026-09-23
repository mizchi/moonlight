// 矢印キーによる編集 - スタンドアロンと埋め込みで同じ挙動を使う
//
// 以前はこの一式が src/main.mbt にだけあり、埋め込み側 (setup_keyboard_handler)
// からは呼べなかった。シェルごとに矢印の挙動が変わってしまうので、両方から
// 呼べるこの層に置く。

///|
/// 矢印キー方向に応じて図形をリサイズ
/// 戻り値: (新しい shape, 新しい x, 新しい y)
fn resize_shape_by_arrow(
  shape : @model.ShapeType,
  x : Double,
  y : Double,
  key : String,
  step : Double,
) -> (@model.ShapeType, Double, Double) {
  let min_size = 10.0 // 最小サイズ
  match shape {
    @model.Rect(w, h, rx, ry) =>
      match key {
        "ArrowRight" => (@model.Rect(w + step, h, rx, ry), x, y)
        "ArrowLeft" => {
          let new_w = if w + step >= min_size { w + step } else { min_size }
          (@model.Rect(new_w, h, rx, ry), x - step, y)
        }
        "ArrowDown" => (@model.Rect(w, h + step, rx, ry), x, y)
        "ArrowUp" => {
          let new_h = if h + step >= min_size { h + step } else { min_size }
          (@model.Rect(w, new_h, rx, ry), x, y - step)
        }
        _ => (shape, x, y)
      }
    @model.Circle(r) => {
      // 円は全方向同じ（半径を増加）
      let new_r = if r + step >= min_size / 2.0 {
        r + step
      } else {
        min_size / 2.0
      }
      (@model.Circle(new_r), x, y)
    }
    @model.Ellipse(rx, ry) =>
      match key {
        "ArrowRight" | "ArrowLeft" => {
          let new_rx = if rx + step >= min_size / 2.0 {
            rx + step
          } else {
            min_size / 2.0
          }
          (@model.Ellipse(new_rx, ry), x, y)
        }
        "ArrowDown" | "ArrowUp" => {
          let new_ry = if ry + step >= min_size / 2.0 {
            ry + step
          } else {
            min_size / 2.0
          }
          (@model.Ellipse(rx, new_ry), x, y)
        }
        _ => (shape, x, y)
      }
    @model.Line(x2, y2) =>
      match key {
        "ArrowRight" => (@model.Line(x2 + step, y2), x, y)
        "ArrowLeft" => (@model.Line(x2, y2), x - step, y)
        "ArrowDown" => (@model.Line(x2, y2 + step), x, y)
        "ArrowUp" => (@model.Line(x2, y2), x, y - step)
        _ => (shape, x, y)
      }
    @model.Text(content, font_size) => {
      // テキストはフォントサイズを変更
      let size = font_size.unwrap_or(16.0)
      match key {
        "ArrowRight" | "ArrowDown" => {
          let new_size = size + step / 2.0
          (@model.Text(content, Some(new_size)), x, y)
        }
        "ArrowLeft" | "ArrowUp" => {
          let new_size = if size - step / 2.0 >= 8.0 {
            size - step / 2.0
          } else {
            8.0
          }
          (@model.Text(content, Some(new_size)), x, y)
        }
        _ => (shape, x, y)
      }
    }
    _ => (shape, x, y) // Polyline, Path はそのまま
  }
}

///|
/// 矢印キーで選択要素をリサイズ
///
/// 線は端点がひとつ動く。その端点が結合していれば結合は外す（マウスで端点を
/// 引き離したときと同じ）。動いたのに繋がったままだと、線は結合先から浮いた
/// まま残り、結合先を動かしたとたんにそこへ飛び戻る。
fn resize_selected_by_arrow(
  state : @core.EditorState,
  history : @model.History,
  selected_ids : Array[String],
  key : String,
  step : Double,
) -> Unit {
  let before = state.elements.get()
  for id in selected_ids {
    guard state.find_element(id) is Some(el) else { continue }
    let (new_shape, new_x, new_y) = resize_shape_by_arrow(
      el.shape,
      el.x,
      el.y,
      key,
      step,
    )
    let connections = release_moved_endpoints(el, new_shape, new_x, new_y)
    // 要素をリサイズ
    state.update_element(id, fn(e) {
      { ..e, shape: new_shape, x: new_x, y: new_y, connections, }
    })
    // 関連要素（子テキスト、接続ライン）を同期更新
    state.sync_related_elements(id)
  }
  // 子要素・接続ラインの追随まで含めて一段の履歴にする
  @core.record_change(history, before, state.elements.get())
}

///|
/// 線の端点が動いたなら、その端点の結合を外した接続情報を返す
fn release_moved_endpoints(
  el : @model.Element,
  new_shape : @model.ShapeType,
  new_x : Double,
  new_y : Double,
) -> @model.LineConnections? {
  guard el.shape is @model.Line(x2, y2) else { return el.connections }
  guard el.connections is Some(conns) else { return None }
  let start_moved = new_x != el.x || new_y != el.y
  let end_moved = match new_shape {
    @model.Line(nx2, ny2) => nx2 != x2 || ny2 != y2
    _ => false
  }
  let next : @model.LineConnections = {
    start: if start_moved {
      None
    } else {
      conns.start
    },
    end: if end_moved {
      None
    } else {
      conns.end
    },
  }
  if next.start is None && next.end is None {
    None
  } else {
    Some(next)
  }
}

///|
/// 矢印キーで選択要素を移動
///
/// 一つだけ選んでいるときはマウスで掴んで動かしたときと同じ（線なら結合先を
/// 連れて動く）。複数なら複数選択のドラッグと同じ。要素ごとに x, y をずらす
/// だけだと、線は始点しか動かず（終点は絶対座標）、結合した線から外れる。
fn move_selected_by_arrow(
  state : @core.EditorState,
  history : @model.History,
  selected_ids : Array[String],
  key : String,
  step : Double,
) -> Unit {
  let (dx, dy) : (Double, Double) = match key {
    "ArrowUp" => (0.0, -step)
    "ArrowDown" => (0.0, step)
    "ArrowLeft" => (-step, 0.0)
    "ArrowRight" => (step, 0.0)
    _ => (0.0, 0.0)
  }
  let before = state.elements.get()
  let after = match selected_ids {
    [id] =>
      match state.find_element(id) {
        Some(el) =>
          @model.move_element_with_relations(before, id, el.x + dx, el.y + dy)
        None => before
      }
    _ => @model.move_selection(before, selected_ids, dx, dy)
  }
  state.elements.set(after)
  @core.record_change(history, before, after)
}

///|
/// 矢印キーでキャンバスをパン
fn pan_by_arrow(state : @core.EditorState, key : String) -> Unit {
  let zoom = state.viewport.get().zoom
  let pan_step = 12.0 / zoom
  match key {
    "ArrowUp" => state.pan(0.0, -pan_step)
    "ArrowDown" => state.pan(0.0, pan_step)
    "ArrowLeft" => state.pan(-pan_step, 0.0)
    "ArrowRight" => state.pan(pan_step, 0.0)
    _ => ()
  }
}

///|
/// 矢印キーイベントを処理
pub fn handle_arrow_key(
  state : @core.EditorState,
  history : @model.History,
  key : String,
  shift_key : Bool,
) -> Unit {
  let selected_ids = state.selected_ids.get()
  if selected_ids.length() == 0 {
    pan_by_arrow(state, key)
    return
  }
  let step = if state.grid_enabled.get() { 10.0 } else { 5.0 }
  if shift_key {
    resize_selected_by_arrow(state, history, selected_ids, key, step)
  } else {
    move_selected_by_arrow(state, history, selected_ids, key, step)
  }
}
