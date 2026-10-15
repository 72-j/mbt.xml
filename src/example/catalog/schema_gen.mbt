// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====
// 源表：moonxml/src/example/catalog/catalog_schema.toml（schema 1.0）
// 再生：moon run skelgen/xmlregen(仓根起跑;改表 → 再生 → 黄金门对拍)
// 绑定器：skelgen/schema/xmlschema_toml_gen.mbt(parse/validate/emit 三件套)
// 面:XML 文档形状骨架(树递归结构体 + 双向机械骨架)。值域校验/业务规则手写补(语义不生成)。

///|
/// doc 元素(机械骨架:字段序 = 表序;基数型:恰一=T / 0..1=T? / 0..n=Array[T])。
pub(all) struct Doc {
  version : String
  lang : String?
  book : Array[Book]
  meta : @moonxml.Node?
} derive(Eq)

///|
pub extend Doc with Eq::{not_equal, equal}

///|
/// book 元素(机械骨架:字段序 = 表序;基数型:恰一=T / 0..1=T? / 0..n=Array[T])。
pub(all) struct Book {
  isbn : String
  title : String
  author : Array[String]
} derive(Eq)

///|
pub extend Book with Eq::{not_equal, equal}

///|
/// doc 元素 → Doc(机械骨架;标签按原文匹配,未知子元素 = 错)。
pub fn doc_from_tree(element : @moonxml.Element) -> Result[Doc, String] {
  let version = match xmlschema_attr_find(element, "version") {
    Some(value) => value
    None => return Err("doc: missing required attribute \"version\"")
  }
  let lang = xmlschema_attr_find(element, "xml:lang")
  let book : Array[Book] = []
  let mut meta : @moonxml.Node? = None
  for child in element.children {
    match child {
      @moonxml.Node::Element(child_element) => {
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
          meta = Some(@moonxml.Node::Element(child_element))
        } else {
          return Err("doc: unexpected element \"\{tag}\"")
        }
      }
      _ => ()
    }
  }
  Ok(Doc::{ version, lang, book, meta, })
}

///|
/// book 元素 → Book(机械骨架;标签按原文匹配,未知子元素 = 错)。
pub fn book_from_tree(element : @moonxml.Element) -> Result[Book, String] {
  let isbn = match xmlschema_attr_find(element, "isbn") {
    Some(value) => value
    None => return Err("book: missing required attribute \"isbn\"")
  }
  let mut title : String? = None
  let author : Array[String] = []
  for child in element.children {
    match child {
      @moonxml.Node::Element(child_element) => {
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
        } else {
          return Err("book: unexpected element \"\{tag}\"")
        }
      }
      _ => ()
    }
  }
  let title_value = match title {
    Some(value) => value
    None => return Err("book: missing required child \"title\"")
  }
  Ok(Book::{ isbn, title: title_value, author, })
}

///|
/// Doc → catalog 元素(canonical 序 = 表序;any 子树原样透传)。
pub fn Doc::to_tree(self : Doc) -> @moonxml.Element {
  let attributes : Array[@moonxml.Attribute] = []
  attributes.push(xmlschema_make_attribute("version", self.version))
  match self.lang {
    Some(value) => attributes.push(xmlschema_make_attribute("xml:lang", value))
    None => ()
  }
  let children : Array[@moonxml.Node] = []
  for value in self.book {
    children.push(@moonxml.Node::Element(value.to_tree()))
  }
  match self.meta {
    Some(value) => children.push(value)
    None => ()
  }
  xmlschema_make_element("catalog", attributes, children)
}

///|
/// Book → book 元素(canonical 序 = 表序;any 子树原样透传)。
pub fn Book::to_tree(self : Book) -> @moonxml.Element {
  let attributes : Array[@moonxml.Attribute] = []
  attributes.push(xmlschema_make_attribute("isbn", self.isbn))
  let children : Array[@moonxml.Node] = []
  children.push(
    @moonxml.Node::Element(xmlschema_make_leaf("title", self.title)),
  )
  for value in self.author {
    children.push(@moonxml.Node::Element(xmlschema_make_leaf("author", value)))
  }
  xmlschema_make_element("book", attributes, children)
}

///|
/// 元素构造(机械形;名字/属性/子节点三件装配)。
fn xmlschema_make_element(
  tag : String,
  attributes : Array[@moonxml.Attribute],
  children : Array[@moonxml.Node],
) -> @moonxml.Element {
  let element : @moonxml.Element = {
    name: xmlschema_xml_name(tag),
    attributes,
    children,
  }
  element
}

///|
/// 标签名 → XmlName(xml: 前缀钉规范 URI——与解析面对齐;其余前缀不解析 URI,表按原文匹配)。
fn xmlschema_xml_name(name : String) -> @moonxml.XmlName {
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
      let named : @moonxml.XmlName = {
        qualified_name: name,
        prefix: Some(prefix),
        local_name: local_part,
        namespace_uri,
      }
      named
    }
    None => {
      let plain : @moonxml.XmlName = {
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
/// 按标签原文找属性(命中 = 原文值;机械形)。
fn xmlschema_attr_find(element : @moonxml.Element, wanted : String) -> String? {
  for attribute in element.attributes {
    if attribute.name.qualified_name == wanted {
      return Some(attribute.value)
    }
  }
  None
}

///|
/// 属性构造(机械形;绑定后返回,躲块首字面歧义)。
fn xmlschema_make_attribute(
  name : String,
  value : String,
) -> @moonxml.Attribute {
  let attribute : @moonxml.Attribute = {
    name: xmlschema_xml_name(name),
    value,
  }
  attribute
}

///|
/// 叶取文本:恰一 Text 子(相邻文本解析面已拼接;CDATA/注释不算叶载荷)。
fn xmlschema_leaf_text(element : @moonxml.Element) -> Result[String, String] {
  if element.children.length() != 1 {
    return Err(
      "xmlschema: leaf \"\{element.name.qualified_name}\" expects exactly one text child",
    )
  }
  match element.children[0] {
    @moonxml.Node::Text(text) => Ok(text)
    _ =>
      Err(
        "xmlschema: leaf \"\{element.name.qualified_name}\" expects a text child",
      )
  }
}

///|
/// 叶构造:恰一 Text 子(机械形)。
fn xmlschema_make_leaf(tag : String, text : String) -> @moonxml.Element {
  let children : Array[@moonxml.Node] = [@moonxml.Node::Text(text)]
  let element : @moonxml.Element = {
    name: xmlschema_xml_name(tag),
    attributes: [],
    children,
  }
  element
}
