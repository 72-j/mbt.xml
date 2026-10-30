///|
/// 外取件准入面：外取实体/外取子集按"外部件"解码——BOM 容错与 text decl
/// 编码识别复用 [decode_source] 前端；准入三闸：
/// ① text decl 语法闸（仅文首；缺 encoding / 序位倒置 / standalone 越权 /
/// 版本词形 / 分隔符越界皆拒）；
/// ② 版次闸（件声明版次晚于文档版次即拒，XML 1.1 §4.3.4）；
/// ③ Char 门（外取件按文档规则处理：版本键控字面扫描，字符引用是 ASCII
/// 文本，天然放行）。
/// text decl 不属于实体内容：残留会被底座按 PI 读，而 PI 目标 "xml" 保留，
/// valid 族会被错拒。取件两步 = decode_source（编码面）+ admit（校验面）。

///|
/// 准入:解码后文本 → text decl 验证剥除 + Char 门 → 实体内容。
/// 无 text decl = 原样过闸(decl 可选,P79)。
fn admit_external_text(
  text : String,
  doc_version : String?,
) -> String raise XmlError {
  let body = validate_strip_text_decl(text, doc_version)
  gate_chars(body, doc_version == Some("1.1"))
  body
}

///|
/// text decl 语法闸(仅文首;P77:<?xml VersionInfo? EncodingDecl S? ?>,
/// 与 XMLDecl 三不同——version 可省/encoding 必备/standalone 越权即拒)。
/// 非 text decl 的 <?xml 形(如 PI 目标 xmlfoo)不归本闸,留给底座 PI 面。
/// 返回剥除后的件体；违例一律 External 域拒（件破即拒，延伸到外取来源）。
fn validate_strip_text_decl(
  text : String,
  doc_version : String?,
) -> String raise XmlError {
  if !text.has_prefix("<?xml") {
    return text
  }
  let limit = text.length()
  // 触发判定:第五字须 S 或 "?>"(后者 = 空声明,缺 encoding 即拒)
  let decl_shaped = limit > 5 &&
    (is_decl_space4(text[5]) || (text[5] == '?' && limit > 6 && text[6] == '>'))
  if !decl_shaped {
    return text
  }
  // 分隔符版次键控:NEL/U+2028 只在 1.1 文档面合法(S 1.1 增两字符;
  // n17/n18:1.0 文档件用 NEL/U+2028 作分隔即拒)
  let allow_1_1_s = doc_version == Some("1.1")
  let mut pos : Int32 = 5
  let mut seen_version : String? = None
  let mut seen_encoding = false
  let mut close : Int32 = -1
  while pos < limit {
    pos = skip_decl_space(text, pos, allow_1_1_s)
    if pos < limit &&
      text[pos] == '?' &&
      pos + 1 < limit &&
      text[pos + 1] == '>' {
      close = pos
      break
    }
    // pseudo-attr 名
    let name_start = pos
    while pos < limit && text[pos] != '=' && !is_decl_space4(text[pos]) {
      pos = pos + 1
    }
    let name = text[name_start:pos].to_owned()
    if name.length() == 0 {
      raise text_decl_error(text, pos, "malformed text declaration")
    }
    // Eq(S* = S*)
    let mut cursor = skip_decl_space(text, pos, allow_1_1_s)
    if cursor >= limit || text[cursor] != '=' {
      raise text_decl_error(text, cursor, "expected '=' in text declaration")
    }
    cursor = skip_decl_space(text, cursor + 1, allow_1_1_s)
    match read_doctype_quoted(text, cursor) {
      Some((value, next)) => {
        if name == "version" {
          if seen_encoding {
            raise text_decl_error(
              text, name_start, "version after encoding in text declaration",
            )
          }
          if seen_version is Some(_) {
            raise text_decl_error(
              text, name_start, "duplicate version in text declaration",
            )
          }
          if value != "1.0" && value != "1.1" {
            raise text_decl_error(
              text,
              name_start,
              "implausible version number '\{value}' in text declaration",
            )
          }
          // 版次闸:件版次晚于文档版次即拒(1.1 件在 1.0 文档 = 违例;
          // 1.0 件在 1.1 文档合法——only-later 规则,eduni/xml-1.1 五案)
          if value == "1.1" && doc_version != Some("1.1") {
            raise text_decl_error(
              text, name_start, "entity version 1.1 later than document version",
            )
          }
          seen_version = Some(value)
        } else if name == "encoding" {
          // EncName(P81):[A-Za-z] 起,续 [A-Za-z0-9._-]
          let value_units = value.length()
          let mut index = 0
          let mut enc_ok = value_units > 0
          while index < value_units {
            let code = value[index].to_int()
            let lead = index == 0
            let ok = if lead {
              (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)
            } else {
              (code >= 0x41 && code <= 0x5A) ||
              (code >= 0x61 && code <= 0x7A) ||
              (code >= 0x30 && code <= 0x39) ||
              code == 0x2E ||
              code == 0x2D ||
              code == 0x5F
            }
            if !ok {
              enc_ok = false
              break
            }
            index = index + 1
          }
          if !enc_ok {
            raise text_decl_error(text, name_start, "malformed encoding name")
          }
          seen_encoding = true
        } else {
          raise text_decl_error(
            text,
            name_start,
            "'\{name}' not allowed in text declaration",
          )
        }
        pos = next
      }
      None =>
        raise text_decl_error(
          text, cursor, "unterminated pseudo-attribute value",
        )
    }
  }
  if close < 0 {
    raise text_decl_error(text, limit - 1, "unterminated text declaration")
  }
  if !seen_encoding {
    raise text_decl_error(
      text, 5, "encoding declaration missing in text declaration",
    )
  }
  text[close + 2:].to_owned()
}

///|
/// decl 面 S 跳扫(版本键控):基础四符处处合法;NEL(#x85)/U+2028 仅
/// 1.1 文档面追加(S 1.1 生产)。其余字符非分隔,即停。
fn skip_decl_space(text : String, start : Int32, allow_1_1 : Bool) -> Int32 {
  let limit = text.length()
  let mut pos = start
  while pos < limit {
    let ch = text[pos]
    if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
      pos = pos + 1
      continue
    }
    if allow_1_1 && (ch == '\u{85}' || ch == '\u{2028}') {
      pos = pos + 1
      continue
    }
    break
  }
  pos
}

///|
fn is_decl_space4(ch : UInt16) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
/// text decl 违例(件坐标;外取件面 span,错误词 External 语义独立)。
fn text_decl_error(text : String, offset : Int32, message : String) -> XmlError {
  XmlError::At(
    error=XmlErrorKind::External(message),
    span=char_span(text, offset),
  )
}
