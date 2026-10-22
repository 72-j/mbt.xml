///|
/// JIS 三码解码(役J1):Shift_JIS / EUC-JP / ISO-2022-JP,判词面真源 =
/// 锁版 WHATWG Encoding Standard(.encodings/encoding-standard.html
/// §12.1.1 / §12.2.1 / §12.3.1;标签映射 §4.2)。数据面 =
/// jis_tables_gen.mbt(jis0208_index / jis0212_index,槽 0 = 未定义)。
/// 错误即拒:spec 的 restore-to-ioQueue 只服务容错续解,本引擎错误面
/// 无续解语义,恢复步省略(错误位置 = 违例字节)。

///|
/// JIS 编码判别(声明名已 lowercase;§4.2 名→编码映射逐标签收口)。
priv enum JisEncoding {
  ShiftJis
  EucJp
  Iso2022Jp
}

///|
fn jis_encoding_of_label(name : String) -> JisEncoding? {
  match name {
    "shift_jis"
    | "shift-jis"
    | "sjis"
    | "windows-31j"
    | "csshiftjis"
    | "ms932"
    | "ms_kanji"
    | "x-sjis" => Some(ShiftJis)
    "euc-jp" | "cseucpkdfmtjapanese" | "x-euc-jp" => Some(EucJp)
    "iso-2022-jp" | "csiso2022jp" => Some(Iso2022Jp)
    _ => None
  }
}

///|
/// 索引查码(spec "the index code point for pointer in index …"):
/// 越界即 null;槽 0 = 表内未定义槽,同为 null。0 作哨码位返回。
fn jis_index_codepoint(table : Array[Int32], pointer : Int32) -> Int32 {
  if pointer < 0 || pointer >= table.length() {
    return 0
  }
  table[pointer]
}

///|
fn decode_jis(
  encoding : JisEncoding,
  view : BytesView,
) -> String raise XmlError {
  match encoding {
    ShiftJis => decode_shift_jis(view)
    EucJp => decode_euc_jp(view)
    Iso2022Jp => decode_iso_2022_jp(view)
  }
}

///|
/// Shift_JIS(§12.3.1):单字节三段(ASCII|0x80→同码位、半角片假名
/// 0xA1-0xDF、双字节引字节 0x81-0x9F/0xE0-0xFC);双字节 pointer =
/// (lead−leadOffset)×188 + byte−offset,leadOffset 按 lead<0xA0 取
/// 0x81/0xC1,offset 按 byte<0x7F 取 0x40/0x41(0x7F 自然出局);
/// pointer 8836-10715 = EUDC 段,映射 0xE000−8836+pointer,先于表查。
fn decode_shift_jis(view : BytesView) -> String raise XmlError {
  let chars : Array[Char] = []
  let mut leading = 0
  for cursor = 0, scan = view {
    match scan {
      [] => break
      [byte, .. rest] => {
        let value = byte.to_int()
        if leading != 0 {
          let lead = leading
          leading = 0
          let offset = if value < 0x7F { 0x40 } else { 0x41 }
          let lead_offset = if lead < 0xA0 { 0x81 } else { 0xC1 }
          let mut pointer = -1
          if (value >= 0x40 && value <= 0x7E) ||
            (value >= 0x80 && value <= 0xFC) {
            pointer = (lead - lead_offset) * 188 + value - offset
          }
          if pointer >= 8836 && pointer <= 10715 {
            chars.push((0xE000 - 8836 + pointer).unsafe_to_char())
            continue cursor + 1, rest
          }
          let codepoint = jis_index_codepoint(jis0208_index, pointer)
          if codepoint != 0 {
            chars.push(codepoint.unsafe_to_char())
            continue cursor + 1, rest
          }
          raise encoding_error(view, cursor, "invalid Shift_JIS sequence")
        }
        if value <= 0x7F || value == 0x80 {
          chars.push(value.unsafe_to_char())
          continue cursor + 1, rest
        }
        if value >= 0xA1 && value <= 0xDF {
          chars.push((0xFF61 - 0xA1 + value).unsafe_to_char())
          continue cursor + 1, rest
        }
        if (value >= 0x81 && value <= 0x9F) || (value >= 0xE0 && value <= 0xFC) {
          leading = value
          continue cursor + 1, rest
        }
        raise encoding_error(view, cursor, "invalid Shift_JIS byte")
      }
    }
  }
  if leading != 0 {
    raise encoding_error(
      view,
      view.length() - 1,
      "truncated Shift_JIS sequence",
    )
  }
  String::from_array(chars[:])
}

///|
/// EUC-JP(§12.1.1):单字节 0x00-0x7F 直通;0x8E + 0xA1-0xDF = 半角
/// 片假名;0x8F + 0xA1-0xFE = jis0212 引字节;其余 0x8E/0x8F/0xA1-0xFE
/// 引 jis0208 对:pointer = (lead−0xA1)×94 + byte−0xA1,jis0212 旗只在
/// 0x8F 面立,用毕即清。
fn decode_euc_jp(view : BytesView) -> String raise XmlError {
  let chars : Array[Char] = []
  let mut leading = 0
  let mut in_jis0212 = false
  for cursor = 0, scan = view {
    match scan {
      [] => break
      [byte, .. rest] => {
        let value = byte.to_int()
        if leading == 0x8E && value >= 0xA1 && value <= 0xDF {
          leading = 0
          chars.push((0xFF61 - 0xA1 + value).unsafe_to_char())
          continue cursor + 1, rest
        }
        if leading == 0x8F && value >= 0xA1 && value <= 0xFE {
          in_jis0212 = true
          leading = value
          continue cursor + 1, rest
        }
        if leading != 0 {
          let lead = leading
          leading = 0
          let mut codepoint = 0
          if lead >= 0xA1 && lead <= 0xFE && value >= 0xA1 && value <= 0xFE {
            let pointer = (lead - 0xA1) * 94 + (value - 0xA1)
            let table = if in_jis0212 { jis0212_index } else { jis0208_index }
            codepoint = jis_index_codepoint(table, pointer)
          }
          in_jis0212 = false
          if codepoint != 0 {
            chars.push(codepoint.unsafe_to_char())
            continue cursor + 1, rest
          }
          raise encoding_error(view, cursor, "invalid EUC-JP sequence")
        }
        if value <= 0x7F {
          chars.push(value.unsafe_to_char())
          continue cursor + 1, rest
        }
        if value == 0x8E || value == 0x8F || (value >= 0xA1 && value <= 0xFE) {
          leading = value
          continue cursor + 1, rest
        }
        raise encoding_error(view, cursor, "invalid EUC-JP byte")
      }
    }
  }
  if leading != 0 {
    raise encoding_error(view, view.length() - 1, "truncated EUC-JP sequence")
  }
  String::from_array(chars[:])
}

///|
/// ISO-2022-JP 状态(spec §12.2.1 七态:ASCII / Roman / katakana /
/// lead byte / trail byte / escape start / escape)。
priv enum Jis2022State {
  Ascii
  Roman
  Katakana
  LeadByte
  TrailByte
  EscapeStart
  Escape
}

///|
/// ISO-2022-JP(§12.2.1):转义序 切换状态(ESC ( B→ASCII、
/// ESC ( J→Roman(0x5C→¥、0x7E→‾)、ESC ( I→半角片假名、ESC $ @|B→
/// 双字节 jis0208 对 0x21-0x7E);output 旗钉"转义后须吐码"——连转两次
/// 即错;ASCII/Roman 态 0x0E/0x0F 拒。终态 TrailByte/EscapeStart/Escape
/// 收尾 = 截断拒。
fn decode_iso_2022_jp(view : BytesView) -> String raise XmlError {
  let chars : Array[Char] = []
  let mut state = Ascii
  let mut output_state = Ascii
  let mut leading = 0
  let mut output = false
  for cursor = 0, scan = view {
    match scan {
      [] => break
      [byte, .. rest] => {
        let value = byte.to_int()
        match state {
          Ascii => {
            if value == 0x1B {
              state = EscapeStart
              continue cursor + 1, rest
            }
            if value <= 0x7F && value != 0x0E && value != 0x0F {
              output = false
              chars.push(value.unsafe_to_char())
              continue cursor + 1, rest
            }
            raise encoding_error(view, cursor, "invalid ISO-2022-JP ASCII byte")
          }
          Roman => {
            if value == 0x1B {
              state = EscapeStart
              continue cursor + 1, rest
            }
            if value == 0x5C {
              output = false
              chars.push((0x00A5).unsafe_to_char())
              continue cursor + 1, rest
            }
            if value == 0x7E {
              output = false
              chars.push((0x203E).unsafe_to_char())
              continue cursor + 1, rest
            }
            if value <= 0x7F && value != 0x0E && value != 0x0F {
              output = false
              chars.push(value.unsafe_to_char())
              continue cursor + 1, rest
            }
            raise encoding_error(view, cursor, "invalid ISO-2022-JP Roman byte")
          }
          Katakana => {
            if value == 0x1B {
              state = EscapeStart
              continue cursor + 1, rest
            }
            if value >= 0x21 && value <= 0x5F {
              output = false
              chars.push((0xFF61 - 0x21 + value).unsafe_to_char())
              continue cursor + 1, rest
            }
            raise encoding_error(
              view, cursor, "invalid ISO-2022-JP katakana byte",
            )
          }
          LeadByte => {
            if value == 0x1B {
              state = EscapeStart
              continue cursor + 1, rest
            }
            if value >= 0x21 && value <= 0x7E {
              output = false
              leading = value
              state = TrailByte
              continue cursor + 1, rest
            }
            raise encoding_error(view, cursor, "invalid ISO-2022-JP lead byte")
          }
          TrailByte => {
            if value == 0x1B {
              state = EscapeStart
              raise encoding_error(
                view, cursor, "ESC in ISO-2022-JP trailing byte",
              )
            }
            if value >= 0x21 && value <= 0x7E {
              state = LeadByte
              let pointer = (leading - 0x21) * 94 + (value - 0x21)
              let codepoint = jis_index_codepoint(jis0208_index, pointer)
              if codepoint == 0 {
                raise encoding_error(
                  view, cursor, "undefined ISO-2022-JP code point",
                )
              }
              output = false
              chars.push(codepoint.unsafe_to_char())
              continue cursor + 1, rest
            }
            state = LeadByte
            raise encoding_error(
              view, cursor, "invalid ISO-2022-JP trailing byte",
            )
          }
          EscapeStart => {
            if value == 0x24 || value == 0x28 {
              leading = value
              state = Escape
              continue cursor + 1, rest
            }
            output = false
            state = output_state
            raise encoding_error(
              view, cursor, "invalid ISO-2022-JP escape start",
            )
          }
          Escape => {
            let lead = leading
            leading = 0
            let entered : Jis2022State? = if lead == 0x28 && value == 0x42 {
              Some(Ascii)
            } else if lead == 0x28 && value == 0x4A {
              Some(Roman)
            } else if lead == 0x28 && value == 0x49 {
              Some(Katakana)
            } else if lead == 0x24 && (value == 0x40 || value == 0x42) {
              Some(LeadByte)
            } else {
              None
            }
            match entered {
              Some(next) => {
                state = next
                output_state = next
                let emitted_since_escape = output
                output = true
                if emitted_since_escape {
                  raise encoding_error(
                    view, cursor, "redundant ISO-2022-JP escape sequence",
                  )
                }
                continue cursor + 1, rest
              }
              None => {
                output = false
                state = output_state
                raise encoding_error(
                  view, cursor, "invalid ISO-2022-JP escape sequence",
                )
              }
            }
          }
        }
      }
    }
  }
  if state is TrailByte || state is EscapeStart || state is Escape {
    raise encoding_error(
      view,
      view.length() - 1,
      "truncated ISO-2022-JP sequence",
    )
  }
  String::from_array(chars[:])
}
