///|
/// 本地字节 helper(ASCII 探针内容;弃用形 Bytes::of_string 不用)。
fn probe_bytes_of(text : String) -> Bytes {
  let out : Array[Byte] = []
  for ch in text {
    out.push(ch.to_int().to_byte())
  }
  Bytes::from_array(out[:])
}

///|
/// 本地 resolver 桩(内存文件面;测试件不跨文件赌可见性)。
priv struct MapResolver {
  files : Map[String, Bytes]
}

///|
impl EntityResolver for MapResolver with fn resolve(
  self : MapResolver,
  _base : String?,
  system_id : String,
  _public_id : String?,
) -> Bytes? {
  self.files.get(system_id)
}

///|
/// 本地桩构造 helper。
fn map_resolver_of(entries : Array[(String, String)]) -> &EntityResolver {
  let files : Map[String, Bytes] = Map([])
  for entry in entries {
    files.set(entry.0, probe_bytes_of(entry.1))
  }
  let resolver : MapResolver = { files, }
  resolver
}

///|
/// 集成单元:外取子集字面量实体 → 内容引用展开成树。
test "external entity expands into tree" {
  let resolver = map_resolver_of([("s.dtd", "<!ENTITY e \"A\">")])
  match
    parse_edition(
      "<!DOCTYPE d SYSTEM \"s.dtd\"><d>&e;</d>",
      edition=Edition5,
      ns=On,
      resolver=Some(resolver),
    ) {
    Ok(document) => assert_true(document.to_xml().contains("<d>A</d>"))
    Err(_) => fail("external entity expansion must parse")
  }
}

///|
/// 集成单元:含标记外取实体 → 预组合成真元素(12 案标记面主径)。
test "markup bearing entity composes markup" {
  let resolver = map_resolver_of([("s.dtd", "<!ENTITY m \"<x t='1'>B</x>\">")])
  match
    parse_edition(
      "<!DOCTYPE d SYSTEM \"s.dtd\"><d>&m;</d>",
      edition=Edition5,
      ns=On,
      resolver=Some(resolver),
    ) {
    Ok(document) => assert_true(document.to_xml().contains("<x t=\"1\">B</x>"))
    Err(_) => fail("markup entity must compose as markup")
  }
}

///|
/// 集成单元:内部优先——内部子集同名实体我表不收,底座自展开。
test "internal subset wins" {
  let resolver = map_resolver_of([("s.dtd", "<!ENTITY e \"E\">")])
  match
    parse_edition(
      "<!DOCTYPE d SYSTEM \"s.dtd\" [<!ENTITY e \"I\">]><d>&e;</d>",
      edition=Edition5,
      ns=On,
      resolver=Some(resolver),
    ) {
    Ok(document) => assert_true(document.to_xml().contains("<d>I</d>"))
    Err(_) => fail("internal-wins parse must succeed")
  }
}

///|
/// 集成单元:属性值位外取实体引用 = WFC 违例,原样留底座拒。
test "external entity in attribute rejects" {
  let resolver = map_resolver_of([
    ("s.dtd", "<!ENTITY m SYSTEM \"m.ent\">"),
    ("m.ent", "X"),
  ])
  match
    parse_edition(
      "<!DOCTYPE d SYSTEM \"s.dtd\"><d a=\"&m;\"></d>",
      edition=Edition5,
      ns=On,
      resolver=Some(resolver),
    ) {
    Ok(_) => fail("external entity in attribute must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// 集成单元:自引用实体 = 深度闸拒(billion-laughs 防御)。
test "recursive entity hits depth gate" {
  let resolver = map_resolver_of([("s.dtd", "<!ENTITY a \"&a;\">")])
  match
    parse_edition(
      "<!DOCTYPE d SYSTEM \"s.dtd\"><d>&a;</d>",
      edition=Edition5,
      ns=On,
      resolver=Some(resolver),
    ) {
    Ok(_) => fail("recursive entity must reject")
    Err(At(error=External(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// 缺省拒面:resolver 缺省(NoExternal 语义)——有外挂声明但取不到,
/// 原文直通零漂移(引用处底座 InvalidEntity 拒)。
test "default closed face unchanged" {
  match
    parse_edition("<!DOCTYPE d SYSTEM \"s.dtd\"><d>&e;</d>", edition=Edition5) {
    Ok(_) => fail("undeclared entity must reject without resolver")
    Err(At(error=InvalidEntity(_), ..)) => ()
    Err(_) => fail("unexpected error kind")
  }
}

///|
/// 重映射单元:账前段不动、账内归引用位、账后累计平移。
test "span patch remap" {
  let patches : Array[SpanPatch] = [
    { composed_start: 10, composed_end: 15, source_start: 4, source_length: 6, },
  ]
  assert_eq(remap_position(3, patches), 3)
  assert_eq(remap_position(12, patches), 4)
  assert_eq(remap_position(20, patches), 21)
}

///|
fn prepare_outcome(
  source : String,
  resolver : &EntityResolver,
) -> Result[(String, Array[SpanPatch]), XmlError] {
  Ok(prepare_external(source, resolver, Editions1to4)) catch {
    why => Err(why)
  }
}

///|
/// 链所有权闭合(役B2):内部字面量链 a→b(外取形)整链收归本层——
/// 组合面 &a; 展开到底,底座不再见 &b;(半路 InvEnt 根因)。c 不动链,
/// 留底座(内部优先不扩权)。
test "internal literal chain claims external entity" {
  let source = "<!DOCTYPE r [<!ENTITY a \"&b;\"><!ENTITY b SYSTEM \"b.ent\"><!ENTITY c \"(ic)\">]><r>&a;&c;</r>"
  let resolver = map_resolver_of([("b.ent", "(B)")])
  let (composed, patches) = match prepare_outcome(source, resolver) {
    Ok(pair) => pair
    Err(_) => fail("chain doc must prepare")
  }
  // 内容区断言走后缀(声明区按零漂移设计原样保留,a 声明值里本就
  // 有字面 &b;——contains 全文探会误咬)
  assert_true(composed.has_suffix("<r>(B)&c;</r>"))
  assert_true(patches.length() == 1) // 只 a 一处顶层账(b 嵌套不记)
}

///|
/// 链闭合负钉:不动链的内部字面量不收归(a→b 皆内部)——&a; 原样
/// 留底座;外取件 x 照常收编展开。两轴互不越界。
test "unclaimed internal literal stays with base" {
  let source = "<!DOCTYPE r [<!ENTITY a \"&b;\"><!ENTITY b \"(ib)\"><!ENTITY x SYSTEM \"x.ent\">]><r>&a;&x;</r>"
  let resolver = map_resolver_of([("x.ent", "(X)")])
  let (composed, patches) = match prepare_outcome(source, resolver) {
    Ok(pair) => pair
    Err(_) => fail("mixed doc must prepare")
  }
  assert_true(composed.contains("&a;"))
  assert_true(composed.contains("(X)"))
  assert_true(!composed.contains("&x;"))
  assert_true(patches.length() == 1) // 只 x 一处账
}
