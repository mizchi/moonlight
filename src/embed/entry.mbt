// 埋め込みモード - エントリポイント
// JavaScript から MoonlightEditor.create() で呼び出される

///|
/// JavaScript グローバルに createEditor を登録
extern "js" fn register_create_editor(
  create_fn : (@js.Any, @js.Any) -> @js.Any,
) =
  #| (createFn) => {
  #|   globalThis.MoonlightEditor = {
  #|     create: createFn
  #|   };
  #| }

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
/// エディタを作成（JavaScript から呼び出される）
fn create_editor_internal(container : @js.Any, options_js : @js.Any) -> @js.Any {
  let options = @lib.EditorOptions::from_js(options_js)
  let width = options.width.unwrap_or(400)
  let height = options.height.unwrap_or(300)
  // エディタ状態を作成
  let state = @lib.SimpleEditorState::new(width, height, options)
  // 初期 SVG が指定されている場合はパース
  match options.initial_svg {
    Some(svg_str) => {
      let elements = @lib.parse_simple_svg(svg_str, new_id)
      if elements.length() > 0 {
        state.elements.set(elements)
      } else {
        @lib.add_sample_elements(state)
      }
    }
    None => @lib.add_sample_elements(state)
  }
  // SVG コンテナを作成
  let _ = @lib.create_svg_container(state, container)
  // ドラッグ状態を作成
  let drag_state = @lib.DragState::new()
  // インタラクションをセットアップ
  @lib.setup_interaction(state, drag_state)
  // 要素変更時に再描画
  let _ = @luna.effect(fn() {
    let _ = state.elements.get()
    @lib.redraw_svg(state)
    // 選択枠を描画
    @lib.render_selection_rect(state)
  })
  // 選択変更時に選択枠を更新
  let _ = @luna.effect(fn() {
    let _ = state.selected_id.get()
    @lib.render_selection_rect(state)
  })
  // フォーカス管理をセットアップ
  let focus_state : @lib.FocusState = {
    has_focus: state.has_focus,
    container: @luna.signal(None),
  }
  @lib.setup_focus_management(focus_state, container)
  // エディタハンドルを作成
  let export_svg = fn() -> String {
    let bg_color = match state.theme_mode.get() {
      @model.Dark => "#1a1a2e"
      @model.Light => "#ffffff"
    }
    @lib.export_elements_to_svg(state.elements.get(), width, height, bg_color)
  }
  let import_svg = fn(svg_str : String) -> Unit {
    let elements = @lib.parse_simple_svg(svg_str, new_id)
    if elements.length() > 0 {
      state.elements.set(elements)
    }
  }
  let clear = fn() -> Unit { state.elements.set([]) }
  let destroy = fn() -> Unit {
    state.elements.set([])
    @lib.clear_container_ffi(container)
  }
  let has_focus = fn() -> Bool { state.has_focus.get() }
  @lib.create_editor_handle(export_svg, import_svg, clear, destroy, has_focus)
}

///|
/// メイン関数（JavaScript から自動的に呼ばれる）
fn main {
  // グローバルに MoonlightEditor.create を登録
  register_create_editor(create_editor_internal)
}
