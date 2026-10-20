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
