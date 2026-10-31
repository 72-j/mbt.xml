# Changelog

本文件面向**使用者**，记录每版对外可见的变化（API / 行为 / 兼容性 / 工程）。
判据与规范细节见 `spec.md`（本仓规范卷）。

## 0.3.2（2026-10-31）

文档面版本：README「测试与验证」补 quicktest 文档台账守恒机说明（树守恒 +
串稳定双口径、CDATA 试金石、Node 五变体池），读数表随新（单元与契约门
139 / 139，含 quicktest 13 例）；对外 API 与行为零变化。

## 0.3.1（2026-10-31）

工程面版本：新增 quicktest 随机状态机测试件（**文档台账守恒机**）——pbtgen
QuickMachine 三面 TOML（`src/quicktest/`）生成骨架 + P0 接框架真面；对外 API
零变化。

### 新增（测试面）

- **`src/quicktest/` 文档台账守恒机**：Fresh→Seed→Ledgered 状态机，Ledgered
  环上 `AppendNode`（载荷选 node 池，Node 五变体全入池：元素带属带文 / 纯
  文本 / 注释 / CDATA / PI / 空元素双属）+ `Roundtrip`；被测性质 = 守恒律
  双口径——①树守恒：`parse(to_xml(d))` 的 Document 结构等 == d（CDATA 是
  试金石：序列化降级即树面破）②串稳定：`to_xml(parse(to_xml(d))) ==
  to_xml(d)`（序列化是 parse∘serialize 的不动点）。随机 60 例 + 固定脚本
  回归基线 + 单例覆盖门 + 固定守恒罐四件（Seed 基线 / 全池逐条 / 序列语义
  重复追加 / 模型-系统双执行同步）。
- **与 jsonld 守恒机的分野**：XML 子节点是有序可重序列——重复追加合法，
  无集合挡板；jsonld 数据集是集合语义（valid 挡重复）。
- **模块依赖**：`moonbit-community/quickcheck_statemachine@0.0.1` +
  `moonbitlang/quickcheck@0.15.1`（仅 quicktest 测试面消费，产品面零涟漪）。

### 口径

- 读数：quicktest 13 例 native/wasm 双绿；全仓 `moon test --deny-warn`
  139/139（xmlconf 2572 在门内）；产品 `.mbti` 零漂移；fmt 零波及。

## 0.3.0（2026-10-30）

**破坏性：底座三支 failable API 迁 raise 风格**（工具链 [0078]
result_error_return 收口，CI `moon check --deny-warn` 门恢复绿）。

### 对外 API

- **破坏性**：`base` 子包 `parse` / `parse_edition` 返回型
  `Result[Document, XmlError]` → `Document raise XmlError`；
  `decode_source` 同（→ `String raise XmlError`）。调用方从
  `match f(x) { Ok(..) .. Err(..) }` 改为 `try f(x) catch { .. }`
  （或在 raise 语境直接透传）。`rdf` 子包入口保持 `Result` 不变
  （错误面为 String，非 Error 型，不在 [0078] 射程）。
- 其余对外面零变更；README 快速上手示例同步换形（版次面示例标签
  实参顺手勘正为 `=` 形）。

### 工程与文档

- `.mbti` 随签名变更同笔重生成（含 Int→Int32 工具链规范形）。
- `src/cmd/xmlconf_flatten` 运行径勘正为
  `moon run src/cmd/xmlconf_flatten`（0.2.1 布局迁移后的旧径失准），
  README 补「命令行工具」节。

### 测试

- 双档读数与 0.2.1 逐字一致（native + wasm）：XML Conformance
  2572 passed / 13 deferred / 2585 total；RDF/XML 197 judged /
  0 deferred；单元与契约门 126 / 126。

## 0.2.1（2026-10-25）

结构重排的实质上架版：registry 的 0.2.0 为重排**前**布局（根包
`thy1016/moonxml` 平铺 + rdf 子包），本版起底座住
`thy1016/moonxml/base`。另：`is_ncname_shape` 改由底座名字谓词组合，
补组合附加符段 `[#x0300-#x036F]`（手搓表漏段，spec 真修）。

## 0.2.0（2026-10-24）

**结构重排（破坏性）+ 新增 RDF/XML 映射层子包**：XML 底座迁至
`thy1016/moonxml/base` 子包；RDF 1.1 全语法面 + RDF 1.2 扩展落
`thy1016/moonxml/rdf`，以 W3C RDF/XML 一致性套件（rdf11/rdf12 分册，
197 案）作判词真源。

### 对外 API

- **破坏性：底座包径变更** `thy1016/moonxml` → `thy1016/moonxml/base`
  （代码前缀 `@moonxml` → `@base`）；底座 API 面本体零变更。
- **新子包 `thy1016/moonxml/rdf`**（`@rdf` 前缀）：

- **新子包 `thy1016/moonxml/rdf`**（`@rdf` 前缀）：
  - `parse_rdf_xml` / `parse_rdf_xml_with_base`（基准 IRI 锚定相对
    引用解析）；`resolve_reference`（RFC 3986：`//` 网络路径取裸
    scheme、fragment 不继承）。
  - **`Term` 模型**：`Iri` / `BNode` / `Literal`（词形、语言标签、
    数据类型、方向四槽——RDF 1.2 方向字面量 `@lang--dir`）/
    `TripleTerm`（RDF 1.2 `<<(s p o)>>` 三元词，嵌套允许）。
  - `Quad { subject, predicate, object, graph }` + `Dataset`；
    `suite_cases()`（197 案判例表，生成面）。
- 语法覆盖：node/property 元素、属性属性、rdf:ID/nodeID/about、
  rdf:li 容器拨号、parseType 四形（Resource / Literal（XMLLiteral
  规范序列化）/ Collection / Triple）、具化（rdf:ID 四元组）与
  RDF 1.2 注解（rdf:annotation / annotationNodeID → reifies）、
  ITS `its:dir` 方向字面量、rdf:version 版本门（元素级生效）。

### 一致性读数

- W3C RDF/XML 套件（rdf11 166 案 + rdf12 31 案 = 197 案）：
  **197 judged / 0 deferred / 0 failed**（组桶判定 + .nt 多重集对拍，
  bnode 双射回溯含三元词下潜）。
- XML Conformance 不变：2572 passed / 13 deferred / 0 failed；
  本仓测试 **126/126**。

### 兼容性

- **破坏**：0.1.0 消费者须把 `import "thy1016/moonxml"` 拨为
  `"thy1016/moonxml/base"`、前缀 `@moonxml` 拨为 `@base`（机械替换）；
  底座 API 形状（类型 / 函数签名）零变更。

## 0.1.0（2026-10-24）

首个发布版：MoonBit 的 XML 底座——自有规范型数据模型 + 拉取式解析 +
规范化序列化，以 W3C XML Conformance Suite 作判词真源。

### 对外 API

- **数据模型**：`XmlName` / `XmlDecl` / `Attribute` / `Element` / `Node` /
  `Document` 全为自有规范型（不泄露底座类型）；`Document::to_xml` 做规范化序列化。
- **解析**：`parse`（缺省命名空间感知）与 `parse_edition`（按 XML 1.0 版本面选名字表：
  Editions1to4 全表 / Edition5 紧凑；1.1 文档恒走紧凑表）。
- **命名空间模式**：`NsMode { On, Off }`——Off 面名字按原文直通、xmlns 视为普通属性。
- **编码前端**：`decode_source(Bytes)`——BOM 嗅探（UTF-8 / UTF-16 LE/BE）、
  声明面编码决策（utf-8 严格 / utf-16 BOM 键控 / iso-8859-1 / euc-jp /
  shift_jis / iso-2022-jp 等）、BOM/声明冲突检测、版本键控 Char 门。
- **外部实体**：`EntityResolver` 端口（缺省拒绝取件，XXE 防线）；外取件准入三闸
  （text decl 语法 / only-later 版次 / 版本键控 Char 门）；错误面独立
  `XmlErrorKind::External`。

### 兼容性与行为

- 命名空间**缺省开启**；非 NS 消费可显式 `NsMode::Off`。
- `error` 判词按 XML 1.0 §1.2 / §5.1：报错与继续解析都在规范符合带内。
- 名字段错误零位报（树不带 span），消息含码点与名字原文。

### 一致性读数

- W3C XML Conformance Suite（xmlts20130923，2585 案）：
  **2572 passed / 13 deferred / 0 failed**；13 案为 A–E 五族在册未闭项
  （逐条分族案由见套件门 `src/xmlconf_suite_test.mbt` 注记）。
- 本仓测试 **120/120**。

### 依赖

- `Milky2018/xml@0.6.0`（Apache-2.0，StAX 式拉取底座；经本仓适配层收口）。
- `moonbitlang/async@0.22.4`（Apache-2.0，IO / 测试面）。

### 许可与语料

- 本仓 **Apache-2.0**（全文见 `LICENSE`）。
- 随仓语料：W3C XML Conformance Suite（xmlts20130923）· W3C XML 1.0 4e /
  1.1 2e 推荐标准快照 · WHATWG Encoding Standard 索引表（CC BY 4.0）——
  来源 / 许可 / 校验和见 `THIRD_PARTY_NOTICES.md` 与各目录 `SHA256SUMS`。
