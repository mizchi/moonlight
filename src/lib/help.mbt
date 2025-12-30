// ヘルプボタン UI

///|
/// ヘルプボタンをセットアップ
pub fn setup_help_button(state : @core.EditorState, show_button : Bool) -> Unit {
  if not(show_button) {
    return
  }
  let container = state.container_el.get()
  if is_container_null_help(container) {
    return
  }
  let btn = create_help_button()
  append_help_button(container, btn)
  add_help_button_click_handler(btn, fn(_e) { open_help_page() })
}

///|
/// ヘルプページを開く
pub fn open_help_page() -> Unit {
  open_help_page_ffi()
}

///|
/// コンテナが null かどうかチェック
extern "js" fn is_container_null_help(container : @js.Any) -> Bool =
  #| (c) => c === null || c === undefined

///|
/// ヘルプボタン要素を作成
extern "js" fn create_help_button() -> @js.Any =
  #| () => {
  #|   const btn = document.createElement('button');
  #|   btn.textContent = '?';
  #|   btn.title = 'Help (Press ?)';
  #|   btn.style.cssText = `
  #|     position: absolute;
  #|     bottom: 8px;
  #|     right: 8px;
  #|     width: 28px;
  #|     height: 28px;
  #|     border-radius: 50%;
  #|     border: 1px solid #ccc;
  #|     background: #fff;
  #|     color: #666;
  #|     font-size: 14px;
  #|     font-weight: bold;
  #|     cursor: pointer;
  #|     z-index: 100;
  #|     display: flex;
  #|     align-items: center;
  #|     justify-content: center;
  #|     transition: all 0.15s;
  #|     box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  #|   `;
  #|   btn.addEventListener('mouseenter', () => {
  #|     btn.style.background = '#f0f0f0';
  #|     btn.style.borderColor = '#999';
  #|   });
  #|   btn.addEventListener('mouseleave', () => {
  #|     btn.style.background = '#fff';
  #|     btn.style.borderColor = '#ccc';
  #|   });
  #|   return btn;
  #| }

///|
/// ヘルプボタンをコンテナに追加
extern "js" fn append_help_button(container : @js.Any, btn : @js.Any) =
  #| (container, btn) => {
  #|   // container が relative/absolute でなければ relative に設定
  #|   const style = getComputedStyle(container);
  #|   if (style.position === 'static') {
  #|     container.style.position = 'relative';
  #|   }
  #|   container.appendChild(btn);
  #| }

///|
/// ヘルプボタンにクリックハンドラを追加
extern "js" fn add_help_button_click_handler(
  btn : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (btn, handler) => btn.addEventListener('click', handler)

///|
/// ヘルプページを新しいタブで開く
extern "js" fn open_help_page_ffi() =
  #| () => {
  #|   // 同じオリジンの /docs/help.html を開く
  #|   window.open('/docs/help.html', '_blank');
  #| }
