///|
/// X2 主链烟测（黑盒，内联 XML；套件级验证住 rdf_suite_test.mbt）。

///|
fn smoke_term_str(term : @rdf.Term) -> String {
  match term {
    Iri(iri) => "<\{iri}>"
    BNode(label) => "_:\{label}"
    Literal(value, lang, datatype, direction) => {
      let mut out = "\"\{value}\""
      match lang {
        Some(l) => out = out + "@\{l}"
        None => ()
      }
      match direction {
        Some(dir) => out = out + "--\{dir}"
        None => ()
      }
      match datatype {
        Some(d) => out = out + "^^<\{d}>"
        None => ()
      }
      out
    }
    TripleTerm(subject, predicate, object) =>
      "<<(" +
      smoke_term_str(subject) +
      " " +
      smoke_term_str(predicate) +
      " " +
      smoke_term_str(object) +
      ")>>"
  }
}

///|
fn smoke_quad_strs(dataset : @rdf.Dataset) -> Array[String] {
  let out : Array[String] = []
  for quad in dataset.quads {
    out.push(
      "\{smoke_term_str(quad.subject)} \{smoke_term_str(quad.predicate)} \{smoke_term_str(quad.object)}",
    )
  }
  out
}

///|
test "smoke: about/resource/typed node" {
  let xml =
    $|<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    $|  xmlns:ex="http://example.org/">
    $|  <rdf:Description rdf:about="http://example.org/a">
    $|    <ex:p rdf:resource="http://example.org/b"/>
    $|  </rdf:Description>
    $|</rdf:RDF>
  let dataset = match @rdf.parse_rdf_xml(xml) {
    Ok(dataset) => dataset
    Err(msg) => fail(msg)
  }
  let got = smoke_quad_strs(dataset)
  assert_eq(got.length(), 1)
  assert_eq(
    got[0],
    "<http://example.org/a> <http://example.org/p> <http://example.org/b>",
  )
}

///|
test "smoke: typed node element + property attribute + xml:lang" {
  let xml =
    $|<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    $|  xmlns:ex="http://example.org/" xml:lang="en">
    $|  <ex:Doc rdf:about="http://example.org/a" ex:title="hello">
    $|    <ex:name>al</ex:name>
    $|  </ex:Doc>
    $|</rdf:RDF>
  let dataset = match @rdf.parse_rdf_xml(xml) {
    Ok(dataset) => dataset
    Err(msg) => fail(msg)
  }
  let got = smoke_quad_strs(dataset)
  // ex:Doc 类型词 + ex:title 属性属性 + ex:name 文本字面量（带 lang）
  assert_eq(got.length(), 3)
  assert_true(
    got.contains(
      "<http://example.org/a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/Doc>",
    ),
  )
  assert_true(
    got.contains(
      "<http://example.org/a> <http://example.org/title> \"hello\"@en",
    ),
  )
  assert_true(
    got.contains("<http://example.org/a> <http://example.org/name> \"al\"@en"),
  )
}

///|
test "smoke: nodeID 共指 + xml:base 叠加" {
  let xml =
    $|<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    $|  xmlns:ex="http://example.org/"
    $|  xml:base="http://base.org/dir/f.rdf">
    $|  <rdf:Description rdf:nodeID="x">
    $|    <ex:link rdf:resource="g.rdf"/>
    $|    <ex:p rdf:nodeID="x"/>
    $|  </rdf:Description>
    $|</rdf:RDF>
  let dataset = match @rdf.parse_rdf_xml(xml) {
    Ok(dataset) => dataset
    Err(msg) => fail(msg)
  }
  let got = smoke_quad_strs(dataset)
  assert_eq(got.length(), 2)
  // 同 nodeID = 同 bnode 标签；base 叠加解析到位
  assert_true(got[0].has_prefix("_:"))
  assert_true(got[0].has_suffix("<http://base.org/dir/g.rdf>"))
  assert_true(got[1].has_prefix("_:"))
  assert_true(got[1].has_suffix("_:bnode0"))
}

///|
test "smoke: rdf:li 拨号 + datatype 字面量" {
  let xml =
    $|<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    $|  xmlns:ex="http://example.org/">
    $|  <rdf:Description rdf:about="http://example.org/list">
    $|    <rdf:li>1</rdf:li>
    $|    <rdf:li rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">2</rdf:li>
    $|  </rdf:Description>
    $|</rdf:RDF>
  let dataset = match @rdf.parse_rdf_xml(xml) {
    Ok(dataset) => dataset
    Err(msg) => fail(msg)
  }
  let got = smoke_quad_strs(dataset)
  assert_eq(got.length(), 2)
  assert_true(
    got.contains(
      "<http://example.org/list> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_1> \"1\"",
    ),
  )
  assert_true(
    got.contains(
      "<http://example.org/list> <http://www.w3.org/1999/02/22-rdf-syntax-ns#_2> \"2\"^^<http://www.w3.org/2001/XMLSchema#integer>",
    ),
  )
}

///|
test "smoke: 负例门（无前缀属性 / 真空属性元素 = bnode）" {
  let xml =
    $|<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    $|  xmlns:ex="http://example.org/">
    $|  <rdf:Description rdf:about="http://example.org/a" title="x"/>
    $|</rdf:RDF>
  match @rdf.parse_rdf_xml(xml) {
    Ok(_) => fail("无前缀属性应报错")
    Err(_) => ()
  }
  let empty_xml =
    $|<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    $|  xmlns:ex="http://example.org/">
    $|  <rdf:Description rdf:about="http://example.org/a">
    $|    <ex:p/>
    $|  </rdf:Description>
    $|</rdf:RDF>
  let dataset = match @rdf.parse_rdf_xml(empty_xml) {
    Ok(dataset) => dataset
    Err(msg) => fail(msg)
  }
  assert_eq(dataset.quads.length(), 1)
  // 真空形 = 空字面量（RDF 1.1 §7.2.24；套件 test002/008 同裁）
  assert_eq(smoke_term_str(dataset.quads[0].object), "\"\"")
}
