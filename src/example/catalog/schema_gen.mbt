// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====
// 源表：moonxml/src/example/catalog/catalog_schema.toml（schema 1.0）
// 再生：moon run skelgen/xmlregen(仓根起跑;改表 → 再生 → 黄金门对拍)
// 绑定器：skelschema/xmlschema_toml_gen.mbt(parse/validate/emit 三件套)
// 目标包:moonxml/src/example/catalog。面:XML 文档形状骨架(树递归结构体 + 双向机械骨架)。值域校验/业务规则手写补(语义不生成)。

///|
/// doc 元素(机械骨架:字段序 = 表序;基数型:恰一=T / 0..1=T? / 0..n=Array[T])。
pub(all) struct Doc {
  version : String
  lang : String?
  book : Array[Book]
  meta : @base.Node?
} derive(Eq)

///|
pub extend Doc with Eq::{not_equal, equal}

///|
/// book 元素(机械骨架:字段序 = 表序;基数型:恰一=T / 0..1=T? / 0..n=Array[T])。
pub(all) struct Book {
  isbn : String
  year : Int32
  price : Double?
  in_print : Bool
  title : String
  author : Array[String]
  pages : Int32
} derive(Eq)

///|
pub extend Book with Eq::{not_equal, equal}

///|
/// doc 元素 → Doc(机械骨架;标签按原文匹配,未知子元素 = 错;
/// 值域/业务规则经 stub_validate_doc 挂点,stubs.mbt 手写)。
pub fn doc_from_tree(element : @base.Element) -> Result[Doc, String] {
  let version = match xmlschema_attr_find(element, "version") {
    Some(value) => value
    None => return Err("doc: missing required attribute \"version\"")
  }
  let lang = xmlschema_attr_find(element, "xml:lang")
  let book : Array[Book] = []
  let mut meta : @base.Node? = None
  for child in element.children {
    match child {
      @base.Node::Element(child_element) => {
        let tag = child_element.name.qualified_name
        if tag == "book" {
          match book_from_tree(child_element) {
            Ok(value) => book.push(value)
            Err(msg) => return Err(msg)
          }
        } else if tag == "meta" {
          if meta is Some(_) {
            return Err("doc: repeated child \"meta\"")
          }
          meta = Some(@base.Node::Element(child_element))
        } else {
          return Err("doc: unexpected element \"\{tag}\"")
        }
      }
      _ =>
        match child {
          @base.Node::Text(text) =>
            if xmlschema_is_blank(text) == false {
              return Err("doc: stray text \"\{text}\"")
            }
          @base.Node::CData(text) =>
            if xmlschema_is_blank(text) == false {
              return Err("doc: stray text \"\{text}\"")
            }
          _ => ()
        }
    }
  }
  let value = Doc::{ version, lang, book, meta, }
  match stub_validate_doc(value) {
    Ok(_) => Ok(value)
    Err(msg) => Err("doc: \{msg}")
  }
}

///|
/// book 元素 → Book(机械骨架;标签按原文匹配,未知子元素 = 错;
/// 值域/业务规则经 stub_validate_book 挂点,stubs.mbt 手写)。
pub fn book_from_tree(element : @base.Element) -> Result[Book, String] {
  let isbn = match xmlschema_attr_find(element, "isbn") {
    Some(value) => value
    None => return Err("book: missing required attribute \"isbn\"")
  }
  let year_raw = match xmlschema_attr_find(element, "year") {
    Some(value) => value
    None => return Err("book: missing required attribute \"year\"")
  }
  let year = match xmlschema_int_of(year_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let in_print_raw = match xmlschema_attr_find(element, "in_print") {
    Some(value) => value
    None => return Err("book: missing required attribute \"in_print\"")
  }
  let in_print = match xmlschema_bool_of(in_print_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let price : Double? = match xmlschema_attr_find(element, "price") {
    Some(raw) =>
      match xmlschema_double_of(raw) {
        Ok(value) => Some(value)
        Err(msg) => return Err(msg)
      }
    None => None
  }
  let mut title : String? = None
  let author : Array[String] = []
  let mut pages : Int32? = None
  for child in element.children {
    match child {
      @base.Node::Element(child_element) => {
        let tag = child_element.name.qualified_name
        if tag == "title" {
          if title is Some(_) {
            return Err("book: repeated child \"title\"")
          }
          match xmlschema_leaf_text(child_element) {
            Ok(text) => title = Some(text)
            Err(msg) => return Err(msg)
          }
        } else if tag == "author" {
          match xmlschema_leaf_text(child_element) {
            Ok(text) => author.push(text)
            Err(msg) => return Err(msg)
          }
        } else if tag == "pages" {
          if pages is Some(_) {
            return Err("book: repeated child \"pages\"")
          }
          match xmlschema_leaf_text(child_element) {
            Ok(text) =>
              match xmlschema_int_of(text) {
                Ok(value) => pages = Some(value)
                Err(msg) => return Err(msg)
              }
            Err(msg) => return Err(msg)
          }
        } else {
          return Err("book: unexpected element \"\{tag}\"")
        }
      }
      _ =>
        match child {
          @base.Node::Text(text) =>
            if xmlschema_is_blank(text) == false {
              return Err("book: stray text \"\{text}\"")
            }
          @base.Node::CData(text) =>
            if xmlschema_is_blank(text) == false {
              return Err("book: stray text \"\{text}\"")
            }
          _ => ()
        }
    }
  }
  let title_value = match title {
    Some(value) => value
    None => return Err("book: missing required child \"title\"")
  }
  let pages_value = match pages {
    Some(value) => value
    None => return Err("book: missing required child \"pages\"")
  }
  let value = Book::{
    isbn,
    year,
    price,
    in_print,
    title: title_value,
    author,
    pages: pages_value,
  }
  match stub_validate_book(value) {
    Ok(_) => Ok(value)
    Err(msg) => Err("book: \{msg}")
  }
}

///|
/// Doc → catalog 元素(canonical 序 = 表序;any 子树原样透传)。
pub fn Doc::to_tree(self : Doc) -> @base.Element {
  let attributes : Array[@base.Attribute] = []
  attributes.push(xmlschema_make_attribute("version", self.version))
  match self.lang {
    Some(value) => attributes.push(xmlschema_make_attribute("xml:lang", value))
    None => ()
  }
  let children : Array[@base.Node] = []
  for value in self.book {
    children.push(@base.Node::Element(value.to_tree()))
  }
  match self.meta {
    Some(value) => children.push(value)
    None => ()
  }
  xmlschema_make_element("catalog", attributes, children)
}

///|
/// Book → book 元素(canonical 序 = 表序;any 子树原样透传)。
pub fn Book::to_tree(self : Book) -> @base.Element {
  let attributes : Array[@base.Attribute] = []
  attributes.push(xmlschema_make_attribute("isbn", self.isbn))
  attributes.push(xmlschema_make_attribute("year", self.year.to_string()))
  match self.price {
    Some(value) =>
      attributes.push(xmlschema_make_attribute("price", value.to_string()))
    None => ()
  }
  attributes.push(
    xmlschema_make_attribute("in_print", self.in_print.to_string()),
  )
  let children : Array[@base.Node] = []
  children.push(@base.Node::Element(xmlschema_make_leaf("title", self.title)))
  for value in self.author {
    children.push(@base.Node::Element(xmlschema_make_leaf("author", value)))
  }
  children.push(
    @base.Node::Element(xmlschema_make_leaf("pages", self.pages.to_string())),
  )
  xmlschema_make_element("book", attributes, children)
}

///|
/// 元素构造(机械形;名字/属性/子节点三件装配)。
fn xmlschema_make_element(
  tag : String,
  attributes : Array[@base.Attribute],
  children : Array[@base.Node],
) -> @base.Element {
  let element : @base.Element = {
    name: xmlschema_xml_name(tag),
    attributes,
    children,
  }
  element
}

///|
/// 标签名 → XmlName（`xml:` 前缀固定为规范 URI，与解析面对齐；其余前缀不解析
/// URI，表按原文匹配）。
fn xmlschema_xml_name(name : String) -> @base.XmlName {
  let colon : (String, String)? = match name.split_once(":") {
    Some(pair) => Some((pair.0.to_owned(), pair.1.to_owned()))
    None => None
  }
  match colon {
    Some((prefix, local_part)) => {
      let namespace_uri : String? = if prefix == "xml" {
        Some("http://www.w3.org/XML/1998/namespace")
      } else {
        None
      }
      let named : @base.XmlName = {
        qualified_name: name,
        prefix: Some(prefix),
        local_name: local_part,
        namespace_uri,
      }
      named
    }
    None => {
      let plain : @base.XmlName = {
        qualified_name: name,
        prefix: None,
        local_name: name,
        namespace_uri: None,
      }
      plain
    }
  }
}

///|
/// XML 空白(S 产生式:#x20 #x9 #xD #xA;拍1:node 内空白文本容忍,
/// 非空白散文本 = 红)。
fn xmlschema_is_blank(text : String) -> Bool {
  for ch in text {
    if !(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
      return false
    }
  }
  true
}

///|
/// 按标签原文找属性(命中 = 原文值;机械形)。
fn xmlschema_attr_find(element : @base.Element, wanted : String) -> String? {
  for attribute in element.attributes {
    if attribute.name.qualified_name == wanted {
      return Some(attribute.value)
    }
  }
  None
}

///|
/// 属性构造(机械形;绑定后返回,躲块首字面歧义)。
fn xmlschema_make_attribute(name : String, value : String) -> @base.Attribute {
  let attribute : @base.Attribute = { name: xmlschema_xml_name(name), value, }
  attribute
}

///|
/// 叶取文本:Text 与 CDATA 同为载荷(卷面裁定 2026-10-22 拍2:XML infoset
/// 等价;旧拒绝形 = 机械骨架最小面,非 infoset 立场)按序拼接;夹非文本子
/// = 红;零载荷 = 红。
fn xmlschema_leaf_text(element : @base.Element) -> Result[String, String] {
  let parts : Array[String] = []
  for child in element.children {
    match child {
      @base.Node::Text(text) => parts.push(text)
      @base.Node::CData(text) => parts.push(text)
      _ =>
        return Err(
          "xmlschema: leaf \"\{element.name.qualified_name}\" has a non-text child",
        )
    }
  }
  if parts.length() == 0 {
    return Err(
      "xmlschema: leaf \"\{element.name.qualified_name}\" expects a text child",
    )
  }
  let mut joined = ""
  for part in parts {
    joined = joined + part
  }
  Ok(joined)
}

///|
/// 叶构造:恰一 Text 子(机械形)。
fn xmlschema_make_leaf(tag : String, text : String) -> @base.Element {
  let children : Array[@base.Node] = [@base.Node::Text(text)]
  let element : @base.Element = {
    name: xmlschema_xml_name(tag),
    attributes: [],
    children,
  }
  element
}

///|
/// 文本 → Int32(核心转换面,失败 = Result 错;catch 形 = fmt 正典)。
fn xmlschema_int_of(text : String) -> Result[Int32, String] {
  let value = @string.parse_int(text) catch {
    _ => return Err("xmlschema: not an int: \"\{text}\"")
  }
  Ok(value)
}

///|
/// 文本 → Double(核心转换面,失败 = Result 错;catch 形 = fmt 正典)。
fn xmlschema_double_of(text : String) -> Result[Double, String] {
  let value = @string.parse_double(text) catch {
    _ => return Err("xmlschema: not a double: \"\{text}\"")
  }
  Ok(value)
}

///|
/// 文本 → Bool(xsd:boolean 词法域 true/false/1/0)。
fn xmlschema_bool_of(text : String) -> Result[Bool, String] {
  if text == "true" || text == "1" {
    Ok(true)
  } else if text == "false" || text == "0" {
    Ok(false)
  } else {
    Err("xmlschema: not a bool: \"\{text}\"")
  }
}

///|
/// 语义挂点名清单(from_tree 调用点数据孪生;接口一致门对表用)。
pub fn xmlschema_hook_names() -> Array[String] {
  ["stub_validate_doc", "stub_validate_book"]
}
