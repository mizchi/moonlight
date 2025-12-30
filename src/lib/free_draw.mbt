// Free Draw - フリードロー機能の操作関数

///|
/// フリードロー開始
pub fn start_free_draw(state : @core.EditorState, x : Double, y : Double) -> Unit {
  let point : @model.Point = { x, y }
  state.free_draw_state.set(Some({ points: [point] }))
}

///|
/// フリードロー継続（ポイント追加）
pub fn continue_free_draw(
  state : @core.EditorState,
  x : Double,
  y : Double,
) -> Unit {
  match state.free_draw_state.get() {
    Some(fds) => {
      let point : @model.Point = { x, y }
      fds.points.push(point)
      // Signal を更新するために再設定
      state.free_draw_state.set(Some(fds))
    }
    None => ()
  }
}

///|
/// フリードロー終了 - ベジェ圧縮して Path 要素を作成
pub fn finish_free_draw(
  state : @core.EditorState,
  new_id : () -> String,
) -> Unit {
  match state.free_draw_state.get() {
    Some(fds) => {
      let points = fds.points
      // 状態をクリア
      state.free_draw_state.set(None)
      // 点が少なすぎる場合はスキップ
      if points.length() < 2 {
        return
      }
      // bezier_fit 用の Point に変換
      let bezier_points : Array[@bezier.Point] = points.map(fn(p) {
        @bezier.Point::new(p.x, p.y)
      })
      // オプションを取得
      let opts = state.free_draw_options.get()
      let bezier_opts : @bezier.Options = {
        min_resample_dist: opts.resample_dist,
        epsilon: opts.epsilon,
        max_error: opts.max_error,
      }
      // ベジェ近似
      let d = @bezier.approximate(bezier_points, bezier_opts)
      if d == "" {
        return
      }
      // 始点・終点を取得
      let first = points[0]
      let last = points[points.length() - 1]
      // Path 要素を作成
      // el.x, el.y を始点に設定（これが基準位置になる）
      let el_id = new_id()
      let path_element : @model.Element = {
        id: el_id,
        x: first.x,
        y: first.y,
        shape: @model.Path(d, first.x, first.y, last.x, last.y),
        style: @model.Style::default(),
        transform: None,
        parent_id: None,
        connections: None,
      }
      // 要素を追加
      let elements = state.elements.get()
      elements.push(path_element)
      state.elements.set(elements)
      // 選択モードに戻り、作成した Path を選択
      state.tool_mode.set(@core.Select)
      state.selected_ids.set([el_id])
    }
    None => ()
  }
}

///|
/// ツールモードを切り替え
pub fn toggle_tool_mode(state : @core.EditorState) -> Unit {
  match state.tool_mode.get() {
    @core.Select => state.tool_mode.set(@core.FreeDraw)
    @core.FreeDraw => state.tool_mode.set(@core.Select)
  }
}

///|
/// 選択モードに切り替え
pub fn set_select_mode(state : @core.EditorState) -> Unit {
  state.tool_mode.set(@core.Select)
}

///|
/// フリードローモードに切り替え
pub fn set_free_draw_mode(state : @core.EditorState) -> Unit {
  state.tool_mode.set(@core.FreeDraw)
}

///|
/// フリードロー中かどうか
pub fn is_drawing(state : @core.EditorState) -> Bool {
  state.free_draw_state.get() is Some(_)
}

///|
/// フリードローモードかどうか
pub fn is_free_draw_mode(state : @core.EditorState) -> Bool {
  state.tool_mode.get() == @core.FreeDraw
}

///|
/// フリードローオプションを更新
pub fn set_free_draw_options(
  state : @core.EditorState,
  resample_dist : Double,
  epsilon : Double,
  max_error : Double,
) -> Unit {
  state.free_draw_options.set({ resample_dist, epsilon, max_error })
}

///|
/// フリードロー中のプレビューポイントを取得
pub fn get_preview_points(state : @core.EditorState) -> Array[@model.Point] {
  match state.free_draw_state.get() {
    Some(fds) => fds.points
    None => []
  }
}
