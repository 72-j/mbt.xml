///|
/// 接口一致门(jsonld interface_gate 先例;评7 立项):骨架挂点 ↔ 手写 stubs
/// 双向对表。拦两类漂移:① stubs 孤儿——表删元素后 stub 未清(骨架是直接
/// 调用面,反向失配编译器咬不住);② stubs 名单与骨架调用点失配。骨架侧
/// 名单 = 生成器直发的 xmlschema_hook_names()(调用点数据孪生,自动真;
/// 生成物 ≡ 源表由 skelgen 联调黄金门把关,本门不重复钉)。缺 stub(骨架
/// 叫了 stubs 没有)= 编译器红,亦不重复钉。

///|
/// stubs.mbt 声明面提取:逐行扫 `fn stub_validate_<id>(` 形,收集挂点名。
/// 命名形 = 宪法级约定(挂点必须住 stubs.mbt、必须 stub_validate_ 前缀)。
fn stubs_declared_hooks(stubs_text : String) -> Array[String] {
  let declared : Array[String] = []
  for line in stubs_text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("fn stub_validate_") {
      let head = trimmed.split("(").collect()[0]
      declared.push(head[3:].to_owned())
    }
  }
  declared
}

///|
async test "catalog interface gate: stubs surface equals skeleton hook names" {
  let stubs_text = @fs.read_file("./src/example/catalog/stubs.mbt").text()
  let declared = stubs_declared_hooks(stubs_text)
  // 双向对表:stubs 声明面 == 骨架调用面(多一少一即红;序不钉——fn 声明序自由)
  let expected = @catalog.xmlschema_hook_names()
  assert_eq(declared.length(), expected.length())
  for name in expected {
    assert_true(declared.contains(name))
  }
}
