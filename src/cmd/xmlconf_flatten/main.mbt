///|
/// xmlconf_flatten —— W3C XML Conformance Suite(xmlts20130923)清单扁平化:
/// 官方聚合清单 xmlconf.xml 用 DTD 外部参数实体聚合 21 本分册(外挂实体
/// 面超出 @moonxml 解析层),本命令按「组→分册」映射逐册用 @moonxml 自解析
/// (dogfood),产锁版 TSV:TYPE \t base+URI \t ID(保持册序,再生逐字节稳定)。
/// 运行:moon run cmd/xmlconf_flatten(cwd = moonxml 仓根)。

///|
/// 分册→基准径映射(摘自 xmlconf.xml 聚合体,套件 2013 锁版后不动)。
let manifest_table : Array[(String, String)] = [
  ("xmltest/xmltest.xml", "xmltest/"),
  ("japanese/japanese.xml", "japanese/"),
  ("sun/sun-valid.xml", "sun/"),
  ("sun/sun-invalid.xml", "sun/"),
  ("sun/sun-not-wf.xml", "sun/"),
  ("sun/sun-error.xml", "sun/"),
  ("oasis/oasis.xml", "oasis/"),
  ("ibm/ibm_oasis_invalid.xml", "ibm/"),
  ("ibm/ibm_oasis_not-wf.xml", "ibm/"),
  ("ibm/ibm_oasis_valid.xml", "ibm/"),
  ("ibm/xml-1.1/ibm_invalid.xml", "ibm/xml-1.1/"),
  ("ibm/xml-1.1/ibm_not-wf.xml", "ibm/xml-1.1/"),
  ("ibm/xml-1.1/ibm_valid.xml", "ibm/xml-1.1/"),
  ("eduni/errata-2e/errata2e.xml", "eduni/errata-2e/"),
  ("eduni/xml-1.1/xml11.xml", "eduni/xml-1.1/"),
  ("eduni/namespaces/1.0/rmt-ns10.xml", "eduni/namespaces/1.0/"),
  ("eduni/namespaces/1.1/rmt-ns11.xml", "eduni/namespaces/1.1/"),
  ("eduni/errata-3e/errata3e.xml", "eduni/errata-3e/"),
  ("eduni/errata-4e/errata4e.xml", "eduni/errata-4e/"),
  ("eduni/namespaces/errata-1e/errata1e.xml", "eduni/namespaces/errata-1e/"),
  ("eduni/misc/ht-bh.xml", "eduni/misc/"),
]

///|
/// 属性按限定名原文取(清单无命名空间)。
fn attribute_of(element : @moonxml.Element, wanted : String) -> String {
  for attribute in element.attributes {
    if attribute.name.qualified_name == wanted {
      return attribute.value
    }
  }
  ""
}

///|
/// 递归收 TEST 素(分册顶层或 TESTCASES 包裹两形)。
fn collect_tests(
  element : @moonxml.Element,
  base : String,
  rows : Array[String],
) -> Unit {
  for node in element.children {
    match node {
      @moonxml.Node::Element(sub) => {
        if sub.name.local_name == "TEST" {
          let uri = attribute_of(sub, "URI")
          let ty = attribute_of(sub, "TYPE")
          let id = attribute_of(sub, "ID")
          rows.push("\{ty}\t\{base}\{uri}\t\{id}")
        }
        collect_tests(sub, base, rows)
      }
      _ => ()
    }
  }
}

///|
/// 剥前置 XML 声明(包裹根前移会挤掉「声明必须在文档首」的位置)。
fn strip_declaration(text : String) -> String {
  if text.has_prefix("<?xml") {
    match text.find("?>") {
      Some(index) => {
        let body_start = index + 2
        text[body_start:].to_owned()
      }
      None => text
    }
  } else {
    text
  }
}

///|
/// XmlError → 可读面(套件工具无 Show/Debug,手格式化;行/列 = 起点值)。
fn xmlconf_error_hint(err : @moonxml.XmlError) -> String {
  match err {
    At(error~, span~) => {
      let kind_text = match error {
        InvalidSyntax(message) => "InvalidSyntax(\{message})"
        UnmatchedTag(expected~, found~) =>
          "UnmatchedTag(expected=\{expected}, found=\{found})"
        InvalidAttribute(message) => "InvalidAttribute(\{message})"
        InvalidEntity(message) => "InvalidEntity(\{message})"
        Encoding(message) => "Encoding(\{message})"
        IllegalChar(codepoint) => "IllegalChar(\{codepoint})"
        Structure(message) => "Structure(\{message})"
        UnexpectedEof => "UnexpectedEof"
      }
      "At(\{kind_text} @ line \{span.start.line} col \{span.start.column})"
    }
  }
}

///|
async fn main {
  let rows : Array[String] = []
  for pair in manifest_table {
    let (manifest, base) = pair
    let text = @fs.read_file("./.xmlconf/xmlconf/\{manifest}").text()
    // sun/ibm 分册是裸 TEST/TESTCASES 片段(多顶层素)——剥声明+包合成根再解析
    let body = strip_declaration(text)
    let document = match
      @moonxml.parse("<flatten-root>\{body}</flatten-root>") {
      Ok(value) => value
      Err(err) => abort("flatten: \{manifest}: \{xmlconf_error_hint(err)}")
    }
    collect_tests(document.root, base, rows)
  }
  let mut joined = ""
  for row in rows {
    joined = "\{joined}\{row}\n"
  }
  @fs.write_file("./.xmlconf/xmlconf_manifest.tsv", joined)
  // 分型计数读数(锁版后由 harness 钉)
  let mut valid_count = 0
  let mut invalid_count = 0
  let mut not_wf_count = 0
  let mut error_count = 0
  for row in rows {
    if row.has_prefix("valid\t") {
      valid_count += 1
    } else if row.has_prefix("invalid\t") {
      invalid_count += 1
    } else if row.has_prefix("not-wf\t") {
      not_wf_count += 1
    } else if row.has_prefix("error\t") {
      error_count += 1
    } else {
      abort("flatten: unknown TYPE in row: \{row}")
    }
  }
  debug(
    "flatten: \{rows.length()} tests (valid \{valid_count} / invalid \{invalid_count} / not-wf \{not_wf_count} / error \{error_count})",
  )
}
