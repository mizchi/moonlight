// FFI - JavaScript との相互運用

///|
/// Popover を表示してボタン位置に配置
pub extern "js" fn show_popover_at_button(popover_id : String, e : @js.Any) =
  #| (popoverId, e) => {
  #|   const popover = document.getElementById(popoverId);
  #|   if (!popover) return;
  #|   const btn = e.currentTarget;
  #|   const rect = btn.getBoundingClientRect();
  #|   popover.showPopover();
  #|   popover.style.left = (rect.left + rect.width / 2) + 'px';
  #|   popover.style.top = (rect.bottom + 6) + 'px';
  #|   popover.style.transform = 'translateX(-50%)';
  #| }

///|
/// Popover を非表示
pub extern "js" fn hide_popover(popover_id : String) =
  #| (popoverId) => {
  #|   const popover = document.getElementById(popoverId);
  #|   if (popover) popover.hidePopover();
  #| }

///|
/// デバッグログ
pub extern "js" fn debug_log(msg : String) =
  #| (msg) => console.log('[DEBUG]', msg)

///|
/// window に keydown イベントリスナーを追加
pub extern "js" fn add_keyboard_listener(handler : (@js.Any) -> Unit) =
  #| (handler) => window.addEventListener('keydown', handler)

///|
/// keydown リスナー
pub extern "js" fn add_keydown_listener(handler : (@js.Any) -> Unit) =
  #| (handler) => window.addEventListener('keydown', handler)

///|
/// keyup リスナー
pub extern "js" fn add_keyup_listener(handler : (@js.Any) -> Unit) =
  #| (handler) => window.addEventListener('keyup', handler)

///|
/// 要素から data-id を持つ最も近い親要素の data-id を取得
pub extern "js" fn get_closest_data_id_ffi(el : @js.Any) -> @js.Any =
  #| (el) => {
  #|   const closest = el.closest('[data-id]');
  #|   return closest ? closest.dataset.id : null;
  #| }

///|
/// SVG の viewBox を更新
pub extern "js" fn update_viewbox_ffi(svg : @js.Any, viewbox : String) =
  #| (svg, viewbox) => svg.setAttribute('viewBox', viewbox)

///|
/// ファイルをダウンロード
pub extern "js" fn download_file(
  content : String,
  filename : String,
  mime_type : String,
) =
  #| (content, filename, mimeType) => {
  #|   const blob = new Blob([content], { type: mimeType });
  #|   const url = URL.createObjectURL(blob);
  #|   const a = document.createElement('a');
  #|   a.href = url;
  #|   a.download = filename;
  #|   document.body.appendChild(a);
  #|   a.click();
  #|   document.body.removeChild(a);
  #|   URL.revokeObjectURL(url);
  #| }

///|
/// 現在時刻を取得（ミリ秒）
pub extern "js" fn get_current_time() -> Double =
  #| () => performance.now()

///|
/// 指定セレクタの要素にフォーカスを遅延設定（初期値付き）
pub extern "js" fn schedule_focus_with_value_ffi(
  selector : String,
  value : String,
) -> Int =
  #| (selector, value) => setTimeout(() => { const el = document.querySelector(selector); if (el) { el.value = value; el.focus(); el.select(); } }, 0)

///|
/// 指定セレクタのテキストエリアにフォーカスを遅延設定（IMEコンポジション対応）
pub extern "js" fn schedule_textarea_focus_ffi(
  selector : String,
  value : String,
) -> Int =
  #| (selector, value) => setTimeout(() => {
  #|   const el = document.querySelector(selector);
  #|   if (el) {
  #|     el.value = value;
  #|     el.focus();
  #|     // カーソルを末尾に移動
  #|     el.setSelectionRange(value.length, value.length);
  #|     // コンポジション状態を追跡
  #|     window.__isComposing = false;
  #|     el.addEventListener('compositionstart', () => { window.__isComposing = true; });
  #|     el.addEventListener('compositionend', () => { window.__isComposing = false; });
  #|   }
  #| }, 0)

///|
/// IMEコンポジション中かどうかを取得
pub extern "js" fn is_composing_ffi() -> Bool =
  #| () => window.__isComposing === true

///|
/// テキストエリアを作成（IMEコンポジション対応）
pub extern "js" fn create_textarea_ffi(
  style : String,
  initial_value : String,
  on_commit : (String) -> Unit,
  on_escape : (String) -> Unit,
  on_input : (String) -> Unit,
) -> @js.Any =
  #| (style, initialValue, onCommit, onEscape, onInput) => {
  #|   const textarea = document.createElement('textarea');
  #|   textarea.id = 'inline-text-edit';
  #|   textarea.style.cssText = style;
  #|   textarea.rows = 1;
  #|   textarea.value = initialValue;
  #|   let isComposing = false;
  #|   let isClosed = false;
  #|   textarea.addEventListener('compositionstart', () => { isComposing = true; });
  #|   textarea.addEventListener('compositionend', () => { isComposing = false; });
  #|   textarea.addEventListener('keydown', (e) => {
  #|     if (e.key === 'Enter' && !isComposing) {
  #|       // Enter（Shift有無問わず、IMEコンポジション中でない場合）: 確定
  #|       e.preventDefault();
  #|       isClosed = true;
  #|       onCommit(textarea.value);
  #|     } else if (e.key === 'Escape') {
  #|       // Escape: キャンセル（初期値に戻す）
  #|       e.preventDefault();
  #|       isClosed = true;
  #|       onEscape(initialValue);
  #|     }
  #|   });
  #|   textarea.addEventListener('blur', () => {
  #|     if (isClosed) return;
  #|     isClosed = true;
  #|     onCommit(textarea.value);
  #|   });
  #|   textarea.addEventListener('input', () => {
  #|     // 横幅を自動調整（テキストに合わせて伸びる）
  #|     textarea.style.width = 'auto';
  #|     textarea.style.width = Math.max(textarea.scrollWidth, 40) + 'px';
  #|     // リアルタイムでテキスト要素を更新（閉じられていなければ）
  #|     if (isClosed) return;
  #|     onInput(textarea.value);
  #|   });
  #|   // フォーカスを遅延設定
  #|   setTimeout(() => {
  #|     textarea.focus();
  #|     textarea.setSelectionRange(initialValue.length, initialValue.length);
  #|   }, 0);
  #|   return textarea;
  #| }

///|
/// イベントから target.value を取得
pub extern "js" fn get_event_target_value(e : @js.Any) -> String =
  #| (e) => e.target.value

///|
/// 文字列を Double にパース（FFI）
extern "js" fn parse_double_ffi(s : String) -> @js.Any =
  #| (s) => { const n = parseFloat(s); return isNaN(n) ? null : n; }

///|
/// 文字列を Double にパース
pub fn parse_double(s : String) -> Double? {
  let result = parse_double_ffi(s)
  if @js.is_nullish(result) {
    None
  } else {
    Some(result.cast())
  }
}

///|
/// SVG text 要素に複数行テキストを設定（tspan使用）
pub extern "js" fn set_multiline_text_ffi(
  text_el : @js.Any,
  content : String,
  x : Double,
  font_size : Double,
) =
  #| (textEl, content, x, fontSize) => {
  #|   // 単一行の場合は textContent を直接設定（高速）
  #|   if (!content.includes('\n')) {
  #|     textEl.textContent = content;
  #|     return;
  #|   }
  #|   // 複数行の場合は tspan を使用
  #|   const lines = content.split('\n');
  #|   const lineHeight = fontSize * 1.2;
  #|   const totalHeight = (lines.length - 1) * lineHeight;
  #|   const startOffset = -totalHeight / 2;
  #|   lines.forEach((line, i) => {
  #|     const tspan = document.createElementNS('http://www.w3.org/2000/svg', 'tspan');
  #|     tspan.setAttribute('x', x);
  #|     tspan.setAttribute('dy', i === 0 ? startOffset : lineHeight);
  #|     tspan.textContent = line || ' ';
  #|     textEl.appendChild(tspan);
  #|   });
  #| }

///|
/// SVG コンテナの子要素をクリア
pub extern "js" fn clear_children_ffi(el : @js.Any) =
  #| (el) => { while (el.firstChild) el.removeChild(el.firstChild); }

///|
/// 子要素を安全に削除（存在しない場合は何もしない）
pub extern "js" fn remove_child_safe_ffi(parent : @js.Any, child : @js.Any) =
  #| (parent, child) => { try { if (child && child.parentNode === parent) parent.removeChild(child); } catch(e) {} }

///|
/// 要素を親から削除
pub extern "js" fn remove_element_ffi(el : @js.Any) =
  #| (el) => { if (el && el.parentNode) el.parentNode.removeChild(el); }

///|
/// 指定した子要素の前に挿入
pub extern "js" fn insert_before_ffi(
  parent : @js.Any,
  new_child : @js.Any,
  ref_child : @js.Any,
) =
  #| (parent, newChild, refChild) => parent.insertBefore(newChild, refChild)

///|
/// ResizeObserver で要素のサイズ変更を監視
pub extern "js" fn observe_resize_ffi(
  el : @js.Any,
  callback : (Double, Double) -> Unit,
) =
  #| (el, callback) => {
  #|   const observer = new ResizeObserver((entries) => {
  #|     for (const entry of entries) {
  #|       const { width, height } = entry.contentRect;
  #|       callback(width, height);
  #|     }
  #|   });
  #|   observer.observe(el);
  #| }

///|
/// 入力要素にフォーカスがあるかチェック
pub extern "js" fn is_input_focused_ffi() -> Bool =
  #| () => {
  #|   const el = document.activeElement;
  #|   if (!el) return false;
  #|   const tag = el.tagName.toLowerCase();
  #|   return tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable;
  #| }

///|
/// ウィンドウサイズを監視
pub extern "js" fn observe_window_resize_ffi(callback : (Int, Int) -> Unit) =
  #| (callback) => {
  #|   callback(window.innerWidth, window.innerHeight);
  #|   window.addEventListener('resize', () => {
  #|     callback(window.innerWidth, window.innerHeight);
  #|   });
  #| }

///|
/// 子要素を取得
pub extern "js" fn get_child_at_ffi(parent : @js.Any, index : Int) -> @js.Any =
  #| (parent, index) => parent.children[index] || null

///|
/// SVG の背景スタイルを更新
pub extern "js" fn update_svg_background_ffi(
  svg : @js.Any,
  background : String,
) =
  #| (svg, background) => svg.style.background = background

///|
/// URL の search パラメータを取得
pub extern "js" fn get_url_search_ffi() -> String =
  #| () => window.location.search

///|
/// SVG の CSS 変数を更新
pub extern "js" fn update_svg_css_vars_ffi(
  svg : @js.Any,
  stroke : String,
  fill : String,
  text_color : String,
) =
  #| (svg, stroke, fill, textColor) => {
  #|   svg.style.setProperty('--ml-stroke', stroke);
  #|   svg.style.setProperty('--ml-fill', fill);
  #|   svg.style.setProperty('--ml-text', textColor);
  #| }

// ============================================================
// クリップボード API
// ============================================================

///|
/// テキストをクリップボードにコピー
pub extern "js" fn copy_text_to_clipboard(
  text : String,
  on_done : () -> Unit,
  on_error : () -> Unit,
) =
  #| (text, onDone, onError) => {
  #|   navigator.clipboard.writeText(text)
  #|     .then(() => onDone())
  #|     .catch(() => onError());
  #| }

///|
/// SVGをPNG画像としてクリップボードにコピー
pub extern "js" fn copy_svg_as_image(
  svg_str : String,
  width : Int,
  height : Int,
  on_done : () -> Unit,
  on_error : () -> Unit,
) =
  #| (svg, width, height, onDone, onError) => {
  #|   const img = new Image();
  #|   const svgBlob = new Blob([svg], { type: 'image/svg+xml' });
  #|   const url = URL.createObjectURL(svgBlob);
  #|   img.onload = () => {
  #|     const canvas = document.createElement('canvas');
  #|     canvas.width = width;
  #|     canvas.height = height;
  #|     const ctx = canvas.getContext('2d');
  #|     ctx.drawImage(img, 0, 0);
  #|     canvas.toBlob(blob => {
  #|       URL.revokeObjectURL(url);
  #|       if (!blob) { onError(); return; }
  #|       const item = new ClipboardItem({ 'image/png': blob });
  #|       navigator.clipboard.write([item])
  #|         .then(() => onDone())
  #|         .catch(() => onError());
  #|     }, 'image/png');
  #|   };
  #|   img.onerror = () => {
  #|     URL.revokeObjectURL(url);
  #|     onError();
  #|   };
  #|   img.src = url;
  #| }

///|
/// クリップボードからテキストを読み込み
pub extern "js" fn read_clipboard_text(
  on_success : (String) -> Unit,
  on_error : () -> Unit,
) =
  #| (onSuccess, onError) => {
  #|   navigator.clipboard.readText()
  #|     .then(text => onSuccess(text))
  #|     .catch(() => onError());
  #| }

///|
/// ファイル選択ダイアログを開く
pub extern "js" fn open_file_dialog(
  accept : String,
  on_file : (String) -> Unit,
) =
  #| (accept, onFile) => {
  #|   const input = document.createElement('input');
  #|   input.type = 'file';
  #|   input.accept = accept;
  #|   input.onchange = async (e) => {
  #|     const file = e.target.files[0];
  #|     if (file) {
  #|       const text = await file.text();
  #|       onFile(text);
  #|     }
  #|   };
  #|   input.click();
  #| }

///|
/// SVG文字列をパースしてDOM要素を返す
pub extern "js" fn parse_svg_string(svg_str : String) -> @js.Any =
  #| (svg) => {
  #|   const parser = new DOMParser();
  #|   const doc = parser.parseFromString(svg, 'image/svg+xml');
  #|   const parseError = doc.querySelector('parsererror');
  #|   if (parseError) return null;
  #|   return doc.documentElement;
  #| }

///|
/// SVG要素の子要素リストを取得
pub extern "js" fn get_svg_children(svg : @js.Any) -> @js.Any =
  #| (svg) => Array.from(svg.children)

///|
/// 要素のタグ名を取得
pub extern "js" fn get_tag_name(el : @js.Any) -> String =
  #| (el) => el.tagName.toLowerCase()

///|
/// 要素の属性を取得（存在しない場合はnull）
pub extern "js" fn get_attribute(el : @js.Any, name : String) -> @js.Any =
  #| (el, name) => el.getAttribute(name)

///|
/// 要素のテキスト内容を取得
pub extern "js" fn get_text_content(el : @js.Any) -> String =
  #| (el) => el.textContent || ''

// ============================================================
// IndexedDB API
// ============================================================

///|
/// IndexedDB に文字列を保存
pub extern "js" fn save_to_indexeddb(
  db_name : String,
  store_name : String,
  key : String,
  value : String,
  on_done : () -> Unit,
  on_error : () -> Unit,
) =
  #| (dbName, storeName, key, value, onDone, onError) => {
  #|   const request = indexedDB.open(dbName, 1);
  #|   request.onupgradeneeded = (e) => {
  #|     const db = e.target.result;
  #|     if (!db.objectStoreNames.contains(storeName)) {
  #|       db.createObjectStore(storeName);
  #|     }
  #|   };
  #|   request.onsuccess = (e) => {
  #|     const db = e.target.result;
  #|     const tx = db.transaction(storeName, 'readwrite');
  #|     const store = tx.objectStore(storeName);
  #|     store.put(value, key);
  #|     tx.oncomplete = () => { db.close(); onDone(); };
  #|     tx.onerror = () => { db.close(); onError(); };
  #|   };
  #|   request.onerror = () => onError();
  #| }

///|
/// IndexedDB から文字列を読み込み
pub extern "js" fn load_from_indexeddb(
  db_name : String,
  store_name : String,
  key : String,
  on_success : (String) -> Unit,
  on_not_found : () -> Unit,
  on_error : () -> Unit,
) =
  #| (dbName, storeName, key, onSuccess, onNotFound, onError) => {
  #|   const request = indexedDB.open(dbName, 1);
  #|   request.onupgradeneeded = (e) => {
  #|     const db = e.target.result;
  #|     if (!db.objectStoreNames.contains(storeName)) {
  #|       db.createObjectStore(storeName);
  #|     }
  #|   };
  #|   request.onsuccess = (e) => {
  #|     const db = e.target.result;
  #|     const tx = db.transaction(storeName, 'readonly');
  #|     const store = tx.objectStore(storeName);
  #|     const getReq = store.get(key);
  #|     getReq.onsuccess = () => {
  #|       db.close();
  #|       if (getReq.result === undefined) {
  #|         onNotFound();
  #|       } else {
  #|         onSuccess(getReq.result);
  #|       }
  #|     };
  #|     getReq.onerror = () => { db.close(); onError(); };
  #|   };
  #|   request.onerror = () => onError();
  #| }
