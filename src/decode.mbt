///|
/// 编码前端 + 版本键控 Char 门。
/// 职责：把 bytes 变成规范 UTF-8 源文本，喂给 [parse] 前的源域处理：
/// ① BOM 嗅探(UTF-8 / UTF-16LE / UTF-16BE,BOM 是 UTF-16 的唯一合法引导);
/// ② 声明面编码决策——支持集 = utf-8(严格)/ utf-16(须 BOM 键控)/
///    iso-8859-1 / ascii 同族;其余编码名 = 不支持编码,拒
///    （引擎实际能力如实报错；套件 error 判词档若按门要求必解析，则挂 deferred，
///    见 ctx.md §5）；
/// 施工账：ctx.md §5（役A1）。
/// ③ BOM/声明冲突检测(两个方向都是错);
/// ④ 严格 UTF-8:坏字节 / CESU 代理 / 过长形一律拒;
/// ⑤ 全文 Char 门,版本取自声明:1.0 全表 vs 1.1 restricted-literal
///    (1.1 的 [#x1-#x8]…[#x86-#x9F] 区须走字符引用,字面 = 拒;NEL 字面合法)。
/// 错误面 = [XmlError](新词 [XmlErrorKind::Encoding] / [XmlErrorKind::IllegalChar]);
/// offset 精确,行列尽力(byte 面按 0x0A 计,text 面按字符计)。
pub fn decode_source(bytes : Bytes) -> Result[String, XmlError] {
  Ok(decode_from(bytes[:])) catch {
    error => Err(error)
  }
}

///|
/// 编码分流:UTF-16 BOM 两臂(分流后声明只许 utf-16 族)、
/// UTF-8 BOM 一臂(剥后按 8 位面走)、无 BOM 8 位面。
fn decode_from(view : BytesView) -> String raise XmlError {
  match view {
    [0xFF, 0xFE, .. rest] => decode_utf16_document(rest, false)
    [0xFE, 0xFF, .. rest] => decode_utf16_document(rest, true)
    [0xEF, 0xBB, 0xBF, .. rest] => decode_8bit_document(rest, true)
    _ => decode_8bit_document(view, false)
  }
}

///|
/// UTF-16 文档面:严格解码(代理配对)→ 声明冲突检 → Char 门。
/// BOM 是本面的编码真源;声明若给出非 utf-16 族编码名即冲突。
fn decode_utf16_document(
  view : BytesView,
  big_endian : Bool,
) -> String raise XmlError {
  let text = decode_utf16(view, big_endian)
  let declaration = scan_decl(text)
  match declaration.encoding {
    Some(name) =>
      if !name.to_lower().has_prefix("utf-16") {
        raise encoding_error(
          view,
          0,
          "UTF-16 byte order mark with '\{name}' declaration",
        )
      }
    None => ()
  }
  gate_chars(text, declaration.version is Some("1.1"))
  text
}

///|
/// 8 位文档面(UTF-8 BOM 已剥):声明嗅探在 latin-1 预览上做
/// (声明段必为 ASCII;非 ASCII 字节只可能出现在值里,嗅探容之)。
fn decode_8bit_document(
  view : BytesView,
  has_utf8_bom : Bool,
) -> String raise XmlError {
  let declaration = scan_decl(latin1_preview(view))
  let declared : String? = match declaration.encoding {
    Some(name) => Some(name.to_lower())
    None => None
  }
  if declared is Some(name) && name.has_prefix("utf-16") {
    raise encoding_error(view, 0, "UTF-16 declaration without byte order mark")
  }
  if has_utf8_bom && declared is Some("iso-8859-1") {
    raise encoding_error(
      view, 0, "UTF-8 byte order mark with 'iso-8859-1' declaration",
    )
  }
  match declared {
    None | Some("utf-8") | Some("ascii") | Some("us-ascii") => {
      let text = decode_strict_utf8(view)
      gate_chars(text, declaration.version is Some("1.1"))
      text
    }
    Some("iso-8859-1") => {
      let text = decode_latin1(view)
      gate_chars(text, declaration.version is Some("1.1"))
      text
    }
    Some(name) =>
      match jis_encoding_of_label(name) {
        Some(encoding) => {
          let text = decode_jis(encoding, view)
          gate_chars(text, declaration.version is Some("1.1"))
          text
        }
        None => raise encoding_error(view, 0, "unsupported encoding '\{name}'")
      }
  }
}

///|
/// 声明嗅探结果:只取 version / encoding 两属性。
priv struct DeclInfo {
  mut version : String?
  mut encoding : String?
}

///|
/// 声明嗅探:文本头恰为 `<?xml ` 才入场(否则空信息,交底座裁);
/// 属性段尽力解析,畸形即返回已得——本层只做编码/版本决策,
/// 声明合法性(缺 version、坏引号等)是底座词法面职责。
fn scan_decl(head : String) -> DeclInfo {
  let info : DeclInfo = { version: None, encoding: None, }
  let marker = "<?xml"
  if head.char_length() < 5 {
    return info
  }
  for k = 0; k < 5; k = k + 1 {
    if head.get_char(k) != marker.get_char(k) {
      return info
    }
  }
  if !is_decl_space(head.get_char(5)) && head.get_char(5) != Some('?') {
    return info
  }
  scan_decl_attrs(head, 5, info)
}

///|
/// 属性段扫描:名字 [= 引号值] 序列直到 `?>`;游标为字符位。
fn scan_decl_attrs(head : String, start : Int32, info : DeclInfo) -> DeclInfo {
  let limit = head.char_length()
  let mut cursor = start
  while cursor < limit {
    while cursor < limit && is_decl_space(head.get_char(cursor)) {
      cursor = cursor + 1
    }
    if cursor >= limit {
      return info
    }
    if head.get_char(cursor) == Some('?') {
      return info
    }
    let name : Array[Char] = []
    while cursor < limit {
      match head.get_char(cursor) {
        Some('=') | Some('?') => break
        Some(ch) =>
          if is_decl_space(Some(ch)) {
            break
          } else {
            name.push(ch)
            cursor = cursor + 1
          }
        None => return info
      }
    }
    while cursor < limit && is_decl_space(head.get_char(cursor)) {
      cursor = cursor + 1
    }
    if head.get_char(cursor) != Some('=') {
      return info
    }
    cursor = cursor + 1
    while cursor < limit && is_decl_space(head.get_char(cursor)) {
      cursor = cursor + 1
    }
    let quote = head.get_char(cursor)
    if !(quote is Some('\'') || quote is Some('"')) {
      return info
    }
    cursor = cursor + 1
    let value : Array[Char] = []
    while cursor < limit && head.get_char(cursor) != quote {
      match head.get_char(cursor) {
        Some(ch) => {
          value.push(ch)
          cursor = cursor + 1
        }
        None => return info
      }
    }
    if cursor >= limit {
      return info
    }
    cursor = cursor + 1
    let attribute = String::from_array(name[:]).to_lower()
    if attribute == "version" {
      info.version = Some(String::from_array(value[:]))
    } else if attribute == "encoding" {
      info.encoding = Some(String::from_array(value[:]))
    }
  }
  info
}

///|
/// 声明段空白(S 生产 = 空格/制表/CR/LF;NEL 在 1.1 是行尾归空白——
/// 嗅探两版统一容之,1.0 面的声明合法性仍归底座裁判)。
fn is_decl_space(ch : Char?) -> Bool {
  ch is Some(' ') ||
  ch is Some('\t') ||
  ch is Some('\r') ||
  ch is Some('\n') ||
  ch is Some('\u{85}')
}

///|
/// 声明嗅探用 latin-1 预览:前 256 字节逐字节映字符。
fn latin1_preview(view : BytesView) -> String {
  let bound = if view.length() < 256 { view.length() } else { 256 }
  decode_latin1(view[0:bound])
}

///|
/// 严格 UTF-8:坏字节即拒(@utf8.decode raise Malformed,
/// 载荷为坏点起的余段 → 反解 offset)。
fn decode_strict_utf8(view : BytesView) -> String raise XmlError {
  @utf8.decode(view, ignore_bom=true) catch {
    malformed =>
      match malformed {
        @utf8.Malformed(remaining) => {
          let offset = view.length() - remaining.length()
          raise encoding_error(view, offset, "malformed UTF-8 sequence")
        }
      }
  }
}

///|
/// UTF-16 严格解码:双字节成码位,代理高低配对接成增面字符,
/// 落单代理 / 奇长度即拒。奇长度先整检(错误定位到末字节)。
fn decode_utf16(view : BytesView, big_endian : Bool) -> String raise XmlError {
  if view.length() % 2 != 0 {
    raise encoding_error(
      view,
      view.length() - 1,
      "UTF-16 sequence with odd byte length",
    )
  }
  let chars : Array[Char] = []
  for cursor = 0, scan = view {
    match scan {
      [] => break
      [_] | [_, _, _] =>
        raise encoding_error(
          view,
          view.length() - 1,
          "UTF-16 sequence with odd byte length",
        )
      [first, second, .. rest] => {
        let unit = utf16_unit(first, second, big_endian)
        if is_high_surrogate(unit) {
          match rest {
            [third, fourth, .. tail] => {
              let paired = utf16_unit(third, fourth, big_endian)
              if is_low_surrogate(paired) {
                let codepoint = 0x10000 +
                  (unit - 0xD800) * 0x400 +
                  (paired - 0xDC00)
                chars.push(codepoint.unsafe_to_char())
                continue cursor + 4, tail
              }
              raise encoding_error(view, cursor, "unpaired surrogate in UTF-16")
            }
            _ =>
              raise encoding_error(view, cursor, "unpaired surrogate in UTF-16")
          }
        }
        if is_low_surrogate(unit) {
          raise encoding_error(view, cursor, "unpaired surrogate in UTF-16")
        }
        chars.push(unit.unsafe_to_char())
        continue cursor + 2, rest
      }
    }
  }
  String::from_array(chars[:])
}

///|
/// 双字节 → UTF-16 码位(字节序由 BOM 定)。
fn utf16_unit(first : Byte, second : Byte, big_endian : Bool) -> Int32 {
  if big_endian {
    first.to_int() * 256 + second.to_int()
  } else {
    second.to_int() * 256 + first.to_int()
  }
}

///|
fn is_high_surrogate(unit : Int32) -> Bool {
  unit >= 0xD800 && unit <= 0xDBFF
}

///|
fn is_low_surrogate(unit : Int32) -> Bool {
  unit >= 0xDC00 && unit <= 0xDFFF
}

///|
/// ISO-8859-1:字节直映码位(#x80-#x9F 控制位照映,合法性归 Char 门)。
fn decode_latin1(view : BytesView) -> String {
  let chars : Array[Char] = []
  for scan = view {
    match scan {
      [] => break
      [byte, .. rest] => {
        chars.push(byte.to_int().unsafe_to_char())
        continue rest
      }
    }
  }
  String::from_array(chars[:])
}

///|
/// 全文 Char 门:对整个解码后文本逐字符查版本键控表。
/// Char 生产约束文档一切产生式(内容/属性/注释/PI/声明/DTD),
/// 前置整扫是正判据非碰绿——底座不做此面,本层补位。
fn gate_chars(text : String, version_is_1_1 : Bool) -> Unit raise XmlError {
  for (offset, ch) in text.iter2() {
    let codepoint = ch.to_int()
    let illegal = if version_is_1_1 {
      illegal_char_1_1(codepoint)
    } else {
      illegal_char_1_0(codepoint)
    }
    if illegal {
      raise XmlError::At(
        error=XmlErrorKind::IllegalChar(codepoint),
        span=char_span(text, offset),
      )
    }
  }
}

///|
/// XML 1.0 Char 生产(4e 全表):
/// [#x9|#xA|#xD|[#x20-#xD7FF]|[#xE000-#xFFFD]|[#x10000-#x10FFFF]]
/// 之外皆非法(含 #x0、C0 受禁区、代理、#xFFFE/#xFFFF)。
fn illegal_char_1_0(codepoint : Int32) -> Bool {
  if codepoint == 0x9 || codepoint == 0xA || codepoint == 0xD {
    return false
  }
  if codepoint >= 0x20 && codepoint <= 0xD7FF {
    return false
  }
  if codepoint >= 0xE000 && codepoint <= 0xFFFD {
    return false
  }
  if codepoint >= 0x10000 && codepoint <= 0x10FFFF {
    return false
  }
  true
}

///|
/// XML 1.1 字面受限区:[#x1-#x8]|[#xB-#xC]|[#xE-#x1F]|[#x7F-#x84]|[#x86-#x9F]
/// 须走字符引用,字面出现即拒;#x85(NEL)字面合法(1.1 行尾)。
/// 区外沿用 1.0 全表(1.1 合法集 ⊇ 1.0 合法集)。
fn illegal_char_1_1(codepoint : Int32) -> Bool {
  if codepoint == 0x85 {
    return false
  }
  if codepoint >= 0x1 && codepoint <= 0x8 {
    return true
  }
  if codepoint >= 0xB && codepoint <= 0xC {
    return true
  }
  if codepoint >= 0xE && codepoint <= 0x1F {
    return true
  }
  if codepoint >= 0x7F && codepoint <= 0x84 {
    return true
  }
  if codepoint >= 0x86 && codepoint <= 0x9F {
    return true
  }
  illegal_char_1_0(codepoint)
}

///|
/// 编码面错误(byte 域):message + offset(0 起),行列按 0x0A 计尽力。
fn encoding_error(
  view : BytesView,
  offset : Int32,
  message : String,
) -> XmlError {
  XmlError::At(
    error=XmlErrorKind::Encoding(message),
    span=byte_span(view, offset),
  )
}

///|
/// byte 面位置:0x0A 不出现在 UTF-8/UTF-16 多字节序内部,
/// 直接数字节得 line;column = 距上一 0x0A 的字节数。
fn byte_span(view : BytesView, offset : Int32) -> SourceSpan {
  let mut line = 1
  let mut last_newline = -1
  for index = 0, scan = view {
    match scan {
      [] => break
      [byte, .. rest] => {
        if index >= offset {
          break
        }
        if byte.to_int() == 0x0A {
          line = line + 1
          last_newline = index
        }
        continue index + 1, rest
      }
    }
  }
  let column = if last_newline < 0 { offset + 1 } else { offset - last_newline }
  {
    start: { offset, line, column, },
    end: { offset: offset + 1, line, column: column + 1, },
  }
}

///|
/// text 面位置(Char 门用):按字符计行列,offset 为字节位(iter2 给)。
fn char_span(text : String, offset : Int32) -> SourceSpan {
  let mut line = 1
  let mut column = 1
  for (seen, ch) in text.iter2() {
    if seen >= offset {
      break
    }
    if ch == '\n' {
      line = line + 1
      column = 1
    } else {
      column = column + 1
    }
  }
  {
    start: { offset, line, column, },
    end: { offset: offset + 1, line, column: column + 1, },
  }
}
