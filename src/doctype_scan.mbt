///|
/// DOCTYPE 序区扫描(役B2):底座 DocType 事件只带根名(F1),SYSTEM/
/// PUBLIC id 与内部子集界由本扫描自持提取。返回 None = 无 doctype 或
/// 序区畸形(后者留给底座报错——本扫描只取件,不做判官)。
priv struct DoctypeScan {
  /// 声明收口 '>' 之后(预组合恢复内容扫描处)
  decl_end : Int32
  system_id : String?
  public_id : String?
  /// 文档 XMLDecl 版次值(役B3 版次闸基准;无 XMLDecl = None = 1.0)。
  /// 只取值不判官——XMLDecl 语法面归底座。
  doc_version : String?
  /// 内部子集起点('[' 之后);无子集 = -1
  subset_start : Int32
  /// 内部子集终点(']' 处);无子集 = -1
  subset_end : Int32
}

///|
/// 序区扫描:越过空白 / PI / 注释找 <!DOCTYPE;遇到根元素起始(其余
/// '<')即止。quote 态与注释态感知的子集括号配对——子集内引号值与
/// 注释中的 ']' 不误判为子集终点。
fn scan_doctype(text : String) -> DoctypeScan? {
  let limit = text.length()
  let doc_version = peek_decl_version(text)
  let mut pos = skip_doctype_space(text, 0)
  while pos < limit {
    let ch = text[pos]
    if ch == '<' {
      if text[pos + 1] == '?' {
        pos = skip_past(text, pos + 2, '?', '>')
        continue
      }
      if text[pos + 1] == '!' && text[pos + 2] == '-' && text[pos + 3] == '-' {
        pos = skip_comment(text, pos + 4)
        continue
      }
      if text[pos + 1] == '!' &&
        text[pos + 2] == 'D' &&
        text[pos + 3] == 'O' &&
        text[pos + 4] == 'C' &&
        text[pos + 5] == 'T' &&
        text[pos + 6] == 'Y' &&
        text[pos + 7] == 'P' &&
        text[pos + 8] == 'E' {
        return scan_doctype_body(text, pos + 9, doc_version)
      }
      // 根元素起始:序区尽,无 doctype
      return None
    }
    if is_doctype_space(ch) {
      pos = pos + 1
      continue
    }
    return None
  }
  None
}

///|
/// <!DOCTYPE 体解析:根名 → ExternalID(SYSTEM/PUBLIC)→ 可选内部子集
/// → 收口 '>'。畸形(缺名/缺引号/未闭合)一律 None——判官权在底座。
fn scan_doctype_body(
  text : String,
  start : Int32,
  doc_version : String?,
) -> DoctypeScan? {
  let limit = text.length()
  let mut pos = skip_doctype_space(text, start)
  let name_start = pos
  while pos < limit && !is_doctype_stop(text[pos]) {
    pos = pos + 1
  }
  if pos == name_start {
    return None // 缺根名
  }
  pos = skip_doctype_space(text, pos)
  let mut system_id : String? = None
  let mut public_id : String? = None
  if has_word(text, pos, "SYSTEM") {
    match read_doctype_quoted(text, pos + 6) {
      Some((value, next)) => {
        system_id = Some(value)
        pos = next
      }
      None => return None
    }
  } else if has_word(text, pos, "PUBLIC") {
    match read_doctype_quoted(text, pos + 6) {
      Some((pubid, next)) =>
        match read_doctype_quoted(text, skip_doctype_space(text, next)) {
          Some((sysid, next2)) => {
            public_id = Some(pubid)
            system_id = Some(sysid)
            pos = next2
          }
          None => return None
        }
      None => return None
    }
  }
  pos = skip_doctype_space(text, pos)
  if pos < limit && text[pos] == '[' {
    let subset_start = pos + 1
    match scan_subset_end(text, subset_start) {
      Some(subset_end) => {
        pos = skip_doctype_space(text, subset_end + 1)
        if pos < limit && text[pos] == '>' {
          Some({
            decl_end: pos + 1,
            system_id,
            public_id,
            doc_version,
            subset_start,
            subset_end,
          })
        } else {
          None // 子集后无收口 '>'
        }
      }
      None => None
    }
  } else if pos < limit && text[pos] == '>' {
    Some({
      decl_end: 0,
      system_id,
      public_id,
      doc_version,
      subset_start: -1,
      subset_end: -1,
    })
  } else {
    None // 声明未收口
  }
}

///|
/// 子集括号配对:quote 态(单双引号字面量)与注释态感知;'|"' 值内
/// 与注释内的 ']' 不收口。返回 ']' 处位;未闭合 = None。
fn scan_subset_end(text : String, start : Int32) -> Int32? {
  let limit = text.length()
  let mut pos = start
  let mut quote : UInt16? = None
  let mut in_comment = false
  let mut in_pi = false
  while pos < limit {
    let ch = text[pos]
    if in_comment {
      if ch == '-' && text[pos + 1] == '-' && text[pos + 2] == '>' {
        pos = pos + 3
        in_comment = false
        continue
      }
      pos = pos + 1
      continue
    }
    if in_pi {
      if ch == '?' && text[pos + 1] == '>' {
        pos = pos + 2
        in_pi = false
        continue
      }
      pos = pos + 1
      continue
    }
    match quote {
      Some(open) => {
        if ch == open {
          quote = None
        }
        pos = pos + 1
        continue
      }
      None => ()
    }
    if ch == '<' &&
      text[pos + 1] == '!' &&
      text[pos + 2] == '-' &&
      text[pos + 3] == '-' {
      in_comment = true
      pos = pos + 4
      continue
    }
    if ch == '<' && text[pos + 1] == '?' {
      in_pi = true
      pos = pos + 2
      continue
    }
    if ch == '\'' || ch == '"' {
      quote = Some(ch)
      pos = pos + 1
      continue
    }
    if ch == ']' {
      return Some(pos)
    }
    pos = pos + 1
  }
  None
}

///|
/// 引号字面量读取(quote 为开引号处);未闭合 = None。
fn read_doctype_quoted(text : String, start : Int32) -> (String, Int32)? {
  let limit = text.length()
  let mut pos = skip_doctype_space(text, start)
  if pos >= limit {
    return None
  }
  let open = text[pos]
  if !(open == '\'' || open == '"') {
    return None
  }
  pos = pos + 1
  let value_start = pos
  while pos < limit && !(text[pos] == open) {
    pos = pos + 1
  }
  if pos >= limit {
    return None
  }
  Some((text[value_start:pos].to_owned(), pos + 1))
}

///|
/// 词前缀核对(区分边界:后续不得为名字续字——"SYSTEMX" 不咬 SYSTEM)。
fn has_word(text : String, pos : Int32, word : String) -> Bool {
  let word_length = word.length()
  if pos + word_length > text.length() {
    return false
  }
  if text[pos:pos + word_length].to_owned() != word {
    return false
  }
  // 边界:词后必须是空白或结构符(引号/'['/'>'/'='/文末;Eq 紧随
  // version 词——`version='1.1'` 形)
  let after = pos + word_length
  after >= text.length() ||
  is_doctype_stop(text[after]) ||
  is_doctype_space(text[after]) ||
  text[after] == '='
}

///|
/// 名字停字:空白与结构符('[' '>' 引号)终止根名扫描。
fn is_doctype_stop(ch : UInt16) -> Bool {
  is_doctype_space(ch) || ch == '[' || ch == '>' || ch == '\'' || ch == '"'
}

///|
fn is_doctype_space(ch : UInt16) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn skip_doctype_space(text : String, start : Int32) -> Int32 {
  let mut pos = start
  while pos < text.length() && is_doctype_space(text[pos]) {
    pos = pos + 1
  }
  pos
}

///|
/// 越过直到 close1+close2 二字组(如 "?>"/"-->" 前二字);未闭合 =
/// 文末。序区容错扫描——畸形留给底座判。
fn skip_past(
  text : String,
  start : Int32,
  close1 : UInt16,
  close2 : UInt16,
) -> Int32 {
  let limit = text.length()
  let mut pos = start
  while pos < limit {
    if text[pos] == close1 && text[pos + 1] == close2 {
      return pos + 2
    }
    pos = pos + 1
  }
  limit
}

///|
/// 注释跳扫(三字组 `-->` 收口;skip_past 二字组吃不住注释——`--`
/// 后还余 `>`,下轮咬 `>` 报 unexpected content)。未闭合 = 文末
/// (容错扫描,判官在底座)。
fn skip_comment(text : String, start : Int32) -> Int32 {
  let limit = text.length()
  let mut pos = start
  while pos + 2 < limit {
    if text[pos] == '-' && text[pos + 1] == '-' && text[pos + 2] == '>' {
      return pos + 3
    }
    pos = pos + 1
  }
  limit
}

///|
/// XMLDecl 版次值只读取(役B3):`<?xml` + S 起头时,取 version 属性
/// 引号值;无 XMLDecl/畸形 = None(判官在底座,此处只为版次闸供基准)。
fn peek_decl_version(text : String) -> String? {
  if !text.has_prefix("<?xml") {
    return None
  }
  let limit = text.length()
  if !(limit > 5 && is_doctype_space(text[5])) {
    return None
  }
  let mut cursor : Int32 = 5
  let mut close : Int32 = -1
  while cursor + 1 < limit {
    if text[cursor] == '?' && text[cursor + 1] == '>' {
      close = cursor
      break
    }
    cursor = cursor + 1
  }
  if close < 0 {
    return None
  }
  let head = text[5:close].to_owned()
  let pos = skip_doctype_space(head, 0)
  if !has_word(head, pos, "version") {
    return None
  }
  // Eq(S? = S?):词后先越空白与 '=',再读引号值(read_doctype_quoted
  // 自带前导空白跳)
  let cursor = skip_doctype_space(head, pos + 7)
  if cursor >= head.length() || head[cursor] != '=' {
    return None
  }
  match read_doctype_quoted(head, cursor + 1) {
    Some((value, _)) => Some(value)
    None => None
  }
}
