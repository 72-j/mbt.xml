///|
/// RDF/XML 主链映射（X2）：moonxml DOM（NsMode::On，名域已解析）→ Dataset。
/// 游走按 RDF 1.1 XML 语法 §6/§7 核心文法；xml:base 解析自写（D-3，
/// 痛感 >100 行或红案 ≥5 时给 moonxml 提面）。X3 面（parseType 三形、
/// rdf:ID 具化、rdf12 tt/an/dir 词）在账 = 判错，由套件 deferred 桶接住。

///|
let rdf_namespace : String = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

///|
let xml_namespace : String = "http://www.w3.org/XML/1998/namespace"

///|
/// RDF 1.0 已除名词（1.1 名域保留禁用）：bagID / aboutEach / aboutEachPrefix。
fn is_removed_rdf_word(local_name : String) -> Bool {
  local_name == "bagID" ||
  local_name == "aboutEach" ||
  local_name == "aboutEachPrefix"
}

///|
/// 节点元素核心定位属性（§6.1.2：rdf:ID / rdf:about / rdf:nodeID）。
fn is_subject_core_attr(local_name : String) -> Bool {
  local_name == "ID" || local_name == "about" || local_name == "nodeID"
}

///|
/// 属性元素禁用的核心词（§7.2.5；rdf:li 走 _N 拨号，不算禁用）。
fn is_forbidden_property_name(local_name : String) -> Bool {
  local_name == "RDF" ||
  local_name == "Description" ||
  local_name == "ID" ||
  local_name == "about" ||
  local_name == "nodeID" ||
  local_name == "parseType" ||
  local_name == "resource" ||
  local_name == "datatype"
}

///|
/// 引用是否带 scheme（首段 `:` 前无 `/` 且首字符为字母，RFC 3986 §3.1）。
fn reference_has_scheme(reference : String) -> Bool {
  let len = reference.length()
  if len == 0 {
    return false
  }
  let first = reference[0]
  if !((first >= 65 && first <= 90) || (first >= 97 && first <= 122)) {
    return false
  }
  for i in 1..<len {
    let ch = reference[i]
    if ch == 58 {
      return true
    }
    if ch == 47 {
      return false
    }
    let scheme_char = (ch >= 65 && ch <= 90) ||
      (ch >= 97 && ch <= 122) ||
      (ch >= 48 && ch <= 57) ||
      ch == 43 ||
      ch == 45 ||
      ch == 46
    if !scheme_char {
      return false
    }
  }
  false
}

///|
/// 路径去点段（RFC 3986 §5.2.4 箍紧形：/./ 与 /../ 收敛；中段空段折叠）。
fn remove_dot_segments(path : String) -> String {
  let absolute = path.has_prefix("/")
  let segments : Array[StringView] = path.split("/").collect()
  let kept : Array[String] = []
  let mut trailing_slash = false
  for seg_view in segments {
    let seg = seg_view.to_owned()
    if seg == "" || seg == "." {
      trailing_slash = true
    } else if seg == ".." {
      let _ = kept.pop()
      trailing_slash = true
    } else {
      kept.push(seg)
      trailing_slash = false
    }
  }
  let joined = join_path(kept)
  let body = if joined == "" {
    if absolute {
      "/"
    } else {
      ""
    }
  } else if absolute {
    "/" + joined
  } else {
    joined
  }
  if trailing_slash && body != "" && !body.has_suffix("/") {
    body + "/"
  } else {
    body
  }
}

///|
fn join_path(parts : Array[String]) -> String {
  let mut out = ""
  for i, part in parts {
    if i > 0 {
      let _ = 0
      out = out + "/" + part
    } else {
      out = part
    }
  }
  out
}

///|
/// 取 base 的 `scheme://authority` 前缀与余下路径（含去 query/frag）。
fn split_base(base : String) -> (String, String) {
  let mut head = base
  // 剥 frag
  for i in 0..<head.length() {
    if head[i] == 35 {
      head = head[:i].to_owned()
      break
    }
  }
  // 剥 query
  for i in 0..<head.length() {
    if head[i] == 63 {
      head = head[:i].to_owned()
      break
    }
  }
  for i in 0..<head.length() {
    // scheme 结束点之后找 "//" 收尾的 authority 边界
    if head[i] == 47 && i + 2 < head.length() && head[i + 1] == 47 {
      // 这是 scheme 分隔 "//" 的头——继续找下一个 '/'
      let mut j = i + 2
      let mut found = -1
      while j < head.length() {
        if head[j] == 47 {
          found = j
          break
        }
        j = j + 1
      }
      if found < 0 {
        return (head, "")
      }
      return (head[:found].to_owned(), head[found:].to_owned())
    }
    if head[i] == 58 {
      // scheme 冒号；下一对应是 "//"
      if i + 2 < head.length() && head[i + 1] == 47 && head[i + 2] == 47 {
        // 继续扫 authority 边界（上面分支会接手）——跳过即可
        continue
      }
      // 无 authority 的 scheme 形（mailto: 等）：整体当 path 处理
      return ("", head)
    }
  }
  ("", head)
}

///|
/// RFC 3986 相对引用解析（D-3 自写）：绝对直通；`//` 回 scheme；`#` 拼
/// base；`/` 接 origin；其余路径合并 + 去点段。
pub fn resolve_reference(base : String, reference : String) -> String {
  if reference_has_scheme(reference) {
    return reference
  }
  // 同文档引用族（RFC 3986 §5.2 分量重组）：片不继承——"" 与 "#…" 皆自 base 去片形
  let mut frag_cut = base.length()
  for i in 0..<base.length() {
    if base[i] == 35 {
      frag_cut = i
      break
    }
  }
  let base_nofrag = base[:frag_cut].to_owned()
  if reference == "" {
    return base_nofrag
  }
  if reference.has_prefix("#") {
    return base_nofrag + reference
  }
  let (prefix, base_path) = split_base(base)
  if reference.has_prefix("//") {
    // 网络路径引用：base 裸 scheme（首冒号含尾）+ reference
    let mut scheme = ""
    for i in 0..<prefix.length() {
      if prefix[i] == 58 {
        scheme = prefix[:i + 1].to_owned()
        break
      }
    }
    return scheme + reference
  }
  if reference.has_prefix("/") {
    return prefix + remove_dot_segments(reference)
  }
  if reference.has_prefix("?") {
    return prefix + base_path + reference
  }
  // 相对路径：取 base path 目录（含尾 `/`）
  let mut dir = base_path
  let mut cut = -1
  for i in 0..<dir.length() {
    if dir[i] == 47 {
      cut = i
    }
  }
  if cut >= 0 {
    dir = dir[:cut + 1].to_owned()
  } else {
    dir = "/"
  }
  prefix + remove_dot_segments(dir + reference)
}

///|
/// XmlName → IRI 词形（名域 URI + 本名；NsMode::On 已解析名域）。
fn expand_element_iri(name : @moonxml.XmlName) -> String {
  match name.namespace_uri {
    Some(ns) => ns + name.local_name
    None => name.qualified_name
  }
}

///|
/// 游走态：四元组汇 + nodeID 账 + rdf:ID 查重账 + li 拨号账 + 序号。
priv struct WalkState {
  quads : Array[Quad]
  bnode_labels : Map[String, String]
  seen_ids : Map[String, Bool]
  li_counters : Map[String, Int32]
  mut serial : Int32
  // li 拨号 scope：按节点元素现访自增（同主语双 Description 各自 _1 起，
  // 套件 rdf-containers-syntax-vs-schema/test008 钉）
  mut li_scope : Int32
}

///|
/// 游走帧：xml:base / xml:lang 作用域（不可变，子帧新建）。
priv struct Frame {
  base : String
  lang : String
}

///|
fn WalkState::fresh_bnode_label(self : WalkState) -> String {
  let label = "bnode\{self.serial}"
  self.serial = self.serial + 1
  label
}

///|
fn WalkState::bnode_label_for(self : WalkState, node_id : String) -> String {
  match self.bnode_labels.get(node_id) {
    Some(label) => label
    None => {
      let label = self.fresh_bnode_label()
      self.bnode_labels[node_id] = label
      label
    }
  }
}

///|
/// rdf:li 拨号：每个包含元素独立计数（§7.2.16）。
fn WalkState::next_li_ordinal(self : WalkState, parent_key : String) -> Int32 {
  match self.li_counters.get(parent_key) {
    Some(n) => {
      self.li_counters[parent_key] = n + 1
      n + 1
    }
    None => {
      self.li_counters[parent_key] = 1
      1
    }
  }
}

///|
fn WalkState::emit(
  self : WalkState,
  subject : Term,
  predicate : Term,
  object : Term,
) -> Unit {
  self.quads.push({ subject, predicate, object, graph: None, })
}

///|
/// 元素上 xml:base / xml:lang 覆盖帧（xml:lang="" 清语言）。
fn frame_of(el : @moonxml.Element, frame : Frame) -> Frame {
  let base = match find_attr(el, xml_namespace, "base") {
    Some(b) => resolve_reference(frame.base, b)
    None => frame.base
  }
  let lang = match find_attr(el, xml_namespace, "lang") {
    Some(l) => l
    None => frame.lang
  }
  { base, lang, }
}

///|
fn find_attr(
  el : @moonxml.Element,
  ns_uri : String,
  local_name : String,
) -> String? {
  for attr in el.attributes {
    match attr.name.namespace_uri {
      Some(ns) =>
        if ns == ns_uri && attr.name.local_name == local_name {
          return Some(attr.value)
        }
      None => ()
    }
  }
  None
}

///|
fn term_key(term : Term) -> String {
  match term {
    Iri(iri) => "i\{iri}"
    BNode(label) => "b\{label}"
    Literal(value, _, _) => "l\{value}"
  }
}

///|
fn is_all_whitespace(text : String) -> Bool {
  for i in 0..<text.length() {
    let ch = text[i]
    if !(ch == 32 || ch == 9 || ch == 10 || ch == 13) {
      return false
    }
  }
  true
}

///|
/// 元素直下文本（Text + CData 拼接）。
fn text_content(el : @moonxml.Element) -> String {
  let mut text = ""
  for child in el.children {
    match child {
      @moonxml.Text(t) => text = text + t
      @moonxml.CData(t) => text = text + t
      _ => ()
    }
  }
  text
}

///|
/// 元素直下子元素。
fn child_elements(el : @moonxml.Element) -> Array[@moonxml.Element] {
  let out : Array[@moonxml.Element] = []
  for child in el.children {
    match child {
      @moonxml.Element(c) => out.push(c)
      _ => ()
    }
  }
  out
}

///|
/// 主链入口：文档原文 → 数据集（文档 base 缺省空 = 引用按原样保形）。
pub fn parse_rdf_xml(text : String) -> Result[Dataset, String] {
  parse_rdf_xml_with_base(text, base="")
}

///|
/// 带 base 入口（套件 harness 传套件根 URL；xml:base 在其上叠加）。
pub fn parse_rdf_xml_with_base(
  text : String,
  base~ : String,
) -> Result[Dataset, String] {
  let edition = @moonxml.XmlEdition::Editions1to4
  let ns = @moonxml.NsMode::On
  let doc = match @moonxml.parse_edition(text, edition~, ns~) {
    Ok(doc) => doc
    Err(_) => return Err("xml ill-formed")
  }
  let state : WalkState = {
    quads: [],
    bnode_labels: Map([]),
    seen_ids: Map([]),
    li_counters: Map([]),
    li_scope: 0,
    serial: 0,
  }
  let root = doc.root
  let root_is_rdf = match root.name.namespace_uri {
    Some(ns) => ns == rdf_namespace && root.name.local_name == "RDF"
    None => false
  }
  let top_frame : Frame = { base, lang: "", }
  if root_is_rdf {
    let frame = frame_of(root, top_frame)
    for child in child_elements(root) {
      match walk_node_element(state, child, frame) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
      // 节点元素之间的字符数据门
      match gate_children_text(root) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
    }
  } else {
    match walk_node_element(state, root, top_frame) {
      Ok(_) => ()
      Err(msg) => return Err(msg)
    }
  }
  Ok({ quads: state.quads, })
}

///|
/// 元素直下文本门：非空白字符数据 = 错（§6.1.1）。
fn gate_children_text(el : @moonxml.Element) -> Result[Unit, String] {
  for child in el.children {
    match child {
      @moonxml.Text(t) =>
        if !is_all_whitespace(t) {
          return Err("元素内容含非空白字符数据")
        }
      @moonxml.CData(t) =>
        if !is_all_whitespace(t) {
          return Err("元素内容含非空白字符数据")
        }
      _ => ()
    }
  }
  Ok(())
}

///|
/// 节点元素游走（§7.2.4–§7.2.11）：定位 + 类型词 + 属性属性 + 子属性元素。
fn walk_node_element(
  state : WalkState,
  el : @moonxml.Element,
  frame : Frame,
) -> Result[Term, String] {
  let frame = frame_of(el, frame)
  state.li_scope = state.li_scope + 1
  // 核心定位属性读取与 rdf:ID 查重（ID 与 about 并存时 about 定位、ID 只验）
  let id_opt = find_attr(el, rdf_namespace, "ID")
  let about_opt = find_attr(el, rdf_namespace, "about")
  let node_id_opt = find_attr(el, rdf_namespace, "nodeID")
  match id_opt {
    Some(id_value) => {
      if !is_ncname_shape(id_value) {
        return Err("rdf:ID 词形非法：\{id_value}")
      }
      let iri = resolve_reference(frame.base, "#" + id_value)
      match state.seen_ids.get(iri) {
        Some(_) => return Err("rdf:ID 重复：\{iri}")
        None => state.seen_ids[iri] = true
      }
    }
    None => ()
  }
  // nodeID 门：词形 + 与 ID/about 互斥（syntax-incomplete error001-005 钉）
  match node_id_opt {
    Some(v) => {
      if !is_ncname_shape(v) {
        return Err("rdf:nodeID 词形非法：\{v}")
      }
      match id_opt {
        Some(_) => return Err("rdf:nodeID 与 rdf:ID 并存非法（§7.2.4）")
        None => ()
      }
      match about_opt {
        Some(_) =>
          return Err("rdf:nodeID 与 rdf:about 并存非法（§7.2.4）")
        None => ()
      }
    }
    None => ()
  }
  let subject : Term = match about_opt {
    Some(v) => Iri(resolve_reference(frame.base, v))
    None =>
      match id_opt {
        Some(v) => Iri(resolve_reference(frame.base, "#" + v))
        None =>
          match node_id_opt {
            Some(v) => BNode(state.bnode_label_for(v))
            None => BNode(state.fresh_bnode_label())
          }
      }
  }
  // 类型词：RDF / Description 之外的元素名 = typed node（§7.2.5）
  let local_name = el.name.local_name
  let is_rdf_name = match el.name.namespace_uri {
    Some(ns) => ns == rdf_namespace
    None => false
  }
  if is_rdf_name && local_name == "RDF" {
    return Err("rdf:RDF 不得嵌套")
  }
  if is_rdf_name && is_removed_rdf_word(local_name) {
    return Err("1.0 除名词禁用：\{local_name}")
  }
  if is_rdf_name &&
    (
      local_name == "ID" ||
      local_name == "about" ||
      local_name == "nodeID" ||
      local_name == "parseType" ||
      local_name == "resource" ||
      local_name == "datatype" ||
      local_name == "li"
    ) {
    return Err("核心语法词不得作节点元素名：\{local_name}")
  }
  let is_bare_core = is_rdf_name && local_name == "Description"
  if !is_bare_core {
    state.emit(
      subject,
      Iri(rdf_namespace + "type"),
      Iri(expand_element_iri(el.name)),
    )
  }
  // 属性属性（§7.2.10）
  for attr in el.attributes {
    match emit_property_attr(state, subject, attr, frame) {
      Ok(_) => ()
      Err(msg) => return Err(msg)
    }
  }
  // 子属性元素（§7.2.14）
  for child in child_elements(el) {
    match walk_property_element(state, subject, child, frame) {
      Ok(_) => ()
      Err(msg) => return Err(msg)
    }
  }
  match gate_children_text(el) {
    Ok(_) => ()
    Err(msg) => return Err(msg)
  }
  Ok(subject)
}

///|
/// rdf:ID / rdf:nodeID 词形门：NCName 近似（XML NCName 产物式裁段——
/// 起始位禁数字/组合符，全程禁冒号；套件 rdfms-rdf-id / syntax-incomplete 钉）。
fn is_ncname_shape(value : String) -> Bool {
  let len = value.length()
  if len == 0 {
    return false
  }
  let c0 = value[0].to_int()
  let start_ok = (c0 >= 65 && c0 <= 90) ||
    (c0 >= 97 && c0 <= 122) ||
    c0 == 95 ||
    (c0 >= 0xC0 && c0 <= 0xD6) ||
    (c0 >= 0xD8 && c0 <= 0xF6) ||
    (c0 >= 0xF8 && c0 <= 0x2FF) ||
    (c0 >= 0x370 && c0 <= 0x37D) ||
    (c0 >= 0x37F && c0 <= 0x1FFF) ||
    (c0 >= 0x200C && c0 <= 0x200D) ||
    (c0 >= 0x2070 && c0 <= 0x218F) ||
    (c0 >= 0x2C00 && c0 <= 0x2FEF) ||
    (c0 >= 0x3001 && c0 <= 0xD7FF) ||
    (c0 >= 0xF900 && c0 <= 0xFDCF) ||
    (c0 >= 0xFDF0 && c0 <= 0xFFFD)
  if !start_ok {
    return false
  }
  for i in 1..<len {
    let ch = value[i].to_int()
    let ok = (ch >= 65 && ch <= 90) ||
      (ch >= 97 && ch <= 122) ||
      (ch >= 48 && ch <= 57) ||
      ch == 95 ||
      ch == 45 ||
      ch == 46 ||
      ch == 0xB7 ||
      (ch >= 0xC0 && ch <= 0xD6) ||
      (ch >= 0xD8 && ch <= 0xF6) ||
      (ch >= 0xF8 && ch <= 0x2FF) ||
      (ch >= 0x370 && ch <= 0x37D) ||
      (ch >= 0x37F && ch <= 0x1FFF) ||
      (ch >= 0x200C && ch <= 0x200D) ||
      (ch >= 0x203F && ch <= 0x2040) ||
      (ch >= 0x2070 && ch <= 0x218F) ||
      (ch >= 0x2C00 && ch <= 0x2FEF) ||
      (ch >= 0x3001 && ch <= 0xD7FF) ||
      (ch >= 0xF900 && ch <= 0xFDCF) ||
      (ch >= 0xFDF0 && ch <= 0xFFFD)
    if !ok {
      return false
    }
  }
  true
}

///|
/// 无冒号属性名以 xml 起头（任意大小写）= xml 保留域，忽略（XML NS 约定；
/// 套件 unrecognised-xml-attributes/test002 钉：xmlnewthing 不炸正例）。
fn is_xml_reserved_attr(qualified_name : String) -> Bool {
  qualified_name.length() >= 3 &&
  (qualified_name[0] | 32) == 120 &&
  (qualified_name[1] | 32) == 109 &&
  (qualified_name[2] | 32) == 108
}

///|
/// 单条属性属性发射（节点元素与 resource 形附挂共用；§7.2.10）。
fn emit_property_attr(
  state : WalkState,
  attach_to : Term,
  attr : @moonxml.Attribute,
  frame : Frame,
) -> Result[Unit, String] {
  match attr.name.namespace_uri {
    Some(ns) => {
      if ns == xml_namespace {
        // xml:* 一律已消化（base/lang）或忽略（space 等）
        return Ok(())
      }
      let local_part = attr.name.local_name
      if ns == rdf_namespace {
        if is_subject_core_attr(local_part) {
          // 节点元素位核心定位词已消费；resource 形附挂位亦然
          return Ok(())
        }
        if local_part == "parseType" ||
          local_part == "resource" ||
          local_part == "datatype" ||
          local_part == "li" ||
          is_removed_rdf_word(local_part) {
          return Err("属性属性位禁用 \{local_part}")
        }
        let predicate : Term = Iri(rdf_namespace + local_part)
        let object : Term = if local_part == "type" {
          Iri(resolve_reference(frame.base, attr.value))
        } else {
          Literal(attr.value, lang_opt(frame), None)
        }
        state.emit(attach_to, predicate, object)
        return Ok(())
      }
      state.emit(
        attach_to,
        Iri(ns + local_part),
        Literal(attr.value, lang_opt(frame), None),
      )
      Ok(())
    }
    None =>
      if is_xml_reserved_attr(attr.name.qualified_name) {
        Ok(())
      } else {
        Err("无前缀属性 \{attr.name.qualified_name} 非法（§6.1.2）")
      }
  }
}

///|
/// resource / nodeID / 空形的属性属性附挂（§7.2.8）——形定核心词先滤除。
fn attach_property_attrs(
  state : WalkState,
  el : @moonxml.Element,
  attach_to : Term,
  frame : Frame,
) -> Result[Unit, String] {
  for attr in el.attributes {
    match attr.name.namespace_uri {
      Some(ns) => {
        if ns == xml_namespace {
          continue
        }
        if ns == rdf_namespace {
          let local_name = attr.name.local_name
          if is_subject_core_attr(local_name) ||
            local_name == "resource" ||
            local_name == "parseType" ||
            local_name == "datatype" {
            continue
          }
        }
        match emit_property_attr(state, attach_to, attr, frame) {
          Ok(_) => ()
          Err(msg) => return Err(msg)
        }
      }
      None =>
        if is_xml_reserved_attr(attr.name.qualified_name) {
          continue
        } else {
          return Err(
            "无前缀属性 \{attr.name.qualified_name} 非法（§6.1.2）",
          )
        }
    }
  }
  Ok(())
}

///|
fn lang_opt(frame : Frame) -> String? {
  if frame.lang == "" {
    None
  } else {
    Some(frame.lang)
  }
}

///|
/// 元素是否带属性属性（resource/nodeID/空形附挂判据）。
fn has_property_attrs(el : @moonxml.Element) -> Bool {
  for attr in el.attributes {
    match attr.name.namespace_uri {
      Some(ns) =>
        if ns == xml_namespace {
          continue
        } else if ns == rdf_namespace &&
          is_subject_core_attr(attr.name.local_name) {
          continue
        } else if ns == rdf_namespace &&
          (
            attr.name.local_name == "parseType" ||
            attr.name.local_name == "datatype"
          ) {
          continue
        } else {
          return true
        }
      None =>
        if is_xml_reserved_attr(attr.name.qualified_name) {
          continue
        } else {
          return true
        }
    }
  }
  false
}

///|
/// 语句发射（reif 可空挂具化 §7.2.21）。
fn WalkState::emit_statement(
  self : WalkState,
  subject : Term,
  predicate : Term,
  object : Term,
  reif : Term?,
) -> Unit {
  self.emit(subject, predicate, object)
  match reif {
    Some(reif_term) =>
      self.emit_reification(reif_term, subject, predicate, object)
    None => ()
  }
}

///|
/// rdf:ID 具化四元组（type/subject/predicate/object）。
fn WalkState::emit_reification(
  self : WalkState,
  reif : Term,
  subject : Term,
  predicate : Term,
  object : Term,
) -> Unit {
  self.emit(reif, Iri(rdf_namespace + "type"), Iri(rdf_namespace + "Statement"))
  self.emit(reif, Iri(rdf_namespace + "subject"), subject)
  self.emit(reif, Iri(rdf_namespace + "predicate"), predicate)
  self.emit(reif, Iri(rdf_namespace + "object"), object)
}

///|
/// 属性元素游走（§7.2.12–§7.2.29）：谓词拨定 + 五形判读。
fn walk_property_element(
  state : WalkState,
  parent : Term,
  el : @moonxml.Element,
  frame : Frame,
) -> Result[Unit, String] {
  let frame = frame_of(el, frame)
  let element_ns = match el.name.namespace_uri {
    Some(ns) => ns
    None => return Err("属性元素须有名域（§7.2.5）")
  }
  let local_part = el.name.local_name
  if element_ns == rdf_namespace &&
    (is_forbidden_property_name(local_part) || is_removed_rdf_word(local_part)) {
    return Err("属性元素禁用核心词 \{local_part}")
  }
  let li_key = "n" + state.li_scope.to_string() + "|" + term_key(parent)
  let predicate : Term = if element_ns == rdf_namespace && local_part == "li" {
    Iri(rdf_namespace + "_" + state.next_li_ordinal(li_key).to_string())
  } else {
    Iri(element_ns + local_part)
  }
  let resource_opt = find_attr(el, rdf_namespace, "resource")
  let node_id_opt = find_attr(el, rdf_namespace, "nodeID")
  // nodeID 门：与 resource 互斥须在 resource 形分派前查（syntax-incomplete error006 钉）
  match node_id_opt {
    Some(_) =>
      match resource_opt {
        Some(_) =>
          return Err("rdf:nodeID 与 rdf:resource 并存非法（§7.2.6）")
        None => ()
      }
    None => ()
  }
  match find_attr(el, rdf_namespace, "parseType") {
    Some(_) => return Err("parseType 未实现（X3 在账）")
    None => ()
  }
  // rdf:ID 具化形（§7.2.21）：NCName 校验 + 全文查重 + 具化节点 IRI
  let reif_opt : Term? = match find_attr(el, rdf_namespace, "ID") {
    Some(id) => {
      if !is_ncname_shape(id) {
        return Err("rdf:ID 词形非法（§7.2.21）")
      }
      let reif_iri = resolve_reference(frame.base, "#" + id)
      match state.seen_ids.get(reif_iri) {
        Some(_) => return Err("rdf:ID 重复 \{reif_iri}（§6.8）")
        None => state.seen_ids[reif_iri] = true
      }
      Some(Iri(reif_iri))
    }
    None => None
  }
  let datatype_opt = find_attr(el, rdf_namespace, "datatype")
  let children = child_elements(el)
  // resource 形
  match resource_opt {
    Some(r) => {
      if children.length() > 0 {
        return Err("rdf:resource 与子元素并存")
      }
      let object : Term = Iri(resolve_reference(frame.base, r))
      match attach_property_attrs(state, el, object, frame) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
      state.emit_statement(parent, predicate, object, reif_opt)
      return Ok(())
    }
    None => ()
  }
  // nodeID 形
  match node_id_opt {
    Some(v) => {
      if children.length() > 0 {
        return Err("rdf:nodeID 与子元素并存")
      }
      if !is_ncname_shape(v) {
        return Err("rdf:nodeID 词形非法：\{v}")
      }
      let object : Term = BNode(state.bnode_label_for(v))
      match attach_property_attrs(state, el, object, frame) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
      state.emit_statement(parent, predicate, object, reif_opt)
      return Ok(())
    }
    None => ()
  }
  // datatype 形
  match datatype_opt {
    Some(dt) => {
      if children.length() > 0 {
        return Err("rdf:datatype 与子元素并存")
      }
      // 套件 datatypes/test001 钉：datatype 与 xml:lang 并存合法，lang 落弃
      let object : Term = Literal(
        text_content(el),
        None,
        Some(resolve_reference(frame.base, dt)),
      )
      state.emit_statement(parent, predicate, object, reif_opt)
      return Ok(())
    }
    None => ()
  }
  // 子元素形：每个子 = 同谓词的节点元素（§7.2.21）
  if children.length() > 0 {
    if has_property_attrs(el) {
      return Err("子元素形不接属性属性")
    }
    for child in children {
      // li scope 现场保存/恢复：子节点元素自有拨号域，归来后续 li 仍归外层
      let outer_scope = state.li_scope
      match walk_node_element(state, child, frame) {
        Ok(subject) =>
          state.emit_statement(parent, predicate, subject, reif_opt)
        Err(msg) => return Err(msg)
      }
      state.li_scope = outer_scope
    }
    match gate_children_text(el) {
      Ok(_) => ()
      Err(msg) => return Err(msg)
    }
    return Ok(())
  }
  // 空属性元素形 / 文本字面量（§7.2.24）——真空形 = 新 bnode（非空串字面量）
  let text = text_content(el)
  if has_property_attrs(el) {
    if text != "" {
      return Err("空属性元素形不接字符数据")
    }
    let object : Term = BNode(state.fresh_bnode_label())
    match attach_property_attrs(state, el, object, frame) {
      Ok(_) => ()
      Err(msg) => return Err(msg)
    }
    state.emit_statement(parent, predicate, object, reif_opt)
    return Ok(())
  }
  if text == "" {
    // 真空形 = 空字面量（RDF 1.1 §7.2.24；套件 empty-property-elements test002/008 钉）
    let object : Term = Literal("", lang_opt(frame), None)
    state.emit_statement(parent, predicate, object, reif_opt)
    return Ok(())
  }
  state.emit_statement(
    parent,
    predicate,
    Literal(text, lang_opt(frame), None),
    reif_opt,
  )
  Ok(())
}
