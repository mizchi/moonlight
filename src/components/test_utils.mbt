// テストユーティリティ - happy-dom ラッパー

///|
/// HappyDOM Window を作成し、グローバルに document と window を注入
pub fn create_happy_window() -> @dom.Window {
  @js.identity(create_happy_window_internal())
}

///|
extern "js" fn create_happy_window_internal() -> @js.Any =
  #|() => {
  #|  const win = new (require("happy-dom").Window)();
  #|  globalThis.window = win;
  #|  globalThis.document = win.document;
  #|  return win;
  #|}
