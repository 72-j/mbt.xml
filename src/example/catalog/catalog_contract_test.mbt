///|
/// 联调门:parse → from_tree → to_tree → 再 parse → from_tree——
/// 值级等价 + 字符串定点(生成骨架正确性由消费端真链路钉,spec 卷一完成门)。
test "catalog roundtrip via generated skeleton" {
  let source = "<?xml version=\"1.0\"?><catalog version=\"2.1\" xml:lang=\"en\"><book isbn=\"i1\"><title>t1</title><author>a1</author><author>a2</author></book><book isbn=\"i2\"><title>t2</title><author>a3</author></book><meta><marker/></meta></catalog>"
  let document = match @moonxml.parse(source) {
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
  assert_true(doc.meta is Some(_))
  // 值级往返:to_tree 产物 → to_xml → 再 parse → 再 from_tree ≡ 原值(Eq)
  let second_source = @moonxml.Document::{
    decl: None,
    doctype: None,
    prologue: [],
    root: doc.to_tree(),
    epilogue: [],
  }.to_xml()
  let second_document = match @moonxml.parse(second_source) {
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
