// ===== STUBS —— 手写语义挂点(与生成物分文件,生成器零涉及) =====
// 骨架(schema_gen.mbt,生成物禁手写)逐 node 元素调用 stub_validate_<id>;
// 本文件 = 唯一手写语义区(值域校验/业务规则填空点)。缺省体 = 直通(试点零语义);
// 真方言进来按需填——改本文件不触发生成链,regen 不碰本文件。
// 接口一致门（catalog_interface_gate_test.mbt）要求：本文件的挂点名集 ≡ 骨架
// `xmlschema_hook_names()`，多一（孤儿 stub）少一（缺 stub）即红。

///|
/// doc 元素语义门(缺省直通;Err 消息透出时带 "doc: " 前缀)
fn stub_validate_doc(_value : Doc) -> Result[Unit, String] {
  Ok(())
}

///|
/// book 元素语义门(第一件真语义,用例役 2026-10-22):isbn 非空形校验。
/// 表收形状不收策略——值域规则住此,regen 不碰本文件。
fn stub_validate_book(value : Book) -> Result[Unit, String] {
  if value.isbn == "" {
    return Err("isbn must not be empty")
  }
  Ok(())
}
