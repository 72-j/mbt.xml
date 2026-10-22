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
/// 外取件解码单元:无 decl 纯 UTF-8 原样通过。
test "external decode plain utf-8" {
  match decode_external(ext_bytes([0x61, 0x62])) {
    Ok(text) => assert_eq(text, "ab")
    Err(_) => fail("plain UTF-8 external piece must decode")
  }
}

///|
/// 外取件解码单元:BOM + text decl 完整剥除(BOM 容错 = R-B1d)。
test "external decode strips BOM and text decl" {
  let bytes = ext_bytes([
    0xEF, 0xBB, 0xBF, // UTF-8 BOM
     0x3C, 0x3F, 0x78, 0x6D, 0x6C, // "<?xml"
     0x20, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, // " version"
     0x3F, 0x3E, // "?>"
     0x61, // "a"
  ])
  match decode_external(bytes) {
    Ok(text) => assert_eq(text, "a")
    Err(_) => fail("BOM + text decl external piece must decode")
  }
}

///|
/// 外取件解码单元:text decl 声明 euc-jp → 真解码(J1 前端复用,
/// 0xA1 0xA1 = U+3000 全角空格)。
test "external decode honors text decl encoding" {
  let bytes = ext_bytes([
    0x3C, 0x3F, 0x78, 0x6D, 0x6C, // "<?xml"
     0x20, 0x65, 0x6E, 0x63, 0x6F, 0x64, 0x69, 0x6E, 0x67, // " encoding"
     0x3D, 0x22, 0x65, 0x75, 0x63, 0x2D, 0x6A, 0x70, 0x22, // '="euc-jp"'
     0x3F, 0x3E, // "?>"
     0xA1, 0xA1, // 全角空格
  ])
  match decode_external(bytes) {
    Ok(text) => assert_eq(text, "\u{3000}")
    Err(_) => fail("euc-jp external piece must decode via text decl")
  }
}

///|
/// 外取件解码单元:未闭合 "<?xml" 头不剥不吞——原样留给底座报错。
test "unterminated text decl stays" {
  let fragment = "<?xml version=\"1.0\""
  assert_eq(strip_text_declaration(fragment), fragment)
}
