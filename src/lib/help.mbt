// ヘルプボタン UI

///|
/// ヘルプページを開く
pub fn open_help_page() -> Unit {
  open_help_page_ffi()
}

///|
/// ヘルプページを新しいタブで開く
extern "js" fn open_help_page_ffi() =
  #| () => {
  #|   // 同じオリジンの /docs/help.html を開く
  #|   window.open('/docs/help.html', '_blank');
  #| }
