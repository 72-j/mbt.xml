///|
/// moonxml 数据模型(spec R-G2 依赖面):底座事件/树 → 本包自有规范型。
/// 底座(Milky2018/xml)的型一律不进本包公开面——换底座只改适配层,gen 面零改。
/// 纪律:解析错误的位置信息经 [XmlError] 透传(ctx §1 契约三);树节点不带 span
/// (往返等价比较才成立;子节点定位 span 随消费端需要再立)。

///|
/// XML 名字(命名空间解析后的 infoset 形):qualified_name 为原文全名,
/// prefix/local_name/namespace_uri 为拆解结果(无命名空间时后两者为 None)。
pub(all) struct XmlName {
  qualified_name : String
  prefix : String?
  local_name : String
  namespace_uri : String?
} derive(Eq)

///|
pub extend XmlName with Eq::{equal, not_equal}

///|
/// XML 声明 `<?xml ... ?>` 的载荷。
pub(all) struct XmlDecl {
  version : String
  encoding : String?
  standalone : String?
} derive(Eq)

///|
pub extend XmlDecl with Eq::{equal, not_equal}

///|
/// 属性(命名空间已解析;xmlns 声明在底座侧与普通属性分离,
/// 适配层并回普通属性面——序列化即统一按属性发,再解析等价)。
pub(all) struct Attribute {
  name : XmlName
  value : String
} derive(Eq)

///|
pub extend Attribute with Eq::{equal, not_equal}

///|
/// 元素:名字 + 属性 + 混合内容子节点。
pub(all) struct Element {
  name : XmlName
  attributes : Array[Attribute]
  children : Array[Node]
} derive(Eq)

///|
pub extend Element with Eq::{equal, not_equal}

///|
/// 树节点:元素 / 文本(实体已展开、相邻段已拼接,ctx §1 契约一)/
/// CDATA 分型保留 / 注释 / 处理指令。
pub(all) enum Node {
  Element(Element)
  Text(String)
  CData(String)
  Comment(String)
  PI(target~ : String, data~ : String)
} derive(Eq)

///|
pub extend Node with Eq::{equal, not_equal}

///|
/// 文档 = 声明 + DOCTYPE + 根前杂项 + 根元素(恰一,适配层查)+
/// 根后杂项。DOCTYPE 仅名字(底座事件面只暴露名;内部子集在解析期
/// 展开,不进树——往返在展开文本上等价)。
pub(all) struct Document {
  decl : XmlDecl?
  doctype : String?
  prologue : Array[Node]
  root : Element
  epilogue : Array[Node]
} derive(Eq)

///|
pub extend Document with Eq::{equal, not_equal}

///|
/// 解析错误面:词表对位底座 kind(规范拼写保留),结构自有。
/// [Structure] 为适配层新增——事件序/树结构错(底座已保 WF,此臂为防御纵深)。
pub(all) suberror XmlErrorKind {
  UnexpectedEof
  InvalidSyntax(String)
  UnmatchedTag(expected~ : String, found~ : String)
  InvalidAttribute(String)
  InvalidEntity(String)
  Structure(String)
} derive(Eq)

///|
pub extend XmlErrorKind with Eq::{equal, not_equal}

///|
/// 错误 = kind + 源位置(ctx §1 契约三:位置信息直接透传)。
pub(all) suberror XmlError {
  At(error~ : XmlErrorKind, span~ : SourceSpan)
} derive(Eq)

///|
pub extend XmlError with Eq::{equal, not_equal}

///|
/// 源位置(错误报告用;字段对位底座,翻译在适配层)。
pub(all) struct SourcePosition {
  offset : Int
  line : Int
  column : Int
} derive(Eq)

///|
pub extend SourcePosition with Eq::{equal, not_equal}

///|
pub(all) struct SourceSpan {
  start : SourcePosition
  end : SourcePosition
} derive(Eq)

///|
pub extend SourceSpan with Eq::{equal, not_equal}
