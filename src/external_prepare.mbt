///|
/// 组合面补丁(错误位面重映射账本):顶层引用一级记账——组合文里替换
/// 段跨度 ↔ 原文里引用跨度。嵌套展开不计账(账本不重叠;错误报位归
/// 顶层引用位)。按组合序push,天然升序。
priv struct SpanPatch {
  composed_start : Int32
  composed_end : Int32
  source_start : Int32
  source_length : Int32
}

///|
/// 组合缓冲(带已写长度——StringBuilder 无 O(1) 长度查询)。
priv struct ComposeBuffer {
  inner : StringBuilder
  mut length : Int32
}

///|
fn write_slice(
  buffer : ComposeBuffer,
  text : String,
  from : Int32,
  to : Int32,
) -> Unit {
  if to > from {
    buffer.inner.write_string(text[from:to].to_owned())
    buffer.length = buffer.length + (to - from)
  }
}

///|
/// 单字照抄(String 索引 = UInt16,write_char 要 Char——切片写绕开型差)。
fn write_unit(buffer : ComposeBuffer, text : String, i : Int32) -> Unit {
  buffer.inner.write_string(text[i:i + 1].to_owned())
  buffer.length = buffer.length + 1
}

///|
/// 预组合入口(役B2,R-B1b 单径定案:无标记/含标记外取实体统一走我层
/// 预组合——底座注入径废弃,缘由见 spec 卷二 B2 增补):doctype 扫描
/// → 内部子集外取形收编(内部优先)→ 外取子集装载 → 内容预展开。
/// 实体表空 = 无外挂实体,原文直通(逐字节零漂移)。
fn prepare_external(
  source : String,
  resolver : &EntityResolver,
) -> (String, Array[SpanPatch]) raise XmlError {
  match scan_doctype(source) {
    None => (source, [])
    Some(doctype) => {
      let load : ExternalLoad = {
        resolver,
        table: Map([]),
        internal_literals: Map([]),
        consumed: 0,
      }
      if doctype.subset_start >= 0 {
        let subset = source[doctype.subset_start:doctype.subset_end].to_owned()
        collect_internal_external_entities(subset, load)
      }
      match doctype.system_id {
        Some(sysid) =>
          match resolver.resolve(None, sysid, doctype.public_id) {
            Some(bytes) =>
              match decode_external(bytes) {
                Ok(subset_text) =>
                  load_external_subset(subset_text, Some(sysid), load)
                Err(why) => raise why
              }
            // 解析面拒:外取子集不装 → 引用处底座 InvalidEntity 自然拒
            // (fetch-fail = reject,B1 事实 F2 同款)
            None => ()
          }
        None => ()
      }
      claim_internal_chains(load)
      if load.table.length() == 0 {
        (source, [])
      } else {
        preexpand(source, doctype, load)
      }
    }
  }
}

///|
/// 预展开:序区与声明区逐字照抄(序区无引用位;声明区引用是 DTD 面);
/// 内容区上下文感知组合(注释/CDATA/PI 内不展开;属性值位按实体类别
/// 分型——外取件引用 = WFC 违例原样留底座拒)。
fn preexpand(
  source : String,
  doctype : DoctypeScan,
  load : ExternalLoad,
) -> (String, Array[SpanPatch]) raise XmlError {
  let buffer : ComposeBuffer = { inner: StringBuilder(), length: 0, }
  let patches : Array[SpanPatch] = []
  write_slice(buffer, source, 0, doctype.decl_end)
  compose_content(
    buffer,
    patches,
    source,
    doctype.decl_end,
    doctype.decl_end,
    load,
    0,
    false,
  )
  (buffer.inner.to_string(), patches)
}

///|
/// 内容组合器:引用展开 + 区域保护。attr_face = 文本处于属性值位
/// (外取件引用不展开;字面量实体引用合法,照展)。depth>0 = 实体
/// 内容再扫(origin 指向顶层引用在原文的起点——错误与账本坐标归一)。
fn compose_content(
  buffer : ComposeBuffer,
  patches : Array[SpanPatch],
  text : String,
  from : Int32,
  origin : Int32,
  load : ExternalLoad,
  depth : Int32,
  attr_face : Bool,
) -> Unit raise XmlError {
  let limit = text.length()
  let mut i : Int32 = from
  while i < limit {
    let ch = text[i]
    if ch == '&' {
      match read_general_reference(text, i) {
        Some((name, ref_end)) =>
          match load.table.get(name) {
            Some(entry) =>
              match entry {
                InternalText(content) => {
                  expand_entry(
                    buffer,
                    patches,
                    name,
                    content,
                    origin + i,
                    ref_end - i,
                    load,
                    depth,
                    attr_face,
                  )
                  i = ref_end
                }
                ExternalPiece(content) =>
                  if attr_face {
                    // §3.1 WFC:属性值位外取引用 = 违例,我层直拒
                    // (底座对属性位未声明实体放行,不能赖它)
                    raise expansion_error(
                      origin + i,
                      "external entity reference in attribute value at '&\{name};'",
                    )
                  } else {
                    expand_entry(
                      buffer,
                      patches,
                      name,
                      content,
                      origin + i,
                      ref_end - i,
                      load,
                      depth,
                      attr_face,
                    )
                    i = ref_end
                  }
              }
            // 预定义/内部/字符引用:原样留底座展开
            None => {
              buffer.inner.write_char('&')
              buffer.length = buffer.length + 1
              i = i + 1
            }
          }
        None => {
          buffer.inner.write_char('&')
          buffer.length = buffer.length + 1
          i = i + 1
        }
      }
      continue
    }
    if ch == '<' && !attr_face {
      if text[i + 1] == '?' {
        let end = skip_past(text, i + 2, '?', '>')
        write_slice(buffer, text, i, end)
        i = end
        continue
      }
      if text[i + 1] == '!' && text[i + 2] == '-' && text[i + 3] == '-' {
        let end = skip_comment(text, i + 4)
        write_slice(buffer, text, i, end)
        i = end
        continue
      }
      if text[i + 1] == '!' &&
        text[i + 2] == '[' &&
        text[i + 3] == 'C' &&
        text[i + 4] == 'D' &&
        text[i + 5] == 'A' &&
        text[i + 6] == 'T' &&
        text[i + 7] == 'A' &&
        text[i + 8] == '[' {
        i = copy_cdata(buffer, text, i)
        continue
      }
      i = copy_tag(buffer, patches, text, i, origin, load, depth)
      continue
    }
    write_unit(buffer, text, i)
    i = i + 1
  }
}

///|
/// 引用展开:深度闸 + 预算闸(billion-laughs 防御;底座预算闸管它自己
/// 的展开,我层展开自担);顶层(depth 0)记补丁账,嵌套不记(账本
/// 不重叠,错误报位归顶层引用位)。
fn expand_entry(
  buffer : ComposeBuffer,
  patches : Array[SpanPatch],
  name : String,
  content : String,
  source_start : Int32,
  source_length : Int32,
  load : ExternalLoad,
  depth : Int32,
  attr_face : Bool,
) -> Unit raise XmlError {
  if depth >= EXTERNAL_EXPANSION_DEPTH {
    raise expansion_error(
      source_start,
      "entity expansion too deep at '&\{name};'",
    )
  }
  load.consumed = load.consumed + content.length()
  if load.consumed > EXTERNAL_EXPANSION_BUDGET {
    raise expansion_error(
      source_start,
      "entity expansion budget exceeded at '&\{name};'",
    )
  }
  if depth == 0 {
    let composed_start = buffer.length
    compose_content(
      buffer,
      patches,
      content,
      0,
      source_start,
      load,
      depth + 1,
      attr_face,
    )
    patches.push({
      composed_start,
      composed_end: buffer.length,
      source_start,
      source_length,
    })
  } else {
    compose_content(
      buffer,
      patches,
      content,
      0,
      source_start,
      load,
      depth + 1,
      attr_face,
    )
  }
}

///|
/// 标签照抄(quote 态感知):标签名/属性名区不展开;引号值区按属性值
/// 位组合(外取件引用原样 = WFC 拒;字面量实体引用展开)。
fn copy_tag(
  buffer : ComposeBuffer,
  patches : Array[SpanPatch],
  text : String,
  start : Int32,
  origin : Int32,
  load : ExternalLoad,
  depth : Int32,
) -> Int32 raise XmlError {
  let limit = text.length()
  buffer.inner.write_char('<')
  buffer.length = buffer.length + 1
  let mut i : Int32 = start + 1
  while i < limit {
    let ch = text[i]
    if ch == '>' {
      buffer.inner.write_char('>')
      buffer.length = buffer.length + 1
      return i + 1
    }
    if ch == '\'' || ch == '"' {
      let open = ch
      write_unit(buffer, text, i)
      i = i + 1
      let value_start = i
      while i < limit && text[i] != open {
        i = i + 1
      }
      let value_end = if i < limit { i } else { limit }
      let value = text[value_start:value_end].to_owned()
      compose_content(
        buffer,
        patches,
        value,
        0,
        origin + value_start,
        load,
        depth,
        true,
      )
      if i < limit {
        write_unit(buffer, text, i)
        i = i + 1
      }
      continue
    }
    write_unit(buffer, text, i)
    i = i + 1
  }
  limit
}

///|
/// CDATA 照抄(]]> 收口;未闭合 = 文末,底座判)。
fn copy_cdata(buffer : ComposeBuffer, text : String, start : Int32) -> Int32 {
  let limit = text.length()
  let mut j : Int32 = start + 9
  let mut end : Int32 = limit
  while j + 2 < limit {
    if text[j] == ']' && text[j + 1] == ']' && text[j + 2] == '>' {
      end = j + 3
      break
    }
    j = j + 1
  }
  write_slice(buffer, text, start, end)
  end
}

///|
/// GE 引用读取(&name;;&# 字符引用与残 '&' 不收)。名字停字 = ';'
/// / 空白 / '<' / '&'。
fn read_general_reference(text : String, start : Int32) -> (String, Int32)? {
  let limit = text.length()
  let mut i : Int32 = start + 1
  if i < limit && text[i] == '#' {
    return None
  }
  while i < limit {
    let ch = text[i]
    if ch == ';' {
      let name = text[start + 1:i].to_owned()
      if name.length() == 0 {
        return None
      }
      return Some((name, i + 1))
    }
    if ch == ' ' ||
      ch == '\t' ||
      ch == '\r' ||
      ch == '\n' ||
      ch == '<' ||
      ch == '&' {
      return None
    }
    i = i + 1
  }
  None
}

///|
/// 展开闸错误(span = 原文引用位 offset;行列零位报——病态路径,
/// 消息带引用名,E1 IllegalName 零位报同款)。
fn expansion_error(offset : Int32, message : String) -> XmlError {
  let position : SourcePosition = { offset, line: 0, column: 0, }
  XmlError::At(error=XmlErrorKind::External(message), span={
    start: position,
    end: position,
  })
}

///|
/// 补丁账本重映射:组合文 offset → 原文 offset。账前段累计平移;
/// 账内 = 归引用位(报位诚实:错误在该次插入的源头)。
fn remap_position(offset : Int32, patches : Array[SpanPatch]) -> Int32 {
  let mut position = offset
  for patch in patches {
    if patch.composed_end <= position {
      position = position +
        patch.source_length -
        (patch.composed_end - patch.composed_start)
    } else if patch.composed_start <= position {
      return patch.source_start
    } else {
      break
    }
  }
  position
}

///|
/// 错误重定位:补丁非空时组合文坐标 → 原文坐标(行列按原文重算,
/// char_span 口径);补丁空 = 原样透传(零漂移保底)。
fn relocate_error(
  error : XmlError,
  patches : Array[SpanPatch],
  source : String,
) -> XmlError {
  if patches.is_empty() {
    return error
  }
  match error {
    At(error~, span~) => {
      let start_offset = remap_position(span.start.offset, patches)
      let end_offset = remap_position(span.end.offset, patches)
      let start_position = char_span(source, start_offset).start
      let end_position = char_span(source, end_offset).start
      At(error~, span={ start: start_position, end: end_position, })
    }
  }
}

///|
/// 链所有权闭合(役B2):内部子集字面量实体若(传递地)引用到本层
/// 收编的实体,须一并收归本表展开——否则底座展开内部链到半路撞上
/// 本层取走的外取名即 InvEnt(ext-sa/012 族)。收归后底座再不会在
/// 内容里见到该名(组合面已整链替换);不动链的内部字面量留底座,
/// 内部优先语义不变。不动点迭代(账序无关)。
fn claim_internal_chains(load : ExternalLoad) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    for name in load.internal_literals.keys() {
      if load.table.contains(name) {
        continue
      }
      match load.internal_literals.get(name) {
        Some(value) =>
          if literal_touches_table(value, load) {
            load.table.set(name, InternalText(value))
            changed = true
          }
        None => ()
      }
    }
  }
}

///|
/// 字面量值引用探测:值内 `&name;` 形引用(跳 `&#` 字符引用)是否
/// 撞到本表实体。PE 引用(`%..;`)在一般实体值内按 bypass 语义不展开,
/// 不入探。
fn literal_touches_table(value : String, load : ExternalLoad) -> Bool {
  let limit = value.length()
  let mut i : Int32 = 0
  while i < limit {
    if value[i] == '&' && !(i + 1 < limit && value[i + 1] == '#') {
      match read_general_reference(value, i) {
        Some((name, next)) => {
          if load.table.contains(name) {
            return true
          }
          i = next
          continue
        }
        None => ()
      }
    }
    i = i + 1
  }
  false
}
