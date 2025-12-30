// Moonlight - Validation モジュール
// 要素の操作可能性を検証し、UI層での操作制御に使用

// ============================================================
// 検証レベルと結果
// ============================================================

///|
/// 検証問題の重大度
pub(all) enum ValidationLevel {
  Error // 致命的な問題（操作不可）
  Warning // 警告（操作可能だが注意が必要）
  Info // 情報（参考）
} derive(Show, Eq)

///|
/// 検証で見つかった問題
pub(all) struct ValidationIssue {
  level : ValidationLevel
  element_id : String? // 問題のある要素ID（None = 全体的な問題）
  code : String // 問題コード（例: "INVALID_PARENT", "ORPHAN_CONNECTION"）
  message : String // 人間が読めるメッセージ
} derive(Show, Eq)

///|
/// 要素の操作権限
pub(all) struct ElementCapability {
  can_move : Bool // 移動可能
  can_resize : Bool // リサイズ可能
  can_edit : Bool // プロパティ編集可能
  can_delete : Bool // 削除可能
  can_connect : Bool // 接続可能（Line要素）
  can_add_child : Bool // 子要素追加可能
} derive(Show, Eq)

///|
/// 全操作可能
pub fn ElementCapability::full() -> ElementCapability {
  {
    can_move: true,
    can_resize: true,
    can_edit: true,
    can_delete: true,
    can_connect: true,
    can_add_child: true,
  }
}

///|
/// 移動のみ可能
pub fn ElementCapability::move_only() -> ElementCapability {
  {
    can_move: true,
    can_resize: false,
    can_edit: false,
    can_delete: false,
    can_connect: false,
    can_add_child: false,
  }
}

///|
/// 移動と削除のみ可能（問題のある要素を除去可能にする）
pub fn ElementCapability::move_and_delete() -> ElementCapability {
  {
    can_move: true,
    can_resize: false,
    can_edit: false,
    can_delete: true,
    can_connect: false,
    can_add_child: false,
  }
}

///|
/// 全操作不可
pub fn ElementCapability::none() -> ElementCapability {
  {
    can_move: false,
    can_resize: false,
    can_edit: false,
    can_delete: false,
    can_connect: false,
    can_add_child: false,
  }
}

///|
/// 検証結果
pub(all) struct ValidationResult {
  is_valid : Bool // 全体として有効か
  issues : Array[ValidationIssue] // 見つかった問題
  capabilities : Map[String, ElementCapability] // 要素ごとの操作権限
} derive(Show)

///|
/// 空の検証結果（有効）
pub fn ValidationResult::valid() -> ValidationResult {
  { is_valid: true, issues: [], capabilities: {} }
}

// ============================================================
// 問題コード定数
// ============================================================

///|
pub let issue_invalid_id : String = "INVALID_ID"

///|
pub let issue_duplicate_id : String = "DUPLICATE_ID"

///|
pub let issue_invalid_parent : String = "INVALID_PARENT"

///|
pub let issue_circular_parent : String = "CIRCULAR_PARENT"

///|
pub let issue_orphan_connection : String = "ORPHAN_CONNECTION"

///|
pub let issue_self_connection : String = "SELF_CONNECTION"

///|
pub let issue_invalid_shape : String = "INVALID_SHAPE"

///|
pub let issue_negative_dimension : String = "NEGATIVE_DIMENSION"

///|
pub let issue_line_same_points : String = "LINE_SAME_POINTS"

///|
pub let issue_text_empty : String = "TEXT_EMPTY"

///|
/// 無効な座標（NaN, Infinity）
pub let issue_invalid_coordinates : String = "INVALID_COORDINATES"

///|
/// プレーンSVG要素（Moonlight形式でない）
pub let issue_plain_svg_element : String = "PLAIN_SVG_ELEMENT"

///|
/// 未サポートのシェープタイプ
pub let issue_unsupported_shape : String = "UNSUPPORTED_SHAPE"

// ============================================================
// ヘルパー関数
// ============================================================

///|
/// 値が有限値かどうかをチェック（NaN, Infinity でない）
fn is_finite(value : Double) -> Bool {
  // NaN は自分自身と等しくない
  if value != value {
    return false
  }
  // Infinity チェック
  if value > 1.0e308 || value < -1.0e308 {
    return false
  }
  true
}

// ============================================================
// 検証関数
// ============================================================

///|
/// 要素配列を検証し、結果を返す
pub fn validate_elements(elements : Array[Element]) -> ValidationResult {
  let issues : Array[ValidationIssue] = []
  let capabilities : Map[String, ElementCapability] = {}

  // ID の収集と重複チェック
  let id_set : Map[String, Int] = {} // id -> count
  for el in elements {
    match id_set.get(el.id) {
      Some(count) => id_set[el.id] = count + 1
      None => id_set[el.id] = 1
    }
  }

  // 各要素を検証
  for el in elements {
    let el_issues = validate_element(el, elements, id_set)
    for issue in el_issues {
      issues.push(issue)
    }

    // 操作権限を決定
    let cap = determine_capability(el, el_issues)
    capabilities[el.id] = cap
  }

  // 全体の有効性を判定（Errorがなければ有効）
  let has_errors = issues.iter().any(fn(i) { i.level == Error })
  { is_valid: not(has_errors), issues, capabilities }
}

///|
/// 単一要素を検証
fn validate_element(
  el : Element,
  all_elements : Array[Element],
  id_counts : Map[String, Int],
) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []

  // ID検証
  if el.id == "" {
    issues.push({
      level: Error,
      element_id: Some(el.id),
      code: issue_invalid_id,
      message: "Element has empty ID",
    })
  }

  // 座標の有効性検証（NaN, Infinity チェック）
  if not(is_finite(el.x)) || not(is_finite(el.y)) {
    issues.push({
      level: Error,
      element_id: Some(el.id),
      code: issue_invalid_coordinates,
      message: "Element has invalid coordinates (NaN or Infinity)",
    })
  }

  // 重複ID検証
  match id_counts.get(el.id) {
    Some(count) if count > 1 =>
      issues.push({
        level: Error,
        element_id: Some(el.id),
        code: issue_duplicate_id,
        message: "Duplicate element ID: \{el.id}",
      })
    _ => ()
  }

  // 親要素検証
  match el.parent_id {
    Some(pid) => {
      let parent_exists = all_elements.iter().any(fn(e) { e.id == pid })
      if not(parent_exists) {
        issues.push({
          level: Warning,
          element_id: Some(el.id),
          code: issue_invalid_parent,
          message: "Parent element '\{pid}' does not exist",
        })
      }

      // 循環参照チェック
      if has_circular_parent(el.id, all_elements) {
        issues.push({
          level: Error,
          element_id: Some(el.id),
          code: issue_circular_parent,
          message: "Circular parent reference detected",
        })
      }
    }
    None => ()
  }

  // 接続検証（Line要素）
  match el.connections {
    Some(conns) => {
      validate_connection(el.id, conns.start, all_elements, issues)
      validate_connection(el.id, conns.end, all_elements, issues)

      // 自己接続チェック
      let self_connected = match (conns.start, conns.end) {
        (Some(s), Some(e)) => s.element_id == e.element_id
        _ => false
      }
      if self_connected {
        issues.push({
          level: Warning,
          element_id: Some(el.id),
          code: issue_self_connection,
          message: "Line connects element to itself",
        })
      }
    }
    None => ()
  }

  // 形状固有の検証
  validate_shape(el, issues)
  issues
}

///|
/// 接続を検証
fn validate_connection(
  line_id : String,
  conn : Connection?,
  all_elements : Array[Element],
  issues : Array[ValidationIssue],
) -> Unit {
  match conn {
    Some(c) => {
      let target_exists = all_elements
        .iter()
        .any(fn(e) { e.id == c.element_id })
      if not(target_exists) {
        issues.push({
          level: Warning,
          element_id: Some(line_id),
          code: issue_orphan_connection,
          message: "Connected element '\{c.element_id}' does not exist",
        })
      }
    }
    None => ()
  }
}

///|
/// 形状固有の検証
fn validate_shape(el : Element, issues : Array[ValidationIssue]) -> Unit {
  match el.shape {
    Rect(w, h, _, _) =>
      if w < 0.0 || h < 0.0 {
        issues.push({
          level: Error,
          element_id: Some(el.id),
          code: issue_negative_dimension,
          message: "Rectangle has negative dimensions",
        })
      }
    Circle(r) =>
      if r < 0.0 {
        issues.push({
          level: Error,
          element_id: Some(el.id),
          code: issue_negative_dimension,
          message: "Circle has negative radius",
        })
      }
    Ellipse(rx, ry) =>
      if rx < 0.0 || ry < 0.0 {
        issues.push({
          level: Error,
          element_id: Some(el.id),
          code: issue_negative_dimension,
          message: "Ellipse has negative radius",
        })
      }
    Line(x2, y2) =>
      if el.x == x2 && el.y == y2 {
        issues.push({
          level: Warning,
          element_id: Some(el.id),
          code: issue_line_same_points,
          message: "Line start and end points are the same",
        })
      }
    Text(content, _) =>
      if content == "" {
        issues.push({
          level: Info,
          element_id: Some(el.id),
          code: issue_text_empty,
          message: "Text element has empty content",
        })
      }
    _ => ()
  }
}

///|
/// 循環参照をチェック
fn has_circular_parent(element_id : String, elements : Array[Element]) -> Bool {
  let visited : Array[String] = []
  let mut current_id = element_id

  // 最大 elements.length() + 1 回のイテレーションでサイクルを検出
  for _ in 0..<(elements.length() + 1) {
    if visited.contains(current_id) {
      return true
    }
    visited.push(current_id)

    // 現在の要素を探す
    let mut found_parent : String? = None
    for el in elements {
      if el.id == current_id {
        found_parent = el.parent_id
        break
      }
    }
    match found_parent {
      Some(pid) => current_id = pid
      None => return false
    }
  }
  false
}

///|
/// 問題に基づいて操作権限を決定
fn determine_capability(
  el : Element,
  issues : Array[ValidationIssue],
) -> ElementCapability {
  // エラーがあるかチェック
  let has_errors = issues.iter().any(fn(i) { i.level == Error })
  if has_errors {
    // エラーがあっても移動と削除は許可
    return ElementCapability::move_and_delete()
  }

  // 警告でも move_only にすべき重大なケースをチェック
  let has_critical_warning = issues.iter().any(fn(i) {
    i.level == Warning &&
      (i.code == issue_invalid_parent || i.code == issue_orphan_connection)
  })
  if has_critical_warning {
    return ElementCapability::move_and_delete()
  }

  // 形状に応じた権限
  match el.shape {
    Line(_, _) =>
      {
        can_move: true,
        can_resize: true,
        can_edit: true,
        can_delete: true,
        can_connect: true,
        can_add_child: false, // Line には子要素を追加できない
      }
    Text(_, _) =>
      {
        can_move: true,
        can_resize: true,
        can_edit: true,
        can_delete: true,
        can_connect: false, // Text には接続できない
        can_add_child: false,
      }
    _ => ElementCapability::full()
  }
}

///|
/// プレーンSVG要素向けの権限を決定
pub fn determine_capability_for_plain_svg(el : Element) -> ElementCapability {
  // プレーンSVGは移動と削除のみ
  ignore(el)
  ElementCapability::move_and_delete()
}

// ============================================================
// 便利な検証ヘルパー
// ============================================================

///|
/// 要素が操作可能か判定
pub fn is_element_operable(
  result : ValidationResult,
  element_id : String,
) -> Bool {
  match result.capabilities.get(element_id) {
    Some(cap) =>
      cap.can_move || cap.can_resize || cap.can_edit || cap.can_delete
    None => false
  }
}

///|
/// 要素の操作権限を取得
pub fn get_element_capability(
  result : ValidationResult,
  element_id : String,
) -> ElementCapability {
  result.capabilities.get(element_id).unwrap_or(ElementCapability::none())
}

///|
/// 特定要素の問題を取得
pub fn get_element_issues(
  result : ValidationResult,
  element_id : String,
) -> Array[ValidationIssue] {
  result.issues
  .iter()
  .filter(fn(i) {
    match i.element_id {
      Some(id) => id == element_id
      None => false
    }
  })
  .collect()
}

///|
/// エラーのみ取得
pub fn get_errors(result : ValidationResult) -> Array[ValidationIssue] {
  result.issues.iter().filter(fn(i) { i.level == Error }).collect()
}

///|
/// 警告のみ取得
pub fn get_warnings(result : ValidationResult) -> Array[ValidationIssue] {
  result.issues.iter().filter(fn(i) { i.level == Warning }).collect()
}

// ============================================================
// 増分検証（パフォーマンス最適化）
// ============================================================

///|
/// 単一要素の検証（他の要素との関係も考慮）
pub fn validate_single_element(
  el : Element,
  all_elements : Array[Element],
) -> Array[ValidationIssue] {
  // ID カウントを作成
  let id_counts : Map[String, Int] = {}
  for e in all_elements {
    match id_counts.get(e.id) {
      Some(count) => id_counts[e.id] = count + 1
      None => id_counts[e.id] = 1
    }
  }
  validate_element(el, all_elements, id_counts)
}

///|
/// 要素が追加可能か事前チェック
pub fn can_add_element(
  new_element : Element,
  existing_elements : Array[Element],
) -> (Bool, Array[ValidationIssue]) {
  // ID重複チェック
  let id_exists = existing_elements.iter().any(fn(e) { e.id == new_element.id })
  if id_exists {
    return (
      false,
      [
        {
          level: Error,
          element_id: Some(new_element.id),
          code: issue_duplicate_id,
          message: "Element with ID '\{new_element.id}' already exists",
        },
      ],
    )
  }

  // 新しい要素を追加した配列で検証
  let all_elements = existing_elements.copy()
  all_elements.push(new_element)
  let issues = validate_single_element(new_element, all_elements)
  let has_errors = issues.iter().any(fn(i) { i.level == Error })
  (not(has_errors), issues)
}

///|
/// 要素が削除可能か事前チェック
pub fn can_delete_element(
  element_id : String,
  all_elements : Array[Element],
) -> (Bool, Array[ValidationIssue]) {
  let issues : Array[ValidationIssue] = []

  // 子要素があるかチェック
  let has_children = all_elements
    .iter()
    .any(fn(e) {
      match e.parent_id {
        Some(pid) => pid == element_id
        None => false
      }
    })
  if has_children {
    issues.push({
      level: Warning,
      element_id: Some(element_id),
      code: "HAS_CHILDREN",
      message: "Element has child elements that will become orphaned",
    })
  }

  // この要素に接続している Line があるかチェック
  let connected_lines : Array[String] = []
  for el in all_elements {
    match el.connections {
      Some(conns) => {
        let is_connected = match (conns.start, conns.end) {
          (Some(s), _) if s.element_id == element_id => true
          (_, Some(e)) if e.element_id == element_id => true
          _ => false
        }
        if is_connected {
          connected_lines.push(el.id)
        }
      }
      None => ()
    }
  }
  if connected_lines.length() > 0 {
    issues.push({
      level: Warning,
      element_id: Some(element_id),
      code: "HAS_CONNECTIONS",
      message: "Element is connected by \{connected_lines.length()} line(s)",
    })
  }

  // 警告のみなら削除可能
  let has_errors = issues.iter().any(fn(i) { i.level == Error })
  (not(has_errors), issues)
}

// ============================================================
// 整合性修復のヒント
// ============================================================

///|
/// 修復アクション
pub(all) enum RepairAction {
  RemoveConnection(String, String) // (line_id, which: "start" | "end")
  RemoveParent(String) // element_id
  DeleteElement(String) // element_id
  RegenerateId(String, String) // (old_id, new_id)
} derive(Show, Eq)

///|
/// 問題に対する修復アクションを提案
pub fn suggest_repairs(issues : Array[ValidationIssue]) -> Array[RepairAction] {
  let actions : Array[RepairAction] = []
  for issue in issues {
    match (issue.code, issue.element_id) {
      (code, Some(id)) if code == issue_orphan_connection =>
        // 孤立した接続を削除
        actions.push(RemoveConnection(id, "auto"))
      (code, Some(id)) if code == issue_invalid_parent =>
        // 無効な親を解除
        actions.push(RemoveParent(id))
      (code, Some(id)) if code == issue_circular_parent =>
        // 循環参照を解消
        actions.push(RemoveParent(id))
      (code, Some(id)) if code == issue_duplicate_id =>
        // 重複IDを再生成
        actions.push(RegenerateId(id, id + "_copy"))
      _ => ()
    }
  }
  actions
}
