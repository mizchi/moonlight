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
) -> @js.Any =
  #| (style, initialValue, onCommit, onEscape) => {
  #|   const textarea = document.createElement('textarea');
  #|   textarea.id = 'inline-text-edit';
  #|   textarea.style.cssText = style;
  #|   textarea.rows = 1;
  #|   textarea.value = initialValue;
  #|   let isComposing = false;
  #|   textarea.addEventListener('compositionstart', () => { isComposing = true; });
  #|   textarea.addEventListener('compositionend', () => { isComposing = false; });
  #|   textarea.addEventListener('keydown', (e) => {
  #|     if (e.key === 'Enter' && !isComposing) {
  #|       // Enter（Shift有無問わず、IMEコンポジション中でない場合）: 確定
  #|       e.preventDefault();
  #|       onCommit(textarea.value);
  #|     } else if (e.key === 'Escape') {
  #|       // Escape: キャンセル（初期値に戻す）
  #|       e.preventDefault();
  #|       onEscape(initialValue);
  #|     }
  #|   });
  #|   textarea.addEventListener('blur', () => {
  #|     onCommit(textarea.value);
  #|   });
  #|   textarea.addEventListener('input', () => {
  #|     // 横幅を自動調整（テキストに合わせて伸びる）
  #|     textarea.style.width = 'auto';
  #|     textarea.style.width = Math.max(textarea.scrollWidth, 40) + 'px';
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
