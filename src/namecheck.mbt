///|
/// 名字段门(役E1,R-E1b/R-E1c):版本键控 × 版本面键控的名字产生式校验。
/// 数据面 = name_tables_gen.mbt(gen 直发区间表 + 谓词);本件只写拼装语义
/// (1.0 Letter = BaseChar|Ideographic、Name/NameChar 组合)与树面行走。
/// 口径:
/// - version="1.1" 文档恒走 1.1 紧凑表(产生式 [4]/[5]),版本面选择无关;
/// - version="1.0"/无声明文档按 [XmlEdition] 选表:Editions1to4 = 4e 全表
///   (BaseChar/Ideographic/CombiningChar/Digit/Extender,产生式 [85]-[89],
///   套件 EDITION="1 2 3 4" 面判词所据);Edition5 = 5e 紧凑表(与 1.1 同形,
///   套件 EDITION="5" 面判词所据;亦即 parse 缺省面 = 现行底座行为)。
/// 门位:树建后全量行走(DOCTYPE 名/PI 目标/元素名/属性名)——M2 实证内部
/// 子集 PI 事件落 prologue/epilogue,树面可见,漏拒族全在此收。

///|
/// XML 1.0 版本面(套件 EDITION 语义:测试按适用版次标注,处理器按面选子集)。
pub(all) enum XmlEdition {
  Editions1to4
  Edition5
} derive(Eq)

///|
pub extend XmlEdition with Eq::{equal, not_equal}

///|
/// 1.0 Letter(4e 产生式 [84])= BaseChar | Ideographic。
fn is_letter_10(code_point : Int32) -> Bool {
  is_base_char_10(code_point) || is_ideographic_10(code_point)
}

///|
/// 1.0 NameStartChar(4e [5] 字符面)= ':' | '_' | Letter。
fn is_name_start_10(code_point : Int32) -> Bool {
  code_point == 0x3A || code_point == 0x5F || is_letter_10(code_point)
}

///|
/// 1.0 NameChar(4e [4])= NameStartChar | Digit | '.' | '-' | CombiningChar |
/// Extender。
fn is_name_char_10(code_point : Int32) -> Bool {
  is_name_start_10(code_point) ||
  is_digit_10(code_point) ||
  code_point == 0x2D ||
  code_point == 0x2E ||
  is_combining_char_10(code_point) ||
  is_extender_10(code_point)
}

///|
/// 5e/1.1 NameStartChar(紧凑表,gen 直发)。
fn is_name_start_5(code_point : Int32) -> Bool {
  is_name_start_char_11(code_point)
}

///|
/// 5e/1.1 NameChar(紧凑表 + 对 NameStartChar 的引用,gen 已展开)。
fn is_name_char_5(code_point : Int32) -> Bool {
  is_name_char_11(code_point)
}

///|
/// 版本面 → 谓词对(version="1.1" 恒走 1.1;否则按版本面选)。
fn name_predicates(
  edition : XmlEdition,
  version_11 : Bool,
) -> ((Int32) -> Bool, (Int32) -> Bool) {
  match (edition, version_11) {
    (_, true) => (is_name_start_5, is_name_char_5)
    (Editions1to4, false) => (is_name_start_10, is_name_char_10)
    (Edition5, false) => (is_name_start_5, is_name_char_5)
  }
}

///|
/// 名字串按谓词对校验;返回违规注记(合法 = None)。
fn name_violation_of(
  name : String,
  edition : XmlEdition,
  version_11 : Bool,
) -> String? {
  let (start_ok, char_ok) = name_predicates(edition, version_11)
  let chars = name.to_array()
  if chars.length() == 0 {
    return Some("empty name")
  }
  let first = chars[0].to_int()
  if start_ok(first) == false {
    return Some(
      "illegal name start character #x\{first.to_string(radix=16)} in \"\{name}\"",
    )
  }
  for index in 1..<chars.length() {
    let code_point = chars[index].to_int()
    if char_ok(code_point) == false {
      return Some(
        "illegal name character #x\{code_point.to_string(radix=16)} in \"\{name}\"",
      )
    }
  }
  None
}

///|
/// 名字段错(树不带 span——R-M1 定案,零位报;消息含码点与名字原文)。
fn name_error(message : String) -> XmlError {
  XmlError::At(error=XmlErrorKind::IllegalName(message), span={
    start: { offset: 0, line: 1, column: 1, },
    end: { offset: 0, line: 1, column: 1, },
  })
}

///|
fn check_name(
  name : String,
  edition : XmlEdition,
  version_11 : Bool,
) -> Unit raise XmlError {
  match name_violation_of(name, edition, version_11) {
    Some(message) => raise name_error(message)
    None => ()
  }
}

///|
/// 树节点行走:PI 目标 + 元素名 + 属性名,递归子树。
fn check_node(
  node : Node,
  edition : XmlEdition,
  version_11 : Bool,
) -> Unit raise XmlError {
  match node {
    PI(target~, ..) => check_name(target, edition, version_11)
    Element(element) => {
      check_name(element.name.qualified_name, edition, version_11)
      for attribute in element.attributes {
        check_name(attribute.name.qualified_name, edition, version_11)
      }
      for child in element.children {
        check_node(child, edition, version_11)
      }
    }
    _ => ()
  }
}

///|
/// 文档名字面全查:DOCTYPE 名 + 根前 + 根 + 根后(声明定版本;无声明 = 1.0)。
fn validate_document_names(
  document : Document,
  edition : XmlEdition,
) -> Unit raise XmlError {
  let version_11 = match document.decl {
    Some(declaration) => declaration.version == "1.1"
    None => false
  }
  match document.doctype {
    Some(name) => check_name(name, edition, version_11)
    None => ()
  }
  for node in document.prologue {
    check_node(node, edition, version_11)
  }
  check_name(document.root.name.qualified_name, edition, version_11)
  for attribute in document.root.attributes {
    check_name(attribute.name.qualified_name, edition, version_11)
  }
  for child in document.root.children {
    check_node(child, edition, version_11)
  }
  for node in document.epilogue {
    check_node(node, edition, version_11)
  }
}
