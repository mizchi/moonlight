// シーンの意味を言葉にする
//
// 視覚テストでは「セマンティックモデルがこう主張している」と
// 「実際に描かれた絵がそうなっている」を突き合わせる必要がある。
// ここで作る説明文がその主張そのもので、vlmkit の自然言語アサーションに渡す。

///|
/// 図形を一行で説明する（座標付き）
pub fn describe_element(el : @model.Element) -> String {
  let bbox = el.bounding_box()
  let where_ = "at (\{@model.num_str(bbox.x)}, \{@model.num_str(bbox.y)}) size \{@model.num_str(bbox.width)}x\{@model.num_str(bbox.height)}"
  match el.shape {
    @model.Rect(_, _, _, _) => "rectangle \{el.id} \{where_}"
    @model.Circle(r) =>
      "circle \{el.id} centred at (\{@model.num_str(el.x)}, \{@model.num_str(el.y)}) radius \{@model.num_str(r)}"
    @model.Ellipse(rx, ry) =>
      "ellipse \{el.id} centred at (\{@model.num_str(el.x)}, \{@model.num_str(el.y)}) radii \{@model.num_str(rx)}x\{@model.num_str(ry)}"
    @model.Line(x2, y2) => {
      // 矢じりの有無は絵の意味を変えるので言葉にする
      let kind = if el.style.marker_end is Some(@model.Arrow) ||
        el.style.marker_start is Some(@model.Arrow) {
        "arrow"
      } else {
        "line"
      }
      "\{kind} \{el.id} from (\{@model.num_str(el.x)}, \{@model.num_str(el.y)}) to (\{@model.num_str(x2)}, \{@model.num_str(y2)})"
    }
    @model.Polyline(points) =>
      "polyline \{el.id} with \{points.length()} points"
    @model.Path(_, _, _, _, _) => "path \{el.id} \{where_}"
    @model.Text(content, _) =>
      match el.parent_id {
        // 図形に結び付いた文字（図形を動かすと付いてくる）
        Some(pid) => "label \{el.id} \"\{content}\" on \{pid} \{where_}"
        None => "text \{el.id} \"\{content}\" \{where_}"
      }
  }
}

///|
/// ジョイントを一行で説明する
pub fn Scene::describe_joint(self : Scene, joint : Joint) -> String {
  let end_name = match joint.endpoint {
    Start => "start"
    End => "end"
  }
  let anchor_name = @model.anchor_to_string(joint.anchor)
  let target_kind = match self.find(joint.target_id) {
    Some(el) => @model.shape_name(el.shape)
    None => "missing element"
  }
  "the \{end_name} of line \{joint.line_id} is attached to the \{anchor_name} anchor of \{target_kind} \{joint.target_id}"
}

///|
/// シーン全体の説明。図形の列挙とジョイントの主張からなる。
pub fn Scene::describe(self : Scene) -> String {
  let lines : Array[String] = []
  if self.elements.length() == 0 {
    lines.push("The canvas is empty.")
  } else {
    lines.push("Shapes:")
    for el in self.elements {
      lines.push("- \{describe_element(el)}")
    }
  }
  let joints = self.joints()
  if joints.length() > 0 {
    lines.push("Connections:")
    for joint in joints {
      lines.push("- \{self.describe_joint(joint)}")
    }
  }
  if self.selection.length() > 0 {
    lines.push("Selected: \{self.selection.join(", ")}")
  }
  lines.join("\n")
}

///|
/// 視覚テストに渡す主張文。
/// 「絵を見てこれが成り立っているか」を判定できる粒度だけを書く。
pub fn Scene::visual_claims(self : Scene) -> Array[String] {
  let claims : Array[String] = []
  // 図形の数と種類は数えれば確かめられる
  let counts : Map[String, Int] = Map([])
  for el in self.elements {
    let name = @model.shape_name(el.shape)
    counts[name] = counts.get(name).unwrap_or(0) + 1
  }
  for name, n in counts {
    claims.push("The image contains exactly \{n} \{name} shape(s).")
  }
  // ジョイントは「線の端が図形に触れている」という見た目の主張になる
  for joint in self.joints() {
    guard self.find(joint.target_id) is Some(target) else { continue }
    let end_name = match joint.endpoint {
      Start => "starting"
      End => "ending"
    }
    let side = anchor_side_phrase(joint.anchor)
    claims.push(
      "The \{end_name} end of a line touches the \{side} of the \{@model.shape_name(target.shape)}, with no visible gap between them.",
    )
  }
  claims
}

///|
/// アンカーを見た目の言葉に直す
pub fn anchor_side_phrase(anchor : @model.Anchor) -> String {
  match anchor {
    @model.Center => "centre"
    @model.Top => "top edge"
    @model.Bottom => "bottom edge"
    @model.Left => "left edge"
    @model.Right => "right edge"
    @model.TopLeft => "top-left corner"
    @model.TopRight => "top-right corner"
    @model.BottomLeft => "bottom-left corner"
    @model.BottomRight => "bottom-right corner"
    @model.LineStart => "start point"
    @model.LineEnd => "end point"
  }
}
