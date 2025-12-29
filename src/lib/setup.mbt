// 共通ライブラリ - エディタセットアップロジック
// Embed と WebComponents で共通して使用する初期化処理

///|
/// エディタセットアップ結果
pub struct EditorSetupResult {
  state : @core.EditorState
  handle : @js.Any
  context_menu : ContextMenuState
}

///|
/// エディタをセットアップ（共通ロジック）
/// container: エディタを挿入する DOM 要素
/// options: エディタオプション
/// new_id: 新しい ID を生成する関数
pub fn setup_editor(
  container : @js.Any,
  options : EditorOptions,
  new_id : () -> String,
) -> EditorSetupResult {
  let width = options.width.unwrap_or(400)
  let height = options.height.unwrap_or(300)
  // エディタ状態を作成
  let state = create_embed_state(width, height, options)
  // 初期 SVG が指定されている場合はパース（空でもデモを表示しない）
  match options.initial_svg {
    Some(svg_str) => {
      let elements = parse_simple_svg(svg_str, new_id)
      if elements.length() > 0 {
        state.elements.set(elements)
      }
      // initialSvg が指定されていれば、空でもデモは表示しない
    }
    None => add_sample_elements(state)
  }
  // SVG コンテナを作成
  let _ = create_svg_container(state, container)
  // ドラッグ状態を作成
  let drag_state = DragState::new()
  // インタラクションをセットアップ
  setup_interaction(state, drag_state)
  // キーボードハンドラをセットアップ
  setup_keyboard_handler(state, new_id)
  // 要素変更時に再描画
  let _ = @luna.effect(fn() {
    let _ = state.elements.get()
    redraw_svg(state)
    // 選択枠とアンカーポイントを描画
    update_selection_ui(state)
    render_anchor_points(state)
  })
  // 選択変更時に選択枠とアンカーポイントを更新
  let _ = @luna.effect(fn() {
    let _ = state.selected_ids.get()
    update_selection_ui(state)
    render_anchor_points(state)
  })
  // フォーカス管理をセットアップ
  let focus_state : FocusState = {
    has_focus: state.has_focus,
    container: @luna.signal(None),
  }
  setup_focus_management(focus_state, container)
  // コンテキストメニューをセットアップ
  let context_menu = ContextMenuState::new()
  setup_context_menu(state, context_menu, new_id)
  // エディタハンドルを作成
  let export_svg = fn() -> String {
    let bg_color = match state.theme_mode.get() {
      @model.Dark => "#1a1a2e"
      @model.Light => "#ffffff"
    }
    export_elements_to_svg(state.elements.get(), width, height, bg_color)
  }
  let import_svg = fn(svg_str : String) -> Unit {
    let elements = parse_simple_svg(svg_str, new_id)
    if elements.length() > 0 {
      state.elements.set(elements)
    }
  }
  let clear = fn() -> Unit { state.elements.set([]) }
  let destroy = fn() -> Unit {
    state.elements.set([])
    clear_container_ffi(container)
  }
  let has_focus_fn = fn() -> Bool { state.has_focus.get() }
  let handle = create_editor_handle(
    export_svg, import_svg, clear, destroy, has_focus_fn,
  )
  { state, handle, context_menu }
}
