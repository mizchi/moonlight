// WebComponents モード - エントリポイント
// <moonlight-editor> カスタム要素を定義

///|
/// カスタム要素を定義
extern "js" fn define_custom_element(
  on_connected : (@js.Any) -> Unit,
  on_disconnected : (@js.Any) -> Unit,
  on_attribute_changed : (@js.Any, String, String, String) -> Unit,
) =
  #| (onConnected, onDisconnected, onAttributeChanged) => {
  #|   class MoonlightEditorElement extends HTMLElement {
  #|     static get observedAttributes() {
  #|       return ['width', 'height', 'gridsnap', 'theme', 'zoom', 'readonly', 'toolbar-visible'];
  #|     }
  #|
  #|     constructor() {
  #|       super();
  #|       this._handle = null;
  #|       this._state = null;
  #|     }
  #|
  #|     connectedCallback() {
  #|       onConnected(this);
  #|     }
  #|
  #|     disconnectedCallback() {
  #|       onDisconnected(this);
  #|     }
  #|
  #|     attributeChangedCallback(name, oldValue, newValue) {
  #|       onAttributeChanged(this, name, oldValue || '', newValue || '');
  #|     }
  #|
  #|     // Public API
  #|     exportSvg() {
  #|       return this._handle?.exportSvg?.() || '<svg></svg>';
  #|     }
  #|
  #|     importSvg(svg) {
  #|       this._handle?.importSvg?.(svg);
  #|     }
  #|
  #|     clear() {
  #|       this._handle?.clear?.();
  #|     }
  #|   }
  #|
  #|   customElements.define('moonlight-editor', MoonlightEditorElement);
  #| }

///|
/// 要素のハンドルを設定
extern "js" fn set_element_handle(element : @js.Any, handle : @js.Any) =
  #| (el, handle) => { el._handle = handle; }

///|
/// 要素から属性を取得
extern "js" fn get_attribute(element : @js.Any, name : String) -> String =
  #| (el, name) => el.getAttribute(name) || ''

///|
/// 文字列を整数に変換
extern "js" fn parse_int(s : String) -> Int =
  #| (s) => parseInt(s, 10) || 0

///|
/// ID カウンター
let id_counter : Ref[Int] = { val: 0 }

///|
/// 新しい ID を生成
fn new_id() -> String {
  id_counter.val = id_counter.val + 1
  "el-\{id_counter.val}"
}

///|
/// connected コールバック
fn on_connected(element : @js.Any) -> Unit {
  // 属性からオプションを取得
  let width_str = get_attribute(element, "width")
  let height_str = get_attribute(element, "height")
  let theme = get_attribute(element, "theme")
  let gridsnap_str = get_attribute(element, "gridsnap")
  let readonly_str = get_attribute(element, "readonly")
  let toolbar_visible_str = get_attribute(element, "toolbar-visible")
  let width = if width_str == "" { 400 } else { parse_int(width_str) }
  let height = if height_str == "" { 300 } else { parse_int(height_str) }
  let options : @lib.EditorOptions = {
    width: Some(width),
    height: Some(height),
    gridsnap: gridsnap_str != "",
    theme: if theme == "" {
      Some("light")
    } else {
      Some(theme)
    },
    zoom: Some(1.0),
    is_readonly: readonly_str != "",
    toolbar_visible: toolbar_visible_str != "false",
    initial_svg: None,
  }
  // Shadow DOM を作成
  let shadow = attach_shadow(element)
  let container = create_container_in_shadow(shadow)
  // 共通セットアップロジックを使用
  let result = @lib.setup_editor(container, options, new_id)
  set_element_handle(element, result.handle)
}

///|
/// disconnected コールバック
fn on_disconnected(element : @js.Any) -> Unit {
  // クリーンアップ
  clear_element_state_ffi(element)
}

///|
/// 要素の状態をクリア
extern "js" fn clear_element_state_ffi(element : @js.Any) =
  #| (el) => { el._handle = null; el._state = null; }

///|
/// attribute changed コールバック
fn on_attribute_changed(
  _element : @js.Any,
  name : String,
  _old_value : String,
  _new_value : String,
) -> Unit {
  // 属性変更時の処理
  // TODO: テーマ変更、readonly 変更などを実装
  let _ = name

}

///|
/// Shadow DOM をアタッチ
extern "js" fn attach_shadow(element : @js.Any) -> @js.Any =
  #| (el) => el.attachShadow({ mode: 'open' })

///|
/// Shadow DOM 内にコンテナを作成
extern "js" fn create_container_in_shadow(shadow : @js.Any) -> @js.Any =
  #| (shadow) => {
  #|   const container = document.createElement('div');
  #|   container.style.width = '100%';
  #|   container.style.height = '100%';
  #|   shadow.appendChild(container);
  #|   return container;
  #| }

///|
/// メイン関数
fn main {
  define_custom_element(on_connected, on_disconnected, on_attribute_changed)
}
