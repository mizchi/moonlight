// WebComponents モード - エントリポイント
// <moonlight-editor> カスタム要素を定義
// embed と同じ @editor モジュールを使用

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
  #|       return ['width', 'height', 'theme', 'readonly'];
  #|     }
  #|
  #|     constructor() {
  #|       super();
  #|       this._handle = null;
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
  #|     // Public API - ハンドルに委譲
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
  #|
  #|     hasFocus() {
  #|       return this._handle?.hasFocus?.() || false;
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
/// 属性から options オブジェクトを作成
extern "js" fn create_options_from_attributes(element : @js.Any) -> @js.Any =
  #| (el) => ({
  #|   width: parseInt(el.getAttribute('width'), 10) || 400,
  #|   height: parseInt(el.getAttribute('height'), 10) || 300,
  #|   theme: el.getAttribute('theme') || 'light',
  #|   readonly: el.hasAttribute('readonly')
  #| })

///|
/// template 内の SVG を取得（なければ空文字）
extern "js" fn get_template_svg(element : @js.Any) -> String =
  #| (el) => {
  #|   const template = el.querySelector('template');
  #|   if (!template) return '';
  #|   const svg = template.content.querySelector('svg');
  #|   if (!svg) return '';
  #|   return svg.outerHTML;
  #| }

///|
/// Shadow DOM を作成してコンテナを返す
extern "js" fn create_shadow_container(element : @js.Any) -> @js.Any =
  #| (el) => {
  #|   const shadow = el.attachShadow({ mode: 'open' });
  #|   const container = document.createElement('div');
  #|   container.style.width = '100%';
  #|   container.style.height = '100%';
  #|   shadow.appendChild(container);
  #|   return container;
  #| }

///|
/// 要素の状態をクリア
extern "js" fn clear_element_handle(element : @js.Any) =
  #| (el) => { el._handle = null; }

///|
/// ハンドルに SVG をインポート
extern "js" fn import_svg_to_handle(handle : @js.Any, svg : String) =
  #| (handle, svg) => { handle?.importSvg?.(svg); }

///|
/// connected コールバック
fn on_connected(element : @js.Any) -> Unit {
  // 属性から options を作成（embed と同じ形式）
  let options_js = create_options_from_attributes(element)
  let options = @editor.EmbedOptions::from_js(options_js)
  // Shadow DOM 内にコンテナを作成
  let container = create_shadow_container(element)
  // embed と同じエディタ作成関数を使用
  let handle = @editor.create_js_editor(container, options)
  set_element_handle(element, handle)
  // template 内に SVG があれば読み込む
  let template_svg = get_template_svg(element)
  if template_svg != "" {
    import_svg_to_handle(handle, template_svg)
  }
}

///|
/// disconnected コールバック
fn on_disconnected(element : @js.Any) -> Unit {
  clear_element_handle(element)
}

///|
/// attribute changed コールバック
fn on_attribute_changed(
  _element : @js.Any,
  _name : String,
  _old_value : String,
  _new_value : String,
) -> Unit {
  // TODO: 動的な属性変更に対応（テーマ切り替えなど）
}

///|
/// メイン関数
fn main {
  define_custom_element(on_connected, on_disconnected, on_attribute_changed)
}
