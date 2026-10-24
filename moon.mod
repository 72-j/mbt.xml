// MoonBit module manifest — mbt.xml
// 定位：XML 底座仓——M0 探针已拍板（R-X1）：底座 = Milky2018/xml@0.6.0
//       （StAX 式拉取 + NamespaceReader + Writer）；下一役 M1 = Node 适配层。
//       仓位裁定与分层评估见主仓 moonmat/requirements.md §二（2026-10-10）。

name = "thy1016/moonxml"

version = "0.1.0"

repository = "https://www.gitlink.org.cn/thy7/mbt.xml"

license = "Apache-2.0"

keywords = [ "xml", "parser", "dom" ]

description = "MoonBit XML base: spec-shaped document model, namespace-aware pull parsing with BOM/encoding detection, canonical serialization, and W3C XML Conformance coverage."

source = "src"

readme = "README.md"

import {
  "Milky2018/xml@0.6.0",
  "moonbitlang/async@0.22.4",
}
