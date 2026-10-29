// MoonBit module manifest — mbt.xml
// 定位：RDF 的 XML 解析仓。引擎底座 = Milky2018/xml@0.6.1（StAX 式拉取 +
// NamespaceReader + Writer）；本仓在其上提供规范型文档模型（Node 适配层）、
// 编码前端、W3C XML 一致性套件门与 RDF/XML 映射层（src/rdf，
// RDF 1.1/1.2，W3C RDF/XML 套件门 197 案）。

name = "thy1016/moonxml"

version = "0.3.0"

repository = "https://www.gitlink.org.cn/thy7/mbt.xml"

license = "Apache-2.0"

keywords = [ "rdf", "xml" ]

description = "MoonBit XML base and RDF/XML parser: spec-shaped document model, namespace-aware pull parsing with BOM/encoding detection, canonical serialization, with W3C XML Conformance and RDF/XML test-suite coverage."

source = "src"

readme = "README.md"

import {
  "Milky2018/xml@0.6.1",
  "moonbitlang/async@0.22.4",
}
