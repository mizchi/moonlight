// Moonlight - 軽量 SVG エディタ

///|
using @element {div, button, text, text_dyn, events, show, input}

///|
/// キャンバスサイズ
let canvas_width : Int = 400

///|
let canvas_height : Int = 300

///|
/// IndexedDB 設定
let db_name : String = "moonlight-editor"

///|
let store_name : String = "scenes"

///|
let scene_key : String = "current"

///|
/// ID カウンター（Signal で管理）
fn create_id_counter() -> @luna.Signal[Int] {
  @luna.signal(0)
}

// ============================================================
// JavaScript 埋め込み用 API
// ============================================================

///|
/// エディタオプション（JavaScript から渡される）
pub struct EmbedOptions {
  width : Int // キャンバス幅（ピクセル）
  height : Int // キャンバス高さ（ピクセル）
  doc_width : Int // ドキュメント幅（viewBox）
  doc_height : Int // ドキュメント高さ（viewBox）
  zoom : Double // 初期ズーム
  theme : String
  is_readonly : Bool
  initial_svg : String? // 初期 SVG（None ならデモ表示）
}

///|
/// デフォルトオプション
pub fn EmbedOptions::default() -> EmbedOptions {
  {
    width: 400,
    height: 300,
    doc_width: 400,
    doc_height: 300,
    zoom: 1.0,
    theme: "light",
    is_readonly: false,
    initial_svg: None,
  }
}

///|
/// JavaScript オブジェクトからオプションを作成
pub fn EmbedOptions::from_js(js_obj : @js.Any) -> EmbedOptions {
  let width = get_int_or_default(js_obj, "width", 400)
  let height = get_int_or_default(js_obj, "height", 300)
  let doc_width = get_int_or_default(js_obj, "doc_width", width)
  let doc_height = get_int_or_default(js_obj, "doc_height", height)
  let zoom = get_double_or_default(js_obj, "zoom", 1.0)
  let theme = get_string_or_default(js_obj, "theme", "light")
  let is_readonly = get_bool_or_default(js_obj, "is_readonly", false)
  let initial_svg = get_string_option(js_obj, "initial_svg")
  {
    width,
    height,
    doc_width,
    doc_height,
    zoom,
    theme,
    is_readonly,
    initial_svg,
  }
}

///|
extern "js" fn get_int_or_default(
  obj : @js.Any,
  key : String,
  default_val : Int,
) -> Int =
  #| (obj, key, def) => typeof obj[key] === 'number' ? obj[key] : def

///|
extern "js" fn get_string_or_default(
  obj : @js.Any,
  key : String,
  default_val : String,
) -> String =
  #| (obj, key, def) => typeof obj[key] === 'string' ? obj[key] : def

///|
extern "js" fn get_bool_or_default(
  obj : @js.Any,
  key : String,
  default_val : Bool,
) -> Bool =
  #| (obj, key, def) => typeof obj[key] === 'boolean' ? obj[key] : def

///|
extern "js" fn get_double_or_default(
  obj : @js.Any,
  key : String,
  default_val : Double,
) -> Double =
  #| (obj, key, def) => typeof obj[key] === 'number' ? obj[key] : def

///|
extern "js" fn get_string_option_ffi(obj : @js.Any, key : String) -> @js.Any =
  #| (obj, key) => obj[key]

///|
extern "js" fn is_string_ffi(val : @js.Any) -> Bool =
  #| (val) => typeof val === 'string'

///|
/// PointerEvent から pointerId を取得
extern "js" fn get_pointer_id(e : @js.Any) -> Int =
  #| (e) => e.pointerId || 0

///|
fn get_string_option(obj : @js.Any, key : String) -> String? {
  let val = get_string_option_ffi(obj, key)
  if is_string_ffi(val) {
    Some(val.cast())
  } else {
    None
  }
}

///|
/// JavaScript 埋め込み用エディタを作成
/// container: DOM コンテナ要素
/// options: エディタオプション
/// 戻り値: エディタハンドル
pub fn create_js_editor(container : @js.Any, options : EmbedOptions) -> @js.Any {
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }

  // 状態を作成（キャンバスサイズを使用）
  let state = @core.EditorState::new_with_mode(
    options.width,
    options.height,
    @core.Embedded,
  )
  let history = @model.History::new()

  // ドキュメントサイズを設定
  state.doc_width.set(options.doc_width.to_double())
  state.doc_height.set(options.doc_height.to_double())

  // ズームを設定（プレビューと同じスケールを維持）
  let viewport = state.viewport.get()
  state.viewport.set({ ..viewport, zoom: options.zoom, })

  // テーマを設定
  let theme = if options.theme == "dark" { @model.Dark } else { @model.Light }
  state.theme_mode.set(theme)
  state.is_readonly.set(options.is_readonly)

  // 初期 SVG が指定されていればパース、なければサンプル要素を追加
  match options.initial_svg {
    Some(svg_str) => {
      let result = import_svg_validated(svg_str, new_id)
      if result.elements.length() > 0 {
        state.elements.set(result.elements)
        // プレーンSVG要素を登録
        if result.plain_svg_ids.length() > 0 {
          state.register_plain_svg_ids(result.plain_svg_ids)
        }
        // バリデーション実行
        state.revalidate()
      }
      // initial_svg が指定されていれば、空でもサンプルは表示しない
    }
    None => add_sample_shapes(state, new_id)
  }

  // コンテナ要素を状態に保存（キーボードハンドラで使用）
  state.container_el.set(container)

  // Luna でレンダリング
  let editor_node = embedded_editor_app(state, history, new_id)
  let dom_container : @js_dom.Element = @js.identity(container)
  @element.render(dom_container |> @element.DomElement::from_dom, editor_node)

  // フォーカス管理をセットアップ（キーボードイベントの制御用）
  let focus_state : @lib.FocusState = {
    has_focus: state.has_focus,
    container: @luna.signal(None),
  }
  @lib.setup_focus_management(focus_state, container)

  // キーボードハンドラをセットアップ（コンテナ単位で受ける）
  @lib.setup_keyboard_handler(state, history, new_id)

  // ハンドルを作成
  let handle = create_editor_handle_js(
    state,
    options.doc_width,
    options.doc_height,
  )

  // イベントリスナーをセットアップ
  setup_handle_events(state, handle)
  handle
}

///|
/// エディタハンドルを作成（JavaScript オブジェクト）
fn create_editor_handle_js(
  state : @core.EditorState,
  width : Int,
  height : Int,
) -> @js.Any {
  let export_svg = fn() -> String {
    let bg_color = match state.theme_mode.get() {
      @model.Dark => "#1a1a2e"
      @model.Light => "#ffffff"
    }
    elements_to_moonlight_svg(state.elements.get(), width, height, bg_color)
  }
  // 取り込めたかどうかを返す。読めない SVG や、対応していない図形しか入って
  // いない SVG を渡されたとき、黙って前のシーンを残したままにすると、埋め込み
  // 側からは成功と区別が付かない。
  let import_svg = fn(svg_str : String) -> Bool {
    let id_counter = create_id_counter()
    let new_id = fn() -> String {
      let current = id_counter.get()
      id_counter.set(current + 1)
      "el-\{current + 1}"
    }
    let result = import_svg_validated(svg_str, new_id)
    if result.elements.length() == 0 {
      return false
    }
    state.elements.set(result.elements)
    // プレーンSVG要素を登録
    state.clear_plain_svg_ids() // 既存のIDをクリア
    if result.plain_svg_ids.length() > 0 {
      state.register_plain_svg_ids(result.plain_svg_ids)
    }
    // バリデーション実行
    state.revalidate()
    true
  }
  let clear = fn() -> Unit { state.elements.set([]) }
  let has_focus = fn() -> Bool { state.has_focus.get() }
  // 選択 API
  let select = fn(ids : Array[String]) -> Unit { state.selected_ids.set(ids) }
  let select_all = fn() -> Unit {
    let all_ids = state.elements.get().map(fn(el) { el.id })
    state.selected_ids.set(all_ids)
  }
  let deselect = fn() -> Unit { state.selected_ids.set([]) }
  let get_selected_ids = fn() -> Array[String] { state.selected_ids.get() }
  // フォーカス API
  // フラグだけ立てても keydown はコンテナまで上がってこないので、DOM 側の
  // フォーカスも一緒に移す
  let focus = fn() -> Unit {
    state.has_focus.set(true)
    @lib.focus_container(state)
  }
  let blur = fn() -> Unit { state.has_focus.set(false) }
  // 要素操作 API
  let get_elements = fn() -> Array[@model.Element] { state.elements.get() }
  let delete_elements = fn(ids : Array[String]) -> Unit {
    state.elements.update(fn(els) {
      els.filter(fn(el) { !ids.contains(el.id) })
    })
    // 削除された要素を選択から除外
    state.selected_ids.update(fn(sel) {
      sel.filter(fn(id) { !ids.contains(id) })
    })
  }
  // モード API
  let set_mode = fn(mode : String) -> Unit {
    let tool_mode = if mode == "freedraw" {
      @core.FreeDraw
    } else {
      @core.Select
    }
    state.tool_mode.set(tool_mode)
  }
  let get_mode = fn() -> String {
    match state.tool_mode.get() {
      @core.Select => "select"
      @core.FreeDraw => "freedraw"
    }
  }
  // readonly API
  let set_readonly = fn(value : Bool) -> Unit { state.is_readonly.set(value) }
  let is_readonly = fn() -> Bool { state.is_readonly.get() }
  create_editor_handle_ffi(
    export_svg, import_svg, clear, has_focus, select, select_all, deselect, get_selected_ids,
    focus, blur, get_elements, delete_elements, set_mode, get_mode, set_readonly,
    is_readonly,
  )
}

///|
/// FFI でハンドルオブジェクトを作成
extern "js" fn create_editor_handle_ffi(
  export_svg : () -> String,
  import_svg : (String) -> Bool,
  clear : () -> Unit,
  has_focus : () -> Bool,
  select : (Array[String]) -> Unit,
  select_all : () -> Unit,
  deselect : () -> Unit,
  get_selected_ids : () -> Array[String],
  focus : () -> Unit,
  blur : () -> Unit,
  get_elements : () -> Array[@model.Element],
  delete_elements : (Array[String]) -> Unit,
  set_mode : (String) -> Unit,
  get_mode : () -> String,
  set_readonly : (Bool) -> Unit,
  is_readonly : () -> Bool,
) -> @js.Any =
  #| (exportSvg, importSvg, clear, hasFocus, select, selectAll, deselect, getSelectedIds, focus, blur, getElements, deleteElements, setMode, getMode, setReadonly, isReadonly) => {
  #| const toIdArray = (ids) =>
  #|   ids == null ? [] : Array.isArray(ids) ? ids : [ids];
  #| return ({
  #|   // 内部コールバック配列
  #|   _changeCallbacks: [],
  #|   _selectCallbacks: [],
  #|   _deselectCallbacks: [],
  #|   _focusCallbacks: [],
  #|   _blurCallbacks: [],
  #|   _modeChangeCallbacks: [],
  #|   _elementAddCallbacks: [],
  #|   _elementDeleteCallbacks: [],
  #|   // 既存 API
  #|   exportSvg: exportSvg,
  #|   importSvg: importSvg,
  #|   clear: clear,
  #|   destroy: () => {},
  #|   hasFocus: hasFocus,
  #|   // 選択 API
  #|   // MoonBit 側は ID の配列を取る。JS からは一つの ID を渡したくなるので
  #|   // ここで揃える（揃えないと Signal に文字列が入り、選択ハンドルが出ない）。
  #|   select: (ids) => select(toIdArray(ids)),
  #|   selectAll: selectAll,
  #|   deselect: deselect,
  #|   getSelectedIds: () => toIdArray(getSelectedIds()),
  #|   // フォーカス API
  #|   focus: focus,
  #|   blur: blur,
  #|   // 要素操作 API
  #|   getElements: getElements,
  #|   getElementById: function(id) {
  #|     const els = getElements();
  #|     return els.find(el => el.id === id) || null;
  #|   },
  #|   deleteElements: (ids) => deleteElements(toIdArray(ids)),
  #|   // モード API
  #|   setMode: setMode,
  #|   getMode: getMode,
  #|   // readonly API
  #|   setReadonly: setReadonly,
  #|   isReadonly: isReadonly,
  #|   // イベント購読 API
  #|   onChange: function(callback) {
  #|     this._changeCallbacks.push(callback);
  #|     return () => { this._changeCallbacks = this._changeCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onSelect: function(callback) {
  #|     this._selectCallbacks.push(callback);
  #|     return () => { this._selectCallbacks = this._selectCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onDeselect: function(callback) {
  #|     this._deselectCallbacks.push(callback);
  #|     return () => { this._deselectCallbacks = this._deselectCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onFocus: function(callback) {
  #|     this._focusCallbacks.push(callback);
  #|     return () => { this._focusCallbacks = this._focusCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onBlur: function(callback) {
  #|     this._blurCallbacks.push(callback);
  #|     return () => { this._blurCallbacks = this._blurCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onModeChange: function(callback) {
  #|     this._modeChangeCallbacks.push(callback);
  #|     return () => { this._modeChangeCallbacks = this._modeChangeCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onElementAdd: function(callback) {
  #|     this._elementAddCallbacks.push(callback);
  #|     return () => { this._elementAddCallbacks = this._elementAddCallbacks.filter(c => c !== callback); };
  #|   },
  #|   onElementDelete: function(callback) {
  #|     this._elementDeleteCallbacks.push(callback);
  #|     return () => { this._elementDeleteCallbacks = this._elementDeleteCallbacks.filter(c => c !== callback); };
  #|   },
  #|   // 内部: イベント発火用
  #|   _fireChange: function() { this._changeCallbacks.forEach(cb => cb()); },
  #|   _fireSelect: function(ids) { this._selectCallbacks.forEach(cb => cb(ids)); },
  #|   _fireDeselect: function() { this._deselectCallbacks.forEach(cb => cb()); },
  #|   _fireFocus: function() { this._focusCallbacks.forEach(cb => cb()); },
  #|   _fireBlur: function() { this._blurCallbacks.forEach(cb => cb()); },
  #|   _fireModeChange: function(mode) { this._modeChangeCallbacks.forEach(cb => cb(mode)); },
  #|   _fireElementAdd: function(id) { this._elementAddCallbacks.forEach(cb => cb(id)); },
  #|   _fireElementDelete: function(id) { this._elementDeleteCallbacks.forEach(cb => cb(id)); }
  #| });
  #| }

///|
/// ハンドルにイベントリスナーをセットアップ
fn setup_handle_events(state : @core.EditorState, handle : @js.Any) -> Unit {
  // 要素変更イベント
  let prev_elements : Ref[Array[@model.Element]] = { val: [], }
  let _ = @luna.effect(fn() {
    let elements = state.elements.get()
    // onChange を発火
    fire_change(handle)
    // 要素追加/削除を検出
    let prev_ids = prev_elements.val.map(fn(el) { el.id })
    let curr_ids = elements.map(fn(el) { el.id })
    // 追加された要素
    for id in curr_ids {
      if !prev_ids.contains(id) {
        fire_element_add(handle, id)
      }
    }
    // 削除された要素
    for id in prev_ids {
      if !curr_ids.contains(id) {
        fire_element_delete(handle, id)
      }
    }
    prev_elements.val = elements
  })
  // 選択変更イベント
  let prev_selected : Ref[Array[String]] = { val: [], }
  let _ = @luna.effect(fn() {
    let selected = state.selected_ids.get()
    if selected.length() > 0 && prev_selected.val.length() == 0 {
      // 選択開始
      fire_select(handle, to_fixed_strings(selected))
    } else if selected.length() == 0 && prev_selected.val.length() > 0 {
      // 選択解除
      fire_deselect(handle)
    } else if selected.length() > 0 {
      // 選択変更
      fire_select(handle, to_fixed_strings(selected))
    }
    prev_selected.val = selected
  })
  // フォーカス変更イベント
  let prev_focus : Ref[Bool] = { val: false, }
  let _ = @luna.effect(fn() {
    let focused = state.has_focus.get()
    if focused && !prev_focus.val {
      fire_focus(handle)
    } else if !focused && prev_focus.val {
      fire_blur(handle)
    }
    prev_focus.val = focused
  })
  // モード変更イベント
  let prev_mode : Ref[@core.ToolMode] = { val: @core.Select, }
  let _ = @luna.effect(fn() {
    let mode = state.tool_mode.get()
    if mode != prev_mode.val {
      let mode_str = match mode {
        @core.Select => "select"
        @core.FreeDraw => "freedraw"
      }
      fire_mode_change(handle, mode_str)
    }
    prev_mode.val = mode
  })
}

///|
/// イベント発火用 FFI
extern "js" fn fire_change(handle : @js.Any) =
  #| (h) => h._fireChange()

///|
/// JS FFI 境界では `Array` が非推奨なため `FixedArray` に詰め替える
fn to_fixed_strings(xs : Array[String]) -> FixedArray[String] {
  let out : FixedArray[String] = FixedArray::make(xs.length(), "")
  for i, x in xs {
    out[i] = x
  }
  out
}

///|
extern "js" fn fire_select(handle : @js.Any, ids : FixedArray[String]) =
  #| (h, ids) => h._fireSelect(ids)

///|
extern "js" fn fire_deselect(handle : @js.Any) =
  #| (h) => h._fireDeselect()

///|
extern "js" fn fire_focus(handle : @js.Any) =
  #| (h) => h._fireFocus()

///|
extern "js" fn fire_blur(handle : @js.Any) =
  #| (h) => h._fireBlur()

///|
extern "js" fn fire_mode_change(handle : @js.Any, mode : String) =
  #| (h, mode) => h._fireModeChange(mode)

///|
extern "js" fn fire_element_add(handle : @js.Any, id : String) =
  #| (h, id) => h._fireElementAdd(id)

///|
extern "js" fn fire_element_delete(handle : @js.Any, id : String) =
  #| (h, id) => h._fireElementDelete(id)

///|
/// 現在の状態を IndexedDB に保存
fn save_state(state : @core.EditorState) -> Unit {
  let elements = state.elements.get()
  let theme = state.theme_mode.get()
  let bg_color = match theme {
    @model.Dark => "#1a1a2e"
    @model.Light => "#ffffff"
  }
  let svg = elements_to_moonlight_svg(
    elements, canvas_width, canvas_height, bg_color,
  )
  save_to_indexeddb(db_name, store_name, scene_key, svg, fn() { () }, fn() {
    ()
  })
}

///|
/// IndexedDB から状態を読み込み
fn load_state(
  state : @core.EditorState,
  new_id : () -> String,
  on_loaded : () -> Unit,
  on_not_found : () -> Unit,
) -> Unit {
  load_from_indexeddb(
    db_name,
    store_name,
    scene_key,
    fn(svg_str) {
      let result = import_svg_validated(svg_str, new_id)
      if result.elements.length() > 0 {
        state.elements.set(result.elements)
        // プレーンSVG要素を登録（IndexedDBから読み込みなので既存はクリア）
        state.clear_plain_svg_ids()
        if result.plain_svg_ids.length() > 0 {
          state.register_plain_svg_ids(result.plain_svg_ids)
        }
        // バリデーション実行
        state.revalidate()
      }
      on_loaded()
    },
    on_not_found,
    on_not_found,
  )
}

///|
/// 自動保存の Effect を設定
fn setup_auto_save(state : @core.EditorState) -> Unit {
  let _ = @luna.effect(fn() {
    let _ = state.elements.get() // 依存関係を登録
    save_state(state)
  })
}

///|
/// URL パラメータからモードを取得
fn get_mode_from_url() -> @core.EditorMode {
  let search = get_url_search_ffi()
  if search.contains("mode=embed") {
    @core.Embedded
  } else {
    @core.Full
  }
}

///|

///|
/// アプリケーションのエントリポイント（外部から呼び出し可能）
pub fn app_main() -> Unit {
  guard @js_dom.document().getElementById("app") is Some(el) else { return }
  let mode = get_mode_from_url()
  match mode {
    @core.Full =>
      @element.render(el |> @element.DomElement::from_dom, editor_app())
    @core.Embedded => {
      let container : @js.Any = @js.identity(el)
      @element.render(
        el |> @element.DomElement::from_dom,
        create_embedded_app(container),
      )
    }
  }
}

///|
/// 埋め込みモード用のアプリを作成（外部から呼び出し可能）
/// container: キーボードとフォーカスを受け取る DOM 要素
pub fn create_embedded_app(container : @js.Any) -> @element.DomNode {
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }
  let state = @core.EditorState::new_with_mode(
    canvas_width,
    canvas_height,
    @core.Embedded,
  )
  let history = @model.History::new()
  // キーボードハンドラが見る先を先に決めておく
  state.container_el.set(container)
  // IndexedDB から読み込み、なければサンプルを追加
  load_state(state, new_id, fn() { setup_auto_save(state) }, fn() {
    add_sample_shapes(state, new_id)
    setup_auto_save(state)
  })
  let node = embedded_editor_app(state, history, new_id)
  // create_js_editor と同じ配線をする。ここが抜けていたので ?mode=embed では
  // キーが一つも効かなかった。
  let focus_state : @lib.FocusState = {
    has_focus: state.has_focus,
    container: @luna.signal(None),
  }
  @lib.setup_focus_management(focus_state, container)
  @lib.setup_keyboard_handler(state, history, new_id)
  node
}

///|
fn editor_app() -> @element.DomNode {
  // ID カウンター
  let id_counter = create_id_counter()
  let new_id = fn() -> String {
    let current = id_counter.get()
    id_counter.set(current + 1)
    "el-\{current + 1}"
  }

  // エディタ状態を初期化
  let state = @core.EditorState::new(canvas_width, canvas_height)

  // 履歴管理
  let history = @model.History::new()

  // IndexedDB から読み込み、なければサンプルを追加
  load_state(state, new_id, fn() { setup_auto_save(state) }, fn() {
    add_sample_shapes(state, new_id)
    setup_auto_save(state)
  })

  // ウィンドウサイズを監視してモバイル判定を更新
  let first_size : Ref[Bool] = { val: true, }
  observe_window_resize_ffi(fn(width, _height) {
    state.is_mobile.set(width < 768)
    // 狭い画面では、パネル（ボトムシート）は閉じた状態で始める。開いていると
    // キャンバスの大半を覆い、最初に出す図がほとんど見えない。
    if first_size.val {
      first_size.val = false
      state.panel_visible.set(width >= 768)
    }
  })

  // Space キーが押されているか
  let space_pressed : Ref[Bool] = { val: false, }

  // Space キーの監視を設定
  setup_keyboard_listener(state, history, space_pressed)

  // 座標取得ヘルパー
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }

  // ダブルクリック検出用の状態
  let last_click_time : Ref[Double] = { val: 0.0, }
  let last_click_element : Ref[String] = { val: "", }
  let double_click_threshold : Double = 300.0

  // アクティブポインター追跡（ピンチズーム用）
  let active_pointers : Ref[Map[Int, @model.Point]] = { val: {}, }

  // テキスト入力を確定するコールバック
  let commit_text_input = fn(text_content : String) {
    commit_text_edit(state, history, new_id, text_content)
  }

  // ポインターイベントハンドラ（タッチ/マウス/ペン統一）
  let on_pointerdown = create_pointerdown_handler(
    state, history, new_id, get_screen_coords, get_scene_coords, space_pressed, last_click_time,
    last_click_element, double_click_threshold, active_pointers,
  )
  let on_pointermove = create_pointermove_handler(
    state, history, get_screen_coords, get_scene_coords, active_pointers,
  )
  let on_pointerup = create_pointerup_handler(
    state,
    history,
    get_screen_coords,
    active_pointers,
    new_id~,
  )
  let on_pointerleave = create_pointerleave_handler(state)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)

  // キーボードショートカット
  setup_keyboard_shortcuts(state, history, new_id)

  // SVG キャンバスを Luna VNode として作成（for_each による差分更新）
  let svg_canvas = render_svg_canvas_node(
    state, on_pointerdown, on_pointermove, on_pointerup, on_pointerleave, on_contextmenu,
    on_wheel,
  )

  // UI
  render_editor_ui_vnode(state, history, new_id, svg_canvas, commit_text_input)
}

// ============================================================
// 初期化ヘルパー
// ============================================================

///|
/// キーボードリスナーを設定（Space + Arrow）
fn setup_keyboard_listener(
  state : @core.EditorState,
  history : @model.History,
  space_pressed : Ref[Bool],
) -> Unit {
  let _ = add_keydown_listener(fn(e) {
    if is_input_focused_ffi() {
      return
    }
    let key : String = e._get("key").cast()
    let keyboard_event : @js_dom.KeyboardEvent = e.cast()
    // Escape キー
    if key == "Escape" {
      if state.is_placing() {
        state.cancel_placement()
      } else if state.context_menu.get() is Some(_) {
        state.hide_context_menu()
      } else if state.tool_mode.get() == @core.FreeDraw {
        // フリードローモードなら Select に戻る
        state.tool_mode.set(@core.Select)
      } else {
        return
      }
      keyboard_event.preventDefault()
      return
    }
    // Space キーでパンモード
    if key == " " {
      space_pressed.val = true
      return
    }
    // コンテキストメニュー表示中は他のキー操作を無効化
    if state.context_menu.get() is Some(_) {
      return
    }
    // 矢印キー
    match key {
      "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight" => {
        let shift_key : Bool = e._get("shiftKey").cast()
        @lib.handle_arrow_key(state, history, key, shift_key)
        keyboard_event.preventDefault()
      }
      _ => ()
    }
  })
  let _ = add_keyup_listener(fn(e) {
    let key : String = e._get("key").cast()
    if key == " " {
      space_pressed.val = false
      if state.is_panning.get() {
        state.end_pan()
      }
    }
  })
}

// ============================================================
// イベントハンドラ作成
// ============================================================

///|
/// pointerdown ハンドラを作成（タッチ/マウス/ペン統一）
fn create_pointerdown_handler(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  get_screen_coords : (@js.Any) -> (Double, Double),
  get_scene_coords : (@js.Any) -> (Double, Double),
  space_pressed : Ref[Bool],
  last_click_time : Ref[Double],
  last_click_element : Ref[String],
  double_click_threshold : Double,
  active_pointers : Ref[Map[Int, @model.Point]],
) -> (@js.Any) -> Unit {
  fn(e) {
    // ポインターを追跡（ピンチズーム用）
    let pointer_id = get_pointer_id(e)
    let (screen_x, screen_y) = get_screen_coords(e)
    active_pointers.val[pointer_id] = { x: screen_x, y: screen_y, }

    // 2本指でピンチズーム開始
    if active_pointers.val.length() == 2 {
      let pointers : Array[(Int, @model.Point)] = active_pointers.val
        .iter()
        .collect()
      let (id1, pos1) = pointers[0]
      let (id2, pos2) = pointers[1]
      state.start_pinch(id1, id2, pos1, pos2)
      return
    }

    // コンテキストメニューが開いている場合は閉じるだけで他のアクションを実行しない
    if state.context_menu.get() is Some(_) {
      state.hide_context_menu()
      return
    }

    // 配置モード中はクリックで確定
    if state.is_placing() {
      state.end_placement()
      return
    }

    // マウスボタンをチェック
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let button = mouse_event.button

    // 中クリック（button === 1）または Space キーでパン開始（埋め込みモードでは無効）
    if state.mode is @core.Full && (button == 1 || space_pressed.val) {
      state.start_pan(screen_x, screen_y)
      return
    }
    let target = e._get("target")
    let dataset = target._get("dataset")

    // アンカーポイントのクリックをチェック（ライン生成）- フリードローモードより優先
    if handle_anchor_click(state, history, new_id, get_scene_coords, e, dataset) {
      return
    }

    // フリードローモードの場合（アンカーポイント以外の場所をクリック）
    if state.tool_mode.get() == @core.FreeDraw {
      let (scene_x, scene_y) = get_scene_coords(e)
      @lib.start_free_draw(state, scene_x, scene_y)
      return
    }

    // リサイズハンドルのクリックをチェック
    if handle_resize_click(state, get_scene_coords, e, dataset) {
      return
    }

    // data-id を直接取得、なければ親要素から取得（tspan 対応）
    let data_id_raw = dataset._get("id")
    let data_id : String? = if @js.is_nullish(data_id_raw) {
      let closest_id = get_closest_data_id_ffi(target)
      if @js.is_nullish(closest_id) {
        None
      } else {
        Some(closest_id.cast())
      }
    } else {
      Some(data_id_raw.cast())
    }
    let (scene_x, scene_y) = get_scene_coords(e)
    let shift_key : Bool = e._get("shiftKey").cast()
    if data_id is Some(id) {
      handle_element_click(
        state, id, scene_x, scene_y, last_click_time, last_click_element, double_click_threshold,
        shift_key,
      )
    } else {
      // 空白をクリック - 矩形選択を開始
      state.select(None)
      state.start_box_select(scene_x, scene_y)
      last_click_time.val = 0.0
      last_click_element.val = ""
    }
  }
}

///|
/// アンカーポイントクリックを処理
fn handle_anchor_click(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  get_scene_coords : (@js.Any) -> (Double, Double),
  e : @js.Any,
  dataset : @js.Any,
) -> Bool {
  let data_anchor_raw = dataset._get("anchor")
  if @js.is_nullish(data_anchor_raw) {
    return false
  }
  let anchor_str : String = data_anchor_raw.cast()
  // data-anchor-element は dataset.anchorElement としてアクセス
  let element_id_raw = dataset._get("anchorElement")
  if @js.is_nullish(element_id_raw) {
    return false
  }
  let source_id : String = element_id_raw.cast()
  guard @model.parse_anchor(anchor_str) is Some(anchor) else { return false }
  guard state.find_element(source_id) is Some(source_el) else { return false }
  let anchor_point = source_el.get_anchor_point(anchor)
  let (scene_x, scene_y) = get_scene_coords(e)
  let line_id = new_id()
  // Arrow として作成（矢印付き）
  // 終点を1pxオフセット（ゼロ長Lineはis_validでスキップされるため）
  let new_line = @model.Element::new(
    line_id,
    anchor_point.x,
    anchor_point.y,
    @model.Line(anchor_point.x + 1.0, anchor_point.y),
  ).with_style(state.get_arrow_style())
  let line_with_conn = {
    ..new_line,
    connections: Some({
      start: Some({ element_id: source_id, anchor, }),
      end: None,
    }),
  }
  @core.execute_command(history, state, @model.AddElement(line_with_conn))
  // リサイズ開始
  state.start_resize(line_id, @model.LineEnd, scene_x, scene_y)
  true
}

///|
/// リサイズハンドルクリックを処理
fn handle_resize_click(
  state : @core.EditorState,
  get_scene_coords : (@js.Any) -> (Double, Double),
  e : @js.Any,
  dataset : @js.Any,
) -> Bool {
  let data_handle_raw = dataset._get("handle")
  if @js.is_nullish(data_handle_raw) {
    return false
  }
  let handle_str : String = data_handle_raw.cast()
  let element_id_raw = dataset._get("elementId")
  if @js.is_nullish(element_id_raw) {
    return false
  }
  let element_id : String = element_id_raw.cast()
  // Path 要素はリサイズ不可
  match state.find_element(element_id) {
    Some(el) => if el.shape is @model.Path(_, _, _, _, _) { return false }
    None => ()
  }
  let (scene_x, scene_y) = get_scene_coords(e)
  let handle = @model.parse_handle_position(handle_str)
  state.start_resize(element_id, handle, scene_x, scene_y)
  true
}

///|
/// 要素クリックを処理
fn handle_element_click(
  state : @core.EditorState,
  id : String,
  scene_x : Double,
  scene_y : Double,
  last_click_time : Ref[Double],
  last_click_element : Ref[String],
  double_click_threshold : Double,
  shift_key : Bool,
) -> Unit {
  // 子要素の場合は親を取得
  let target_id = match state.get_parent_id(id) {
    Some(parent_id) => parent_id
    None => id
  }
  let now = get_current_time()
  let is_child = state.is_child_element(id)
  let is_text_child = if is_child {
    match state.find_element(id) {
      Some(el) => el.shape is @model.Text(_, _)
      None => false
    }
  } else {
    false
  }
  let dblclick_target = if is_text_child { id } else { target_id }
  if last_click_element.val == dblclick_target &&
    now - last_click_time.val < double_click_threshold {
    // ダブルクリック検出
    last_click_time.val = 0.0
    last_click_element.val = ""
    state.end_drag()
    if is_text_child {
      handle_text_edit(state, id)
    } else {
      handle_double_click(state, target_id)
    }
    return
  }
  last_click_time.val = now
  last_click_element.val = dblclick_target
  let already_selected = state.is_selected(target_id)
  let selected_count = state.selected_ids.get().length()

  // Shift+クリック: 複数選択のトグル
  if shift_key {
    if already_selected {
      state.remove_from_selection(target_id)
    } else {
      state.add_to_selection(target_id)
    }
    // 複数選択中はドラッグを開始
    if state.selected_ids.get().length() > 1 {
      state.start_multi_drag(scene_x, scene_y)
    } else if state.selected_ids.get().length() == 1 {
      // 1つだけ選択中の場合は通常ドラッグ
      let selected_id = state.selected_ids.get()[0]
      state.start_drag(selected_id, scene_x, scene_y)
    }
    return
  }

  // 通常クリック
  if already_selected && selected_count > 1 {
    state.start_multi_drag(scene_x, scene_y)
  } else {
    state.select(Some(target_id))
    state.start_drag(target_id, scene_x, scene_y)
  }
}

///|
/// ダブルクリック時のテキスト編集開始
fn handle_double_click(state : @core.EditorState, element_id : String) -> Unit {
  guard state.find_element(element_id) is Some(el) else { return }
  // Path 要素はテキスト編集不可（位置計算が困難なため）
  if el.shape is @model.Path(_, _, _, _, _) {
    return
  }
  // テキスト要素の場合は直接編集
  if el.shape is @model.Text(content, font_size) {
    // parent_id がない場合は自分自身を親として扱う
    let parent_id = el.parent_id.unwrap_or(element_id)
    state.start_text_edit_existing(
      element_id,
      parent_id,
      el.x,
      el.y,
      content,
      font_size,
    )
    return
  }
  // 親要素の場合：既存のテキスト子要素があるかチェック
  let children = state.get_children(element_id)
  for child in children {
    if child.shape is @model.Text(content, font_size) {
      // 既存テキストを編集
      // 子テキストの座標は親からの相対座標の場合があるため、親要素の中心座標を使用する
      let bbox = el.bounding_box()
      let center_x = bbox.x + bbox.width / 2.0
      let center_y = bbox.y + bbox.height / 2.0
      state.start_text_edit_existing(
        child.id,
        element_id,
        center_x,
        center_y,
        content,
        font_size,
      )
      return
    }
  }
  // テキスト子要素がない場合は新規作成
  let bbox = el.bounding_box()
  let center_x = bbox.x + bbox.width / 2.0
  let center_y = bbox.y + bbox.height / 2.0
  state.start_text_edit(element_id, center_x, center_y)
}

///|
/// テキスト要素の編集開始
fn handle_text_edit(state : @core.EditorState, text_id : String) -> Unit {
  guard state.find_element(text_id) is Some(el) else { return }
  guard el.shape is @model.Text(content, font_size) else { return }
  // parent_id がない場合は自分自身を親として扱う
  let parent_id = el.parent_id.unwrap_or(text_id)
  // テキストの表示位置を計算
  // 親要素がある場合は親の中心座標、ない場合はテキスト自体の座標を使用
  let (text_x, text_y) = match el.parent_id {
    Some(pid) =>
      match state.find_element(pid) {
        Some(parent) => {
          let bbox = parent.bounding_box()
          (bbox.x + bbox.width / 2.0, bbox.y + bbox.height / 2.0)
        }
        None => (el.x, el.y)
      }
    None => (el.x, el.y)
  }
  state.start_text_edit_existing(
    text_id, parent_id, text_x, text_y, content, font_size,
  )
}

///|
/// テキスト入力を確定
fn commit_text_edit(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  text_content : String,
) -> Unit {
  guard state.text_edit.get() is Some(edit_state) else { return }
  match edit_state.editing_id {
    Some(text_id) =>
      if text_content == "" {
        if state.find_element(text_id) is Some(el) {
          @core.execute_command(history, state, state.removal_of(el))
        }
      } else if text_content != edit_state.initial_text {
        // UpdateText コマンドを使ってUndoスタックに記録
        @core.execute_command(
          history,
          state,
          @model.UpdateText(text_id, edit_state.initial_text, text_content),
        )
      }
    None =>
      if text_content != "" {
        // 親要素がある場合、親のstrokeカラーを継承
        let text_style = if edit_state.parent_id != "" {
          match state.find_element(edit_state.parent_id) {
            Some(parent_el) =>
              match parent_el.style.stroke {
                Some(color) => { ..state.get_text_style(), fill: Some(color), }
                None => state.get_text_style()
              }
            None => state.get_text_style()
          }
        } else {
          state.get_text_style()
        }
        let text_el = @model.Element::new(
            new_id(),
            edit_state.x,
            edit_state.y,
            @model.Text(text_content, Some(16.0)),
          )
          .with_style(text_style)
          .with_parent(edit_state.parent_id)
        @core.execute_command(history, state, @model.AddElement(text_el))
      }
  }
  state.end_text_edit()
}

///|
/// pointermove ハンドラを作成
fn create_pointermove_handler(
  state : @core.EditorState,
  history : @model.History,
  get_screen_coords : (@js.Any) -> (Double, Double),
  get_scene_coords : (@js.Any) -> (Double, Double),
  active_pointers : Ref[Map[Int, @model.Point]],
) -> (@js.Any) -> Unit {
  fn(e) {
    // ボタンが離されているのにドラッグ中の場合は終了（領域外でリリースされた場合）
    let buttons : Int = e._get("buttons").cast()
    if buttons == 0 {
      if state.drag_state.get() is Some(_) {
        state.end_drag()
      }
      if state.resize_state.get() is Some(_) {
        state.end_resize()
      }
      if state.multi_drag_state.get() is Some(_) {
        state.end_multi_drag()
      }
      // 領域外で離された操作も、pointerup と同じく一段の履歴にする
      state.commit_gesture(history)
    }

    // ポインター位置を更新
    let pointer_id = get_pointer_id(e)
    let (screen_x, screen_y) = get_screen_coords(e)
    active_pointers.val[pointer_id] = { x: screen_x, y: screen_y, }

    // ピンチズーム中の場合
    if state.is_pinching() {
      state.update_pinch(pointer_id, { x: screen_x, y: screen_y, })
      return
    }

    // コンテキストメニューが開いている場合は移動操作を無効化
    if state.context_menu.get() is Some(_) {
      return
    }

    // マウス位置を更新（キーバインドでの挿入用）
    let (scene_x, scene_y) = get_scene_coords(e)
    state.mouse_scene_pos.set({ x: scene_x, y: scene_y, })
    state.mouse_in_canvas.set(true)

    // フリードロー中の場合
    if @lib.is_drawing(state) {
      @lib.continue_free_draw(state, scene_x, scene_y)
      // プレビュー描画
      let svg = state.svg_el.get()
      if !@js.is_nullish(svg) {
        let points = @lib.get_preview_points(state)
        @lib.draw_free_draw_preview(svg, points)
      }
      return
    }
    if state.is_panning.get() {
      let (screen_x, screen_y) = get_screen_coords(e)
      state.pan_move(screen_x, screen_y)
      return
    }
    if state.is_placing() {
      // 配置モード中は要素をマウス位置に追従
      state.update_placement({ x: scene_x, y: scene_y, })
    } else if state.is_resizing() {
      state.resize_move(scene_x, scene_y)
    } else if state.is_multi_dragging() {
      state.multi_drag_move(scene_x, scene_y)
    } else if state.is_dragging() {
      state.drag_move(scene_x, scene_y)
    } else if state.is_box_selecting() {
      state.update_box_select(scene_x, scene_y)
    }
  }
}

///|
/// pointerup ハンドラを作成
fn create_pointerup_handler(
  state : @core.EditorState,
  history : @model.History,
  get_screen_coords : (@js.Any) -> (Double, Double),
  active_pointers : Ref[Map[Int, @model.Point]],
  new_id? : () -> String = fn() { "" },
) -> (@js.Any) -> Unit {
  let _ = get_screen_coords // unused but kept for consistency
  fn(e) {
    // ポインターを削除
    let pointer_id = get_pointer_id(e)
    active_pointers.val.remove(pointer_id)

    // ピンチズーム終了
    state.end_pinch(pointer_id)
    // フリードロー中の場合
    if @lib.is_drawing(state) {
      // プレビューを削除
      let svg = state.svg_el.get()
      if !@js.is_nullish(svg) {
        @lib.remove_free_draw_preview(svg)
      }
      // Path 要素を作成
      @lib.finish_free_draw(state, new_id, history~)
      return
    }
    if state.is_panning.get() {
      state.end_pan()
      return
    }
    if state.is_box_selecting() {
      state.end_box_select()
      return
    }
    finish_pointer_gesture(state, history)
  }
}

///|
/// ポインタ操作（リサイズ・複数ドラッグ・ドラッグ）を確定し、一段の履歴にする。
/// 確定（丸め・接続の張り替え・潰れた線の破棄）が済んでから、開始時点との
/// 差分を積む。
fn finish_pointer_gesture(
  state : @core.EditorState,
  history : @model.History,
) -> Unit {
  if state.resize_state.get() is Some(_) {
    state.end_resize()
  } else if state.multi_drag_state.get() is Some(_) {
    state.end_multi_drag()
  } else {
    state.end_drag()
  }
  state.commit_gesture(history)
}

///|
/// pointerleave ハンドラを作成（ポインターが画面外に出た時に状態をリセット）
/// 注意: ドラッグ/リサイズ中の状態はリセットしない（pointerup で処理）
fn create_pointerleave_handler(state : @core.EditorState) -> (@js.Any) -> Unit {
  fn(_e) {
    // マウスがキャンバス外に出たことを記録
    state.mouse_in_canvas.set(false)
    // フリードロー中の場合はキャンセル
    if @lib.is_drawing(state) {
      let svg = state.svg_el.get()
      if !@js.is_nullish(svg) {
        @lib.remove_free_draw_preview(svg)
      }
      state.free_draw_state.set(None)
    }
    // パンと矩形選択のみリセット（ドラッグ/リサイズは継続可能に）
    if state.is_panning.get() {
      state.end_pan()
    }
    if state.is_box_selecting() {
      state.end_box_select()
    }
    // 配置モードはキャンセル
    if state.placement_state.get() is Some(_) {
      state.end_placement()
    }
    // ドラッグ/リサイズ/マルチドラッグは pointerup で終了するので
    // ここではリセットしない（領域外でもドラッグ継続可能に）
  }
}

///|
/// wheel ハンドラを作成（マウス位置を基準にズーム）
fn create_wheel_handler(
  state : @core.EditorState,
  get_screen_coords : (@js.Any) -> (Double, Double),
) -> (@js.Any) -> Unit {
  fn(e) {
    let _ = e._call("preventDefault", [])
    let delta_y : Double = e._get("deltaY").cast()
    let (screen_x, screen_y) = get_screen_coords(e)
    let zoom_in = delta_y < 0.0
    state.zoom_at(screen_x, screen_y, zoom_in)
  }
}

///|
/// contextmenu ハンドラを作成
fn create_contextmenu_handler(
  state : @core.EditorState,
  get_scene_coords : (@js.Any) -> (Double, Double),
) -> (@js.Any) -> Unit {
  fn(e) {
    let _ = e._call("preventDefault", [])
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let (scene_x, scene_y) = get_scene_coords(e)
    let target = e._get("target")
    // data-id を直接取得、なければ親要素から取得（tspan 対応）
    let data_id_raw = target._get("dataset")._get("id")
    let target_id : String? = if @js.is_nullish(data_id_raw) {
      let closest_id = get_closest_data_id_ffi(target)
      if @js.is_nullish(closest_id) {
        None
      } else {
        Some(closest_id.cast())
      }
    } else {
      Some(data_id_raw.cast())
    }
    if target_id is Some(id) {
      state.select(Some(id))
    }
    state.show_context_menu(
      mouse_event.clientX,
      mouse_event.clientY,
      scene_x,
      scene_y,
      target_id,
    )
  }
}

///|
/// キーボードショートカットを設定
fn setup_keyboard_shortcuts(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  let handler : (@js.Any) -> Unit = fn(e) {
    // テキスト編集中または入力要素にフォーカスがある場合は無視
    if state.text_edit.get() is Some(_) {
      return
    }
    if is_input_focused_ffi() {
      return
    }
    let key : String = e._get("key").cast()
    let ctrl_key : Bool = e._get("ctrlKey").cast()
    let meta_key : Bool = e._get("metaKey").cast()
    let shift_key : Bool = e._get("shiftKey").cast()
    let is_cmd = ctrl_key || meta_key

    // マウス位置を取得
    let pos = state.mouse_scene_pos.get()
    match key {
      // 消す範囲の判定も履歴の積み方も埋め込み側と同じものを使う。
      // ここに同じ計算のコピーがあると、片方だけ直したときに挙動がずれる。
      "Delete" | "Backspace" => @lib.delete_selection(state, history)
      "Escape" =>
        if state.tool_mode.get() == @core.FreeDraw {
          state.tool_mode.set(@core.Select)
        } else {
          state.select(None)
        }
      // 1: Rectangle をマウス位置に挿入（固定サイズ）
      "1" => {
        let el_id = new_id()
        let width = 80.0
        let height = 60.0
        let new_rect = @model.Element::new(
          el_id,
          pos.x - width / 2.0,
          pos.y - height / 2.0,
          @model.Rect(width, height, None, None),
        ).with_style(state.get_default_style())
        @core.execute_command(history, state, @model.AddElement(new_rect))
        state.select(Some(el_id))
      }
      // 2: Circle をマウス位置に挿入（固定サイズ）
      "2" => {
        let el_id = new_id()
        let new_circle = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Circle(40.0),
        ).with_style(state.get_default_style())
        @core.execute_command(history, state, @model.AddElement(new_circle))
        state.select(Some(el_id))
      }
      // 3: Ellipse をマウス位置に挿入（固定サイズ）
      "3" => {
        let el_id = new_id()
        let new_ellipse = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Ellipse(60.0, 35.0),
        ).with_style(state.get_default_style())
        @core.execute_command(history, state, @model.AddElement(new_ellipse))
        state.select(Some(el_id))
      }
      // 4: Line をマウス位置に挿入（固定サイズ）
      "4" => {
        let el_id = new_id()
        let dx = 100.0
        let dy = 50.0
        let new_line = @model.Element::new(
          el_id,
          pos.x - dx / 2.0,
          pos.y - dy / 2.0,
          @model.Line(pos.x + dx / 2.0, pos.y + dy / 2.0),
        ).with_style(state.get_line_style())
        @core.execute_command(history, state, @model.AddElement(new_line))
        state.select(Some(el_id))
      }
      // 5: Arrow をマウス位置に挿入（固定サイズ）
      "5" => {
        let el_id = new_id()
        let dx = 100.0
        let dy = 50.0
        let new_arrow = @model.Element::new(
          el_id,
          pos.x - dx / 2.0,
          pos.y - dy / 2.0,
          @model.Line(pos.x + dx / 2.0, pos.y + dy / 2.0),
        ).with_style(state.get_arrow_style())
        @core.execute_command(history, state, @model.AddElement(new_arrow))
        state.select(Some(el_id))
      }
      // 6: Text をマウス位置に挿入（固定サイズ）
      "6" => {
        let el_id = new_id()
        let new_text = @model.Element::new(
          el_id,
          pos.x,
          pos.y,
          @model.Text("Text", Some(16.0)),
        ).with_style(state.get_text_style())
        @core.execute_command(history, state, @model.AddElement(new_text))
        state.select(Some(el_id))
      }
      "a" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          state.select_all()
        }
      "c" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          @lib.copy_selection(state)
        }
      "v" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          @lib.paste_clipboard(state, history, new_id)
        } else {
          // v: 選択モードに切り替え
          @lib.set_select_mode(state)
        }
      "d" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          @lib.duplicate_selection(state, history, new_id)
        }
      // Cmd/Ctrl+Shift+Z は Redo。shift 付きの z は "Z" で来ることも "z" の
      // まま来ることもあるので、両方を同じ入口で見る。
      "z" | "Z" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          if shift_key {
            let _ = @core.redo_command(history, state)
          } else {
            let _ = @core.undo_command(history, state)
          }
        }
      "y" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          let _ = @core.redo_command(history, state)
        }
      "s" =>
        if is_cmd {
          let _ = e._call("preventDefault", [])
          // Ctrl+S: SVGファイルをダウンロード
          let svg_str = elements_to_moonlight_svg(
            state.elements.get(),
            state.doc_width.get().to_int(),
            state.doc_height.get().to_int(),
            state.get_theme().background,
          )
          download_file(svg_str, "moonlight.svg", "image/svg+xml")
        }
      "C" =>
        // Ctrl+Shift+C: SVGテキストをクリップボードにコピー
        if is_cmd && shift_key {
          let _ = e._call("preventDefault", [])
          let svg_str = elements_to_moonlight_svg(
            state.elements.get(),
            state.doc_width.get().to_int(),
            state.doc_height.get().to_int(),
            state.get_theme().background,
          )
          copy_text_to_clipboard(svg_str, fn() { () }, fn() { () })
        }
      "V" =>
        // Ctrl+Shift+V: クリップボードからSVGをインポート
        if is_cmd && shift_key {
          let _ = e._call("preventDefault", [])
          read_clipboard_text(
            fn(text) {
              let result = import_svg_validated(text, new_id)
              for el in result.elements {
                @core.execute_command(history, state, @model.AddElement(el))
              }
              if result.elements.length() > 0 {
                // プレーンSVG要素を登録（既存に追加）
                if result.plain_svg_ids.length() > 0 {
                  state.register_plain_svg_ids(result.plain_svg_ids)
                }
                // バリデーション実行
                state.revalidate()
                let ids = result.elements
                  .filter(fn(el) { el.parent_id is None })
                  .map(fn(el) { el.id })
                state.select_multiple(ids)
              }
            },
            fn() { () },
          )
        } else if !is_cmd {
          // V: 選択モードに切り替え
          @lib.set_select_mode(state)
        }
      // P: フリードローモード切替
      "p" | "P" => @lib.toggle_tool_mode(state)
      // ?: ヘルプ（埋め込み側では前から効いていた）
      "?" => @lib.open_help_page()
      _ => ()
    }
  }
  add_keyboard_listener(handler)
}

// ============================================================
// UI レンダリング
// ============================================================

///|
/// エディタ UI をレンダリング（Luna VNode ベース）
fn render_editor_ui_vnode(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  svg_canvas : @element.DomNode,
  commit_text_input : (String) -> Unit,
) -> @element.DomNode {
  // メインレイアウト（全画面キャンバス + フローティングUI）
  div(
    style="position: relative; width: 100%; height: 100%; overflow: hidden;",
    [
      // キャンバス（画面全体）
      div(style="position: absolute; inset: 0;", [
        svg_canvas,
        // テキスト入力
        render_text_input_container(state, commit_text_input),
      ]),
      // フローティングツールバー（上部中央）
      div(
        dyn_style=fn() {
          let is_mobile = state.is_mobile.get()
          if is_mobile {
            // モバイルでは下端をパネル（ボトムシート）が占めるので、ツールバーは上に置く。
            // 横一列では 375px に収まらないため折り返す。
            "position: fixed; top: 8px; left: 8px; right: 8px; display: flex; flex-wrap: wrap; justify-content: center; gap: 4px; align-items: center; background: rgba(255,255,255,0.95); padding: 6px 8px; border: 1px solid #ddd; border-radius: 8px; font-size: 11px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 110; box-sizing: border-box;"
          } else {
            // 右上のパネル開閉ボタン（32px + 余白）を避けて収まるように上限を置く
            "position: fixed; top: 12px; left: 50%; transform: translateX(-50%); max-width: calc(100vw - 88px); box-sizing: border-box; display: flex; gap: 4px; align-items: center; background: rgba(255,255,255,0.95); padding: 6px 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 11px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 110;"
          }
        },
        [render_embedded_toolbar(state, history, new_id)],
      ),
      // フローティングパネル（デスクトップ: 右端、モバイル: 下部）
      show(fn() { state.panel_visible.get() }, fn() {
        render_floating_panel(state, history)
      }),
      // パネル表示/非表示トグル
      render_panel_toggle(state),
      // コンテキストメニュー
      show(fn() { state.context_menu.get() is Some(_) }, fn() {
        render_context_menu(state, history, new_id)
      }),
    ],
  )
}

///|
/// パネル表示/非表示トグルボタン
fn render_panel_toggle(state : @core.EditorState) -> @element.DomNode {
  button(
    dyn_style=fn() {
      let is_mobile = state.is_mobile.get()
      let visible = state.panel_visible.get()
      let icon_transform = if visible {
        ""
      } else {
        "transform: rotate(180deg);"
      }
      if is_mobile {
        "position: fixed; bottom: 12px; right: 12px; width: 36px; height: 36px; border-radius: 50%; background: rgba(255,255,255,0.95); border: 1px solid #ddd; cursor: pointer; font-size: 14px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 101; " +
        icon_transform
      } else {
        "position: fixed; top: 12px; right: 12px; width: 32px; height: 32px; border-radius: 50%; background: rgba(255,255,255,0.95); border: 1px solid #ddd; cursor: pointer; font-size: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 101; " +
        icon_transform
      }
    },
    on=events().click(fn(_) { state.panel_visible.update(fn(v) { !v }) }),
    [text_dyn(fn() { if state.panel_visible.get() { "×" } else { "☰" } })],
  )
}

// ============================================================
// 埋め込みモード
// ============================================================

///|
/// 埋め込みビューをレンダリング（簡易モード）
/// 親要素のサイズにフィットし、aspect-ratio でアスペクト比を維持
fn render_embedded_view(
  state : @core.EditorState,
  svg_canvas : @element.DomNode,
  commit_text_input : (String) -> Unit,
) -> @element.DomNode {
  // コンテナ：aspect-ratio で比率を維持（フラットな構造）
  div(
    dyn_style=fn() {
      let doc_w = state.doc_width.get()
      let doc_h = state.doc_height.get()
      "position: relative; width: 100%; aspect-ratio: \{doc_w} / \{doc_h};"
    },
    [
      // SVG キャンバス
      svg_canvas,
      // テキスト入力（absolute positioned）
      render_text_input_container(state, commit_text_input),
      // 編集ボタン（右上固定）- アイコンのみ、aria-label付き
      @element.create_element(
        "button",
        [
          (
            "style",
            @element.Static(
              "position: absolute; top: 8px; right: 8px; padding: 10px; background: rgba(59, 130, 246, 0.95); border: none; border-radius: 8px; cursor: pointer; color: white; box-shadow: 0 2px 8px rgba(59, 130, 246, 0.4); z-index: 10; display: flex; align-items: center; justify-content: center;",
            ),
          ),
          ("aria-label", @element.Static("Edit in fullscreen")),
          ("title", @element.Static("Edit in fullscreen")),
          ("click", @element.Handler(fn(_) { state.modal_open.set(true) })),
        ],
        [@components.svg_icon(@components.icon_edit_expand, 20)],
      ),
    ],
  )
}

///|
/// エディタモーダルをレンダリング（フルエディタを別ウィンドウ風に表示）
pub fn render_editor_modal(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  // フルエディタ用の SVG を作成
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }
  let space_pressed : Ref[Bool] = { val: false, }
  let last_click_time : Ref[Double] = { val: 0.0, }
  let last_click_element : Ref[String] = { val: "", }
  let double_click_threshold : Double = 300.0
  let active_pointers : Ref[Map[Int, @model.Point]] = { val: {}, }
  let commit_text_input = fn(text_content : String) {
    commit_text_edit(state, history, new_id, text_content)
  }
  let on_pointerdown = create_pointerdown_handler(
    state, history, new_id, get_screen_coords, get_scene_coords, space_pressed, last_click_time,
    last_click_element, double_click_threshold, active_pointers,
  )
  let on_pointermove = create_pointermove_handler(
    state, history, get_screen_coords, get_scene_coords, active_pointers,
  )
  let on_pointerup = create_pointerup_handler(
    state,
    history,
    get_screen_coords,
    active_pointers,
    new_id~,
  )
  let on_pointerleave = create_pointerleave_handler(state)
  let on_wheel = create_wheel_handler(state, get_screen_coords)
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)
  let modal_svg = render_svg_canvas_node(
    state, on_pointerdown, on_pointermove, on_pointerup, on_pointerleave, on_contextmenu,
    on_wheel,
  )

  // キーボードはコンテナ側の @lib.setup_keyboard_handler が受ける。
  // ここで window に足すと、モーダルを開くたびにリスナーが積み上がり（外す口が
  // 無い）、矢印キーの移動量が開いた回数だけ倍になっていた。閉じたあとも残る。

  // モーダルオーバーレイ（クリックで閉じる）
  div(
    style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000; display: flex; align-items: center; justify-content: center;",
    on=events().click(fn(_) { state.modal_open.set(false) }),
    [
      // モーダルウィンドウ（クリックイベントの伝播を止める）
      div(
        style="width: 90vw; max-width: 1200px; height: 85vh; background: white; border-radius: 8px; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 4px 24px rgba(0,0,0,0.3);",
        on=events().click(fn(e) {
          let _ = e.as_any()._call("stopPropagation", [])
        }),
        [
          // ヘッダー
          div(
            style="display: flex; justify-content: space-between; align-items: center; padding: 8px 16px; border-bottom: 1px solid #ddd; background: #f8f8f8; flex-shrink: 0;",
            [
              div(style="font-weight: 500; font-size: 14px;", [
                text("Moonlight Editor"),
              ]),
              // 閉じるボタン - アイコンのみ、aria-label付き
              @element.create_element(
                "button",
                [
                  (
                    "style",
                    @element.Static(
                      "padding: 8px; background: #f5f5f5; border: 1px solid #d0d0d0; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #555;",
                    ),
                  ),
                  ("aria-label", @element.Static("Close")),
                  ("title", @element.Static("Close")),
                  (
                    "click",
                    @element.Handler(fn(_) { state.modal_open.set(false) }),
                  ),
                ],
                [@components.svg_icon(@components.icon_close, 18)],
              ),
            ],
          ),
          // エディタ本体
          div(
            style="flex: 1; display: flex; overflow: hidden; min-height: 0;",
            [
              // キャンバス領域
              div(style="flex: 1; position: relative; min-width: 0;", [
                modal_svg,
                render_text_input_container(state, commit_text_input),
              ]),
              // サイドパネル（インライン版 - position: fixed なし）
              div(
                style="width: 240px; border-left: 1px solid #ddd; overflow-y: auto; background: #fafafa;",
                [render_inline_panel(state, history)],
              ),
            ],
          ),
          // ツールバー（下部）
          div(
            style="display: flex; gap: 4px; align-items: center; padding: 8px 12px; border-top: 1px solid #ddd; background: #f8f8f8; flex-shrink: 0;",
            [render_embedded_toolbar(state, history, new_id)],
          ),
          // コンテキストメニュー（表示時のみ）
          show(fn() { state.context_menu.get() is Some(_) }, fn() {
            render_context_menu(state, history, new_id)
          }),
        ],
      ),
    ],
  )
}

///|
/// 埋め込みエディタアプリをレンダリング
fn embedded_editor_app(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  // 埋め込み用の簡易イベントハンドラ（選択・ドラッグ・テキスト編集のみ）
  let get_screen_coords = fn(e : @js.Any) -> (Double, Double) {
    let mouse_event : @js_dom.MouseEvent = e.cast()
    let svg = e._get("currentTarget")
    let rect = svg._call("getBoundingClientRect", [])
    let screen_x = mouse_event.clientX - (rect._get("left").cast() : Double)
    let screen_y = mouse_event.clientY - (rect._get("top").cast() : Double)
    (screen_x, screen_y)
  }
  let get_scene_coords = fn(e : @js.Any) -> (Double, Double) {
    let (screen_x, screen_y) = get_screen_coords(e)
    let vp = state.viewport.get()
    let scene = vp.screen_to_scene(screen_x, screen_y)
    (scene.x, scene.y)
  }
  let space_pressed : Ref[Bool] = { val: false, }
  let last_click_time : Ref[Double] = { val: 0.0, }
  let last_click_element : Ref[String] = { val: "", }
  let double_click_threshold : Double = 300.0
  let active_pointers : Ref[Map[Int, @model.Point]] = { val: {}, }
  let commit_text_input = fn(text_content : String) {
    commit_text_edit(state, history, new_id, text_content)
  }

  // 簡易ハンドラ（選択・移動・テキスト編集のみ）
  let on_pointerdown = create_pointerdown_handler(
    state, history, new_id, get_screen_coords, get_scene_coords, space_pressed, last_click_time,
    last_click_element, double_click_threshold, active_pointers,
  )
  let on_pointermove = create_pointermove_handler(
    state, history, get_screen_coords, get_scene_coords, active_pointers,
  )
  let on_pointerup = create_pointerup_handler(
    state,
    history,
    get_screen_coords,
    active_pointers,
    new_id~,
  )
  let on_pointerleave = create_pointerleave_handler(state)
  // 埋め込みモードではズームを無効化
  let on_wheel = fn(_e : @js.Any) { () }
  // コンテキストメニューは有効化（要素の詳細表示・挿入機能）
  let on_contextmenu = create_contextmenu_handler(state, get_scene_coords)
  let svg_canvas = render_svg_canvas_node(
    state, on_pointerdown, on_pointermove, on_pointerup, on_pointerleave, on_contextmenu,
    on_wheel,
  )
  // 埋め込みビュー（フラットな構造）
  @element.fragment([
    render_embedded_view(state, svg_canvas, commit_text_input),
    // コンテキストメニュー（表示時のみ）
    show(fn() { state.context_menu.get() is Some(_) }, fn() {
      render_context_menu(state, history, new_id)
    }),
    // モーダル（表示時のみ）
    show(fn() { state.modal_open.get() }, fn() {
      render_editor_modal(state, history, new_id)
    }),
  ])
}

///|
/// 16進数カラーコードから明度を計算（0.0〜1.0）
fn get_color_luminance(hex : String) -> Double {
  // #RRGGBB 形式を想定、文字配列に変換
  let chars : Array[Char] = hex.to_upper().iter().collect()
  let start = if chars.length() > 0 && chars[0] == '#' { 1 } else { 0 }
  guard chars.length() >= start + 6 else { return 0.5 }
  // 各チャンネルを抽出
  let r = (hex_char_to_int(chars[start]) * 16 +
  hex_char_to_int(chars[start + 1])).to_double()
  let g = (hex_char_to_int(chars[start + 2]) * 16 +
  hex_char_to_int(chars[start + 3])).to_double()
  let b = (hex_char_to_int(chars[start + 4]) * 16 +
  hex_char_to_int(chars[start + 5])).to_double()
  // 相対輝度の計算（sRGB）
  (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
}

///|
/// 16進数文字を数値に変換
fn hex_char_to_int(c : Char) -> Int {
  match c {
    '0' => 0
    '1' => 1
    '2' => 2
    '3' => 3
    '4' => 4
    '5' => 5
    '6' => 6
    '7' => 7
    '8' => 8
    '9' => 9
    'A' => 10
    'B' => 11
    'C' => 12
    'D' => 13
    'E' => 14
    'F' => 15
    _ => 0
  }
}

///|
/// テキスト色に対してコントラストのある背景色を返す
fn get_contrasting_bg(text_color : String, theme : @model.ThemeMode) -> String {
  let luminance = get_color_luminance(text_color)
  // テキストが暗い（明度 < 0.5）なら明るい背景、逆なら暗い背景
  if luminance < 0.5 {
    // 暗いテキスト → 明るい背景
    match theme {
      @model.Light => "#ffffff"
      @model.Dark => "#e0e0e0"
    }
  } else {
    // 明るいテキスト → 暗い背景
    match theme {
      @model.Light => "#2a2a2a"
      @model.Dark => "#1a1a2e"
    }
  }
}

///|
/// テキスト入力コンテナ（FFI 要素を Effect で手動管理）
fn render_text_input_container(
  state : @core.EditorState,
  commit : (String) -> Unit,
) -> @element.DomNode {
  let container_ref : Ref[@js.Any?] = { val: None, }
  let current_textarea : Ref[@js.Any?] = { val: None, }

  // Effect で text_edit の変更を監視
  let _ = @luna.effect(fn() {
    let text_edit = state.text_edit.get()

    // コンテナがまだレンダリングされていない場合は何もしない
    let container = match container_ref.val {
      Some(c) => c
      None => return
    }

    // 既存の textarea を削除
    if current_textarea.val is Some(textarea) {
      remove_child_safe_ffi(container, textarea)
      current_textarea.val = None
    }

    // 新しい textarea を作成
    if text_edit is Some(edit_state) {
      let vp = state.viewport.get()
      let theme = state.theme_mode.get()
      let elements = state.elements.get()
      let theme_colors = state.get_theme()
      // テキスト色を取得（既存テキストの色または親要素のstroke）
      let default_text_color = theme_colors.stroke
      // CSS変数を実際の色に変換
      let resolve_color = fn(color : String) -> String {
        if color.has_prefix("var(") {
          theme_colors.stroke
        } else {
          color
        }
      }
      let text_color = match edit_state.editing_id {
        Some(id) =>
          // 既存テキストの編集
          match state.find_element(id) {
            Some(el) => {
              let parent_stroke = @model.get_parent_stroke(
                elements,
                el.parent_id,
              )
              resolve_color(@model.get_text_fill_color(el.style, parent_stroke))
            }
            None => default_text_color
          }
        None =>
          // 新規テキスト作成（親要素のstrokeを使用）
          match state.find_element(edit_state.parent_id) {
            Some(parent) =>
              resolve_color(parent.style.stroke.unwrap_or(default_text_color))
            None => default_text_color
          }
      }
      // テキスト入力の位置を決定
      // 常に親要素の中心座標を使用（子テキストの座標が相対座標の場合があるため）
      let (text_x, text_y) : (Double, Double) = match
        state.find_element(edit_state.parent_id) {
        Some(parent) => {
          let bbox = parent.bounding_box()
          let center_x = bbox.x + bbox.width / 2.0
          let center_y = bbox.y + bbox.height / 2.0
          (center_x, center_y)
        }
        None => (edit_state.x, edit_state.y)
      }
      // 背景色（テキスト色とのコントラストを考慮）
      // テキスト色が暗い（#000000に近い）場合は明るい背景、逆の場合は暗い背景
      let bg_color = get_contrasting_bg(text_color, theme)
      // Embed モード（モーダルなし）ではパーセント指定、それ以外はピクセル指定
      let is_embed_view = state.mode is @core.Embedded &&
        !state.modal_open.get()
      let base_font_size = match edit_state.font_size {
        Some(size) => size
        None => 16.0
      }
      let style = if is_embed_view {
        // Embed: viewBox "0 0 doc_w doc_h" に対するパーセント位置
        let doc_w = state.doc_width.get()
        let doc_h = state.doc_height.get()
        let left_pct = text_x / doc_w * 100.0
        let top_pct = text_y / doc_h * 100.0
        "position: absolute; left: \{left_pct}%; top: \{top_pct}%; transform: translate(-50%, -50%); min-width: 40px; padding: 2px 4px; border: none; background: \{bg_color}; color: \{text_color}; font-family: sans-serif; font-size: \{base_font_size}px; line-height: 1.2; text-align: center; outline: none; box-sizing: border-box; resize: none; overflow: hidden; caret-color: currentColor; white-space: nowrap; border-radius: 2px;"
      } else {
        // Full/Modal: viewport に基づくピクセル位置
        let screen_pos = vp.scene_to_screen(text_x, text_y)
        let min_width = 40.0 * vp.zoom
        let scaled_font_size = base_font_size * vp.zoom
        let scaled_height = scaled_font_size * 1.5
        "position: absolute; left: \{screen_pos.x}px; top: \{screen_pos.y}px; transform: translate(-50%, -50%); min-width: \{min_width}px; height: \{scaled_height}px; padding: 2px 4px; border: none; background: \{bg_color}; color: \{text_color}; font-family: sans-serif; font-size: \{scaled_font_size}px; line-height: 1.2; text-align: center; outline: none; box-sizing: border-box; resize: none; overflow: hidden; caret-color: currentColor; white-space: nowrap; border-radius: 2px;"
      }
      // リアルタイム更新用のコールバック
      let editing_id = edit_state.editing_id
      let initial_text = edit_state.initial_text
      // 入力中のリアルタイム更新は一時的に無効化（textareaが消える問題を調査中）
      let on_input = fn(_value : String) { () }
      let on_escape = fn(_value : String) {
        // キャンセル時は元のテキストに戻す
        match editing_id {
          Some(id) => state.update_text_raw(id, initial_text)
          None => ()
        }
        state.text_edit.set(None)
      }
      let textarea = create_textarea_ffi(
        style,
        initial_text,
        fn(value) { commit(value) },
        on_escape,
        on_input,
      )
      append_child_ffi(container, textarea)
      current_textarea.val = Some(textarea)
    }
  })
  @element.create_element(
    "div",
    [
      (
        "style",
        @element.Static(
          "position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none;",
        ),
      ),
      ("__ref", @element.Handler(fn(el) { container_ref.val = Some(el) })),
    ],
    [],
  )
}

///|
// svg_icon, toolbar_button は @components から利用

///|
/// 埋め込みツールバー（SVGアイコン + キーバインド表示）
fn render_embedded_toolbar(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  let theme = state.get_theme()
  // 一列に並べると狭い画面に収まらないので折り返す
  div(
    style="display: flex; flex-wrap: wrap; justify-content: center; gap: 3px; align-items: center;",
    [
      // 図形追加ボタン
      @components.toolbar_button(
        @components.svg_icon(@components.icon_rect, 16),
        Some("1"),
        "Rectangle",
        fn() {
          let el_id = new_id()
          let pos = state.get_placement_position()
          let width = 80.0
          let height = 60.0
          let new_rect = @model.Element::new(
            el_id,
            pos.x - width / 2.0,
            pos.y - height / 2.0,
            @model.Rect(width, height, None, None),
          ).with_style(state.get_default_style())
          @core.execute_command(history, state, @model.AddElement(new_rect))
          state.select(Some(el_id))
        },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_circle, 16),
        Some("2"),
        "Circle",
        fn() {
          let el_id = new_id()
          let pos = state.get_placement_position()
          let new_circle = @model.Element::new(
            el_id,
            pos.x,
            pos.y,
            @model.Circle(40.0),
          ).with_style(state.get_default_style())
          @core.execute_command(history, state, @model.AddElement(new_circle))
          state.select(Some(el_id))
        },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_ellipse, 16),
        Some("3"),
        "Ellipse",
        fn() {
          let el_id = new_id()
          let pos = state.get_placement_position()
          let new_ellipse = @model.Element::new(
            el_id,
            pos.x,
            pos.y,
            @model.Ellipse(60.0, 35.0),
          ).with_style(state.get_default_style())
          @core.execute_command(history, state, @model.AddElement(new_ellipse))
          state.select(Some(el_id))
        },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_line, 16),
        Some("4"),
        "Line",
        fn() {
          let el_id = new_id()
          let pos = state.get_placement_position()
          let dx = 100.0
          let dy = 50.0
          let new_line = @model.Element::new(
            el_id,
            pos.x - dx / 2.0,
            pos.y - dy / 2.0,
            @model.Line(pos.x + dx / 2.0, pos.y + dy / 2.0),
          ).with_style(state.get_line_style())
          @core.execute_command(history, state, @model.AddElement(new_line))
          state.select(Some(el_id))
        },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_arrow, 16),
        Some("5"),
        "Arrow",
        fn() {
          let el_id = new_id()
          let pos = state.get_placement_position()
          let dx = 100.0
          let dy = 50.0
          let new_arrow = @model.Element::new(
            el_id,
            pos.x - dx / 2.0,
            pos.y - dy / 2.0,
            @model.Line(pos.x + dx / 2.0, pos.y + dy / 2.0),
          ).with_style(state.get_arrow_style())
          @core.execute_command(history, state, @model.AddElement(new_arrow))
          state.select(Some(el_id))
        },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_text, 16),
        Some("6"),
        "Text",
        fn() {
          let el_id = new_id()
          let pos = state.get_placement_position()
          let font_size = 24.0
          // テキストは左上基準、概算で中央配置（"Text"の幅≒50px）
          let new_text = @model.Element::new(
            el_id,
            pos.x - 25.0,
            pos.y + font_size / 3.0,
            @model.Text("Text", Some(font_size)),
          ).with_style(state.get_text_style())
          @core.execute_command(history, state, @model.AddElement(new_text))
          state.select(Some(el_id))
        },
        theme~,
      ),
      // セパレータ
      @components.toolbar_separator(theme),
      // ツールモード切替
      @components.toolbar_button(
        @components.svg_icon(
          if state.tool_mode.get() == @core.FreeDraw {
            @components.icon_pen
          } else {
            @components.icon_cursor
          },
          16,
        ),
        Some("P"),
        if state.tool_mode.get() == @core.FreeDraw {
          "Free Draw (active)"
        } else {
          "Free Draw"
        },
        fn() { @lib.toggle_tool_mode(state) },
        theme~,
      ),
      // セパレータ
      @components.toolbar_separator(theme),
      // Undo/Redo
      @components.toolbar_button(
        @components.svg_icon(@components.icon_undo, 16),
        Some("⌘Z"),
        "Undo",
        fn() { let _ = @core.undo_command(history, state) },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_redo, 16),
        Some("⌘Y"),
        "Redo",
        fn() { let _ = @core.redo_command(history, state) },
        theme~,
      ),
      // セパレータ
      @components.toolbar_separator(theme),
      // ズームコントロール
      @components.toolbar_button(
        @components.svg_icon(@components.icon_zoom_out, 16),
        None,
        "Zoom Out",
        fn() { state.zoom_out() },
        theme~,
      ),
      @element.span(
        style="min-width: 44px; text-align: center; font-size: 11px; font-weight: 500; color: \{theme.ui_text};",
        [
          text_dyn(fn() {
            let zoom = state.viewport.get().zoom
            "\{(zoom * 100.0).to_int()}%"
          }),
        ],
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_zoom_in, 16),
        None,
        "Zoom In",
        fn() { state.zoom_in() },
        theme~,
      ),
      @components.toolbar_button(
        @components.svg_icon(@components.icon_reset, 16),
        None,
        "Fit to Canvas",
        fn() { state.fit_to_canvas(right_inset=panel_inset(state)) },
        theme~,
      ),
      // セパレータ
      @components.toolbar_separator(theme),
      // グリッドスナップ（トグルボタン + Popover）
      {
        let snap_popover_id = "tooltip-grid-snap"
        let snap_popover_style = "position: fixed; margin: 0; padding: 4px 8px; background: #333; color: #fff; font-size: 11px; border-radius: 4px; white-space: nowrap; border: none;"
        div(style="position: relative; display: inline-block;", [
          @element.create_element(
            "button",
            [
              (
                "style",
                @element.Dynamic(fn() {
                  let enabled = state.grid_enabled.get()
                  let is_dark = state.theme_mode.get() == @model.Dark
                  let current_theme = if is_dark {
                    @model.Theme::dark()
                  } else {
                    @model.Theme::light()
                  }
                  let base = "display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; padding: 4px 6px; cursor: pointer; border: 1px solid; border-radius: 4px; min-width: 36px; height: 40px;"
                  if enabled {
                    let enabled_bg = if is_dark { "#1e3a5f" } else { "#e3f2fd" }
                    let enabled_border = if is_dark {
                      "#4a9eff"
                    } else {
                      "#2196f3"
                    }
                    let enabled_color = if is_dark {
                      "#60a5fa"
                    } else {
                      "#1976d2"
                    }
                    base +
                    "background: \{enabled_bg}; border-color: \{enabled_border}; color: \{enabled_color};"
                  } else {
                    base +
                    "background: \{current_theme.ui_bg}; border-color: \{current_theme.ui_border}; color: \{current_theme.ui_text_muted};"
                  }
                }),
              ),
              ("aria-label", @element.Static("Grid Snap")),
              ("click", @element.Handler(fn(_) { state.toggle_grid() })),
              (
                "mouseenter",
                @element.Handler(fn(e) {
                  show_popover_at_button(snap_popover_id, e)
                }),
              ),
              (
                "mouseleave",
                @element.Handler(fn(_) { hide_popover(snap_popover_id) }),
              ),
            ],
            [
              @components.svg_icon(@components.icon_grid, 16),
              @element.span(
                style="color: inherit; font-size: 9px; line-height: 1;",
                [text("Snap")],
              ),
            ],
          ),
          div(
            style=snap_popover_style,
            attrs=[
              ("id", @element.AttrString(snap_popover_id)),
              ("popover", @element.AttrString("manual")),
            ],
            [text("Grid Snap")],
          ),
        ])
      },
      // セパレータ
      @components.toolbar_separator(theme),
      // エクスポート（Moonlight SVG形式でダウンロード）
      @components.toolbar_button(
        @components.svg_icon(@components.icon_export, 16),
        None,
        "Download SVG (Ctrl+S)",
        fn() {
          let svg_str = elements_to_moonlight_svg(
            state.elements.get(),
            state.doc_width.get().to_int(),
            state.doc_height.get().to_int(),
            state.get_theme().background,
          )
          download_file(svg_str, "moonlight.svg", "image/svg+xml")
        },
        theme~,
      ),
      // コピー（SVGテキスト）
      @components.toolbar_button(
        @components.svg_icon(@components.icon_copy, 16),
        None,
        "Copy SVG (Ctrl+Shift+C)",
        fn() {
          let svg_str = elements_to_moonlight_svg(
            state.elements.get(),
            state.doc_width.get().to_int(),
            state.doc_height.get().to_int(),
            state.get_theme().background,
          )
          copy_text_to_clipboard(svg_str, fn() { () }, fn() { () })
        },
        theme~,
      ),
      // インポート
      @components.toolbar_button(
        @components.svg_icon(@components.icon_import, 16),
        None,
        "Import SVG (Ctrl+Shift+V)",
        fn() {
          open_file_dialog(".svg", fn(text) {
            let result = import_svg_validated(text, new_id)
            for el in result.elements {
              @core.execute_command(history, state, @model.AddElement(el))
            }
            if result.elements.length() > 0 {
              // プレーンSVG要素を登録（既存に追加）
              if result.plain_svg_ids.length() > 0 {
                state.register_plain_svg_ids(result.plain_svg_ids)
              }
              // バリデーション実行
              state.revalidate()
              let ids = result.elements
                .filter(fn(el) { el.parent_id is None })
                .map(fn(el) { el.id })
              state.select_multiple(ids)
            }
          })
        },
        theme~,
      ),
      // GitHub リンク（フルモードのみ）
      @element.show(fn() { state.mode is @core.Full }, fn() {
        @element.fragment([
          @components.toolbar_separator(theme),
          @components.toolbar_button(
            @components.svg_icon(@components.icon_github, 16),
            None,
            "View on GitHub",
            fn() { open_github_url() },
            theme~,
          ),
        ])
      }),
    ],
  )
}

///|
/// GitHub URL
let github_url : String = "https://github.com/mizchi/moonlight"

///|
/// GitHub ページを開く
fn open_github_url() -> Unit {
  open_url_ffi(github_url)
}

///|
extern "js" fn open_url_ffi(url : String) =
  #| (url) => window.open(url, '_blank')

// =============================================================================
// SVG キャンバス（Luna VNode + for_each による差分更新）
// =============================================================================

///|
/// SVG キャンバスを作成（Luna VNode + for_each による差分更新）
fn render_svg_canvas_node(
  state : @core.EditorState,
  on_pointerdown : (@js.Any) -> Unit,
  on_pointermove : (@js.Any) -> Unit,
  on_pointerup : (@js.Any) -> Unit,
  on_pointerleave : (@js.Any) -> Unit,
  on_contextmenu : (@js.Any) -> Unit,
  on_wheel : (@js.Any) -> Unit,
) -> @element.DomNode {
  // 要素キーのリスト（for_each の差分キー）
  //
  // ID だけをキーにすると、同じ ID に別種の図形が入れ替わったときに古い DOM
  // ノードが使い回され、rect のノードに circle の属性が上書きされる。SVG を
  // 読み込み直すと ID が振り直されて衝突するので、実際にそうなる。
  // 図形の種類までキーに含めて、種類が変われば作り直させる。
  // Line/Arrow は常に手前に出したいので最後に並べる。
  let element_keys = @luna.memo(fn() {
    let elements = state.elements.get()
    let non_lines : Array[String] = []
    let lines : Array[String] = []
    for el in elements {
      if el.shape is @model.Line(_, _) {
        lines.push(element_key(el))
      } else {
        non_lines.push(element_key(el))
      }
    }
    non_lines.append(lines)
    non_lines
  })

  // SVG 子要素
  let children : Array[@element.DomNode] = []

  // 矢印マーカーの defs（静的）+ ドキュメントシャドウフィルタ
  let defs_node : @js_dom.Node = create_arrow_defs().cast()
  children.push(@element.static_node(defs_node))
  // ドキュメントシャドウフィルタ（テーマに応じて変化）
  children.push(
    create_doc_shadow_filter_node(state.theme_mode.get() == @model.Dark),
  )

  // Canvas 背景（境界外グレー + ドキュメント境界）
  children.push(render_canvas_background_vnode(state))

  // グリッド線（grid_enabled に応じて表示/非表示）
  children.push(
    @element.create_element_ns(
      @element.svg_ns,
      "g",
      [
        (
          "style",
          @element.Dynamic(fn() {
            if state.grid_enabled.get() {
              "visibility: visible;"
            } else {
              "visibility: hidden;"
            }
          }),
        ),
      ],
      [render_grid_vnode(state)],
    ),
  )

  // 要素を for_each で描画（ID + 図形の種類をキーにした差分更新）
  children.push(
    @element.for_each(fn() { element_keys() }, fn(key, _idx) {
      render_element_vnode(state, element_id_of_key(key))
    }),
  )

  // 選択ハンドル・アンカー
  children.push(render_selection_overlay(state))

  // 矩形選択ボックス
  children.push(
    @element.show(fn() { state.box_select.get() is Some(_) }, fn() {
      render_box_select_vnode(state)
    }),
  )

  // 線ドラッグ中のアンカーポイント
  children.push(
    @element.show(
      fn() {
        match state.resize_state.get() {
          Some(resize) => resize.start_shape is @model.Line(_, _)
          None => false
        }
      },
      fn() { render_all_anchors_vnode(state) },
    ),
  )

  // 接続ハイライト
  children.push(
    @element.show(fn() { state.pending_connection.get() is Some(_) }, fn() {
      render_connection_highlight_vnode(state)
    }),
  )

  // SVG 属性（100% サイズ、viewBox は動的）
  let svg_attrs : Array[(String, @element.AttrValue)] = [
    ("width", @element.Static("100%")),
    ("height", @element.Static("100%")),
    (
      "viewBox",
      @element.Dynamic(fn() {
        // Embedモードではドキュメント全体を表示（0, 0, doc_w, doc_h）
        // ただしモーダルが開いている場合はフルモードのviewBoxを使用
        if state.mode is @core.Embedded && !state.modal_open.get() {
          let doc_w = state.doc_width.get()
          let doc_h = state.doc_height.get()
          "0 0 \{doc_w} \{doc_h}"
        } else {
          let vp = state.viewport.get()
          let cw = state.canvas_width.get().to_double()
          let ch = state.canvas_height.get().to_double()
          let vb_width = cw / vp.zoom
          let vb_height = ch / vp.zoom
          "\{vp.scroll_x} \{vp.scroll_y} \{vb_width} \{vb_height}"
        }
      }),
    ),
    (
      "style",
      @element.Dynamic(fn() {
        let theme = state.get_theme()
        // 埋め込みモードではコンテナ側にボーダーがあるのでSVGのボーダーは不要
        let border = if state.mode is @core.Embedded {
          "none"
        } else {
          "1px solid #ccc"
        }
        // ツールモードに応じてカーソルを変更
        let cursor = match state.tool_mode.get() {
          @core.FreeDraw => "crosshair"
          @core.Select => "default"
        }
        "border: \{border}; user-select: none; touch-action: none; overflow: hidden; cursor: \{cursor}; --ml-stroke: \{theme.stroke}; --ml-fill: \{theme.fill}; --ml-text: \{theme.text};"
      }),
    ),
    ("pointerdown", @element.Handler(on_pointerdown)),
    ("pointermove", @element.Handler(on_pointermove)),
    ("pointerup", @element.Handler(on_pointerup)),
    ("pointerleave", @element.Handler(on_pointerleave)),
    ("contextmenu", @element.Handler(on_contextmenu)),
    ("wheel", @element.Handler(on_wheel)),
    // ResizeObserver で canvas サイズを更新し、初回はドキュメントを中央に配置（Fullモードのみ）
    (
      "__ref",
      @element.Handler(fn(svg_el) {
        // SVG 要素への参照を保存（フリードロープレビュー用）
        state.svg_el.set(svg_el)
        let is_first_resize : Ref[Bool] = { val: true, }
        observe_resize_ffi(svg_el, fn(width : Double, height : Double) {
          let w = width.to_int()
          let h = height.to_int()
          if w > 0 && h > 0 {
            state.canvas_width.set(w)
            state.canvas_height.set(h)
            // 初回のみドキュメントを中央に配置（Fullモードまたはモーダル表示時）
            if is_first_resize.val {
              is_first_resize.val = false
              // Embedモードでモーダルが閉じている場合はビューポートを (0, 0, 1.0) に固定
              if state.mode is @core.Full || state.modal_open.get() {
                state.fit_to_canvas(right_inset=panel_inset(state))
              }
            }
          }
        })
      }),
    ),
  ]
  @element.create_element_ns(@element.svg_ns, "svg", svg_attrs, children)
}
