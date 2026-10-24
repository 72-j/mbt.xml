///|
/// RDF 词项——N-Quads 词形同构：IRI / 空白节点 / 字面量。
/// 空白节点存裸名（不含 `_:` 前缀）；字面量 = 词形 + 语言标签 +
/// 数据类型 IRI（RDF 1.1 口径：简单字面量即 xsd:string、带语言标签
/// 即 rdf:langString，由词形直表达，不落隐式 datatype 槽）。
pub(all) enum Term {
  Iri(String)
  BNode(String)
  Literal(String, String?, String?)
}

///|
/// 四元组：主语 / 谓语限于 Iri / BNode（映射层入口把关），宾语任意；
/// 图槽 None = 默认图（RDF/XML 是 triple 语法，数据集 = 单一默认图）。
pub(all) struct Quad {
  subject : Term
  predicate : Term
  object : Term
  graph : Term?
}

///|
/// 数据集：四元组多重集（对拍口径 = spec §3 D-4：逐四元组匹配消去 +
/// 计数相等，禁整体排序逐字节）。
pub(all) struct Dataset {
  quads : Array[Quad]
}
