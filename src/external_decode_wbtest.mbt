///|
/// 本地字节 helper(测试件三手病纪律:helper fns 不跨文件赌可见性)。
fn ext_bytes(items : Array[Int32]) -> Bytes {
  let out : Array[Byte] = []
  for item in items {
    out.push(item.to_byte())
  }
  Bytes::from_array(out[:])
}

///|
/// 准入结果包装(raise 归 Result,断言面用)。
fn admit_outcome(
  text : String,
  doc_version : String?,
) -> Result[String, XmlError] {
  Ok(admit_external_text(text, doc_version)) catch {
    why => Err(why)
  }
}

///|
/// 准入单元:无 decl 纯 UTF-8 原样通过(零漂移保底)。
test "admit plain utf-8 passes" {
  match admit_outcome("ab", None) {
    Ok(body) => assert_eq(body, "ab")
    Err(_) => fail("plain UTF-8 external piece must pass")
  }
}

///|
/// 准入单元:BOM + 完整 text decl 剥除(BOM 容错 = R-B1d)。
test "admit strips BOM and text decl" {
  let bytes = ext_bytes([
    0xEF, 0xBB, 0xBF, // UTF-8 BOM
     0x3C, 0x3F, 0x78, 0x6D, 0x6C, // "<?xml"
     0x20, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, // " version"
     0x3D, 0x22, 0x31, 0x2E, 0x30, 0x22, // '="1.0"'
     0x20, 0x65, 0x6E, 0x63, 0x6F, 0x64, 0x69, 0x6E, 0x67, // " encoding"
     0x3D, 0x22, 0x55, 0x54, 0x46, 0x2D, 0x38, 0x22, // '="UTF-8"'
     0x3F, 0x3E, // "?>"
     0x61, // "a"
  ])
  match decode_source(bytes) {
    Ok(raw) =>
      match admit_outcome(raw, None) {
        Ok(body) => assert_eq(body, "a")
        Err(_) => fail("BOM + text decl piece must pass")
      }
    Err(_) => fail("BOM + UTF-8 piece must decode")
  }
}

///|
/// 准入单元:text decl 声明 euc-jp → 真解码(J1 前端复用,0xA1 0xA1 =
/// U+3000 全角空格)。
test "admit honors text decl encoding" {
  let bytes = ext_bytes([
    0x3C, 0x3F, 0x78, 0x6D, 0x6C, // "<?xml"
     0x20, 0x65, 0x6E, 0x63, 0x6F, 0x64, 0x69, 0x6E, 0x67, // " encoding"
     0x3D, 0x22, 0x65, 0x75, 0x63, 0x2D, 0x6A, 0x70, 0x22, // '="euc-jp"'
     0x3F, 0x3E, // "?>"
     0xA1, 0xA1, // 全角空格
  ])
  match decode_source(bytes) {
    Ok(raw) =>
      match admit_outcome(raw, None) {
        Ok(body) => assert_eq(body, "\u{3000}")
        Err(_) => fail("euc-jp piece must decode via text decl")
      }
    Err(_) => fail("euc-jp piece must decode")
  }
}

///|
/// T 闸:缺 encoding = 拒(P77 encoding 必备;dtd07)。
test "text decl without encoding rejects" {
  match admit_outcome("<?xml version=\"1.0\"?><!ELEMENT r EMPTY>", None) {
    Ok(_) => fail("text decl without encoding must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// T 闸:standalone 越权 = 拒(P77 无 SDDecl 位;ext-sa/002)。
test "standalone in text decl rejects" {
  match admit_outcome("<?xml version=\"1.0\" standalone=\"yes\"?>data", None) {
    Ok(_) => fail("standalone in text decl must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// T 闸:version 晚于 encoding(序位倒置)= 拒(P77 序位)。
test "version after encoding rejects" {
  match admit_outcome("<?xml encoding=\"UTF-8\" version=\"1.0\"?>", None) {
    Ok(_) => fail("version after encoding must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// T 闸:版本词形越界 = 拒(VersionNum 只认 1.0/1.1;009.ent 42.88 形)。
test "implausible version rejects" {
  match admit_outcome("<?xml version=\"42.88\" encoding=\"utf-8\"?>", None) {
    Ok(_) => fail("implausible version must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// V 闸:1.1 件在无声明(=1.0)文档 = 拒(only-later;E38/eduni 003)。
test "entity version later than document rejects" {
  match
    admit_outcome("<?xml version=\"1.1\" encoding=\"utf-8\"?>some text", None) {
    Ok(_) => fail("1.1 entity under 1.0 document must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// V 闸:1.0 件在 1.1 文档 = 合法(only-later 非相等;ibm77v01 校准)。
test "entity version 1.0 under 1.1 document accepts" {
  match
    admit_outcome(
      "<?xml version='1.0' encoding='UTF-8'?><!ELEMENT r EMPTY>",
      Some("1.1"),
    ) {
    Ok(_) => ()
    Err(_) => fail("1.0 entity under 1.1 document must accept")
  }
}

///|
/// T 闸:NEL 分隔符在非 1.1 文档面 = 拒(S 1.0 无 #x85;n17)。
test "nel separator under 1.0 document rejects" {
  match admit_outcome("<?xml version=\"1.0\" \u{85} encoding='UTF-8'?>", None) {
    Ok(_) => fail("NEL separator under 1.0 document must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// T 闸:NEL 分隔符在 1.1 文档面 = 合法(S 1.1 增 #x85/#x2028;校准钉)。
test "nel separator under 1.1 document accepts" {
  match
    admit_outcome("<?xml version='1.1' \u{85} encoding='UTF-8'?>", Some("1.1")) {
    Ok(_) => ()
    Err(_) => fail("NEL separator under 1.1 document must accept")
  }
}

///|
/// Char 门:件体字面控制字符 = 拒(1.1 restricted-literal;n04  形)。
test "literal control char in body rejects" {
  match
    admit_outcome("<?xml version='1.0' encoding='UTF-8'?>\u{89}", Some("1.1")) {
    Ok(_) => fail("literal control char must reject")
    Err(At(error=IllegalChar(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// Char 门:字符引用 = ASCII 文本,天然放行(ibm77v22-29 校准钉)。
test "char reference passes char gate" {
  match
    admit_outcome(
      "<?xml version='1.1' encoding='UTF-8'?>&#x007F;&#x0080;",
      Some("1.1"),
    ) {
    Ok(body) => assert_eq(body, "&#x007F;&#x0080;")
    Err(_) => fail("char reference must pass the char gate")
  }
}

///|
/// T 闸:未闭合 text decl(缺 ?>)= 拒(ibm 1.0 面 P77 n03/n04 形)。
test "unterminated text decl rejects" {
  match admit_outcome("<?xml version=\"1.0\"", None) {
    Ok(_) => fail("unterminated text decl must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// 触发面:PI 目标 xmlfoo 不是 text decl,不归本闸(原样过)。
test "xml-prefixed pi target is not a text decl" {
  match admit_outcome("<?xmlfoo data?>rest", None) {
    Ok(body) => assert_eq(body, "<?xmlfoo data?>rest")
    Err(_) => fail("xml-prefixed PI target must pass through")
  }
}
