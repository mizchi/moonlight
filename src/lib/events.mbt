// イベントシステム - ライブラリAPI向けイベント管理

///|
/// イベントコールバック型
pub struct EventCallbacks {
  on_change : Array[() -> Unit]
  on_select : Array[(Array[String]) -> Unit]
  on_deselect : Array[() -> Unit]
  on_focus : Array[() -> Unit]
  on_blur : Array[() -> Unit]
  on_mode_change : Array[(String) -> Unit]
  on_element_add : Array[(String) -> Unit]
  on_element_delete : Array[(String) -> Unit]
}

///|
/// 新しいイベントコールバック構造体を作成
pub fn EventCallbacks::new() -> EventCallbacks {
  {
    on_change: [],
    on_select: [],
    on_deselect: [],
    on_focus: [],
    on_blur: [],
    on_mode_change: [],
    on_element_add: [],
    on_element_delete: [],
  }
}

///|
/// イベントをセットアップ（Signal変更を監視してコールバックを発火）
pub fn setup_event_listeners(
  state : @core.EditorState,
  callbacks : EventCallbacks,
) -> Unit {
  // 要素変更イベント
  let prev_elements : Ref[Array[@model.Element]] = { val: [] }
  let _ = @luna.effect(fn() {
    let elements = state.elements.get()
    // onChange を発火
    for cb in callbacks.on_change {
      cb()
    }
    // 要素追加/削除を検出
    let prev_ids = prev_elements.val.map(fn(el) { el.id })
    let curr_ids = elements.map(fn(el) { el.id })
    // 追加された要素
    for id in curr_ids {
      if not(prev_ids.contains(id)) {
        for cb in callbacks.on_element_add {
          cb(id)
        }
      }
    }
    // 削除された要素
    for id in prev_ids {
      if not(curr_ids.contains(id)) {
        for cb in callbacks.on_element_delete {
          cb(id)
        }
      }
    }
    prev_elements.val = elements
  })
  // 選択変更イベント
  let prev_selected : Ref[Array[String]] = { val: [] }
  let _ = @luna.effect(fn() {
    let selected = state.selected_ids.get()
    if selected.length() > 0 && prev_selected.val.length() == 0 {
      // 選択開始
      for cb in callbacks.on_select {
        cb(selected)
      }
    } else if selected.length() == 0 && prev_selected.val.length() > 0 {
      // 選択解除
      for cb in callbacks.on_deselect {
        cb()
      }
    } else if selected.length() > 0 {
      // 選択変更
      for cb in callbacks.on_select {
        cb(selected)
      }
    }
    prev_selected.val = selected
  })
  // フォーカス変更イベント
  let prev_focus : Ref[Bool] = { val: false }
  let _ = @luna.effect(fn() {
    let focused = state.has_focus.get()
    if focused && not(prev_focus.val) {
      for cb in callbacks.on_focus {
        cb()
      }
    } else if not(focused) && prev_focus.val {
      for cb in callbacks.on_blur {
        cb()
      }
    }
    prev_focus.val = focused
  })
  // モード変更イベント
  let prev_mode : Ref[@core.ToolMode] = { val: @core.Select }
  let _ = @luna.effect(fn() {
    let mode = state.tool_mode.get()
    if mode != prev_mode.val {
      let mode_str = match mode {
        @core.Select => "select"
        @core.FreeDraw => "freedraw"
      }
      for cb in callbacks.on_mode_change {
        cb(mode_str)
      }
    }
    prev_mode.val = mode
  })

}
