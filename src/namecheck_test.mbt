///|
/// 役E1 名字段门单元(黑盒,pub 面用):版本面键控(4e 全表 vs 5e 紧凑)、
/// 版本键控(1.1 文档不受版本面影响)、树面全查(PI/元素/属性)、
/// 词表钉实报形(IllegalName 消息含码点)。

///|
fn kind_of(result : Result[@moonxml.Document, @moonxml.XmlError]) -> String {
  match result {
    Ok(_) => "ok"
    Err(At(error=@moonxml.IllegalName(message), ..)) =>
      "IllegalName(\{message})"
    Err(At(error~, ..)) => "kind:\{error_to_text(error)}"
  }
}

///|
fn error_to_text(error : @moonxml.XmlErrorKind) -> String {
  match error {
    @moonxml.UnexpectedEof => "UnexpectedEof"
    @moonxml.InvalidSyntax(message) => "InvalidSyntax(\{message})"
    @moonxml.UnmatchedTag(expected~, found~) =>
      "UnmatchedTag(\{expected},\{found})"
    @moonxml.InvalidAttribute(message) => "InvalidAttribute(\{message})"
    @moonxml.InvalidEntity(message) => "InvalidEntity(\{message})"
    @moonxml.Encoding(message) => "Encoding(\{message})"
    @moonxml.IllegalChar(codepoint) => "IllegalChar(\{codepoint})"
    @moonxml.IllegalName(message) => "IllegalName(\{message})"
    @moonxml.Structure(message) => "Structure(\{message})"
    @moonxml.External(message) => "External(\{message})"
  }
}

///|
test "PI target: U+0132 rejected on editions 1-4, accepted on edition 5" {
  // 套件对样:ibm/not-wf/P85/ibm85n03(2-4 版判词)vs errata-4e/ibm85n03(5 版判词)
  let source = "<?\u{0132} pi data?><doc/>"
  let old_face = kind_of(
    @moonxml.parse_edition(source, edition=@moonxml.Editions1to4),
  )
  assert_true(old_face.contains("IllegalName"))
  assert_true(old_face.contains("#x132"))
  assert_true(old_face.contains("start character"))
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Edition5)),
    "ok",
  )
}

///|
test "element name: long s rejected on editions 1-4, accepted on edition 5" {
  let source = "<egg\u{017F}/>"
  assert_true(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Editions1to4)).contains(
      "IllegalName",
    ),
  )
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Edition5)),
    "ok",
  )
}

///|
test "middle dot is a 1.0 NameChar (Extender) in editions 1-4" {
  let source = "<a\u{00B7}/>"
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Editions1to4)),
    "ok",
  )
}

///|
test "combining char start: rejected at base wordface before the gate" {
  // 5e/1.1 紧凑表首字不含组合字符——底座 split_qualified_name 先拒(InvalidSyntax),
  // 门不可达;门只在 ≤4e 面新增拒绝(5e 面门 ⊆ 底座,零新增)。
  let source = "<\u{0300}x/>"
  match @moonxml.parse_edition(source, edition=@moonxml.Editions1to4) {
    Err(At(error=@moonxml.InvalidSyntax(_), ..)) => ()
    other => fail("expected base InvalidSyntax, got \{kind_of(other)}")
  }
}

///|
test "version 1.1 document ignores edition knob (compact tables always)" {
  let source = "<?xml version=\"1.1\"?><?\u{0132} pi?><egg\u{017F}/>"
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Editions1to4)),
    "ok",
  )
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Edition5)),
    "ok",
  )
}

///|
test "no declaration defaults to 1.0 face" {
  let source = "<?\u{0132} pi?><doc/>"
  assert_true(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Editions1to4)).contains(
      "IllegalName",
    ),
  )
}

///|
test "attribute name gated on both faces" {
  let source = "<doc a\u{0132}=\"v\"/>"
  assert_true(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Editions1to4)).contains(
      "IllegalName",
    ),
  )
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Edition5)),
    "ok",
  )
}

///|
test "parse equals parse_edition at edition 5 (default face)" {
  let source = "<?xml version=\"1.0\"?><doc a=\"b\">text</doc>"
  assert_true(
    @moonxml.parse(source) ==
    @moonxml.parse_edition(source, edition=@moonxml.Edition5),
  )
}

///|
test "wordface message pins the offending name text" {
  let source = "<?\u{0132}x?><doc/>"
  match @moonxml.parse_edition(source, edition=@moonxml.Editions1to4) {
    Ok(_) => fail("must reject")
    Err(At(error=@moonxml.IllegalName(message), ..)) =>
      assert_true(message.contains("\"\u{0132}x\""))
    Err(other) =>
      match other {
        At(error=kind, ..) => fail("wrong kind: \{error_to_text(kind)}")
      }
  }
}

///|
test "names legal in both faces pass (namespace-qualified forms)" {
  let source = "<a:b xmlns:a=\"urn:x\" xml:lang=\"en\"><c.d-e_f/></a:b>"
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Editions1to4)),
    "ok",
  )
  assert_eq(
    kind_of(@moonxml.parse_edition(source, edition=@moonxml.Edition5)),
    "ok",
  )
}

///|
/// 役N1 NS 模式旗标:非 NS 面(名字原文直通/xmlns 即普通属性/无前缀解析)
/// 与 NS-on 面的树形状钉。

///|
test "ns-off: colon names accepted (element, attribute, PI target)" {
  let source = "<?PITarget: with colon?><:lead a:b=\"v\" tail:=\"w\"><x:y/></:lead>"
  assert_eq(
    kind_of(
      @moonxml.parse_edition(
        source,
        edition=@moonxml.Editions1to4,
        ns=@moonxml.Off,
      ),
    ),
    "ok",
  )
}

///|
test "ns-off: combining char after colon accepted on 4e face" {
  // 套件对样 oasis/p04pass1:NS-always-on 下必拒,非 NS 面 1.0 合法
  let source = "<A.-:\u{0300}\u{00B7}/>"
  assert_eq(
    kind_of(
      @moonxml.parse_edition(
        source,
        edition=@moonxml.Editions1to4,
        ns=@moonxml.Off,
      ),
    ),
    "ok",
  )
}

///|
test "ns-off: xmlns is an ordinary attribute kept in place" {
  let source = "<doc xmlns=\"urn:d\" a=\"1\" xmlns:p=\"urn:p\"/>"
  match
    @moonxml.parse_edition(source, edition=@moonxml.Edition5, ns=@moonxml.Off) {
    Ok(document) => {
      let attributes = document.root.attributes
      assert_eq(attributes.length(), 3)
      assert_eq(attributes[0].name.qualified_name, "xmlns")
      assert_eq(attributes[1].name.qualified_name, "a")
      assert_eq(attributes[2].name.qualified_name, "xmlns:p")
      // 非 NS 面:无命名空间语义可记
      assert_true(attributes[0].name.namespace_uri is None)
      assert_true(document.root.name.prefix is None)
      assert_eq(document.root.name.local_name, "doc")
    }
    Err(_) => fail("ns-off must accept")
  }
}

///|
test "ns-off: unbound prefix accepted (no NS resolution)" {
  let source = "<p:doc p:attr=\"v\"/>"
  assert_eq(
    kind_of(
      @moonxml.parse_edition(source, edition=@moonxml.Edition5, ns=@moonxml.Off),
    ),
    "ok",
  )
}

///|
test "ns-on unchanged: unbound prefix still rejected" {
  let source = "<p:doc/>"
  match
    @moonxml.parse_edition(source, edition=@moonxml.Edition5, ns=@moonxml.On) {
    Err(At(error=@moonxml.InvalidSyntax(message), ..)) =>
      assert_true(message.contains("undeclared namespace prefix"))
    other => fail("ns-on must reject unbound prefix: \{other_is_err(other)}")
  }
}

///|
fn other_is_err(
  result : Result[@moonxml.Document, @moonxml.XmlError],
) -> String {
  match result {
    Ok(_) => "parsed ok"
    Err(At(error~, ..)) => error_to_text(error)
  }
}
