///|
/// 文档 → 规范 XML 串:声明/DOCTYPE 在前,根元素无子时自闭合,
/// 文本与属性值转义,CDATA/注释/PI 原形发。
/// 合同:对 parse 产物往返等价(字符串定点);手搭树的非法值不在此校验。
pub fn Document::to_xml(self : Document) -> String {
  let buffer = StringBuilder()
  match self.decl {
    Some(declaration) => buffer.write_string(decl_to_string(declaration))
    None => ()
  }
  match self.doctype {
    Some(name) => {
      buffer.write_string("<!DOCTYPE ")
      buffer.write_string(name)
      buffer.write_string(">")
    }
    None => ()
  }
  for node in self.prologue {
    emit_node(buffer, node)
  }
  emit_element(buffer, self.root)
  for node in self.epilogue {
    emit_node(buffer, node)
  }
  buffer.to_string()
}

///|
/// 声明行(属性序 version → encoding → standalone,与底座解析形对位)。
fn decl_to_string(declaration : XmlDecl) -> String {
  let buffer = StringBuilder()
  buffer.write_string("<?xml version=\"")
  buffer.write_string(declaration.version)
  buffer.write_string("\"")
  match declaration.encoding {
    Some(encoding) => {
      buffer.write_string(" encoding=\"")
      buffer.write_string(encoding)
      buffer.write_string("\"")
    }
    None => ()
  }
  match declaration.standalone {
    Some(standalone) => {
      buffer.write_string(" standalone=\"")
      buffer.write_string(standalone)
      buffer.write_string("\"")
    }
    None => ()
  }
  buffer.write_string("?>")
  buffer.to_string()
}

///|
fn emit_element(buffer : StringBuilder, element : Element) -> Unit {
  buffer.write_string("<")
  buffer.write_string(element.name.qualified_name)
  for attribute in element.attributes {
    buffer.write_string(" ")
    buffer.write_string(attribute.name.qualified_name)
    buffer.write_string("=\"")
    buffer.write_string(@xml.escape(attribute.value))
    buffer.write_string("\"")
  }
  if element.children.length() == 0 {
    buffer.write_string("/>")
  } else {
    buffer.write_string(">")
    for child in element.children {
      emit_node(buffer, child)
    }
    buffer.write_string("</")
    buffer.write_string(element.name.qualified_name)
    buffer.write_string(">")
  }
}

///|
fn emit_node(buffer : StringBuilder, node : Node) -> Unit {
  match node {
    Node::Element(element) => emit_element(buffer, element)
    Node::Text(content) => buffer.write_string(@xml.escape(content))
    Node::CData(content) => {
      buffer.write_string("<![CDATA[")
      buffer.write_string(content)
      buffer.write_string("]]>")
    }
    Node::Comment(content) => {
      buffer.write_string("<!--")
      buffer.write_string(content)
      buffer.write_string("-->")
    }
    Node::PI(target~, data~) => {
      buffer.write_string("<?")
      buffer.write_string(target)
      buffer.write_string(" ")
      buffer.write_string(data)
      buffer.write_string("?>")
    }
  }
}
