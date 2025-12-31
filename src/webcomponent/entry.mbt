// WebComponents モード - エントリポイント
// SSR 対応: Declarative Shadow DOM + 遅延 hydration
//
// チャンク設計:
// 1. このファイル (shell): カスタム要素登録 + プレビュー + Edit ボタン (~5KB)
// 2. editor モジュール: 編集クリック時に動的 import (~150KB)

///|
/// エディタモジュールの URL（同じオリジンから読み込み）
extern "js" fn get_editor_module_url() -> String =
  #| () => {
  #|   const currentScript = document.currentScript;
  #|   if (currentScript?.src) {
  #|     return currentScript.src.replace('.component.js', '.editor.js');
  #|   }
  #|   return './moonlight-editor.editor.js';
  #| }

///|
/// カスタム要素を定義（軽量シェル）
extern "js" fn define_custom_element(editor_url : String) =
  #| (editorUrl) => {
  #|   class MoonlightEditorElement extends HTMLElement {
  #|     static get observedAttributes() {
  #|       return ['width', 'height', 'theme', 'readonly', 'trigger'];
  #|     }
  #|
  #|     constructor() {
  #|       super();
  #|       this._handle = null;
  #|       this._hydrated = false;
  #|       this._editorUrl = editorUrl;
  #|       this._preloadPromise = null;  // プリロード用 Promise
  #|     }
  #|
  #|     connectedCallback() {
  #|       // Light DOM の子要素がパースされるのを待つ
  #|       requestAnimationFrame(() => {
  #|         // Declarative Shadow DOM があれば再利用、なければ作成
  #|         if (!this.shadowRoot) {
  #|           this._createPreviewShadow();
  #|         }
  #|         this._setupEditButton();
  #|         this._setupHoverTrigger();
  #|       });
  #|     }
  #|
  #|     _createPreviewShadow() {
  #|       const shadow = this.attachShadow({ mode: 'open' });
  #|       const width = this.getAttribute('width') || '400';
  #|       const height = this.getAttribute('height') || '300';
  #|       const theme = this.getAttribute('theme') || 'light';
  #|       const bg = theme === 'dark' ? '#1a1a2e' : '#ffffff';
  #|       // Light DOM から SVG を取得（template > 直接の SVG 子要素）
  #|       const template = this.querySelector('template:not([shadowrootmode])');
  #|       const svgFromTemplate = template?.content.querySelector('svg');
  #|       const svgFromLightDom = this.querySelector(':scope > svg');
  #|       const svg = svgFromTemplate || svgFromLightDom;
  #|       const svgHtml = svg ? svg.outerHTML : `<svg viewBox="0 0 ${width} ${height}" style="background:${bg}"></svg>`;
  #|
  #|       shadow.innerHTML = `
  #|         <style>
  #|           :host { display: block; position: relative; }
  #|           .preview-container { position: relative; border: 1px solid #e0e0e0; border-radius: 4px; overflow: hidden; box-sizing: border-box; }
  #|           .preview-container svg { display: block; width: 100%; height: auto; box-sizing: border-box; }
  #|           .edit-btn { position: absolute; top: 8px; right: 8px; padding: 8px 16px; background: #2196f3; color: white; border: none; border-radius: 4px; cursor: pointer; font: 14px system-ui, sans-serif; box-shadow: 0 2px 4px rgba(0,0,0,0.2); display: flex; align-items: center; gap: 6px; }
  #|           .edit-btn:hover { background: #1976d2; }
  #|           .edit-btn.loading { opacity: 0.8; cursor: wait; }
  #|           .spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,0.3); border-top-color: white; border-radius: 50%; animation: spin 0.8s linear infinite; display: none; }
  #|           .edit-btn.loading .spinner { display: block; }
  #|           .edit-btn.loading .btn-text { display: none; }
  #|           @keyframes spin { to { transform: rotate(360deg); } }
  #|           .editor-container { position: relative; border: 1px solid #e0e0e0; border-radius: 4px; overflow: hidden; box-sizing: border-box; }
  #|           .editor-container *, .editor-container *::before, .editor-container *::after { margin: 0; padding: 0; box-sizing: border-box; }
  #|           .editor-container svg { display: block; }
  #|         </style>
  #|         <div class="preview-container">
  #|           ${svgHtml}
  #|           <button class="edit-btn" data-action="edit">
  #|             <span class="btn-text">Edit</span>
  #|             <span class="spinner"></span>
  #|           </button>
  #|         </div>
  #|       `;
  #|     }
  #|
  #|     _setupEditButton() {
  #|       const btn = this.shadowRoot?.querySelector('[data-action="edit"]');
  #|       btn?.addEventListener('click', () => {
  #|         // プリロード中/完了なら即座に hydrate、そうでなければロード開始
  #|         if (this._preloadPromise) {
  #|           this._hydrate();
  #|         } else {
  #|           this._startLoading();
  #|         }
  #|       });
  #|     }
  #|
  #|     _setupHoverTrigger() {
  #|       const trigger = this.getAttribute('trigger');
  #|       if (trigger !== 'hover') return;
  #|
  #|       const container = this.shadowRoot?.querySelector('.preview-container');
  #|       if (!container) return;
  #|
  #|       container.addEventListener('pointerenter', () => this._startLoading(), { once: true });
  #|     }
  #|
  #|     // ロード開始（スピナー表示 + プリロード + 完了時に自動 hydrate）
  #|     _startLoading() {
  #|       if (this._preloadPromise || this._hydrated) return;
  #|
  #|       // スピナー表示
  #|       const btn = this.shadowRoot?.querySelector('.edit-btn');
  #|       btn?.classList.add('loading');
  #|
  #|       // プリロード開始、完了したら即座に hydrate
  #|       this._preloadPromise = import(this._editorUrl);
  #|       this._preloadPromise.then(() => this._hydrate());
  #|     }
  #|
  #|     async _hydrate() {
  #|       if (this._hydrated) return;
  #|
  #|       try {
  #|         // プリロード済みならそれを使う
  #|         const module = await (this._preloadPromise || import(this._editorUrl));
  #|
  #|         // Light DOM から SVG を取得（直接の SVG 子要素 > template）
  #|         // NOTE: text要素は text-anchor="middle", dominant-baseline="middle" が必要
  #|         // このエディタで生成したSVGは既にこの形式で出力される
  #|         // TODO: 外部SVGの座標変換は将来対応
  #|         const svgFromLightDom = this.querySelector(':scope > svg');
  #|         const template = this.querySelector('template:not([shadowrootmode])');
  #|         const svgFromTemplate = template?.content.querySelector('svg');
  #|         const svg = svgFromLightDom || svgFromTemplate;
  #|         const initialSvg = svg?.outerHTML || '';
  #|
  #|         // viewBox からドキュメントサイズを取得
  #|         const viewBox = svg?.getAttribute('viewBox')?.split(/\s+/).map(Number) || [0, 0, 400, 300];
  #|         const docWidth = viewBox[2] || 400;
  #|         const docHeight = viewBox[3] || 300;
  #|
  #|         // プレビューの実際のサイズを取得
  #|         const shadow = this.shadowRoot;
  #|         const previewContainer = shadow.querySelector('.preview-container');
  #|         const previewRect = previewContainer?.getBoundingClientRect();
  #|         const containerWidth = Math.round(previewRect?.width || docWidth);
  #|         const containerHeight = Math.round(previewRect?.height || docHeight);
  #|
  #|         // ズームレベルを計算（プレビューと同じスケールを維持）
  #|         const zoom = Math.min(containerWidth / docWidth, containerHeight / docHeight);
  #|
  #|         // Shadow DOM をエディタで置き換え
  #|         shadow.innerHTML = '<div class="editor-container"></div>';
  #|         const container = shadow.querySelector('.editor-container');
  #|
  #|         // エディタを初期化（ドキュメントサイズ + ズームで同じ見た目を維持）
  #|         const options = {
  #|           width: containerWidth,
  #|           height: containerHeight,
  #|           docWidth: docWidth,
  #|           docHeight: docHeight,
  #|           zoom: zoom,
  #|           theme: this.getAttribute('theme') || 'light',
  #|           readonly: this.hasAttribute('readonly'),
  #|           initialSvg: initialSvg  // 空文字でも渡す（デモ防止）
  #|         };
  #|         console.log('[moonlight] options.initialSvg defined:', options.initialSvg !== undefined);
  #|
  #|         this._handle = module.createEditor(container, options);
  #|         this._hydrated = true;
  #|
  #|         // 保留中の onChange コールバックを登録
  #|         if (this._pendingOnChange) {
  #|           this._pendingOnChange.forEach(cb => this._handle.onChange(cb));
  #|           this._pendingOnChange = null;
  #|         }
  #|       } catch (e) {
  #|         console.error('Failed to load editor:', e);
  #|         if (btn) {
  #|           btn.textContent = 'Error - Retry';
  #|           btn.classList.remove('loading');
  #|         }
  #|       }
  #|     }
  #|
  #|     // Public API
  #|     exportSvg() {
  #|       if (this._handle) return this._handle.exportSvg();
  #|       const svg = this.querySelector('template:not([shadowrootmode])')?.content.querySelector('svg');
  #|       return svg?.outerHTML || '<svg></svg>';
  #|     }
  #|
  #|     importSvg(svg) { this._handle?.importSvg?.(svg); }
  #|     clear() { this._handle?.clear?.(); }
  #|     hasFocus() { return this._handle?.hasFocus?.() || false; }
  #|
  #|     // イベント購読 API
  #|     onChange(callback) {
  #|       if (this._handle) {
  #|         return this._handle.onChange(callback);
  #|       }
  #|       // hydration 前は保留リストに追加
  #|       this._pendingOnChange = this._pendingOnChange || [];
  #|       this._pendingOnChange.push(callback);
  #|       return () => {
  #|         this._pendingOnChange = this._pendingOnChange?.filter(c => c !== callback);
  #|       };
  #|     }
  #|
  #|     // 明示的に hydration を開始
  #|     startEditing() { return this._hydrate(); }
  #|   }
  #|
  #|   customElements.define('moonlight-editor', MoonlightEditorElement);
  #| }

///|
/// メイン関数（軽量シェルのみ登録）
fn main {
  let editor_url = get_editor_module_url()
  define_custom_element(editor_url)
}
