///|
/// 外部资源解析端口：外部 DTD 子集与外取实体的唯一取件缝。
/// 缺省拒绝取件（`parse_edition` 的 resolver 缺省 None，不取外件，语义零漂移）
/// ——XXE 防线。策略对齐同门 D-18 消费端政策参数先例：取件失败走独立错误词
/// [XmlErrorKind::External]，不污染编解码错误语义。网络访问由消费方实现，
/// 本仓不内置网络 resolver。
/// 施工账：ctx.md §11（役B2，R-B1a）。
pub(open) trait EntityResolver {
  // base = 引用方的资源定位（文档自身 = None；外取子集内再引用 = 该子集的
  // system_id），供实现方拼相对路径；解析责任在实现侧，本仓无 URI 库。
  // public_id 只透传不解析（PUBLIC→SYSTEM 的目录映射未实现）。
  fn resolve(Self, base : String?, system_id : String, public_id : String?) -> Bytes?
}
