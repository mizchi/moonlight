// GitHub リンクボタン UI

///|
/// GitHub リンクボタンをセットアップ
pub fn setup_github_link(state : @core.EditorState, github_url : String?) -> Unit {
  let url = match github_url {
    Some(u) => u
    None => return
  }
  let container = state.container_el.get()
  if is_container_null_github(container) {
    return
  }
  let btn = create_github_button()
  append_github_button(container, btn)
  add_github_button_click_handler(btn, fn(_e) { open_github_page(url) })
}

///|
/// GitHub ページを開く
pub fn open_github_page(url : String) -> Unit {
  open_github_page_ffi(url)
}

///|
/// コンテナが null かどうかチェック
extern "js" fn is_container_null_github(container : @js.Any) -> Bool =
  #| (c) => c === null || c === undefined

///|
/// GitHub ボタン要素を作成
extern "js" fn create_github_button() -> @js.Any =
  #| () => {
  #|   const btn = document.createElement('a');
  #|   btn.title = 'View on GitHub';
  #|   btn.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
  #|     <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
  #|   </svg>`;
  #|   btn.style.cssText = `
  #|     position: absolute;
  #|     bottom: 8px;
  #|     right: 44px;
  #|     width: 28px;
  #|     height: 28px;
  #|     border-radius: 50%;
  #|     border: 1px solid #ccc;
  #|     background: #fff;
  #|     color: #666;
  #|     font-size: 14px;
  #|     cursor: pointer;
  #|     z-index: 100;
  #|     display: flex;
  #|     align-items: center;
  #|     justify-content: center;
  #|     transition: all 0.15s;
  #|     box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  #|     text-decoration: none;
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
/// GitHub ボタンをコンテナに追加
extern "js" fn append_github_button(container : @js.Any, btn : @js.Any) =
  #| (container, btn) => {
  #|   // container が relative/absolute でなければ relative に設定
  #|   const style = getComputedStyle(container);
  #|   if (style.position === 'static') {
  #|     container.style.position = 'relative';
  #|   }
  #|   container.appendChild(btn);
  #| }

///|
/// GitHub ボタンにクリックハンドラを追加
extern "js" fn add_github_button_click_handler(
  btn : @js.Any,
  handler : (@js.Any) -> Unit,
) =
  #| (btn, handler) => btn.addEventListener('click', handler)

///|
/// GitHub ページを新しいタブで開く
extern "js" fn open_github_page_ffi(url : String) =
  #| (url) => {
  #|   window.open(url, '_blank');
  #| }
