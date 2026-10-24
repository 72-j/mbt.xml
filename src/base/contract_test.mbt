///|
/// 三条消费方契约（M0 探针移交的注意点，各有用例覆盖）。

///|
/// 契约一:相邻 Text 事件按实体边界切分——适配层必须拼回单节点。
test "contract/text-concatenation" {
  let document = match @moonxml.parse("<doc>a&amp;b&#65;c</doc>") {
    Ok(document) => document
    Err(_) => fail("entity corpus must parse")
  }
  assert_eq(document.root.children.length(), 1)
  match document.root.children[0] {
    @moonxml.Node::Text(text) => assert_eq(text, "a&bAc")
    _ => fail("expected concatenated text node")
  }
}

///|
/// 契约二:自闭合根的事件是 Empty 不是 Start+End——根槽臂必须接。
test "contract/empty-root-arm" {
  let document = match @moonxml.parse("<leaf attr=\"v\"/>") {
    Ok(document) => document
    Err(_) => fail("empty root must parse")
  }
  assert_eq(document.root.name.qualified_name, "leaf")
  assert_eq(document.root.children.length(), 0)
  assert_eq(document.root.attributes.length(), 1)
  assert_eq(document.root.attributes[0].value, "v")
}

///|
/// 契约三:错误面透传位置(kind + 行/列)。
/// 底座把错配闭标报 InvalidSyntax(实报定谳:UnmatchedTag 词表在,
/// 但此形走 InvalidSyntax）——以实测形为准。
test "contract/error-span-passthrough" {
  let error = match @moonxml.parse("<d><a></b></d>") {
    Err(error) => error
    Ok(_) => fail("mismatched tag must fail")
  }
  match error {
    @moonxml.XmlError::At(error~, span~) => {
      assert_true(error is @moonxml.XmlErrorKind::InvalidSyntax(_))
      assert_eq(span.start.line, 1)
      assert_eq(span.start.column, 7)
    }
  }
}

///|
/// 命名空间解析语义落在树里(适配层职责,spec §1.4)。
test "model/namespace-resolution" {
  let document = match
    @moonxml.parse(
      "<r xmlns:p=\"http://e/x\" xmlns=\"http://e/d\"><p:a p:k=\"1\"><b/></p:a></r>",
    ) {
    Ok(document) => document
    Err(_) => fail("namespace corpus must parse")
  }
  let child = match document.root.children[0] {
    @moonxml.Node::Element(element) => element
    _ => fail("expected element child")
  }
  assert_eq(child.name.qualified_name, "p:a")
  assert_eq(child.name.prefix, Some("p"))
  assert_eq(child.name.local_name, "a")
  assert_eq(child.name.namespace_uri, Some("http://e/x"))
  assert_eq(document.root.name.namespace_uri, Some("http://e/d"))
  assert_eq(child.attributes.length(), 1)
  assert_eq(child.attributes[0].name.namespace_uri, Some("http://e/x"))
  let grandchild = match child.children[0] {
    @moonxml.Node::Element(element) => element
    _ => fail("expected element grandchild")
  }
  assert_eq(grandchild.name.local_name, "b")
  assert_eq(grandchild.name.namespace_uri, Some("http://e/d"))
}

///|
/// xmlns 并回属性面(序列化面统一按属性发;前缀/缺省两形)。
test "model/xmlns-merged-back" {
  let document = match
    @moonxml.parse("<r xmlns:p=\"http://e/x\" xmlns=\"http://e/d\"/>") {
    Ok(document) => document
    Err(_) => fail("xmlns corpus must parse")
  }
  assert_eq(document.root.attributes.length(), 2)
  assert_eq(document.root.attributes[0].name.qualified_name, "xmlns:p")
  assert_eq(document.root.attributes[0].name.prefix, Some("xmlns"))
  assert_eq(document.root.attributes[0].name.local_name, "p")
  assert_eq(document.root.attributes[0].value, "http://e/x")
  assert_eq(document.root.attributes[1].name.qualified_name, "xmlns")
  assert_eq(document.root.attributes[1].name.prefix, None)
}

///|
/// 文档骨架落位:decl/doctype/前杂项/根/后杂项各就各位。
test "model/document-zones" {
  let source = "<?xml version=\"1.0\"?><!-- front --><?lead x?><!DOCTYPE r><r/><!-- back -->"
  let document = match @moonxml.parse(source) {
    Ok(document) => document
    Err(_) => fail("zone corpus must parse")
  }
  let declaration = match document.decl {
    Some(declaration) => declaration
    None => fail("declaration expected")
  }
  assert_eq(declaration.version, "1.0")
  assert_eq(document.doctype, Some("r"))
  assert_eq(document.prologue.length(), 2)
  assert_true(document.prologue[0] is @moonxml.Node::Comment(_))
  assert_true(
    document.prologue[1] is @moonxml.Node::PI(target="lead", data="x"),
  )
  assert_eq(document.epilogue.length(), 1)
  assert_true(document.epilogue[0] is @moonxml.Node::Comment(_))
}

///|
/// CDATA 与相邻文本分型保留(不并节点;序列化原形往返)。
test "model/cdata-kept-distinct" {
  let document = match @moonxml.parse("<d>a<![CDATA[<raw>&]]>b</d>") {
    Ok(document) => document
    Err(_) => fail("cdata corpus must parse")
  }
  assert_eq(document.root.children.length(), 3)
  assert_true(document.root.children[0] is @moonxml.Node::Text("a"))
  assert_true(document.root.children[1] is @moonxml.Node::CData("<raw>&"))
  assert_true(document.root.children[2] is @moonxml.Node::Text("b"))
  assert_eq(document.to_xml(), "<d>a<![CDATA[<raw>&]]>b</d>")
}

///|
/// 畸形输入拒绝面:未知实体/标签错配/空文档,均 Err。
test "error/malformed-rejections" {
  assert_true(@moonxml.parse("<d>&nope;</d>") is Err(_))
  assert_true(@moonxml.parse("") is Err(_))
  assert_true(@moonxml.parse("<d><a></b></d>") is Err(_))
}
