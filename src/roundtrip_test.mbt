///|
/// 往返门：parse → to_xml → re-parse 字符串定点 + 树等价。
/// 语料对位 ctx.md §1 的 M0 探针八例（well-formed 族）。
/// 施工账：ctx.md §2（役M1）· §1（M0 探针）。

///|
/// 字符串定点:canonical(parse(canonical(parse(s)))) ≡ canonical(parse(s))。
/// 树等价另测(定点抓不住系统性丢节点,如全量吞注释)。
fn round_trips(source : String) -> Bool {
  match @moonxml.parse(source) {
    Ok(document) => {
      let first_pass = document.to_xml()
      match @moonxml.parse(first_pass) {
        Ok(reparsed) => reparsed.to_xml() == first_pass
        Err(_) => false
      }
    }
    Err(_) => false
  }
}

///|
/// 树等价:parse(s) ≡ parse(to_xml(parse(s)))。
fn trees_survive(source : String) -> Bool {
  match @moonxml.parse(source) {
    Ok(document) =>
      match @moonxml.parse(document.to_xml()) {
        Ok(reparsed) => document == reparsed
        Err(_) => false
      }
    Err(_) => false
  }
}

///|
test "roundtrip/nested" {
  let source = "<catalog><book><title>T1</title></book><book><title>T2</title></book></catalog>"
  assert_true(round_trips(source))
  assert_true(trees_survive(source))
}

///|
test "roundtrip/decl+doctype+entities" {
  let source = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE doc [<!ENTITY greeting \"hello\">]><doc>&greeting; &amp; &lt;tag&gt;</doc>"
  let document = match @moonxml.parse(source) {
    Ok(document) => document
    Err(_) => fail("parse failed: entity corpus must be well-formed")
  }
  assert_true(document.doctype == Some("doc"))
  assert_true(round_trips(source))
  assert_true(trees_survive(source))
}

///|
test "roundtrip/namespaces" {
  let source = "<svg:root xmlns:svg=\"http://www.w3.org/2000/svg\" xmlns=\"http://example.com/default\"><svg:child svg:attr=\"v\">t</svg:child><plain/></svg:root>"
  assert_true(round_trips(source))
  assert_true(trees_survive(source))
}

///|
test "roundtrip/cdata-comment-pi" {
  let source = "<doc><!-- note --><?printer mode=\"draft\"?><![CDATA[raw <stuff> & more]]>tail</doc>"
  assert_true(round_trips(source))
  assert_true(trees_survive(source))
}

///|
test "roundtrip/unicode-and-deep" {
  let unicode_source = "<文档 属性=\"值\">天籁 🎵 &amp; more</文档>"
  assert_true(round_trips(unicode_source))
  assert_true(trees_survive(unicode_source))
  let mut deep_source = "<root>"
  for _ in 0..<50 {
    deep_source += "<layer>"
  }
  for _ in 0..<50 {
    deep_source += "</layer>"
  }
  deep_source += "</root>"
  assert_true(round_trips(deep_source))
  assert_true(trees_survive(deep_source))
}

///|
test "roundtrip/multi-attributes-and-empty-root" {
  let source = "<a id=\"1\" class=\"x\" data-k=\"v\"/>"
  assert_true(round_trips(source))
  assert_true(trees_survive(source))
}
