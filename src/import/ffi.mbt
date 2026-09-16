// SVG Import 用 FFI 関数

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
extern "js" fn get_svg_children(svg : @js.Any) -> @js.Any =
  #| (svg) => Array.from(svg.children)

///|
/// 要素のタグ名を取得
extern "js" fn get_tag_name(el : @js.Any) -> String =
  #| (el) => el.tagName.toLowerCase()

///|
/// 要素の属性を取得（存在しない場合はnull）
extern "js" fn get_attribute(el : @js.Any, name : String) -> @js.Any =
  #| (el, name) => el.getAttribute(name)

///|
/// 要素のテキスト内容を取得
extern "js" fn get_text_content(el : @js.Any) -> String =
  #| (el) => el.textContent || ''

///|
/// 文字列を Double にパース（FFI）
extern "js" fn parse_double_ffi(s : String) -> @js.Any =
  #| (s) => { const n = parseFloat(s); return isNaN(n) ? null : n; }

///|
/// 文字列を Double にパース
fn parse_double(s : String) -> Double? {
  let result = parse_double_ffi(s)
  if @js.is_nullish(result) {
    None
  } else {
    Some(result.cast())
  }
}

///|
/// transform が translate() だけで出来ていれば、合計を [tx, ty] で返す。
/// rotate/scale/matrix が混ざっていれば null（座標には畳み込めない）。
extern "js" fn sum_translates_ffi(t : String) -> @js.Any =
  #| (t) => {
  #|   const terms = t.match(/[a-zA-Z]+\s*\([^)]*\)/g);
  #|   if (!terms) return null;
  #|   let tx = 0, ty = 0;
  #|   for (const term of terms) {
  #|     const m = /^translate\s*\(\s*(-?[\d.eE+-]+)\s*(?:[, ]\s*(-?[\d.eE+-]+)\s*)?\)$/.exec(term.trim());
  #|     if (!m) return null;
  #|     const x = parseFloat(m[1]);
  #|     const y = m[2] === undefined ? 0 : parseFloat(m[2]);
  #|     if (!isFinite(x) || !isFinite(y)) return null;
  #|     tx += x; ty += y;
  #|   }
  #|   return [tx, ty];
  #| }

///|
/// transform を平行移動として読む。読めなければ None。
fn as_translation(t : String) -> (Double, Double)? {
  let result = sum_translates_ffi(t)
  if @js.is_nullish(result) {
    None
  } else {
    let pair : Array[Double] = result.cast()
    Some((pair[0], pair[1]))
  }
}
