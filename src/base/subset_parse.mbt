///|
/// 子集声明解析：收编外部/内部子集里的声明——
/// · ENTITY 表装载（外取实体经 resolver 取件）；
/// · ATTLIST/ELEMENT/NOTATION 语法过闸（引号态感知跳过）。
/// 声明面的拒因记作 not-wf 族（dtd07 等的正判落点）；条件段 INCLUDE 解析、IGNORE 跳过。
///
/// 参数实体（PE）面：声明立账（字面量值 / 外取件址），声明间引用按账处理，
/// 条件段关键词位展开（`<![ %e; [`），声明内部按值内顶层 `>` 补全。
/// 尚未展开：PE 值直接注入内容区（内部子集展开面）。
/// 施工账：ctx.md §11（役B2）· §12（役B3）· §14–§16（役PE 位形 / 闸补 / 组合）；
/// R-B1d = 声明面拒因。
const EXTERNAL_EXPANSION_DEPTH : Int32 = 32

///|
const EXTERNAL_EXPANSION_BUDGET : Int32 = 1000000

///|
/// 声明所在子集面：ExternalSubset = 字面量 ENTITY 也归本表（base 看不到外取子集）；
/// InternalSubset = 字面量实体归底座（内部优先），本层只收编外取形。
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
/// 外取 PE 件址（引用位取件用）：相对 system_id 按**声明位** base 解
/// （规范 4.2：相对路径归属声明所在件，而不是引用位）。
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
  /// PE 声明账：字面量 PE 值（名 → 原文）与外取件址（名 → 件 id）。
  /// 条件段关键词位 / 声明内部结束位 / 声明间引用三处都从这里取。
  /// PE 单独记账，不进内容区展开（内部优先律只辖一般实体）。
  pe_values : Map[String, String]
  pe_externals : Map[String, PeExternalId]
  /// PE 引用递归深度闸(%x "%x;" 形自指防御)。
  mut pe_depth : Int32
  /// 文档版次基准（Char 门与名字表键控用；无 XMLDecl = None = 1.0）。
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
      pos = skip_pi_declaration(text, pos, load)
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
/// ENTITY 声明：名 → 字面量值 / 外取 id（SYSTEM|PUBLIC [+ NDATA]）。
/// 字面量：ExternalSubset 归本表；InternalSubset 归底座（跳过）；PE 声明两态都不展开。
/// 外取形：取件为 None = 视作未声明（引用处底座自然拒）；取件成功但解码失败 =
/// External 错（件破即拒）。
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
            InternalSubset =>
              if load.pe_depth > 0 {
                // PE 值里产的 GE 声明 = 本层认领装表
                // (first-wins:直接声明在前 = 让位)
                if load.internal_literals.contains(entity_name) == false {
                  if load.table.contains(entity_name) == false {
                    load.table.set(entity_name, InternalText(value))
                  }
                }
              } else {
                load.internal_literals.set(entity_name, value)
              }
          }
          // PE 声明立账：值入 pe_values，供条件段关键词位 / 声明内部结束位 /
          // 声明间引用三处展开。次序律同规范 4.4.8：内部子集 PE 值优先。
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
              // 语义保留:解码失败重贴 External 标签(原文报法,账本见 ctx.md)
              let content = admit_external_text(
                decode_source(bytes),
                load.doc_version,
              ) catch {
                _ =>
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
          // 外取 PE 立账：引用位才取件（按需读），件址随声明位 base 录。
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
/// 条件段：`<![INCLUDE[ … ]]>` 解析体 / `<![IGNORE[ … ]]>` 跳过体；
/// 关键词不备 = External 错；体以嵌套感知的 `]]>` 结束。
/// 关键词位若是 PE 引用（`<![ %e; [` 形），走 parse_conditional_pe。
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
/// 条件段 PE 关键词位：关键词流 = PE 值（前置）+ 引用后原文（续）；
/// `[` 可来自值内（如 `%e` = "INCLUDE["）或原文。
/// 展开不落盘——体仍住原文，结束扫描与报位零位移。
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
/// DTD 子集 PI 闸：PI 目标须是名字（规范 P79；`[` 等非名字首即拒），
/// 且须有 `?>` 结束（未闭合 = not-wf）。目标名按版次选表。
fn skip_pi_declaration(
  text : String,
  start : Int32,
  load : ExternalLoad,
) -> Int32 raise XmlError {
  let limit = text.length()
  let (name_start_ok, name_char_ok) = name_predicates(
    load.edition,
    load.doc_version == Some("1.1"),
  )
  let target_start = start + 2
  if target_start >= limit ||
    name_start_ok(text[target_start].to_int()) == false {
    raise external_error(text, start, "PI target must be a name in DTD subset")
  }
  let mut pos = target_start + 1
  while pos < limit && name_char_ok(text[pos].to_int()) {
    pos = pos + 1
  }
  // PI 数据区 = 自由内容（P79），不核；只找 `?>` 结束
  while pos + 1 < limit {
    if text[pos] == '?' && text[pos + 1] == '>' {
      return pos + 2
    }
    pos = pos + 1
  }
  raise external_error(text, start, "PI not terminated in DTD subset")
}

///|
/// ATTLIST/ELEMENT/NOTATION 过闸跳过：引号态感知找到结束位 `>`；
/// 未闭合 = External 错；引号外的 PE 引用按值结束。
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
/// PE 值内顶层 '>' 探测（引号态感知——值内引号串里的 '>' 不算结束）。
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
/// 声明间 PE 引用：外取件取回后按外取子集解析（件内 ENTITY 声明落表）；
/// 字面量值按 DTD 片段再扫（markup 起 = `<` 或续引 PE = `%`），碎片值
/// （`&37;` 转义注入形）保持机械跳过。未定义 PE = 跳过；自指/环 = 深度闸拒。
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
          let content = admit_external_text(
            decode_source(bytes),
            load.doc_version,
          )
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
      // char refs included at reference time (spec 4.4.8 步2):只解
      // '&#..;' 形;'&name;' 引用保持 bypass 原样。
      let decoded = pe_value_char_refs(value)
      let head = decoded.trim_start()
      if head.length() > 0 && (head[0] == '<' || head[0] == '%') {
        if load.pe_depth >= EXTERNAL_EXPANSION_DEPTH {
          raise external_error(
            text,
            start,
            "parameter entity expansion too deep at '%\{name};'",
          )
        }
        load.pe_depth = load.pe_depth + 1
        parse_declarations(decoded, base_uri, load, policy)
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
/// 单 char ref 解码形:`&#D+;`/`&#xH+;` → (码点, 分号后位)。无数字/
/// 无分号/非数字单元 = None(闸 P 声明位已拒形残,此处双保险)。
fn char_ref_code_point(value : String, start : Int32) -> (Int32, Int32)? {
  let limit = value.length()
  let is_hex = start + 2 < limit && value[start + 2] == 'x'
  let number_base : Int32 = if is_hex { 16 } else { 10 }
  let mut pos = if is_hex { start + 3 } else { start + 2 }
  let mut code_point : Int32 = 0
  let mut digit_count : Int32 = 0
  while pos < limit {
    let unit = value[pos]
    if unit == ';' {
      if digit_count == 0 {
        return None
      }
      return Some((code_point, pos + 1))
    }
    let digit : Int32 = if unit >= 0x30 && unit <= 0x39 {
      unit.to_int() - 0x30
    } else if is_hex && unit >= 0x41 && unit <= 0x46 {
      unit.to_int() - 0x37
    } else if is_hex && unit >= 0x61 && unit <= 0x66 {
      unit.to_int() - 0x57
    } else {
      return None
    }
    code_point = code_point * number_base + digit
    digit_count = digit_count + 1
    pos = pos + 1
  }
  None
}

///|
/// PE 值 char-ref 处理：PE 值在引用位展开时即时解析 `&#…;`（规范 4.4.8 步 2），
/// `&name;` 引用保持 bypass 原样。码点域防护：代理区 / >0x10FFFF 即拒。
fn pe_value_char_refs(value : String) -> String raise XmlError {
  let limit = value.length()
  let out = StringBuilder()
  let mut i : Int32 = 0
  while i < limit {
    let unit = value[i]
    if unit == '&' && i + 1 < limit && value[i + 1] == '#' {
      match char_ref_code_point(value, i) {
        Some((code_point, next)) => {
          if (code_point >= 0xD800 && code_point <= 0xDFFF) ||
            code_point > 0x10FFFF {
            raise external_error(
              value, i, "char ref to surrogate/out-of-range code point in PE value",
            )
          }
          let unit_char = Int32::unsafe_to_char(code_point)
          out.write_char(unit_char)
          i = next
          continue
        }
        None => ()
      }
    }
    let _ = out.write_char(unit.to_int().unsafe_to_char())
    i = i + 1
  }
  out.to_string()
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
