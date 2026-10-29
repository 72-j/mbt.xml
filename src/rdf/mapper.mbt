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
/// ITS 命名域（RDF 1.2 dir 族；its:dir 文本方向）。
let its_namespace : String = "http://www.w3.org/2005/11/its"

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
fn expand_element_iri(name : @base.XmlName) -> String {
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
/// 游走帧：xml:base / xml:lang / its:dir 作用域 + rdf:version 版本门
/// （不可变，子帧新建；dir/version 供 RDF 1.2 面）。
priv struct Frame {
  base : String
  lang : String
  dir : String
  version_12 : Bool
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
fn frame_of(el : @base.Element, frame : Frame) -> Frame {
  let base = match find_attr(el, xml_namespace, "base") {
    Some(b) => resolve_reference(frame.base, b)
    None => frame.base
  }
  let lang = match find_attr(el, xml_namespace, "lang") {
    Some(l) => l
    None => frame.lang
  }
  // rdf:version="1.2" 可落任意元素（dir-05 钉：属性元素携带），子树局部生效
  let version_attr = match find_attr(el, rdf_namespace, "version") {
    Some(v) => v == "1.2"
    None => false
  }
  let version_12 = frame.version_12 || version_attr
  // its:dir 版本门：rdf:version="1.2" 声明后方生效（dir-02 钉：无版本纯 @en）
  let dir = if version_12 {
    match find_attr(el, its_namespace, "dir") {
      Some(d) => d
      None => frame.dir
    }
  } else {
    frame.dir
  }
  { base, lang, dir, version_12, }
}

///|
fn find_attr(
  el : @base.Element,
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
    Literal(value, _, _, _) => "l\{value}"
    TripleTerm(sub, pred, obj) =>
      "t\{term_key(sub)}\{term_key(pred)}\{term_key(obj)}"
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
fn text_content(el : @base.Element) -> String {
  let mut text = ""
  for child in el.children {
    match child {
      @base.Text(t) => text = text + t
      @base.CData(t) => text = text + t
      _ => ()
    }
  }
  text
}

///|
/// 元素直下子元素。
fn child_elements(el : @base.Element) -> Array[@base.Element] {
  let out : Array[@base.Element] = []
  for child in el.children {
    match child {
      @base.Element(c) => out.push(c)
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
  let edition = @base.XmlEdition::Editions1to4
  let ns = @base.NsMode::On
  let doc = @base.parse_edition(text, edition~, ns~) catch {
    _ => return Err("xml ill-formed")
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
  let version_12 = match find_attr(root, rdf_namespace, "version") {
    Some(v) => v == "1.2"
    None => false
  }
  let top_frame : Frame = { base, lang: "", dir: "", version_12, }
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
fn gate_children_text(el : @base.Element) -> Result[Unit, String] {
  for child in el.children {
    match child {
      @base.Text(t) =>
        if !is_all_whitespace(t) {
          return Err("元素内容含非空白字符数据")
        }
      @base.CData(t) =>
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
  el : @base.Element,
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
/// NCName 形判定（RDF/XML 的 rdf:ID/rdf:nodeID 名值；XML NS：Name 全禁 ':'）。
/// 字符类 = base 名字产生式谓词（5e 与 1.1 同表；组合符段 [#x0300-#x036F]
/// 由 base 表覆盖——自搓表漏段已修，_suite NCName 负例族兜底）。
fn is_ncname_shape(value : String) -> Bool {
  let len = value.length()
  if len == 0 {
    return false
  }
  let first = value[0].to_int()
  if first == 58 || !@base.is_name_start_char_11(first) {
    return false
  }
  for i in 1..<len {
    let ch = value[i].to_int()
    if ch == 58 || !@base.is_name_char_11(ch) {
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
  attr : @base.Attribute,
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
          Literal(attr.value, lang_opt(frame), None, dir_opt(frame))
        }
        state.emit(attach_to, predicate, object)
        return Ok(())
      }
      state.emit(
        attach_to,
        Iri(ns + local_part),
        Literal(attr.value, lang_opt(frame), None, dir_opt(frame)),
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
  el : @base.Element,
  attach_to : Term,
  frame : Frame,
) -> Result[Unit, String] {
  for attr in el.attributes {
    match attr.name.namespace_uri {
      Some(ns) => {
        if ns == xml_namespace {
          continue
        }
        if ns == its_namespace {
          // ITS 属性 = 框架元数据（its:dir 已入 frame），不挂属性属性
          continue
        }
        if ns == rdf_namespace {
          let local_name = attr.name.local_name
          if is_subject_core_attr(local_name) ||
            local_name == "resource" ||
            local_name == "parseType" ||
            local_name == "datatype" ||
            local_name == "annotation" ||
            local_name == "annotationNodeID" ||
            local_name == "version" ||
            local_name == "ID" {
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
/// 方向槽（RDF 1.2）：仅语言标签字面量携带（dir-06 钉：无 lang 纯词形）。
fn dir_opt(frame : Frame) -> String? {
  if frame.lang != "" && frame.dir != "" {
    Some(frame.dir)
  } else {
    None
  }
}

///|
/// 元素是否带属性属性（resource/nodeID/空形附挂判据）。
fn has_property_attrs(el : @base.Element) -> Bool {
  for attr in el.attributes {
    match attr.name.namespace_uri {
      Some(ns) =>
        if ns == xml_namespace {
          continue
        } else if ns == its_namespace {
          // ITS 属性（its:dir/its:version）= 框架元数据，非属性属性（dir-04 钉）
          continue
        } else if ns == rdf_namespace &&
          is_subject_core_attr(attr.name.local_name) {
          continue
        } else if ns == rdf_namespace &&
          (
            attr.name.local_name == "parseType" ||
            attr.name.local_name == "datatype" ||
            attr.name.local_name == "annotation" ||
            attr.name.local_name == "annotationNodeID" ||
            attr.name.local_name == "version"
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
/// XMLLiteral 文本转义（& < >；C14N 文本位转义集）。
fn xml_literal_escape(text : String) -> String {
  let mut out = ""
  for i in 0..<text.length() {
    let ch = text[i].to_int()
    if ch == 38 {
      out = out + "&amp;"
    } else if ch == 60 {
      out = out + "&lt;"
    } else if ch == 62 {
      out = out + "&gt;"
    } else {
      out = out + Int32::unsafe_to_char(ch).to_string()
    }
  }
  out
}

///|
/// XMLLiteral 节点序列化（exclusive C14N 近似：空元素展开形 `<x></x>`、
/// 属性文档序、文本转义；名域声明不加——套件 xml-canon 两案全裸元素）。
fn serialize_xml_literal_node(node : @base.Node) -> String {
  match node {
    @base.Element(element) => {
      let qname = element.name.qualified_name
      let mut out = "<" + qname
      for attr in element.attributes {
        out = out +
          " " +
          attr.name.qualified_name +
          "=\"" +
          xml_literal_escape(attr.value) +
          "\""
      }
      out = out + ">"
      for child in element.children {
        out = out + serialize_xml_literal_node(child)
      }
      out + "</" + qname + ">"
    }
    @base.Text(text) => xml_literal_escape(text)
    @base.CData(text) => xml_literal_escape(text)
    _ => ""
  }
}

///|
/// 语句发射（reif 可空挂具化 §7.2.21；annotation 可空挂 RDF 1.2 reifies）。
fn WalkState::emit_statement(
  self : WalkState,
  subject : Term,
  predicate : Term,
  object : Term,
  reif : Term?,
  annotation : Term?,
) -> Unit {
  self.emit(subject, predicate, object)
  match annotation {
    Some(reifier) =>
      self.emit(
        reifier,
        Iri(rdf_namespace + "reifies"),
        TripleTerm(subject, predicate, object),
      )
    None => ()
  }
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
  el : @base.Element,
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
  let parse_type_opt = find_attr(el, rdf_namespace, "parseType")
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
  // rdf:annotation（IRI 形）/ rdf:annotationNodeID（bnode 形）（RDF 1.2）：
  // 语句旁发 reifies 三元词；非版本门（an-01/an-02 钉）；双出 = 语法错
  let annotation_iri_opt = find_attr(el, rdf_namespace, "annotation")
  let annotation_nid_opt = find_attr(el, rdf_namespace, "annotationNodeID")
  let annotation_opt : Term? = match (annotation_iri_opt, annotation_nid_opt) {
    (Some(_), Some(_)) =>
      return Err("rdf:annotation 与 annotationNodeID 并存非法")
    (Some(iri_ref), None) => Some(Iri(resolve_reference(frame.base, iri_ref)))
    (None, Some(node_id)) => {
      if !is_ncname_shape(node_id) {
        return Err("rdf:annotationNodeID 非 NCName")
      }
      Some(BNode(state.bnode_label_for(node_id)))
    }
    (None, None) => None
  }
  let datatype_opt = find_attr(el, rdf_namespace, "datatype")
  let children = child_elements(el)
  // parseType 分派（§7.2.22/§7.2.23）：Collection 链 / Resource 内嵌属性面
  match parse_type_opt {
    Some(_) =>
      match datatype_opt {
        Some(_) => return Err("parseType 与 rdf:datatype 并存非法")
        None => ()
      }
    None => ()
  }
  match parse_type_opt {
    Some("Collection") => {
      if has_property_attrs(el) {
        return Err("parseType=Collection 不接属性属性")
      }
      match gate_children_text(el) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
      let nil_iri : Term = Iri(rdf_namespace + "nil")
      if children.length() == 0 {
        state.emit_statement(
          parent, predicate, nil_iri, reif_opt, annotation_opt,
        )
        return Ok(())
      }
      // 逆序构链：尾先建，rest 往前挂
      let items : Array[Term] = []
      for child in children {
        match walk_node_element(state, child, frame) {
          Ok(subject) => items.push(subject)
          Err(msg) => return Err(msg)
        }
      }
      let mut rest : Term = nil_iri
      let mut i = items.length() - 1
      while i >= 0 {
        let node : Term = BNode(state.fresh_bnode_label())
        state.emit(node, Iri(rdf_namespace + "first"), items[i])
        state.emit(node, Iri(rdf_namespace + "rest"), rest)
        rest = node
        i = i - 1
      }
      state.emit_statement(parent, predicate, rest, reif_opt, annotation_opt)
      return Ok(())
    }
    Some("Resource") => {
      let res_subject : Term = match resource_opt {
        Some(r) => Iri(resolve_reference(frame.base, r))
        None =>
          match node_id_opt {
            Some(v) => BNode(state.bnode_label_for(v))
            None => BNode(state.fresh_bnode_label())
          }
      }
      match attach_property_attrs(state, el, res_subject, frame) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
      for child in children {
        match walk_property_element(state, res_subject, child, frame) {
          Ok(_) => ()
          Err(msg) => return Err(msg)
        }
      }
      match gate_children_text(el) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
      state.emit_statement(
        parent, predicate, res_subject, reif_opt, annotation_opt,
      )
      return Ok(())
    }
    Some("Triple") => {
      // RDF 1.2 版本门：无 rdf:version="1.2" → 忽略不报错（tt-01 钉）
      if !frame.version_12 {
        return Ok(())
      }
      // 子须恰一节点元素；其下属性元素语句恰一 → 三元词；零/多语句 = 语法错（tt-07/08 钉）
      if children.length() != 1 {
        return Err("parseType=Triple 子节点元素须恰一")
      }
      {
        let child = children[0]
        // 临时游走态：quads 自带，bnode/ID/li 账共享；serial/li_scope 走后回传
        let temp_state : WalkState = {
          quads: [],
          bnode_labels: state.bnode_labels,
          seen_ids: state.seen_ids,
          li_counters: state.li_counters,
          li_scope: state.li_scope,
          serial: state.serial,
        }
        let temp_frame = frame_of(child, frame)
        temp_state.li_scope = temp_state.li_scope + 1
        match walk_node_element(temp_state, child, temp_frame) {
          Ok(_) => ()
          Err(msg) => return Err(msg)
        }
        state.serial = temp_state.serial
        state.li_scope = temp_state.li_scope
        if temp_state.quads.length() != 1 {
          return Err("parseType=Triple 子属性语句须恰一")
        }
        let statement = temp_state.quads[0]
        let triple_term : Term = TripleTerm(
          statement.subject,
          statement.predicate,
          statement.object,
        )
        state.emit_statement(
          parent, predicate, triple_term, reif_opt, annotation_opt,
        )
      }
      return Ok(())
    }
    Some("Literal") => {
      // Literal 与 rdf:resource/nodeID 并存禁（套件 empty-property error001/002 钉）
      match resource_opt {
        Some(_) => return Err("parseType=Literal 与 rdf:resource 并存非法")
        None => ()
      }
      match node_id_opt {
        Some(_) => return Err("parseType=Literal 与 rdf:nodeID 并存非法")
        None => ()
      }
      // XMLLiteral = 子节点规范序列化（RDF 1.1 §5.1；语言标签沿用语境）
      let mut serialized = ""
      for child in el.children {
        serialized = serialized + serialize_xml_literal_node(child)
      }
      let object : Term = Literal(
        serialized,
        lang_opt(frame),
        Some(rdf_namespace + "XMLLiteral"),
        dir_opt(frame),
      )
      state.emit_statement(parent, predicate, object, reif_opt, annotation_opt)
      return Ok(())
    }
    Some(other) => return Err("parseType=\{other} 未实现（X3 在账）")
    None => ()
  }
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
      state.emit_statement(parent, predicate, object, reif_opt, annotation_opt)
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
      state.emit_statement(parent, predicate, object, reif_opt, annotation_opt)
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
        None,
      )
      state.emit_statement(parent, predicate, object, reif_opt, annotation_opt)
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
          state.emit_statement(
            parent, predicate, subject, reif_opt, annotation_opt,
          )
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
    state.emit_statement(parent, predicate, object, reif_opt, annotation_opt)
    return Ok(())
  }
  if text == "" {
    // 真空形 = 空字面量（RDF 1.1 §7.2.24；套件 empty-property-elements test002/008 钉）
    let object : Term = Literal("", lang_opt(frame), None, dir_opt(frame))
    state.emit_statement(parent, predicate, object, reif_opt, annotation_opt)
    return Ok(())
  }
  state.emit_statement(
    parent,
    predicate,
    Literal(text, lang_opt(frame), None, dir_opt(frame)),
    reif_opt,
    annotation_opt,
  )
  Ok(())
}
