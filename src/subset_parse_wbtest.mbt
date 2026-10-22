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
  { resolver, table: Map([]), internal_literals: Map([]), consumed: 0, }
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
/// 子集装载单元:声明残渣 = External 错(R-B1d 拒因落声明面)。
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
