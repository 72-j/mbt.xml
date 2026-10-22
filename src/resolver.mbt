///|
/// 外部资源解析端口(役B2,R-B1a):外部 DTD 子集与外取实体的唯一取件缝。
/// 缺省拒 = parse_edition 的 resolver 缺省 None(不取外件,现状语义
/// 零漂移)——XXE 防御缺省关,策略对齐 moonrdb D-18 消费端政策参数
/// 先例(禁止污染编解码错误语义,外取面错误走独立词
/// [XmlErrorKind::External]);网络面 = 消费方实现者自担,本仓不携
/// 网络 resolver。
pub(open) trait EntityResolver {
  // base = 引用方资源定位(文档本身引用 = None;外取子集内再引用 =
  // 该子集的 system_id),供实现方做相对径拼接;解析责任在实现侧,
  // 本仓无 URI 库。public_id 按裁定仅透传不解析(PUBLIC→SYSTEM 目录
  // 不实现,spec 卷二待探②)。
  fn resolve(Self, base : String?, system_id : String, public_id : String?) -> Bytes?
}
