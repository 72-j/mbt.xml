///|
/// 单元门：编码前端 + 版本键控 Char 门。
/// 套件级读数在 xmlconf_suite_test；本件覆盖机制单元
/// (BOM 嗅探/严格 UTF-8/UTF-16 代理/支持编码集/冲突/两版 Char 表)。
/// 施工账：ctx.md §5（役A1）。

///|
fn bytes_of(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
/// 文本 → 码位序列(含 BOM 前缀的 UTF-16 字节形;增面字符走代理对)。
fn utf16_bytes_of(input : String, big_endian : Bool) -> Array[Byte] {
  let out : Array[Byte] = []
  let bom : Array[Byte] = if big_endian { [0xFE, 0xFF] } else { [0xFF, 0xFE] }
  for byte in bom {
    out.push(byte)
  }
  for _, ch in input.iter2() {
    let codepoint = ch.to_int()
    if codepoint >= 0x10000 {
      let value = codepoint - 0x10000
      let high = 0xD800 + value / 0x400
      let low = 0xDC00 + value % 0x400
      push_utf16_unit(out, high, big_endian)
      push_utf16_unit(out, low, big_endian)
    } else {
      push_utf16_unit(out, codepoint, big_endian)
    }
  }
  out
}

///|
fn push_utf16_unit(out : Array[Byte], unit : Int32, big_endian : Bool) -> Unit {
  let high_byte = (unit / 256).to_byte()
  let low_byte = (unit % 256).to_byte()
  if big_endian {
    out.push(high_byte)
    out.push(low_byte)
  } else {
    out.push(low_byte)
    out.push(high_byte)
  }
}

///|
test "utf-8 plain document passes through" {
  match @base.decode_source(Bytes::from_array(bytes_of("<a>hi</a>")[:])) {
    Ok(text) => assert_eq(text, "<a>hi</a>")
    Err(_) => fail("plain UTF-8 must decode")
  }
}

///|
test "utf-8 BOM is stripped" {
  let parts = bytes_of("<a/>")
  let with_bom : Array[Byte] = [0xEF, 0xBB, 0xBF]
  for byte in parts {
    with_bom.push(byte)
  }
  match @base.decode_source(Bytes::from_array(with_bom[:])) {
    Ok(text) => assert_eq(text, "<a/>")
    Err(_) => fail("UTF-8 BOM document must decode")
  }
}

///|
test "malformed utf-8 (CESU surrogate) is rejected" {
  let parts = bytes_of("<a>")
  let broken : Array[Byte] = [0xED, 0xA0, 0x80]
  for byte in broken {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => fail("CESU-8 surrogate must be rejected")
    Err(@base.XmlError::At(error~, span~)) => {
      assert_true(error is @base.XmlErrorKind::Encoding(_))
      assert_eq(span.start.offset, 3)
    }
  }
}

///|
test "invalid utf-8 lead byte is rejected" {
  let parts = bytes_of("<a>")
  let broken : Array[Byte] = [0xF7, 0x80, 0x80, 0x80]
  for byte in broken {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => fail("invalid lead byte must be rejected")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "utf-16 LE with BOM decodes" {
  let bytes = utf16_bytes_of("<a/>\n", false)
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(text) => assert_eq(text, "<a/>\n")
    Err(_) => fail("UTF-16LE document must decode")
  }
}

///|
test "utf-16 BE with BOM decodes astral surrogate pair" {
  let bytes = utf16_bytes_of("<a>𝄞</a>", true)
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(text) => assert_eq(text, "<a>𝄞</a>")
    Err(_) => fail("UTF-16BE with surrogate pair must decode")
  }
}

///|
test "utf-16 odd byte length is rejected" {
  let bytes = utf16_bytes_of("<a/>", true)
  bytes.push((0x00).to_byte())
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => fail("odd UTF-16 length must be rejected")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "utf-16 unpaired high surrogate is rejected" {
  let bytes : Array[Byte] = [0xFE, 0xFF]
  push_utf16_unit(bytes, 0xD834, true)
  push_utf16_unit(bytes, 0x0041, true)
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => fail("unpaired surrogate must be rejected")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "declared euc-jp decodes jis0208 body" {
  let parts = bytes_of("<?xml version=\"1.0\" encoding=\"euc-jp\"?><a>")
  let body : Array[Byte] = [0xA1, 0xA1]
  for byte in body {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(text) =>
      assert_eq(
        text, "<?xml version=\"1.0\" encoding=\"euc-jp\"?><a>\u{3000}</a>",
      )
    Err(_) => fail("declared euc-jp must decode (役J1)")
  }
}

///|
test "declared shift_jis decodes kanji body" {
  let parts = bytes_of("<?xml version=\"1.0\" encoding=\"shift_jis\"?><a>")
  let body : Array[Byte] = [0x93, 0xFA]
  for byte in body {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(text) =>
      assert_eq(
        text, "<?xml version=\"1.0\" encoding=\"shift_jis\"?><a>日</a>",
      )
    Err(_) => fail("declared shift_jis must decode (役J1)")
  }
}

///|
test "declared iso-2022-jp decodes escape-switched body" {
  let parts = bytes_of("<?xml version=\"1.0\" encoding=\"iso-2022-jp\"?><a>")
  let body : Array[Byte] = [0x1B, 0x24, 0x42, 0x30, 0x21, 0x1B, 0x28, 0x42]
  for byte in body {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(text) =>
      assert_eq(
        text, "<?xml version=\"1.0\" encoding=\"iso-2022-jp\"?><a>亜</a>",
      )
    Err(_) => fail("declared iso-2022-jp must decode (役J1)")
  }
}

///|
test "declared koi8-r is rejected as unsupported" {
  let bytes = bytes_of("<?xml version=\"1.0\" encoding=\"koi8-r\"?><a/>")
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => fail("koi8-r is outside the supported set")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "declared utf-16 without BOM is rejected" {
  let bytes = bytes_of("<?xml version=\"1.0\" encoding=\"utf-16\"?><a/>")
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => fail("utf-16 declaration requires a BOM")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "utf-8 BOM with iso-8859-1 declaration is a conflict" {
  let with_bom : Array[Byte] = [0xEF, 0xBB, 0xBF]
  for byte in bytes_of("<?xml version=\"1.0\" encoding=\"iso-8859-1\"?><x/>") {
    with_bom.push(byte)
  }
  match @base.decode_source(Bytes::from_array(with_bom[:])) {
    Ok(_) => fail("BOM/declaration conflict must be rejected")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "utf-16 BOM with utf-8 declaration is a conflict" {
  let bytes = utf16_bytes_of(
    "<?xml version=\"1.0\" encoding=\"utf-8\"?><x/>", true,
  )
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => fail("BOM/declaration conflict must be rejected")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::Encoding(_))
  }
}

///|
test "utf-16 BOM with matching declaration passes" {
  let bytes = utf16_bytes_of(
    "<?xml version='1.0' encoding='UTF-16'?><root/>", true,
  )
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(text) =>
      assert_eq(text, "<?xml version='1.0' encoding='UTF-16'?><root/>")
    Err(_) => fail("matching UTF-16 declaration must pass")
  }
}

///|
test "iso-8859-1 body decodes byte-per-character" {
  let parts = bytes_of("<?xml version=\"1.0\" encoding=\"iso-8859-1\"?><a>")
  parts.push((0xE9).to_byte())
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(text) =>
      assert_eq(
        text, "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?><a>é</a>",
      )
    Err(_) => fail("iso-8859-1 document must decode")
  }
}

///|
test "us-ascii declaration is accepted as utf-8 family" {
  let bytes = bytes_of("<?xml version=\"1.0\" encoding=\"us-ascii\"?><a/>")
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => ()
    Err(_) => fail("us-ascii document must decode")
  }
}

///|
test "char gate 1.0 rejects literal form feed" {
  let parts = bytes_of("<a>")
  parts.push((0x0C).to_byte())
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => fail("form feed is not a Char in XML 1.0")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::IllegalChar(0x0C))
  }
}

///|
test "char gate 1.0 accepts literal NEL" {
  let parts = bytes_of("<a>")
  let nel : Array[Byte] = [0xC2, 0x85]
  for byte in nel {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => ()
    Err(_) => fail("NEL is a Char in XML 1.0")
  }
}

///|
test "char gate 1.1 rejects literal C1 control" {
  let parts = bytes_of("<?xml version=\"1.1\"?><a>")
  let c1 : Array[Byte] = [0xC2, 0x80]
  for byte in c1 {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => fail("C1 control literal is restricted in XML 1.1")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::IllegalChar(0x80))
  }
}

///|
test "char gate 1.1 rejects literal DEL" {
  let parts = bytes_of("<?xml version=\"1.1\"?><a>")
  parts.push((0x7F).to_byte())
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => fail("DEL literal is restricted in XML 1.1")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::IllegalChar(0x7F))
  }
}

///|
test "char gate 1.1 accepts literal NEL" {
  let parts = bytes_of("<?xml version=\"1.1\"?><a>")
  let nel : Array[Byte] = [0xC2, 0x85]
  for byte in nel {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => ()
    Err(_) => fail("NEL literal is a line end in XML 1.1")
  }
}

///|
test "char gate rejects U+FFFF" {
  let parts = bytes_of("<a>")
  let tail : Array[Byte] = [0xEF, 0xBF, 0xBF]
  for byte in tail {
    parts.push(byte)
  }
  for byte in bytes_of("</a>") {
    parts.push(byte)
  }
  match @base.decode_source(Bytes::from_array(parts[:])) {
    Ok(_) => fail("U+FFFF is not a Char in any XML version")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::IllegalChar(0xFFFF))
  }
}

///|
test "char gate keys on version inside utf-16 documents" {
  let bytes = utf16_bytes_of("<doc>\u{0004}</doc>", false)
  match @base.decode_source(Bytes::from_array(bytes[:])) {
    Ok(_) => fail("C0 control must be gated in the UTF-16 face too")
    Err(@base.XmlError::At(error~, ..)) =>
      assert_true(error is @base.XmlErrorKind::IllegalChar(0x04))
  }
}

///|
/// 真解码见证：三套件原件端到端必须 Ok（实现前这三件是
/// Err(UnsupportedEncoding)；回退即红）。内容指纹取自固定版本套件文件。
/// 施工账：ctx.md §9（役J1）。
async test "japanese suite witnesses decode for real" {
  let eucjp = @fs.read_file("./.xmlconf/xmlconf/japanese/weekly-euc-jp.xml").binary()
  match @base.decode_source(eucjp) {
    Ok(text) => assert_true(text.contains("週報サンプル"))
    Err(_) => fail("weekly-euc-jp must truly decode")
  }
  let sjis = @fs.read_file("./.xmlconf/xmlconf/japanese/pr-xml-shift_jis.xml").binary()
  match @base.decode_source(sjis) {
    Ok(text) => assert_true(text.contains("拡張可能な"))
    Err(_) => fail("pr-xml-shift_jis must truly decode")
  }
  let iso2022 = @fs.read_file(
    "./.xmlconf/xmlconf/japanese/pr-xml-iso-2022-jp.xml",
  ).binary()
  match @base.decode_source(iso2022) {
    Ok(text) => assert_true(text.contains("拡張可能な"))
    Err(_) => fail("pr-xml-iso-2022-jp must truly decode")
  }
}
