///|
/// RDF 词项——N-Quads 词形同构：IRI / 空白节点 / 字面量 / 三元词。
/// 空白节点存裸名（不含 `_:` 前缀）；字面量 = 词形 + 语言标签 +
/// 数据类型 IRI + 方向（RDF 1.1 口径：简单字面量即 xsd:string、
/// 带语言标签即 rdf:langString，由词形直表达，不落隐式 datatype 槽；
/// RDF 1.2 增方向槽——`@en--ltr` 形，仅语言标签字面量携带）。
/// 三元词 = TripleTerm(主语, 谓语, 宾语)（RDF 1.2 `<<(s p o)>>`，
/// 嵌套允许——宾语位可再含 TripleTerm）。
pub(all) enum Term {
  Iri(String)
  BNode(String)
  Literal(String, String?, String?, String?)
  TripleTerm(Term, Term, Term)
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
