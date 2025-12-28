// フォーカス管理ユーティリティ

///|
/// tabindex を設定
pub extern "js" fn set_tabindex_ffi(el : @js.Any, index : Int) =
  #| (el, index) => el.setAttribute('tabindex', index.toString())

///|
/// focusin リスナー追加
pub extern "js" fn add_focusin_listener_ffi(
  el : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (el, handler) => el.addEventListener('focusin', handler)

///|
/// focusout リスナー追加
pub extern "js" fn add_focusout_listener_ffi(
  el : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (el, handler) => el.addEventListener('focusout', handler)

///|
/// フォーカスがコンテナ内にあるか確認
pub extern "js" fn is_focus_within_ffi(
  container : @js.Any,
  event : @js.Any,
) -> Bool =
  #| (container, e) => container.contains(e.relatedTarget)

///|
/// キーボードイベントを処理すべきかどうかを判定
/// フォーカスがエディタ内にある場合のみ true を返す
pub fn should_handle_keyboard(has_focus : @luna.Signal[Bool]) -> Bool {
  has_focus.get()
}

///|
/// フォーカス状態
pub(all) struct FocusState {
  has_focus : @luna.Signal[Bool] // フォーカスがあるか
  container : @luna.Signal[@js.Any?] // フォーカス管理用コンテナ
}

///|
/// フォーカス状態を作成
pub fn FocusState::new() -> FocusState {
  { has_focus: @luna.signal(false), container: @luna.signal(None) }
}

///|
/// フォーカス管理を設定
pub fn setup_focus_management(
  focus_state : FocusState,
  container : @js.Any,
) -> Unit {
  // コンテナを保存
  focus_state.container.set(Some(container))
  // tabindex を設定（フォーカス可能にする）
  set_tabindex_ffi(container, 0)
  // focusin イベント
  add_focusin_listener_ffi(
    container,
    fn(_e) { focus_state.has_focus.set(true) },
  )
  // focusout イベント
  add_focusout_listener_ffi(
    container,
    fn(e) {
      // related target がコンテナ外なら focus を失う
      if not(is_focus_within_ffi(container, e)) {
        focus_state.has_focus.set(false)
      }
    },
  )
}

///|
/// コンテナレベルでキーボードイベントを設定
pub extern "js" fn add_keydown_listener_to_element(
  el : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (el, handler) => el.addEventListener('keydown', handler)

///|
/// コンテナレベルでキーボードイベントを設定
pub extern "js" fn add_keyup_listener_to_element(
  el : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (el, handler) => el.addEventListener('keyup', handler)
