// 共通レンダリングモジュール
// Preview/Embed/WebComponent で共通のSVGレンダリング関数

// =============================================================================
// FFI 関数
// =============================================================================

///|
/// SVG 要素を作成（createElementNS）
pub extern "js" fn create_svg_element_ns(tag : String) -> @js.Any =
  #| (tag) => document.createElementNS('http://www.w3.org/2000/svg', tag)

///|
/// SVG 要素に属性を設定
pub extern "js" fn set_svg_attr(el : @js.Any, name : String, value : String) =
  #| (el, name, value) => el.setAttribute(name, value)

///|
/// 子要素を追加
pub extern "js" fn append_child(parent : @js.Any, child : @js.Any) =
  #| (parent, child) => parent.appendChild(child)

///|
/// innerHTML を設定
pub extern "js" fn set_inner_html(el : @js.Any, html : String) =
  #| (el, html) => el.innerHTML = html

// =============================================================================
// 矢印マーカー定義
// =============================================================================

// =============================================================================
// スタイル属性ヘルパー
// =============================================================================

// =============================================================================
// 要素レンダリング（共通ロジック）
// =============================================================================

// =============================================================================
// 選択枠・アンカーポイント描画
// =============================================================================

// =============================================================================
// 要素の境界計算
// =============================================================================

// =============================================================================
// アンカーポイント位置計算
// =============================================================================

// =============================================================================
// SVGエクスポート
// =============================================================================

// =============================================================================
// プレビュー線描画（アンカードラッグ時）
// =============================================================================

///|
/// フリードロープレビューを描画
pub fn draw_free_draw_preview(
  svg : @js.Any,
  points : Array[@model.Point],
) -> Unit {
  if points.length() < 2 {
    remove_free_draw_preview(svg)
    return
  }
  let points_str = points.map(fn(p) { "\{p.x},\{p.y}" }).join(" ")
  draw_free_draw_preview_ffi(svg, points_str)
}

///|
extern "js" fn draw_free_draw_preview_ffi(svg : @js.Any, points_str : String) =
  #| (svg, pointsStr) => {
  #|   let existing = svg.querySelector('.free-draw-preview');
  #|   if (!existing) {
  #|     existing = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
  #|     existing.setAttribute('class', 'free-draw-preview');
  #|     existing.setAttribute('fill', 'none');
  #|     existing.setAttribute('stroke', '#888');
  #|     existing.setAttribute('stroke-width', '1');
  #|     existing.setAttribute('stroke-linecap', 'round');
  #|     existing.setAttribute('stroke-linejoin', 'round');
  #|     existing.setAttribute('stroke-dasharray', '4 2');
  #|     existing.setAttribute('opacity', '0.6');
  #|     existing.setAttribute('pointer-events', 'none');
  #|     svg.appendChild(existing);
  #|   }
  #|   existing.setAttribute('points', pointsStr);
  #| }

///|
/// フリードロープレビューを削除
pub extern "js" fn remove_free_draw_preview(svg : @js.Any) =
  #| (svg) => {
  #|   const existing = svg.querySelector('.free-draw-preview');
  #|   if (existing) existing.remove();
  #| }
