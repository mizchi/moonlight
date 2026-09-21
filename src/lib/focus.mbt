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
/// 要素に実際に DOM フォーカスを当てる
extern "js" fn focus_element_ffi(el : @js.Any) =
  #| (el) => {
  #|   if (el && typeof el.focus === 'function') el.focus({ preventScroll: true });
  #| }

///|
/// エディタのコンテナにフォーカスを戻す
///
/// keydown はフォーカスのある要素から上に伝わるので、フォーカスがコンテナの外
/// （メニューのボタンを押すと、そのボタンごと消えて body に落ちる）にあると、
/// has_focus が立っていてもキーはコンテナまで届かない。
pub fn focus_container(state : @core.EditorState) -> Unit {
  focus_element_ffi(state.container_el.get())
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
  { has_focus: @luna.signal(false), container: @luna.signal(None), }
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
  add_focusin_listener_ffi(container, fn(_e) { focus_state.has_focus.set(true) })
  // focusout イベント
  add_focusout_listener_ffi(container, fn(e) {
    // related target がコンテナ外なら focus を失う
    if !is_focus_within_ffi(container, e) {
      focus_state.has_focus.set(false)
    }
  })
}
