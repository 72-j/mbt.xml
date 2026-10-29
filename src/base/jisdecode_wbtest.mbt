///|
/// 白盒机制门：JIS 三码解码器直调（私有 fn，黑盒不可见）。
/// 期望码位全部自固定版本表 `.encodings/index-*.txt` 机械核定
/// （93 FA→日 U+65E5 / 82 A0→あ U+3042 / A1 A1→U+3000 /
/// iso-2022 30 21→亜 U+4E9C；jis0212[0] 未定义 = 现成负例）。
/// 套件级读数在 xmlconf_suite_test；集成面经 decode_source 在 decode_test。
/// 施工账：ctx.md §9（役J1）。

///|
fn byte_sequence_of(items : Array[Int32]) -> Bytes {
  let out : Array[Byte] = []
  for value in items {
    out.push(value.to_byte())
  }
  Bytes::from_array(out[:])
}

///|
test "shift_jis two-byte pair decodes via table" {
  let text = decode_shift_jis(byte_sequence_of([0x93, 0xFA])[:])
  assert_eq(text, "日")
  let text2 = decode_shift_jis(byte_sequence_of([0x82, 0xA0])[:])
  assert_eq(text2, "あ")
}

///|
test "shift_jis halfwidth katakana and 0x80 direct map" {
  assert_eq(decode_shift_jis(byte_sequence_of([0xA1])[:]), "｡")
  assert_eq(decode_shift_jis(byte_sequence_of([0xDF])[:]), "ﾟ")
  assert_eq(decode_shift_jis(byte_sequence_of([0x80])[:]), "\u{0080}")
}

///|
test "shift_jis EUDC range outranks index table" {
  let text = decode_shift_jis(byte_sequence_of([0xF0, 0x40])[:])
  assert_eq(text, "\u{E000}")
  let text2 = decode_shift_jis(byte_sequence_of([0xF9, 0xFC])[:])
  assert_eq(text2, "\u{E757}")
}

///|
test "shift_jis rejects 0x7F trail and 0xA0 lead" {
  let bad_trail = Ok(decode_shift_jis(byte_sequence_of([0x81, 0x7F])[:])) catch {
    err => Err(err)
  }
  assert_true(bad_trail is Err(_))
  let bad_lead = Ok(decode_shift_jis(byte_sequence_of([0xA0])[:])) catch {
    err => Err(err)
  }
  assert_true(bad_lead is Err(_))
  let bad_single = Ok(decode_shift_jis(byte_sequence_of([0xFD])[:])) catch {
    err => Err(err)
  }
  assert_true(bad_single is Err(_))
}

///|
test "shift_jis truncated lead at end of queue is rejected" {
  let outcome = Ok(decode_shift_jis(byte_sequence_of([0x81])[:])) catch {
    err => Err(err)
  }
  assert_true(outcome is Err(_))
}

///|
test "euc_jp jis0208 pair and halfwidth escape" {
  assert_eq(decode_euc_jp(byte_sequence_of([0xA1, 0xA1])[:]), "\u{3000}")
  assert_eq(decode_euc_jp(byte_sequence_of([0x8E, 0xA1])[:]), "｡")
}

///|
test "euc_jp jis0212 escape uses supplementary table" {
  let outcome = Ok(decode_euc_jp(byte_sequence_of([0x8F, 0xA1, 0xA1])[:])) catch {
    err => Err(err)
  }
  assert_true(outcome is Err(_))
  match outcome {
    Err(XmlError::At(error~, span~)) => {
      assert_true(error is XmlErrorKind::Encoding(_))
      assert_eq(span.start.offset, 2)
    }
    Ok(_) => fail("jis0212 slot 0 is undefined")
  }
}

///|
test "euc_jp rejects 0x80 0xFF and truncated lead" {
  let high = Ok(decode_euc_jp(byte_sequence_of([0x80])[:])) catch {
    err => Err(err)
  }
  assert_true(high is Err(_))
  let lead = Ok(decode_euc_jp(byte_sequence_of([0xFE])[:])) catch {
    err => Err(err)
  }
  assert_true(lead is Err(_))
  let truncated = Ok(decode_euc_jp(byte_sequence_of([0x8F, 0xA1])[:])) catch {
    err => Err(err)
  }
  assert_true(truncated is Err(_))
}

///|
test "iso_2022_jp switches to jis0208 pairs after ESC $ B" {
  let text = decode_iso_2022_jp(
    byte_sequence_of([0x1B, 0x24, 0x42, 0x30, 0x21])[:],
  )
  assert_eq(text, "亜")
}

///|
test "iso_2022_jp roman swaps yen and overline" {
  let text = decode_iso_2022_jp(
    byte_sequence_of([0x1B, 0x28, 0x4A, 0x5C, 0x7E, 0x41])[:],
  )
  assert_eq(text, "¥‾A")
}

///|
test "iso_2022_jp katakana state maps halfwidth range" {
  let text = decode_iso_2022_jp(byte_sequence_of([0x1B, 0x28, 0x49, 0x21])[:])
  assert_eq(text, "｡")
}

///|
test "iso_2022_jp redundant escape and bad escape are rejected" {
  let redundant = Ok(
    decode_iso_2022_jp(
      byte_sequence_of([0x1B, 0x24, 0x42, 0x1B, 0x24, 0x42, 0x30, 0x21])[:],
    ),
  ) catch {
    err => Err(err)
  }
  assert_true(redundant is Err(_))
  let bogus = Ok(decode_iso_2022_jp(byte_sequence_of([0x1B, 0x28, 0x58])[:])) catch {
    err => Err(err)
  }
  assert_true(bogus is Err(_))
  let truncated = Ok(
    decode_iso_2022_jp(byte_sequence_of([0x1B, 0x24, 0x42, 0x30])[:]),
  ) catch {
    err => Err(err)
  }
  assert_true(truncated is Err(_))
}

///|
test "jis_2022 ascii state rejects SI/SO shift bytes" {
  let so = Ok(decode_iso_2022_jp(byte_sequence_of([0x0E])[:])) catch {
    err => Err(err)
  }
  assert_true(so is Err(_))
  let si = Ok(decode_iso_2022_jp(byte_sequence_of([0x0F])[:])) catch {
    err => Err(err)
  }
  assert_true(si is Err(_))
}

///|
test "jis labels resolve all thirteen spec tags" {
  assert_true(jis_encoding_of_label("shift_jis") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("shift-jis") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("sjis") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("windows-31j") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("csshiftjis") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("ms932") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("ms_kanji") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("x-sjis") is Some(ShiftJis))
  assert_true(jis_encoding_of_label("euc-jp") is Some(EucJp))
  assert_true(jis_encoding_of_label("cseucpkdfmtjapanese") is Some(EucJp))
  assert_true(jis_encoding_of_label("x-euc-jp") is Some(EucJp))
  assert_true(jis_encoding_of_label("iso-2022-jp") is Some(Iso2022Jp))
  assert_true(jis_encoding_of_label("csiso2022jp") is Some(Iso2022Jp))
  assert_true(jis_encoding_of_label("utf-8") is None)
  assert_true(jis_encoding_of_label("iso-8859-2") is None)
}

///|
test "jis index lookup bounds and undefined slots" {
  assert_eq(jis_index_codepoint(jis0208_index, 0), 0x3000)
  assert_eq(jis_index_codepoint(jis0208_index, 1410), 0x4E9C)
  assert_eq(jis_index_codepoint(jis0208_index, -1), 0)
  assert_eq(jis_index_codepoint(jis0208_index, jis0208_index.length()), 0)
  assert_eq(jis_index_codepoint(jis0212_index, 0), 0)
}
