///|
/// 子集声明解析(役B2,R-B1d):外取子集/内部子集的 WF 级声明收编——
/// ENTITY 表装载(外取实体取件走 resolver),ATTLIST/ELEMENT/NOTATION
/// 语法过闸(quote 态感知跳过)。拒因落声明面 = not-wf 族(dtd07 等)
/// 的正判 locus。条件段 INCLUDE 解析 / IGNORE 跳过。
/// 役PE位形(2026-10-22)升级:PE 声明立账(字面量值 pe_values / 外取件
/// pe_externals);声明间 PE 引用按账处理(外取件取件按声明解析,字面量
/// 值形备则按 DTD 片再扫);条件段关键词位 PE 展开(`<![ %e; [`);声明
/// 内部 PE 收口位形(值含顶层 '>' 补全声明)。仍不展开:PE 值往内容区
/// 的直接注入(内部子集展开面,pe02/E13 族,候独立役)。
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
/// 外取 PE 件址(役PE位形):引用位取件用。相对 system_id 按**声明位**
/// base 解(spec 4.2 相对径归属声明所在件,非引用位——%intpe 从别件
/// 引用时 %extpe 仍按其声明件解)。
priv struct PeExternalId {
  base : String?
  system_id : String
  public_id : String?
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
  /// PE 声明账(役PE位形):字面量 PE 值(名 → 值原文)与外取 PE 件址
  /// (名 → 件 id)。条件段关键词位 / 声明内部收口 / 声明间引用三处
  /// 位形的展开源。PE 账与一般实体表分账——PE 是 DTD 机械面,不进
  /// 内容展开(内部优先律只辖一般实体)。
  pe_values : Map[String, String]
  pe_externals : Map[String, PeExternalId]
  /// PE 引用递归深度闸(%x "%x;" 形自指防御)。
  mut pe_depth : Int32
  /// 文档版次基准(役B3 版次闸 + Char 门键控;无 XMLDecl = None = 1.0)。
  doc_version : String?
  /// standalone=='yes'(闸 S,闸补役):正文/属性位展开本表实体即拒
  /// (WFC 2.9 Entity Declared——外取件声明实体被引用,standalone 越权)。
  standalone_yes : Bool
  /// 版本面(闸 G 名字校验键控):外取子集声明名字按文档面选表。
  edition : XmlEdition
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
      pos = reference_pe(text, pos, base_uri, load, policy)
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
    if ch == '<' &&
      text[pos + 1] == '!' &&
      (
        has_word(text, pos + 2, "ELEMENT") ||
        has_word(text, pos + 2, "ATTLIST") ||
        has_word(text, pos + 2, "NOTATION")
      ) {
      // 闸 G(闸补役):声明名合法性(ELEMENT/ATTLIST/NOTATION 产生式
      // 面名核;外取子集不进底座,语法判官在本层)
      pos = gate_declaration_name(text, pos, load)
      continue
    }
    if ch == '<' && text[pos + 1] == '!' {
      pos = skip_markup_declaration(text, pos, load)
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
/// 实体值引用语法闸(闸补役,P09/P67/P69 产生式面):值内 '%' 须起
/// PEReference 形('%' 名 ';'),'&' 须起 Reference 形('&' 名 ';' 或字
/// 符引用)。只核形不核表(声明面 = VC,不归良构层);非 ASCII 码元
/// 概认名字符(超收侧保守——拒闸宁漏勿误,异体名归名字表闸)。
fn entity_value_refs_wellformed(value : String) -> Bool {
  let limit = value.length()
  fn is_name_start_unit(unit : UInt16) -> Bool {
    (unit >= 0x41 && unit <= 0x5A) ||
    (unit >= 0x61 && unit <= 0x7A) ||
    unit == 0x5F ||
    unit == 0x3A ||
    unit >= 0x80
  }

  fn is_name_char_unit(unit : UInt16) -> Bool {
    is_name_start_unit(unit) ||
    (unit >= 0x30 && unit <= 0x39) ||
    unit == 0x2D ||
    unit == 0x2E ||
    unit == 0xB7
  }

  fn is_hex_digit_unit(unit : UInt16) -> Bool {
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x46) ||
    (unit >= 0x61 && unit <= 0x66)
  }

  fn reference_wellformed(value : String, intro : Int32) -> Bool {
    let limit = value.length()
    let mut i : Int32 = intro + 1
    if i >= limit {
      return false
    }
    if value[i] == '#' {
      // 字符引用:&#x hex+ ';' 或 &# dec+ ';'
      i = i + 1
      if i < limit && (value[i] == 0x78 || value[i] == 0x58) {
        i = i + 1
      }
      let digits_start = i
      while i < limit && is_hex_digit_unit(value[i]) {
        i = i + 1
      }
      return i > digits_start && i < limit && value[i] == 0x3B
    }
    if is_name_start_unit(value[i]) == false {
      return false
    }
    i = i + 1
    while i < limit && is_name_char_unit(value[i]) {
      i = i + 1
    }
    return i < limit && value[i] == 0x3B
  }

  let mut i : Int32 = 0
  while i < limit {
    let ch = value[i]
    if ch == 0x25 || ch == 0x26 {
      if reference_wellformed(value, i) == false {
        return false
      }
      // 引用整体跳过(';' 在 reference_wellformed 已证存在)
      let mut j : Int32 = i + 1
      while j < limit && value[j] != 0x3B {
        j = j + 1
      }
      i = j + 1
      continue
    }
    i = i + 1
  }
  true
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
        // 闸 P(闸补役):值内引用形不备即拒(P09 产生式;p09fail/008 族)
        if entity_value_refs_wellformed(value) == false {
          raise external_error(
            text,
            pos,
            "malformed reference in entity value for '\{entity_name}'",
          )
        }
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
          // PE 声明立账(役PE位形):值入 pe_values,供条件段关键词位 /
          // 声明内部收口 / 声明间引用三处位形展开。次序律 = 4.4.8 同律:
          // 内部子集 PE 值优先,外取子集同名声明让位(内部子集内后者覆
          // 前;外取子集内先到先得——门级保守)。
        } else if policy is InternalSubset ||
          load.pe_values.contains(entity_name) == false {
          load.pe_values.set(entity_name, value)
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
          pos = skip_markup_declaration(text, pos, load)
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
        } else {
          // 外取 PE 立账(役PE位形):引用位才取件(spec 按需读),件址
          // 随录声明位 base(E18 链:%extpe 从别件引用仍按其声明件解)。
          load.pe_externals.set(entity_name, PeExternalId::{
            base: base_uri,
            system_id: sysid,
            public_id,
          })
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
/// 关键词不备 = External 错。体以嵌套感知的 "]]>" 收口。关键词位是
/// PE 引用(`<![ %e; [` 形)走 parse_conditional_pe 展开位。
fn parse_conditional(
  text : String,
  start : Int32,
  base_uri : String?,
  load : ExternalLoad,
  policy : DeclPolicy,
) -> Int32 raise XmlError {
  let keyword_start = start + 3
  let limit = text.length()
  let mut keyword_probe = keyword_start
  while keyword_probe < limit &&
        (
          text[keyword_probe] == ' ' ||
          text[keyword_probe] == '\t' ||
          text[keyword_probe] == '\r' ||
          text[keyword_probe] == '\n'
        ) {
    keyword_probe = keyword_probe + 1
  }
  if keyword_probe < limit && text[keyword_probe] == '%' {
    return parse_conditional_pe(text, start, base_uri, load, policy)
  }
  let mut pos = keyword_start
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
/// 条件段 PE 关键词位形(役PE位形):关键词流 = PE 值(前置)+ 引用后
/// 原文(续);'[' 可来自值内(022 形 `%e` = "INCLUDE[")或原文。
/// 展开不落盘——体仍住原文,收口扫描与错误报位零位移;值内 '[' 之后
/// 的残段不入流(门级保真,严于门位形不在此过)。
fn parse_conditional_pe(
  text : String,
  start : Int32,
  base_uri : String?,
  load : ExternalLoad,
  policy : DeclPolicy,
) -> Int32 raise XmlError {
  let limit = text.length()
  let mut keyword_pos = start + 3
  while keyword_pos < limit &&
        (
          text[keyword_pos] == ' ' ||
          text[keyword_pos] == '\t' ||
          text[keyword_pos] == '\r' ||
          text[keyword_pos] == '\n'
        ) {
    keyword_pos = keyword_pos + 1
  }
  let (name, ref_end) = match pe_reference_end(text, keyword_pos) {
    Some(found) => found
    None =>
      raise external_error(
        text, start, "unterminated parameter entity reference",
      )
  }
  let value = match load.pe_values.get(name) {
    Some(found) => found
    None =>
      raise external_error(
        text,
        start + 3,
        "unresolved parameter entity in conditional section",
      )
  }
  let value_limit = value.length()
  let mut bracket : Int32 = -1
  for index in 0..<value_limit {
    if value[index] == '[' {
      bracket = index
      break
    }
  }
  let keyword_body : (String, Int32) = if bracket >= 0 {
    (value[:bracket].trim().to_owned(), ref_end)
  } else {
    let mut scan = ref_end
    while scan < limit &&
          (
            text[scan] == ' ' ||
            text[scan] == '\t' ||
            text[scan] == '\r' ||
            text[scan] == '\n'
          ) {
      scan = scan + 1
    }
    if scan >= limit || text[scan] != '[' {
      raise external_error(text, start, "unterminated conditional section")
    }
    (value.trim().to_owned(), scan + 1)
  }
  let keyword = keyword_body.0
  let body_start = keyword_body.1
  let close = match scan_conditional_close(text, body_start) {
    Some(found) => found
    None =>
      raise external_error(text, start, "unterminated conditional section body")
  }
  if keyword == "INCLUDE" {
    parse_declarations(
      text[body_start:close].to_owned(),
      base_uri,
      load,
      policy,
    )
  } else if keyword != "IGNORE" {
    raise external_error(
      text,
      start + 3,
      "conditional keyword must be INCLUDE or IGNORE",
    )
  }
  close + 3
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
/// 声明名合法性闸(闸补役,ibm77n14 形 `<!ELEMENT 0node>`):名字按
/// 文档版次面选表(4e/5e/1.1),非法即 External 错;合法则照旧过闸
/// 跳过(体语法仍不深究——本闸只管名字面)。
fn gate_declaration_name(
  text : String,
  start : Int32,
  load : ExternalLoad,
) -> Int32 raise XmlError {
  let limit = text.length()
  let mut word_end = start + 2
  while word_end < limit && !is_doctype_space(text[word_end]) {
    word_end = word_end + 1
  }
  let (name_start_ok, name_char_ok) = name_predicates(
    load.edition,
    load.doc_version == Some("1.1"),
  )
  let mut pos = skip_doctype_space(text, word_end)
  let name_start = pos
  while pos < limit && !is_doctype_stop(text[pos]) {
    pos = pos + 1
  }
  if pos > name_start && text[name_start] == '%' {
    // 名位 PE 引用(021/023 位形:`<!ATTLIST %e;`):名字由 PE 供,
    // 合法性随 PE 展开面,本闸不核——照旧过闸跳过。
    return skip_markup_declaration(text, start, load)
  }
  let mut wellformed = pos > name_start
  if wellformed {
    wellformed = name_start_ok(text[name_start].to_int())
    let mut i = name_start + 1
    while i < pos && wellformed {
      wellformed = name_char_ok(text[i].to_int())
      i = i + 1
    }
  }
  if wellformed == false {
    raise external_error(
      text,
      start,
      "illegal name in declaration at '\{text[start:pos]}'",
    )
  }
  skip_markup_declaration(text, start, load)
}

///|
/// ATTLIST/ELEMENT/NOTATION 过闸跳过:quote 态感知找到收口 '>';
/// 未闭合 = External 错(声明面拒因)。引号外 PE 引用按值收口
/// (役PE位形,005/E14 补全声明位形)。
fn skip_markup_declaration(
  text : String,
  start : Int32,
  load : ExternalLoad,
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
    if ch == '%' {
      match pe_reference_end(text, pos) {
        Some((name, ref_end)) =>
          match load.pe_values.get(name) {
            Some(value) => {
              if value_has_top_level_gt(value) {
                // 值内顶层 '>' = 声明在值内闭合;返回引用后位(值尾
                // 残段属声明间内容,门级保守不追)。
                return ref_end
              }
              pos = ref_end
              continue
            }
            None => {
              // 未名 PE:跳过引用继续扫(原语义)。
              pos = ref_end
              continue
            }
          }
        None => {
          // 孤 '%' 无引用形:单步前进防挂。
          pos = pos + 1
          continue
        }
      }
    }
    if ch == '>' {
      return pos + 1
    }
    pos = pos + 1
  }
  raise external_error(text, start, "unterminated markup declaration")
}

///|
/// PE 值内顶层 '>' 探测(quote 态感知——值内引号串里的 '>' 不收口)。
fn value_has_top_level_gt(value : String) -> Bool {
  let limit = value.length()
  let mut i : Int32 = 0
  let mut quote : UInt16? = None
  while i < limit {
    let ch = value[i]
    match quote {
      Some(open) => if ch == open { quote = None }
      None =>
        if ch == '\'' || ch == '"' {
          quote = Some(ch)
        } else if ch == '>' {
          return true
        }
    }
    i = i + 1
  }
  false
}

///|
/// PE 引用名读取(%name;):返回 (名, 引用尾);停字非 ';' 或空名 = None。
fn pe_reference_end(text : String, start : Int32) -> (String, Int32)? {
  let limit = text.length()
  let mut pos = start + 1
  while pos < limit &&
        !(text[pos] == ';' || text[pos] == '>' || text[pos] == '<') {
    pos = pos + 1
  }
  if pos < limit && text[pos] == ';' {
    let name = text[start + 1:pos].to_owned()
    if name.length() > 0 {
      return Some((name, pos + 1))
    }
  }
  None
}

///|
/// 声明间 PE 引用(役PE位形升级):外取件取件后按外取子集解析(E18 链:
/// 件内容里的 ENTITY 声明落表);字面量值形备(markup 起 = '<' 或续引
/// PE = '%')按 DTD 片再扫,碎片值('&37;' 转义注入形,pe02 族)保持
/// 机械跳过。未名 PE = 机械跳过(原语义);自指/环 = 深度闸拒。
fn reference_pe(
  text : String,
  start : Int32,
  base_uri : String?,
  load : ExternalLoad,
  policy : DeclPolicy,
) -> Int32 raise XmlError {
  let (name, ref_end) = match pe_reference_end(text, start) {
    Some(found) => found
    None =>
      raise external_error(
        text, start, "unterminated parameter entity reference",
      )
  }
  match load.pe_externals.get(name) {
    Some(id) => {
      if load.pe_depth >= EXTERNAL_EXPANSION_DEPTH {
        raise external_error(
          text,
          start,
          "parameter entity expansion too deep at '%\{name};'",
        )
      }
      load.pe_depth = load.pe_depth + 1
      match load.resolver.resolve(id.base, id.system_id, id.public_id) {
        Some(bytes) => {
          let content = match decode_source(bytes) {
            Ok(raw) => admit_external_text(raw, load.doc_version)
            Err(why) => raise why
          }
          load_external_subset(
            content,
            Some(merge_base_reference(id.base, id.system_id)),
            load,
          )
        }
        None => ()
      }
      load.pe_depth = load.pe_depth - 1
      return ref_end
    }
    None => ()
  }
  match load.pe_values.get(name) {
    Some(value) => {
      let head = value.trim_start()
      if head.length() > 0 && (head[0] == '<' || head[0] == '%') {
        if load.pe_depth >= EXTERNAL_EXPANSION_DEPTH {
          raise external_error(
            text,
            start,
            "parameter entity expansion too deep at '%\{name};'",
          )
        }
        load.pe_depth = load.pe_depth + 1
        parse_declarations(value, base_uri, load, policy)
        load.pe_depth = load.pe_depth - 1
      }
      ref_end
    }
    None => ref_end
  }
}

///|
/// 子代基址合成(RFC 3986 §5.2 merge + 去点段):外取件解析后的子代
/// 声明基址 = 父基址目录面 + 本件 system_id,归一成仍对 doc 可解的
/// 相对引用(E18 链实证:extpe 自 subdir1/E18-pe 以 "../subdir2/
/// E18-extpe" 声明,子代若直传生 system_id,resolver 面的 ".." 会咬掉
/// doc 目录——合成后 = "subdir2/E18-extpe",子代 resolve 落对位)。
/// system id 按 spec 只涉径面,归一只做 '.'/'..' 段折叠;绝对形
/// (前导 '/' 或 scheme 冒号先于斜杠)按 RFC §5.2.2 原样直传。
fn merge_base_reference(base : String?, system_id : String) -> String {
  for index in 0..<system_id.length() {
    let ch = system_id[index]
    if ch == ':' {
      return system_id
    }
    if ch == '/' {
      break
    }
  }
  if system_id.has_prefix("/") {
    return system_id
  }
  match base {
    None => system_id
    Some(base_uri) => {
      let mut head_end = -1
      let limit = base_uri.length()
      for index in 0..<limit {
        if base_uri[index] == '/' {
          head_end = index
        }
      }
      normalize_dot_segments(base_uri[:head_end + 1].to_owned() + system_id)
    }
  }
}

///|
/// 点段折叠(suite_join 同律,包内自有件——测试件 helper 不跨面)。
fn normalize_dot_segments(path : String) -> String {
  let segments : Array[String] = []
  for segment in path.split("/") {
    let name = segment.to_owned()
    if name == "" || name == "." {
      continue
    }
    if name == ".." {
      if segments.length() > 0 {
        let _ = segments.pop()
      }
      continue
    }
    segments.push(name)
  }
  let mut joined = ""
  for index, segment in segments {
    if index > 0 {
      joined = joined + "/"
    }
    joined = joined + segment
  }
  joined
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
