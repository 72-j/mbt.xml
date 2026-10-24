# Changelog

本文件面向**使用者**，记录每版对外可见的变化（API / 行为 / 兼容性 / 工程）。
内部役录、判据与勘定沿革见 `ctx.md` / `spec.md`（本仓账本），不在此重复。

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
  （案由与处置见 `ctx.md` §17）。
- 本仓测试 **120/120**。

### 依赖

- `Milky2018/xml@0.6.0`（Apache-2.0，StAX 式拉取底座；经本仓适配层收口）。
- `moonbitlang/async@0.22.4`（Apache-2.0，IO / 测试面）。

### 许可与语料

- 本仓 **Apache-2.0**（全文见 `LICENSE`）。
- 随仓语料：W3C XML Conformance Suite（xmlts20130923）· W3C XML 1.0 4e /
  1.1 2e 推荐标准快照 · WHATWG Encoding Standard 索引表（CC BY 4.0）——
  来源 / 许可 / 校验和见 `THIRD_PARTY_NOTICES.md` 与各目录 `SHA256SUMS`。
