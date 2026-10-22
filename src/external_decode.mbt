///|
/// 外取件解码面(役B2,R-B1d):外取实体/外取子集按外部件解码——BOM
/// 容错与 text decl 编码识别复用 [decode_source] 前端;解码输出若以
/// text decl 开头则剥除。text decl 非实体内容:残留会被底座按 PI 读,
/// 而 PI 目标 "xml" 保留,valid 族会被错拒。
fn decode_external(bytes : Bytes) -> Result[String, XmlError] {
  match decode_source(bytes) {
    Ok(text) => Ok(strip_text_declaration(text))
    Err(why) => Err(why)
  }
}

///|
/// 剥除开头 text decl(仅当确在文首;未闭合 decl 不吞——留给底座按
/// PI 面报错,位面诚实)。text decl 后的换行属于声明语法,一并剥离
/// 属合法(内容前置空白处处合法)。
fn strip_text_declaration(text : String) -> String {
  if !text.has_prefix("<?xml") {
    return text
  }
  let limit = text.length()
  let mut cursor = 5
  let mut close = -1
  while cursor + 1 < limit {
    if text[cursor] == '?' && text[cursor + 1] == '>' {
      close = cursor
      break
    }
    cursor = cursor + 1
  }
  if close < 0 {
    text
  } else {
    text[close + 2:].to_owned()
  }
}
