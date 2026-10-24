// MoonBit module manifest — mbt.xml
// 定位：XML 底座仓。引擎底座 = Milky2018/xml@0.6.0（StAX 式拉取 +
// NamespaceReader + Writer）；本仓在其上提供规范型文档模型（Node 适配层）、
// 编码前端与 W3C 一致性套件门。

name = "thy1016/moonxml"

version = "0.2.0"

repository = "https://www.gitlink.org.cn/thy7/mbt.xml"

license = "Apache-2.0"

keywords = [ "rdf", "xml" ]

description = "MoonBit XML base: spec-shaped document model, namespace-aware pull parsing with BOM/encoding detection, canonical serialization, and W3C XML Conformance coverage."

source = "src"

readme = "README.md"

import {
  "Milky2018/xml@0.6.0",
  "moonbitlang/async@0.22.4",
}
