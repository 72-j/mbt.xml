///|
/// 联调门:parse → from_tree → to_tree → 再 parse → from_tree——
/// 值级等价 + 字符串定点（生成骨架的正确性由消费端真链路验证；spec 卷一完成门）。
test "catalog roundtrip via generated skeleton" {
  let source = "<?xml version=\"1.0\"?><catalog version=\"2.1\" xml:lang=\"en\"><book isbn=\"i1\" year=\"2020\" in_print=\"true\"><title>t1</title><author>a1</author><author>a2</author><pages>320</pages></book><book isbn=\"i2\" year=\"1999\" price=\"42.8\" in_print=\"false\"><title>t2</title><author>a3</author><pages>288</pages></book><meta><marker/></meta></catalog>"
  let document = match @base.parse(source) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  let doc = match @catalog.doc_from_tree(document.root) {
    Ok(value) => value
    Err(msg) => abort("from_tree failed: \{msg}")
  }
  // 表序收数断言:属性(必带 + xml:lang)/ 重复孩子 / 恰一叶 / any 透传
  assert_eq(doc.version, "2.1")
  assert_eq(doc.lang, Some("en"))
  assert_eq(doc.book.length(), 2)
  assert_eq(doc.book[0].isbn, "i1")
  assert_eq(doc.book[0].title, "t1")
  assert_eq(doc.book[0].author.length(), 2)
  assert_eq(doc.book[1].author[0], "a3")
  // 型别实弹断言(用例役):Int32 收数 / Double? 0..1 / Bool / 型别叶
  assert_eq(doc.book[0].year, 2020)
  assert_eq(doc.book[0].pages, 320)
  assert_true(doc.book[0].price is None)
  assert_eq(doc.book[1].price, Some(42.8))
  assert_eq(doc.book[1].in_print, false)
  assert_true(doc.meta is Some(_))
  // 值级往返:to_tree 产物 → to_xml → 再 parse → 再 from_tree ≡ 原值(Eq)
  let second_source = @base.Document::{
    decl: None,
    doctype: None,
    prologue: [],
    root: doc.to_tree(),
    epilogue: [],
  }.to_xml()
  let second_document = match @base.parse(second_source) {
    Ok(value) => value
    Err(_) => abort("re-parse failed")
  }
  let doc2 = match @catalog.doc_from_tree(second_document.root) {
    Ok(value) => value
    Err(msg) => abort("second from_tree failed: \{msg}")
  }
  assert_true(doc2 == doc)
  // 字符串定点:再解析后的文档再序列化 = 逐字节同
  assert_eq(second_document.to_xml(), second_source)
}

///|
/// 拍1(2026-10-22):node 内非空白散文本 = 红;空白文本(排版)容忍。
test "catalog stray text in node is rejected, blank tolerated" {
  let with_stray = match
    @base.parse(
      "<?xml version=\"1.0\"?><catalog version=\"2.1\">stray<book isbn=\"i1\" year=\"2020\" in_print=\"true\"><title>t1</title><pages>1</pages></book></catalog>",
    ) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  match @catalog.doc_from_tree(with_stray.root) {
    Err(msg) => assert_true(msg.contains("stray text"))
    Ok(_) => fail("stray text must be rejected")
  }
  let with_blank = match
    @base.parse(
      "<?xml version=\"1.0\"?><catalog version=\"2.1\"> <book isbn=\"i1\" year=\"2020\" in_print=\"true\"><title>t1</title><pages>1</pages></book> </catalog>",
    ) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  assert_true(@catalog.doc_from_tree(with_blank.root) is Ok(_))
}

///|
/// 拍2(2026-10-22):CDATA 叶 = 载荷(infoset 等价;Text/CData 按序拼合)。
test "catalog CDATA leaf is text payload" {
  let source = "<?xml version=\"1.0\"?><catalog version=\"2.1\"><book isbn=\"i1\" year=\"2020\" in_print=\"true\"><title>a<![CDATA[b]]>c</title><pages>3</pages></book></catalog>"
  let document = match @base.parse(source) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  let doc = match @catalog.doc_from_tree(document.root) {
    Ok(value) => value
    Err(msg) => abort("from_tree failed: \{msg}")
  }
  assert_eq(doc.book[0].title, "abc")
}

///|
/// 类型转换负例三条：词法域外值 = 红，错误消息带 helper 域标
/// （xmlschema: not an int/double/bool）。
test "catalog typed conversion failures are red" {
  // int 词法域外:year="abc"
  let bad_int = match
    @base.parse(
      "<catalog version=\"2.1\"><book isbn=\"i1\" year=\"abc\" in_print=\"true\"><title>t</title><pages>1</pages></book></catalog>",
    ) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  match @catalog.doc_from_tree(bad_int.root) {
    Err(msg) => assert_true(msg.contains("not an int"))
    Ok(_) => fail("bad int must be red")
  }
  // double 词法域外:price="x"
  let bad_double = match
    @base.parse(
      "<catalog version=\"2.1\"><book isbn=\"i1\" year=\"2020\" price=\"x\" in_print=\"true\"><title>t</title><pages>1</pages></book></catalog>",
    ) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  match @catalog.doc_from_tree(bad_double.root) {
    Err(msg) => assert_true(msg.contains("not a double"))
    Ok(_) => fail("bad double must be red")
  }
  // bool 词法域外:in_print="yes"(xsd:boolean 域 = true/false/1/0)
  let bad_bool = match
    @base.parse(
      "<catalog version=\"2.1\"><book isbn=\"i1\" year=\"2020\" in_print=\"yes\"><title>t</title><pages>1</pages></book></catalog>",
    ) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  match @catalog.doc_from_tree(bad_bool.root) {
    Err(msg) => assert_true(msg.contains("not a bool"))
    Ok(_) => fail("bad bool must be red")
  }
}

///|
/// 用例役(2026-10-22):挂点第一件真语义——stubs.mbt 里 stub_validate_book
/// 的 isbn 非空形校验。骨架捕获挂点 Err 后加 "book: " 前缀透出。
test "catalog hook semantic: empty isbn rejected via stub" {
  let source = "<catalog version=\"2.1\"><book isbn=\"\" year=\"2020\" in_print=\"true\"><title>t</title><pages>1</pages></book></catalog>"
  let document = match @base.parse(source) {
    Ok(value) => value
    Err(_) => abort("parse failed")
  }
  match @catalog.doc_from_tree(document.root) {
    Err(msg) => assert_true(msg.contains("book: isbn must not be empty"))
    Ok(_) => fail("empty isbn must be rejected by the stub hook")
  }
}
