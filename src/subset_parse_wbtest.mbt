///|
/// 子集解析白盒测试：闸 P / G / S / PI 与 PE 组合的正反例。
/// 施工账：ctx.md §14–§16（役PE；R-B1d 声明面）。

///|
/// 拒取件 resolver(本地测试面:一切外取件 None)。
priv struct DenyAll {}

///|
impl EntityResolver for DenyAll with fn resolve(
  _self : DenyAll,
  _base : String?,
  _system_id : String,
  _public_id : String?,
) -> Bytes? {
  None
}

///|
/// 本地装载上下文 helper(测试件不跨文件赌可见性)。
fn subset_load_with(resolver : &EntityResolver) -> ExternalLoad {
  {
    resolver,
    table: Map([]),
    internal_literals: Map([]),
    pe_values: Map([]),
    pe_externals: Map([]),
    pe_depth: 0,
    doc_version: None,
    standalone_yes: false,
    edition: Editions1to4,
    consumed: 0,
  }
}

///|
/// 白盒 test 块 = raise 语境:收成 Result 再 match(断言在 catch 外)。
fn subset_outcome(load : () -> Unit raise XmlError) -> Result[Unit, XmlError] {
  Ok(load()) catch {
    why => Err(why)
  }
}

///|
/// 子集装载单元:外取子集字面量 ENTITY 归我表;PE 声明接受不收编;
/// ATTLIST/ELEMENT 过闸。
test "external subset literal entity loads" {
  let load = subset_load_with(DenyAll::{ })
  let subset = "<!ENTITY open \"A\"><!ENTITY % pe \"p\"><!ELEMENT r ANY><!ATTLIST r a CDATA \"x\">"
  match subset_outcome(() => load_external_subset(subset, None, load)) {
    Ok(_) => {
      match load.table.get("open") {
        Some(InternalText(value)) => assert_eq(value, "A")
        _ => fail("literal entity must load as internal text")
      }
      assert_true(load.table.get("pe") is None)
    }
    Err(_) => fail("well-formed subset must load")
  }
}

///|
/// 子集装载单元:内部子集面字面量不收编(内部优先,底座自持)。
test "internal subset literal entity skipped" {
  let load = subset_load_with(DenyAll::{ })
  let subset = "<!ENTITY internal \"I\">"
  match subset_outcome(() => collect_internal_external_entities(subset, load)) {
    Ok(_) => assert_true(load.table.get("internal") is None)
    Err(_) => fail("internal subset scan must pass")
  }
}

///|
/// 子集装载单元：声明后的残渣按声明面拒（External 错）。
test "subset junk rejected" {
  let load = subset_load_with(DenyAll::{ })
  let subset = "<!ENTITY open \"A\"> junk >"
  match subset_outcome(() => load_external_subset(subset, None, load)) {
    Ok(_) => fail("subset junk must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// 子集装载单元:条件段 INCLUDE 解析体、IGNORE 跳过体。
test "conditional sections gate declarations" {
  let load = subset_load_with(DenyAll::{ })
  let subset = "<![INCLUDE[<!ENTITY inc \"I\">]]><![IGNORE[<!ENTITY ign \"X\">]]>"
  match subset_outcome(() => load_external_subset(subset, None, load)) {
    Ok(_) => {
      match load.table.get("inc") {
        Some(InternalText(value)) => assert_eq(value, "I")
        _ => fail("included entity must load")
      }
      assert_true(load.table.get("ign") is None)
    }
    Err(_) => fail("conditional subset must load")
  }
}

///|
/// 子集装载单元:未闭合引号值 = External 错(声明面拒因,not-wf 族)。
test "unterminated entity value rejects" {
  let load = subset_load_with(DenyAll::{ })
  let subset = "<!ENTITY open \"unclosed>"
  match subset_outcome(() => load_external_subset(subset, None, load)) {
    Ok(_) => fail("unterminated value must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// 条件段关键词位可以是 PE 引用（`<![ %e; [`）：关键词从 pe_values 取；
/// 值可自带 `[`（与关键词一体）。体保持原文，零位移。
test "conditional PE keyword gates body" {
  let load = subset_load_with(DenyAll::{ })
  load.pe_values.set("e", "INCLUDE")
  let subset = "<![ %e; [\n<!ENTITY inc \"I\">\n]]>"
  match subset_outcome(() => load_external_subset(subset, None, load)) {
    Ok(_) =>
      match load.table.get("inc") {
        Some(InternalText(value)) => assert_eq(value, "I")
        _ => fail("PE-keyword INCLUDE must parse body")
      }
    Err(_) => fail("conditional PE INCLUDE must pass")
  }
  let ignore_load = subset_load_with(DenyAll::{ })
  ignore_load.pe_values.set("e", "IGNORE")
  let ignore_subset = "<![ %e; [\n<!ENTITY ign \"X\">\n]]>"
  match
    subset_outcome(() => load_external_subset(ignore_subset, None, ignore_load)) {
    Ok(_) => assert_true(ignore_load.table.get("ign") is None)
    Err(_) => fail("conditional PE IGNORE must skip body")
  }
  let bracket_load = subset_load_with(DenyAll::{ })
  bracket_load.pe_values.set("e", "INCLUDE[")
  let bracket_subset = "<![ %e; <!ELEMENT r ANY>]]>"
  match
    subset_outcome(() => {
      load_external_subset(bracket_subset, None, bracket_load)
    }) {
    Ok(_) => assert_true(bracket_load.table.get("r") is None)
    Err(_) => fail("bracket-in-value conditional must pass")
  }
}

///|
/// 声明残段可用 PE 值内顶层 `>` 结束（如 `(#PCDATA)>` 补全 ELEMENT 声明）；
/// 结束后不再追声明间残段，后续声明照常解析。
test "PE value top-level gt closes declaration" {
  let load = subset_load_with(DenyAll::{ })
  load.pe_values.set("e", "(#PCDATA)>")
  let subset = "<!ELEMENT doc (#PCDATA) %e;\n<!ELEMENT after ANY>"
  match subset_outcome(() => load_external_subset(subset, None, load)) {
    Ok(_) => assert_true(load.table.get("after") is None)
    Err(_) => fail("PE-closed declaration must pass")
  }
}

///|
/// 外取链桩 resolver(键 = doc 相对径;点段折叠同 resolver 契约;
/// 测试件 helper 不跨文件,本地自有)。
priv struct ChainResolver {
  store : Map[String, String]
}

///|
impl EntityResolver for ChainResolver with fn resolve(
  self : ChainResolver,
  base : String?,
  system_id : String,
  _public_id : String?,
) -> Bytes? {
  let rel = match base {
    None => ""
    Some(uri) => {
      let mut last = -1
      let limit = uri.length()
      for index in 0..<limit {
        if uri[index] == '/' {
          last = index
        }
      }
      if last < 0 {
        ""
      } else {
        uri[:last].to_owned()
      }
    }
  }
  match self.store.get(normalize_dot_segments(rel + "/" + system_id)) {
    Some(text) => {
      let out : Array[Byte] = []
      for ch in text {
        out.push(ch.to_int().to_byte())
      }
      Some(Bytes::from_array(out[:]))
    }
    None => None
  }
}

///|
/// 外取 PE 链：子代声明基址按 RFC 3986 路径规则合成；`../` 三跳后孙代实体落表。
/// （直接传原始 system_id 时，resolver 的 `..` 会吃掉 doc 目录 ⇒ 孙代取件落空；
/// 这是本测试要复现的破形。）
test "external PE chain resolves child base" {
  let store : Map[String, String] = Map([
    (
      "subdir1/E18-pe", "<!ENTITY % extpe SYSTEM \"../subdir2/E18-extpe\">\n<!ENTITY % intpe \"%extpe;\">",
    ),
    ("subdir2/E18-extpe", "<!ENTITY ent SYSTEM 'E18-ent'>"),
    ("subdir2/E18-ent", "CONTENT"),
  ])
  let resolver : &EntityResolver = ChainResolver::{ store, }
  let load = subset_load_with(resolver)
  let subset = "<!ENTITY % pe SYSTEM \"subdir1/E18-pe\">%pe;\n%intpe;\n"
  match subset_outcome(() => collect_internal_external_entities(subset, load)) {
    Ok(_) =>
      match load.table.get("ent") {
        Some(ExternalPiece(content)) => assert_eq(content, "CONTENT")
        _ => fail("chain-resolved entity must land in table")
      }
    Err(_) => fail("E18 chain must pass")
  }
}

///|
/// 子代基址合成单元:None 直传 / '..' 折叠 / 绝对径与 scheme 原样。
test "merge_base_reference unit shapes" {
  assert_eq(merge_base_reference(None, "sub/a.ent"), "sub/a.ent")
  assert_eq(
    merge_base_reference(Some("sub1/E18-pe"), "../sub2/x.ent"),
    "sub2/x.ent",
  )
  assert_eq(merge_base_reference(Some("f.ent"), "g.ent"), "g.ent")
  assert_eq(merge_base_reference(Some("sub/a.ent"), "/abs/x.ent"), "/abs/x.ent")
  assert_eq(
    merge_base_reference(Some("sub/a.ent"), "http://x/y.ent"),
    "http://x/y.ent",
  )
}

///|
/// 闸 P（实体值引用语法）：孤 `%` / 孤 `&` / 无 `;` 的引用违反 P09 产生式；
/// 正形（`%pe;` / `&#60;` / `&amp;`）照常装载。
test "entity value reference syntax gate" {
  let load = subset_load_with(DenyAll::{ })
  let bad = "<!ENTITY e \"100%\">"
  match subset_outcome(() => load_external_subset(bad, None, load)) {
    Ok(_) => fail("lone percent in value must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
  let load2 = subset_load_with(DenyAll::{ })
  let bad2 = "<!ENTITY % e \"asdf&\">"
  match subset_outcome(() => load_external_subset(bad2, None, load2)) {
    Ok(_) => fail("lone ampersand in value must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
  let load3 = subset_load_with(DenyAll::{ })
  let good = "<!ENTITY % e \"%pe;\">"
  match subset_outcome(() => load_external_subset(good, None, load3)) {
    Ok(_) => ()
    Err(_) => fail("well-formed value refs must load")
  }
}

///|
/// 闸 G（声明名合法性）：`<!ELEMENT 0node>` 数字起名 = 拒；
/// 合法名字与名字位的 PE 引用照旧过闸。
test "declaration name validity gate" {
  let load = subset_load_with(DenyAll::{ })
  let bad = "<!ELEMENT 0node EMPTY>"
  match subset_outcome(() => load_external_subset(bad, None, load)) {
    Ok(_) => fail("digit-start element name must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
  let load2 = subset_load_with(DenyAll::{ })
  let good = "<!ELEMENT _a-1 ANY><!NOTATION n2 SYSTEM \"x\">"
  match subset_outcome(() => load_external_subset(good, None, load2)) {
    Ok(_) => ()
    Err(_) => fail("legal declaration names must pass")
  }
  let load3 = subset_load_with(DenyAll::{ })
  load3.pe_values.set("e", "doc a1 CDATA")
  let pe_name = "<!ATTLIST %e; \"v1\">"
  match subset_outcome(() => load_external_subset(pe_name, None, load3)) {
    Ok(_) => ()
    Err(_) => fail("PE-carried ATTLIST name must pass")
  }
}

///|
/// 闸 S（standalone WFC）：`standalone='yes'` 时在正文位展开本表实体即拒
/// （WFC 2.9 Entity Declared）；缺省 standalone 不拦。
test "standalone yes rejects table entity expansion" {
  let load = { ..subset_load_with(DenyAll::{ }), standalone_yes: true, }
  load.table.set("ext", ExternalPiece("X"))
  let buffer : ComposeBuffer = { inner: StringBuilder(), length: 0, }
  let outcome = subset_outcome(() => {
    expand_entry(buffer, [], "ext", "X", 0, 5, load, 0, false)
  })
  match outcome {
    Ok(_) => fail("standalone expansion must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
  let load2 = subset_load_with(DenyAll::{ })
  load2.table.set("ext", ExternalPiece("X"))
  let buffer2 : ComposeBuffer = { inner: StringBuilder(), length: 0, }
  match
    subset_outcome(() => {
      expand_entry(buffer2, [], "ext", "X", 0, 5, load2, 0, false)
    }) {
    Ok(_) => ()
    Err(_) => fail("non-standalone expansion must pass")
  }
}

///|
/// PE 组合端到端：双层 PE 链（xx → `%zz;` → zz → GE 声明）+ char-ref 绕行；
/// PE 携带的 GE 声明由本层认领并落表。
test "pe-carried entity claims table" {
  let load = subset_load_with(DenyAll::{ })
  let subset = "<!ENTITY % xx '&#37;zz;'>" +
    "<!ENTITY % zz '&#60;!ENTITY tricky \"error-prone\" >' >" +
    "%xx;"
  match subset_outcome(() => collect_internal_external_entities(subset, load)) {
    Ok(_) =>
      match load.table.get("tricky") {
        Some(InternalText(value)) => assert_eq(value, "error-prone")
        _ => fail("PE-carried entity must claim table")
      }
    Err(_) => fail("pe02 shape must load")
  }
}

///|
/// PE 值 char-ref 在引用位处理：十进制 / 十六进制解析，`&name;` 保持 bypass。
/// 断言放在 catch 外（避免吞掉断言失败）。
test "pe value char refs decode" {
  let results : Array[String] = []
  match
    subset_outcome(() => {
      results.push(pe_value_char_refs("&#37;zz;"))
      results.push(pe_value_char_refs("&#x3C;!E>"))
      results.push(pe_value_char_refs("plain"))
      results.push(pe_value_char_refs("a&amp;b"))
    }) {
    Ok(_) => ()
    Err(_) => fail("decode must not raise")
  }
  assert_eq(results[0], "%zz;")
  assert_eq(results[1], "<!E>")
  assert_eq(results[2], "plain")
  assert_eq(results[3], "a&amp;b")
}

///|
/// 闸 PI：目标不是名字（`<?[`）即拒；正形带数据区可过；未闭合即拒。
test "subset PI gate" {
  let load = subset_load_with(DenyAll::{ })
  let bad = "<?[INCLUDE[<!ELEMENT r ANY>]]>"
  match subset_outcome(() => load_external_subset(bad, None, load)) {
    Ok(_) => fail("PI with bracket target must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
  let load2 = subset_load_with(DenyAll::{ })
  let good = "<?t this is content ?><!ENTITY e \"v\">"
  match subset_outcome(() => load_external_subset(good, None, load2)) {
    Ok(_) =>
      match load2.table.get("e") {
        Some(InternalText(value)) => assert_eq(value, "v")
        _ => fail("PI must not eat following declaration")
      }
    Err(_) => fail("PI with content must pass")
  }
  let load3 = subset_load_with(DenyAll::{ })
  let unterminated = "<?target <!ELEMENT r ANY>"
  match subset_outcome(() => load_external_subset(unterminated, None, load3)) {
    Ok(_) => fail("unterminated PI must reject")
    Err(At(error=XmlErrorKind::External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}
