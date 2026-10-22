///|
/// 序区扫描单元:无 doctype → None。
test "doctype scan absent" {
  assert_true(scan_doctype("<a/>") is None)
  assert_true(scan_doctype("<!-- c --><a/>") is None)
}

///|
/// 序区扫描单元:SYSTEM id 提取,无子集。
test "doctype scan system id" {
  match
    scan_doctype("<?xml version=\"1.0\"?><!DOCTYPE r SYSTEM \"s.dtd\"><a/>") {
    Some(scan) => {
      assert_eq(scan.system_id, Some("s.dtd"))
      assert_true(scan.public_id is None)
      assert_true(scan.subset_start < 0)
    }
    None => fail("SYSTEM doctype must scan")
  }
}

///|
/// 序区扫描单元:PUBLIC 双 id + 内部子集界提取。
test "doctype scan public and subset" {
  let text = "<!DOCTYPE r PUBLIC \"p-id\" \"s.dtd\" [ <!ENTITY e \"v\"> ]><a/>"
  match scan_doctype(text) {
    Some(scan) => {
      assert_eq(scan.public_id, Some("p-id"))
      assert_eq(scan.system_id, Some("s.dtd"))
      let subset = text[scan.subset_start:scan.subset_end].to_owned()
      assert_eq(subset, " <!ENTITY e \"v\"> ")
    }
    None => fail("PUBLIC doctype must scan")
  }
}

///|
/// 序区扫描单元:子集内引号值与注释中的 ']' 不误判收口。
test "doctype scan subset bracket awareness" {
  let text = "<!DOCTYPE r SYSTEM \"s\" [ <!-- ] --> <!ENTITY e \"]>\"> ]><a/>"
  match scan_doctype(text) {
    Some(scan) => {
      let subset = text[scan.subset_start:scan.subset_end].to_owned()
      assert_true(subset.contains("<!ENTITY e \"]>\">"))
    }
    None => fail("bracket-aware subset scan must close")
  }
}
