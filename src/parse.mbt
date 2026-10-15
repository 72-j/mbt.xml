///|
/// 元素构建中帧(栈顶 = 当前接受子节点的元素;End 弹帧落树)。
priv struct ElementFrame {
  name : XmlName
  attributes : Array[Attribute]
  children : Array[Node]
}

///|
/// 相邻 Text 事件拼接:底座按实体边界切分多段,消费方须自行拼(契约一)。
fn append_text(nodes : Array[Node], content : String) -> Unit {
  let tail_index = nodes.length() - 1
  if tail_index >= 0 {
    match nodes[tail_index] {
      Text(previous) => nodes[tail_index] = Text(previous + content)
      _ => nodes.push(Text(content))
    }
  } else {
    nodes.push(Text(content))
  }
}

///|
/// 适配层结构错(防御纵深:底座已保 WF,此面正常解析不可达)。
fn structure_error(base_span : @xml.SourceSpan, message : String) -> XmlError {
  XmlError::At(
    error=XmlErrorKind::Structure(message),
    span=translate_span(base_span),
  )
}

///|
fn translate_name(base_name : @xml.XmlName) -> XmlName {
  {
    qualified_name: base_name.qualified_name,
    prefix: base_name.prefix,
    local_name: base_name.local_name,
    namespace_uri: base_name.namespace_uri,
  }
}

///|
/// xmlns 前缀声明("xmlns:p")→ 属性名。
fn xmlns_prefixed(prefix : String) -> XmlName {
  {
    qualified_name: "xmlns:" + prefix,
    prefix: Some("xmlns"),
    local_name: prefix,
    namespace_uri: None,
  }
}

///|
/// xmlns 缺省声明("xmlns")→ 属性名(无前缀)。
fn xmlns_default() -> XmlName {
  {
    qualified_name: "xmlns",
    prefix: None,
    local_name: "xmlns",
    namespace_uri: None,
  }
}

///|
fn xmlns_name(prefix : String?) -> XmlName {
  match prefix {
    Some(prefix) => xmlns_prefixed(prefix)
    None => xmlns_default()
  }
}

///|
/// 底座元素属性面 → 树属性:普通属性按序翻译,xmlns 声明并回队尾
/// (底座把 xmlns 与普通属性分离;并回后序列化统一按属性发,再解析等价)。
fn build_attributes(base_element : @xml.NamespaceElement) -> Array[Attribute] {
  let attributes : Array[Attribute] = []
  for base_attribute in base_element.attributes {
    attributes.push({
      name: translate_name(base_attribute.name),
      value: base_attribute.value,
    })
  }
  for base_declaration in base_element.namespace_declarations {
    attributes.push({
      name: xmlns_name(base_declaration.prefix),
      value: base_declaration.namespace_uri,
    })
  }
  attributes
}

///|
/// 元素落位:栈非空挂栈顶,否则占根槽(恰一;再来的元素 = 结构错)。
/// 根槽用单格数组表达(0/1 长度),避免 mut 局部跨助手传递。
fn attach_element(
  element : Element,
  stack : Array[ElementFrame],
  root_slot : Array[Element],
  base_span : @xml.SourceSpan,
) -> Unit raise XmlError {
  if stack.length() > 0 {
    stack[stack.length() - 1].children.push(Node::Element(element))
  } else if root_slot.length() == 0 {
    root_slot.push(element)
  } else {
    raise structure_error(base_span, "unexpected element after root")
  }
}

///|
/// 事件折叠 → 文档树。阶段由根槽/栈深推导:栈深>0 = 根内;
/// 根槽空 = 根前;根槽有根且栈空 = 根后。
fn parse_into(source : String) -> Document raise XmlError {
  let reader = @xml.NamespaceReader::from_string(source)
  let events = reader.read_events_until_eof() catch {
    base_error => raise translate_error(base_error)
  }
  let mut declaration : XmlDecl? = None
  let mut doctype : String? = None
  let prologue : Array[Node] = []
  let epilogue : Array[Node] = []
  let root_slot : Array[Element] = []
  let stack : Array[ElementFrame] = []
  for event in events {
    match event.kind {
      @xml.Decl(version~, encoding~, standalone~) => {
        if declaration is Some(_) {
          raise structure_error(event.span, "duplicate XML declaration")
        }
        declaration = Some({ version, encoding, standalone, })
      }
      @xml.DocType(name) => {
        if doctype is Some(_) {
          raise structure_error(event.span, "duplicate DOCTYPE")
        }
        doctype = Some(name)
      }
      @xml.Comment(content) =>
        if stack.length() > 0 {
          stack[stack.length() - 1].children.push(Node::Comment(content))
        } else if root_slot.length() == 0 {
          prologue.push(Node::Comment(content))
        } else {
          epilogue.push(Node::Comment(content))
        }
      @xml.PI(target~, data~) =>
        if stack.length() > 0 {
          stack[stack.length() - 1].children.push(Node::PI(target~, data~))
        } else if root_slot.length() == 0 {
          prologue.push(Node::PI(target~, data~))
        } else {
          epilogue.push(Node::PI(target~, data~))
        }
      @xml.Text(content) =>
        if stack.length() > 0 {
          append_text(stack[stack.length() - 1].children, content)
        } else if root_slot.length() == 0 {
          append_text(prologue, content)
        } else {
          append_text(epilogue, content)
        }
      @xml.CData(content) =>
        if stack.length() > 0 {
          stack[stack.length() - 1].children.push(Node::CData(content))
        } else if root_slot.length() == 0 {
          prologue.push(Node::CData(content))
        } else {
          epilogue.push(Node::CData(content))
        }
      @xml.Start(base_element) => {
        if root_slot.length() > 0 && stack.length() == 0 {
          raise structure_error(event.span, "unexpected element after root")
        }
        stack.push({
          name: translate_name(base_element.name),
          attributes: build_attributes(base_element),
          children: [],
        })
      }
      @xml.Empty(base_element) => {
        let element : Element = {
          name: translate_name(base_element.name),
          attributes: build_attributes(base_element),
          children: [],
        }
        attach_element(element, stack, root_slot, event.span)
      }
      @xml.End(_) =>
        match stack.pop() {
          Some(frame) => {
            let element : Element = {
              name: frame.name,
              attributes: frame.attributes,
              children: frame.children,
            }
            attach_element(element, stack, root_slot, event.span)
          }
          None =>
            raise structure_error(event.span, "end tag without matching start")
        }
      @xml.Eof => ()
    }
  }
  if root_slot.length() == 0 {
    raise XmlError::At(
      error=XmlErrorKind::Structure("document has no root element"),
      span={
        start: { offset: 0, line: 1, column: 1, },
        end: { offset: 0, line: 1, column: 1, },
      },
    )
  }
  { decl: declaration, doctype, prologue, root: root_slot[0], epilogue, }
}

///|
/// 解析入口:源文本 → 文档树(命名空间已解析,实体已展开;
/// 错误面 = [XmlError],位置透传)。
pub fn parse(source : String) -> Result[Document, XmlError] {
  Ok(parse_into(source)) catch {
    error => Err(error)
  }
}
