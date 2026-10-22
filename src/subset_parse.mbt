///|
/// 子集声明解析(役B2,R-B1d):外取子集/内部子集的 WF 级声明收编——
/// ENTITY 表装载(外取实体取件走 resolver),ATTLIST/ELEMENT/NOTATION
/// 语法过闸(quote 态感知跳过)。拒因落声明面 = not-wf 族(dtd07 等)
/// 的正判 locus。PE 声明接受不展开、PE 引用机械跳过(PE 展开面 = C 族,
/// 不越界);条件段 INCLUDE 解析 / IGNORE 跳过(C∩B 10 案仍留 deferred)。
const EXTERNAL_EXPANSION_DEPTH : Int32 = 32

///|
const EXTERNAL_EXPANSION_BUDGET : Int32 = 1000000

///|
/// 声明所在子集面:ExternalSubset = 字面量 ENTITY 也归我表(base 看不到
/// 外取子集);InternalSubset = 字面量实体底座自持(内部优先,R-B1b),
/// 只收编外取形(文件取件 base 不管)。
priv enum DeclPolicy {
  ExternalSubset
  InternalSubset
}

///|
/// 实体类别(属性值位 WFC 规则的分型依据):字面量声明(外取子集内)
/// = 内部实体,属性值引用合法;外取件 = 外部实体,属性值引用是 WFC
/// 违例——不展开,交底座拒(§3.1 no external entity refs in attr)。
priv enum ExternalEntityEntry {
  InternalText(String)
  ExternalPiece(String)
}

///|
/// 外取装载上下文:resolver 端口 + 实体表(名 → 解码后原文,展开在
/// 插入时递归做)+ 展开预算计数(billion-laughs 闸)。
priv struct ExternalLoad {
  resolver : &EntityResolver
  table : Map[String, ExternalEntityEntry]
  /// 内部子集字面量实体账(名 → 字面量值,spec 4.4.8 内部优先:外部
  /// 子集同名声明让位)。值在手 = 链所有权闭合的种子——字面量链若
  /// (传递地)引用到本层收编的外取件,须整体收归本层展开(底座
  /// 只见内部字面量,链半路撞外取名即 InvEnt)。
  internal_literals : Map[String, String]
  /// 文档版次基准(役B3 版次闸 + Char 门键控;无 XMLDecl = None = 1.0)。
  doc_version : String?
  mut consumed : Int32
}

///|
fn external_error(
  subset_text : String,
  offset : Int32,
  message : String,
) -> XmlError {
  XmlError::At(
    error=XmlErrorKind::External(message),
    span=char_span(subset_text, offset),
  )
}

///|
/// 外取子集装载(解码后文本;base = 该子集自身 system_id,子集内实体
/// 相对径以它为引用方)。
fn load_external_subset(
  subset_text : String,
  base_uri : String?,
  load : ExternalLoad,
) -> Unit raise XmlError {
  parse_declarations(subset_text, base_uri, load, ExternalSubset)
}

///|
/// 内部子集收编:外取形 ENTITY 取件归我;字面量实体入账不动原位
/// (内部优先,底座自持;值记账供链所有权闭合——见 ExternalLoad)。
fn collect_internal_external_entities(
  subset_text : String,
  load : ExternalLoad,
) -> Unit raise XmlError {
  parse_declarations(subset_text, None, load, InternalSubset)
}

///|
fn parse_declarations(
  text : String,
  base_uri : String?,
  load : ExternalLoad,
  policy : DeclPolicy,
) -> Unit raise XmlError {
  let limit = text.length()
  let mut pos = 0
  while pos < limit {
    pos = skip_doctype_space(text, pos)
    if pos >= limit {
      break
    }
    let ch = text[pos]
    if ch == '%' {
      pos = skip_pe_reference(text, pos)
      continue
    }
    if ch == '<' && text[pos + 1] == '?' {
      // PI 目标 "xml" 保留(2.8,大小写不计):text decl 只许在件首,
      // 中部出现即错置(P79 序位,ibm30n01)
      if has_xml_target(text, pos + 2) {
        raise external_error(
          text, pos, "text declaration not allowed in external subset body",
        )
      }
      pos = skip_past(text, pos + 2, '?', '>')
      continue
    }
    if ch == '<' &&
      text[pos + 1] == '!' &&
      text[pos + 2] == '-' &&
      text[pos + 3] == '-' {
      pos = skip_comment(text, pos + 4)
      continue
    }
    if ch == '<' && text[pos + 1] == '!' && text[pos + 2] == '[' {
      pos = parse_conditional(text, pos, base_uri, load, policy)
      continue
    }
    if ch == '<' && text[pos + 1] == '!' && has_word(text, pos + 2, "ENTITY") {
      pos = parse_entity_declaration(text, pos, base_uri, load, policy)
      continue
    }
    if ch == '<' && text[pos + 1] == '!' {
      pos = skip_markup_declaration(text, pos)
      continue
    }
    raise external_error(
      text,
      pos,
      "unexpected content in DTD subset at offset \{pos}",
    )
  }
}

///|
/// ENTITY 声明:名 → 字面量值 / 外取 id(SYSTEM|PUBLIC [+ NDATA])。
/// 字面量:ExternalSubset 归我表;InternalSubset 底座自持(跳过);
/// PE 声明两态皆不展开(接受不收编)。外取形:取件 None = 不声明
/// (引用处底座 InvalidEntity 自然拒 = fetch-fail reject);取件有
/// 但解码败 = External 错(件破即拒,R-B1d)。
fn parse_entity_declaration(
  text : String,
  start : Int32,
  base_uri : String?,
  load : ExternalLoad,
  policy : DeclPolicy,
) -> Int32 raise XmlError {
  let limit = text.length()
  let mut pos = skip_doctype_space(text, start + 8)
  let mut is_pe = false
  if pos < limit && text[pos] == '%' {
    is_pe = true
    pos = skip_doctype_space(text, pos + 1)
  }
  let name_start = pos
  while pos < limit &&
        !(text[pos] == ' ' ||
        text[pos] == '\t' ||
        text[pos] == '\r' ||
        text[pos] == '\n' ||
        text[pos] == '>') {
    pos = pos + 1
  }
  let entity_name = text[name_start:pos].to_owned()
  if entity_name.length() == 0 {
    raise external_error(text, start, "ENTITY declaration without a name")
  }
  pos = skip_doctype_space(text, pos)
  if pos < limit && (text[pos] == '\'' || text[pos] == '"') {
    match read_doctype_quoted(text, pos) {
      Some((value, next)) => {
        if !is_pe {
          match policy {
            ExternalSubset =>
              // 内部优先:内部子集已声明同名 → 让位(不装表,引用处底座
              // 或本层链闭合展开内部形)
              if load.internal_literals.contains(entity_name) {
                ()
              } else {
                load.table.set(entity_name, InternalText(value))
              }
            InternalSubset => load.internal_literals.set(entity_name, value)
          }
        }
        pos = next
      }
      None =>
        raise external_error(
          text,
          pos,
          "unterminated entity value for '\{entity_name}'",
        )
    }
  } else if has_word(text, pos, "SYSTEM") || has_word(text, pos, "PUBLIC") {
    let mut public_id : String? = None
    let mut skip_system_word = 6
    if has_word(text, pos, "PUBLIC") {
      match read_doctype_quoted(text, pos + 6) {
        Some((pubid, next)) => {
          public_id = Some(pubid)
          pos = skip_doctype_space(text, next)
          // PUBLIC 形第二引号串直随 pubid 之后,无 SYSTEM 词可跳
          skip_system_word = 0
        }
        None =>
          raise external_error(
            text,
            pos,
            "PUBLIC id missing for '\{entity_name}'",
          )
      }
    }
    match read_doctype_quoted(text, pos + skip_system_word) {
      Some((sysid, next)) => {
        pos = next
        // NDATA 尾巴(不可解析实体):不装表——内容引用拒 = 正判,
        // 属性 ENTITY 型引用面随属性缺省役再议。
        pos = skip_doctype_space(text, pos)
        if has_word(text, pos, "NDATA") {
          pos = skip_markup_declaration(text, pos)
          return pos
        }
        if !is_pe {
          match load.resolver.resolve(base_uri, sysid, public_id) {
            Some(bytes) => {
              let content = match decode_source(bytes) {
                Ok(raw) => admit_external_text(raw, load.doc_version)
                Err(_) =>
                  raise XmlError::At(
                    error=XmlErrorKind::External(
                      "external entity '\{entity_name}' decode failed",
                    ),
                    span=char_span(text, start),
                  )
              }
              if load.internal_literals.contains(entity_name) {
                ()
              } else {
                load.table.set(entity_name, ExternalPiece(content))
              }
            }
            None => ()
          }
        }
      }
      None =>
        raise external_error(
          text,
          pos,
          "system id missing for '\{entity_name}'",
        )
    }
  } else {
    raise external_error(
      text,
      pos,
      "ENTITY '\{entity_name}' has neither value nor external id",
    )
  }
  pos = skip_doctype_space(text, pos)
  if pos < limit && text[pos] == '>' {
    return pos + 1
  }
  raise external_error(
    text,
    pos,
    "unterminated ENTITY declaration for '\{entity_name}'",
  )
}

///|
/// 条件段:<![INCLUDE[ ... ]]> 解析体 / <![IGNORE[ ... ]]> 跳过体;
/// 关键词不备 = External 错。体以嵌套感知的 "]]>" 收口。
fn parse_conditional(
  text : String,
  start : Int32,
  base_uri : String?,
  load : ExternalLoad,
  policy : DeclPolicy,
) -> Int32 raise XmlError {
  let keyword_start = start + 3
  let mut pos = keyword_start
  let limit = text.length()
  while pos < limit && text[pos] != '[' {
    pos = pos + 1
  }
  if pos >= limit {
    raise external_error(text, start, "unterminated conditional section")
  }
  let keyword = text[keyword_start:pos].to_owned().trim().to_owned()
  let body_start = pos + 1
  match scan_conditional_close(text, body_start) {
    Some(close) => {
      if keyword == "INCLUDE" {
        parse_declarations(
          text[body_start:close].to_owned(),
          base_uri,
          load,
          policy,
        )
      } else if keyword != "IGNORE" {
        raise external_error(
          text, keyword_start, "conditional keyword must be INCLUDE or IGNORE",
        )
      }
      close + 3
    }
    None =>
      raise external_error(text, start, "unterminated conditional section body")
  }
}

///|
/// 嵌套感知的 "]]>" 扫描(quote/注释态感知;<![[]] 嵌套计数)。
fn scan_conditional_close(text : String, start : Int32) -> Int32? {
  let limit = text.length()
  let mut pos = start
  let mut depth = 1
  let mut quote : UInt16? = None
  let mut in_comment = false
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
    if ch == '<' && text[pos + 1] == '!' && text[pos + 2] == '[' {
      depth = depth + 1
      pos = pos + 3
      continue
    }
    if ch == ']' && text[pos + 1] == ']' && text[pos + 2] == '>' {
      depth = depth - 1
      if depth == 0 {
        return Some(pos)
      }
      pos = pos + 3
      continue
    }
    if ch == '\'' || ch == '"' {
      quote = Some(ch)
    }
    pos = pos + 1
  }
  None
}

///|
/// ATTLIST/ELEMENT/NOTATION 过闸跳过:quote 态感知找到收口 '>';
/// 未闭合 = External 错(声明面拒因)。
fn skip_markup_declaration(
  text : String,
  start : Int32,
) -> Int32 raise XmlError {
  let limit = text.length()
  let mut pos = start
  let mut quote : UInt16? = None
  while pos < limit {
    let ch = text[pos]
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
    if ch == '\'' || ch == '"' {
      quote = Some(ch)
      pos = pos + 1
      continue
    }
    if ch == '>' {
      return pos + 1
    }
    pos = pos + 1
  }
  raise external_error(text, start, "unterminated markup declaration")
}

///|
/// 声明间 PE 引用机械跳过(%name;);未闭合 = External 错。
fn skip_pe_reference(text : String, start : Int32) -> Int32 raise XmlError {
  let limit = text.length()
  let mut pos = start + 1
  while pos < limit &&
        !(text[pos] == ';' || text[pos] == '>' || text[pos] == '<') {
    pos = pos + 1
  }
  if pos < limit && text[pos] == ';' {
    return pos + 1
  }
  raise external_error(text, start, "unterminated parameter entity reference")
}

///|
/// PI 目标保留字探测(2.8):`xml` 三字母大小写不计,后随 S 或 `?>`
/// 才咬(PI 目标 xmlfoo 之类合法,留给底座)。
fn has_xml_target(text : String, start : Int32) -> Bool {
  let limit = text.length()
  if start + 3 > limit {
    return false
  }
  let word = [(0x78, 0x58), (0x6D, 0x4D), (0x6C, 0x4C)]
  for index, pair in word {
    let code = text[start + index].to_int()
    let (lower, upper) = pair
    if code != lower && code != upper {
      return false
    }
  }
  let after = start + 3
  if after >= limit {
    return false
  }
  let ch = text[after]
  ch == ' ' ||
  ch == '\t' ||
  ch == '\r' ||
  ch == '\n' ||
  (ch == '?' && after + 1 < limit && text[after + 1] == '>')
}
