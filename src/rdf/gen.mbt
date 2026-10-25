// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====
// 源表：rdf/rdfxml_gen/rdfxml_gen.toml（schema 1.0）
// 再生：moon run rdf/rdfxml_gen/cmd（改表 → 重跑 → 黄金门对拍）
// 绑定器：rdf/rdfxml_gen/rdfxml_toml_gen.mbt（parse / validate / emit）

///|
/// 步骤表全量枚举（[[steps]]）
pub(all) enum RdfXmlStep {
  DocumentEntry
  NodeElementEnter
  NodeElementSubject
  NodeElementTyped
  PropertyElementForm
  PropertyElementResource
  PropertyElementParseType
  ParseTypeResource
  ParseTypeLiteral
  ParseTypeCollection
  PropertyElementLiteral
  EmitQuad
}

///|
/// 步骤 id（账面对照用）
pub fn RdfXmlStep::id(self : RdfXmlStep) -> String {
  match self {
    DocumentEntry => "document.entry"
    NodeElementEnter => "node_element.enter"
    NodeElementSubject => "node_element.subject"
    NodeElementTyped => "node_element.typed"
    PropertyElementForm => "property_element.form"
    PropertyElementResource => "property_element.resource"
    PropertyElementParseType => "property_element.parse_type"
    ParseTypeResource => "parse_type.resource"
    ParseTypeLiteral => "parse_type.literal"
    ParseTypeCollection => "parse_type.collection"
    PropertyElementLiteral => "property_element.literal"
    EmitQuad => "emit.quad"
  }
}

///|
/// next 边（[[steps]].next；缺省 = 本阶段终点）
pub fn RdfXmlStep::next_step(self : RdfXmlStep) -> RdfXmlStep? {
  match self {
    DocumentEntry => None
    NodeElementEnter => Some(NodeElementSubject)
    NodeElementSubject => Some(NodeElementTyped)
    NodeElementTyped => None
    PropertyElementForm => None
    PropertyElementResource => None
    PropertyElementParseType => None
    ParseTypeResource => None
    ParseTypeLiteral => None
    ParseTypeCollection => None
    PropertyElementLiteral => None
    EmitQuad => None
  }
}

///|
/// 形态分派（[[steps]].dispatch；未声明步 → None）
pub fn RdfXmlStep::dispatch(self : RdfXmlStep, shape : String) -> RdfXmlStep? {
  match self {
    PropertyElementForm =>
      match shape {
        "resource" => Some(PropertyElementResource)
        "parse_type" => Some(PropertyElementParseType)
        "literal" => Some(PropertyElementLiteral)
        _ => None
      }
    PropertyElementParseType =>
      match shape {
        "Resource" => Some(ParseTypeResource)
        "Literal" => Some(ParseTypeLiteral)
        "Collection" => Some(ParseTypeCollection)
        _ => None
      }
    _ => None
  }
}

///|
/// 步骤手写落点（[[steps]].handler_hook；None = 无手写，调度直通）
pub fn RdfXmlStep::handler(self : RdfXmlStep) -> String? {
  match self {
    DocumentEntry => Some("RdfXmlMapper::handle_document")
    NodeElementEnter => Some("RdfXmlMapper::handle_node_enter")
    NodeElementSubject => Some("RdfXmlMapper::handle_subject")
    NodeElementTyped => Some("RdfXmlMapper::handle_typed_node")
    PropertyElementForm => Some("RdfXmlMapper::handle_property_form")
    PropertyElementResource => None
    PropertyElementParseType => Some("RdfXmlMapper::handle_parse_type")
    ParseTypeResource => None
    ParseTypeLiteral => None
    ParseTypeCollection => None
    PropertyElementLiteral => None
    EmitQuad => Some("RdfXmlMapper::handle_emit_quad")
  }
}

///|
/// 词表全量枚举（[[element_terms]]）
pub(all) enum RdfXmlElementTerm {
  RdfRDF
  RdfDescription
  RdfLi
  RdfAbout
  RdfID
  RdfNodeID
  RdfResource
  RdfDatatype
  RdfParseType
  Resource
  Literal
  Collection
  XmlLang
  XmlBase
}

///|
/// 词形（账面对照用）
pub fn RdfXmlElementTerm::name(self : RdfXmlElementTerm) -> String {
  match self {
    RdfRDF => "rdf:RDF"
    RdfDescription => "rdf:Description"
    RdfLi => "rdf:li"
    RdfAbout => "rdf:about"
    RdfID => "rdf:ID"
    RdfNodeID => "rdf:nodeID"
    RdfResource => "rdf:resource"
    RdfDatatype => "rdf:datatype"
    RdfParseType => "rdf:parseType"
    Resource => "Resource"
    Literal => "Literal"
    Collection => "Collection"
    XmlLang => "xml:lang"
    XmlBase => "xml:base"
  }
}

///|
/// 词族（[[element_terms]].family；封闭集见 validate）
pub fn RdfXmlElementTerm::family(self : RdfXmlElementTerm) -> String {
  match self {
    RdfRDF => "document"
    RdfDescription => "node_element"
    RdfLi => "prop_element"
    RdfAbout => "node_attr"
    RdfID => "node_attr"
    RdfNodeID => "node_attr"
    RdfResource => "prop_attr"
    RdfDatatype => "prop_attr"
    RdfParseType => "prop_attr"
    Resource => "parse_type"
    Literal => "parse_type"
    Collection => "parse_type"
    XmlLang => "xml_attr"
    XmlBase => "xml_attr"
  }
}

///|
/// 词表手写落点（[[element_terms]].handler_hook；None = 纯词表占位）
pub fn RdfXmlElementTerm::handler(self : RdfXmlElementTerm) -> String? {
  match self {
    RdfRDF => None
    RdfDescription => None
    RdfLi => Some("RdfXmlMapper::handle_container_li")
    RdfAbout => Some("RdfXmlMapper::handle_about")
    RdfID => Some("RdfXmlMapper::handle_rdf_id")
    RdfNodeID => Some("RdfXmlMapper::handle_node_id")
    RdfResource => Some("RdfXmlMapper::handle_resource")
    RdfDatatype => Some("RdfXmlMapper::handle_datatype")
    RdfParseType => Some("RdfXmlMapper::handle_parse_type_attr")
    Resource => Some("RdfXmlMapper::handle_parse_type_resource")
    Literal => Some("RdfXmlMapper::handle_parse_type_literal")
    Collection => Some("RdfXmlMapper::handle_parse_type_collection")
    XmlLang => Some("RdfXmlMapper::handle_xml_lang")
    XmlBase => Some("RdfXmlMapper::handle_xml_base")
  }
}
