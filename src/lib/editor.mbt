// 共通ライブラリ - エディタ作成ロジック
// FFI関数とレンダリング関数は render.mbt から使用

///|
/// 要素のスタイルを設定
pub extern "js" fn set_style(el : @js.Any, style : String) =
  #| (el, style) => el.style.cssText = style

///|
/// null を返す
extern "js" fn js_null() -> @js.Any =
  #| () => null

///|
/// コンテナをクリア
pub extern "js" fn clear_container_ffi(container : @js.Any) =
  #| (container) => { container.innerHTML = ''; }

///|
/// エディタハンドルを作成
pub extern "js" fn create_editor_handle(
  export_svg_fn : () -> String,
  import_svg_fn : (String) -> Unit,
  clear_fn : () -> Unit,
  destroy_fn : () -> Unit,
  has_focus_fn : () -> Bool,
) -> @js.Any =
  #| (exportSvg, importSvg, clear, destroy, hasFocus) => ({
  #|   _changeCallbacks: [],
  #|   exportSvg: exportSvg,
  #|   importSvg: importSvg,
  #|   clear: clear,
  #|   destroy: destroy,
  #|   hasFocus: hasFocus,
  #|   onChange: function(callback) { this._changeCallbacks.push(callback); }
  #| })

///|
/// プレビューハンドルを作成
pub extern "js" fn create_preview_handle(
  open_fn : () -> Unit,
  close_fn : () -> Unit,
  is_open_fn : () -> Bool,
  get_svg_fn : () -> String,
  set_svg_fn : (String) -> Unit,
) -> @js.Any =
  #| (open, close, isOpen, getSvg, setSvg) => ({
  #|   openEditor: open,
  #|   closeEditor: close,
  #|   isOpen: isOpen,
  #|   getSvg: getSvg,
  #|   setSvg: setSvg
  #| })

// SimpleEditorState は @core.EditorState の型エイリアス

///|
pub type SimpleEditorState = @core.EditorState

///|
/// 埋め込みエディタ状態を作成
pub fn create_embed_state(
  width : Int,
  height : Int,
  options : EditorOptions,
) -> @core.EditorState {
  let state = @core.EditorState::new_with_mode(width, height, @core.Embedded)
  // オプションを適用
  state.theme_mode.set(parse_theme(options.theme))
  state.is_readonly.set(options.is_readonly)
  state.show_toolbar.set(options.toolbar_visible)
  state
}

// ============================================================
// ヘルパー関数（単一選択用）
// ============================================================

// get_selected_id は @core.EditorState のメソッドとして定義
// state.get_selected_id() を使用

///|
/// 選択を設定（単一選択として）
pub fn set_selected_id(state : @core.EditorState, id : String?) -> Unit {
  match id {
    Some(i) => state.selected_ids.set([i])
    None => state.selected_ids.set([])
  }
}

///|
/// SVG を再描画（共通レンダリング関数を使用）
pub fn redraw_svg(state : @core.EditorState) -> Unit {
  let svg = state.svg_el.get()
  // 既存の子要素をクリア
  clear_svg_children(svg)
  // 矢印マーカーの defs を再追加
  let defs = create_arrow_defs()
  append_child(svg, defs)
  // 背景を追加
  let bg = create_svg_element_ns("rect")
  set_svg_attr(bg, "width", "100%")
  set_svg_attr(bg, "height", "100%")
  let bg_color = match state.theme_mode.get() {
    @model.Dark => "#1a1a2e"
    @model.Light => "#ffffff"
  }
  set_svg_attr(bg, "fill", bg_color)
  append_child(svg, bg)
  // 要素を描画（選択状態に応じてハイライト）
  let selected_id = state.get_selected_id()
  let elements = state.elements.get()
  for el in elements {
    let is_selected = match selected_id {
      Some(id) => el.id == id
      None => false
    }
    // 親要素のストローク色を取得（テキスト要素の色継承用）
    let parent_stroke = @model.get_parent_stroke(elements, el.parent_id)
    let dom_el = render_element_to_svg_with_parent(
      el, is_selected, parent_stroke,
    )
    append_child(svg, dom_el)
  }
}

///|
/// SVG コンテナを作成して初期化
pub fn create_svg_container(
  state : @core.EditorState,
  container : @js.Any,
) -> @js.Any {
  let width = state.width
  let height = state.height
  // SVG 要素を作成
  let svg = create_svg_element_ns("svg")
  set_svg_attr(svg, "viewBox", "0 0 \{width} \{height}")
  set_svg_attr(svg, "width", width.to_string())
  set_svg_attr(svg, "height", height.to_string())
  set_style(svg, "display: block; max-width: 100%; height: auto;")
  // 矢印マーカーの defs を追加
  let defs = create_arrow_defs()
  append_child(svg, defs)
  // コンテナに追加
  append_child(container, svg)
  // 状態に参照を保存
  state.svg_el.set(svg)
  state.container_el.set(container)
  // ツールモード変更時のカーソル変更エフェクト
  setup_cursor_effect(state, svg)
  // 初期描画
  redraw_svg(state)
  svg
}

///|
/// ツールモードに応じたカーソル変更エフェクトをセットアップ
fn setup_cursor_effect(state : @core.EditorState, svg : @js.Any) -> Unit {
  let _ = @luna.effect(fn() {
    let mode = state.tool_mode.get()
    let cursor = match mode {
      @core.FreeDraw => "crosshair"
      @core.Select => "default"
    }
    set_style_property(svg, "cursor", cursor)
  })

}

///|
/// 要素の CSS スタイルプロパティを設定
extern "js" fn set_style_property(el : @js.Any, prop : String, value : String) =
  #| (el, prop, value) => el.style[prop] = value

///|
/// 簡易 SVG パーサー（基本的な図形のみ）
pub fn parse_simple_svg(
  svg_string : String,
  new_id : () -> String,
) -> Array[@model.Element] {
  let elements : Array[@model.Element] = []
  // 非常に簡易的なパーサー（実際のプロダクションでは DOM パーサーを使用すべき）
  // rect, circle, ellipse, line, text を検出
  parse_svg_rects(svg_string, elements, new_id)
  parse_svg_circles(svg_string, elements, new_id)
  elements
}

///|
/// SVG から rect 要素をパース（簡易版）
fn parse_svg_rects(
  _svg : String,
  _elements : Array[@model.Element],
  _new_id : () -> String,
) -> Unit {
  // 簡易実装：実際のプロダクションでは正規表現または DOM パーサーを使用
  // ここでは省略
}

///|
/// SVG から circle 要素をパース（簡易版）
fn parse_svg_circles(
  _svg : String,
  _elements : Array[@model.Element],
  _new_id : () -> String,
) -> Unit {
  // 簡易実装
}

///|
/// サンプル図形を追加
pub fn add_sample_elements(state : @core.EditorState) -> Unit {
  let elements : Array[@model.Element] = [
    {
      id: "sample-rect",
      x: 50.0,
      y: 50.0,
      shape: @model.Rect(100.0, 60.0, None, None),
      style: {
        fill: Some("#4CAF50"),
        stroke: Some("#2E7D32"),
        stroke_width: Some(2.0),
        opacity: None,
        stroke_dasharray: None,
        marker_start: None,
        marker_end: None,
        font_family: None,
      },
      transform: None,
      parent_id: None,
      connections: None,
    },
    {
      id: "sample-circle",
      x: 250.0,
      y: 100.0,
      shape: @model.Circle(40.0),
      style: {
        fill: Some("#2196F3"),
        stroke: Some("#1565C0"),
        stroke_width: Some(2.0),
        opacity: None,
        stroke_dasharray: None,
        marker_start: None,
        marker_end: None,
        font_family: None,
      },
      transform: None,
      parent_id: None,
      connections: None,
    },
    // 矢印付きLine（サンプル）
    {
      id: "sample-arrow",
      x: 150.0,
      y: 80.0,
      shape: @model.Line(210.0, 80.0),
      style: {
        fill: None,
        stroke: Some("#333333"),
        stroke_width: Some(2.0),
        opacity: None,
        stroke_dasharray: None,
        marker_start: None,
        marker_end: Some(@model.Arrow),
        font_family: None,
      },
      transform: None,
      parent_id: None,
      connections: None,
    },
  ]
  state.elements.set(elements)
}
