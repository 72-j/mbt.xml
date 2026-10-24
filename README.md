# MoonXML

`thy1016/moonxml` 是 RDF 的 XML 解析器——面向 RDF 工具链的 MoonBit XML
解析基座，供 RDF/XML 等 XML 系序列化的映射层消费。提供命名空间感知的
拉取式解析、强类型文档模型（DOM 树）、规范化序列化与编码前端，另含
XML 1.0 版次面 / 1.1 键控、外部实体解析端口与 billion-laughs 防护。

本仓与 `thy1016/moonttl`（Turtle / TriG / N-Triples / N-Quads 解析）、
`thy1016/jsonld`（JSON-LD 1.1 通用库）同属 RDF 解析库项目族，
工程纪律与体例一脉相承。

## 特性

包结构：`thy1016/moonxml/base`（XML 底座：模型 / 解析 / 序列化 / 编码 /
名字表）+ `thy1016/moonxml/rdf`（RDF/XML 映射层）。

- 规范型文档模型：`Document` / `Element` / `Node` 强类型树，`to_xml`
  规范化序列化，解析–序列化往返稳定。
- 解析入口分层：`parse` 一行入口（命名空间已解析、实体已展开）；
  `parse_edition` 全参入口（版次面 / NS 面 / 实体解析器可选）。
- 命名空间双面：`NsMode::On`（NS-aware，缺省）与 `NsMode::Off`
  （非 NS 面，名字按原文直通，冒号名与组合字符衔接段合法）。
- 版本面键控：XML 1.0 四版次（`Editions1to4` 全表 / `Edition5` 紧凑）
  与 1.1 的名字产生式差异按版次键控。
- 编码前端 `decode_source`：BOM 嗅探（UTF-8 / UTF-16 LE/BE）+ 声明面
  编码决策（utf-8、utf-16、iso-8859-1，及 euc-jp / shift_jis /
  iso-2022-jp 三码十三标签），BOM 与声明冲突检测。
- 外部实体可控：`EntityResolver` 端口缺省不取外件（XXE 防御缺省关）；
  实体展开带 document 级输出预算双闸。
- 强类型错误面：`XmlError` 携带精确 `SourceSpan`（行 / 列 / 字节偏移）。
- W3C 一致性：XML Conformance Suite（xmlts20130923）自测
  2572 passed / 13 deferred / 0 failed。
- RDF/XML 映射层：`@rdf` 子包——RDF 1.1 全语法面 + RDF 1.2 三元词 /
  注解 / 方向字面量，W3C RDF/XML 套件 197 案全判全绿。

## 安装

确保环境中已安装 MoonBit 工具链，然后在模块根目录：

```bash
moon add thy1016/moonxml
```

再在用到它的包的 `moon.pkg` `import` 块中添加 `"thy1016/moonxml/base"`，
代码内以 `@base` 前缀使用。RDF/XML 面（`@rdf` 前缀）另加
`"thy1016/moonxml/rdf"`。

## 快速上手

### 解析与序列化

```moonbit
match @base.parse("<r><a>1</a><b x=\"2\"/></r>") {
  Ok(doc) => println(doc.to_xml())
  Err(_) => println("parse failed")
}
```

`Document` 含 `decl` / `doctype` / `prologue` / `root` / `epilogue`；
元素与节点按 `Element` / `Node`（`Text` / `CData` / `Comment` / `PI`）
强类型遍历，命名空间信息在 `XmlName`（`prefix` / `local_name` /
`namespace_uri`）。

### 版次面与 NS 面

```moonbit
// XML 1.0 四版次全表名字面（Edition5 为现行第五版紧凑面）
let opts_edition = @base.parse_edition(
  source,
  edition: @base.XmlEdition::Editions1to4,
)
// 非 NS 面：名字原文直通，xmlns 即普通属性
let ns_off = @base.parse_edition(
  source,
  edition: @base.XmlEdition::Edition5,
  ns: @base.NsMode::Off,
)
```

### 字节输入与编码

```moonbit
// BOM 嗅探 + 声明面编码决策；不支持面返回 Encoding 错
match @base.decode_source(bytes) {
  Ok(text) => println("decoded \{text.length()} chars")
  Err(_) => println("unsupported encoding")
}
```

### 外部实体解析

库内不做网络 I/O；外部实体经 `EntityResolver` 回调由调用方供给，
缺省 `None` = 拒取一切外件（XXE 防御缺省关）：

```moonbit
// resolver : &EntityResolver——实现 resolve(public_id, system_id, base)
// 返回 None 表示拒取；构造时经 parse_edition 的 resolver 参数注入。
```

### RDF/XML 解析

```moonbit
// RDF 1.1/1.2 XML → Dataset（Quad{subject, predicate, object, graph}）
match @rdf.parse_rdf_xml(xml) {
  Ok(dataset) =>
    for quad in dataset.quads {
      println(quad.predicate)
    }
  Err(msg) => println(msg)
}
// 带基准 IRI（xml:base 相对引用解析锚）
match @rdf.parse_rdf_xml_with_base(xml, base="https://example.org/doc") {
  Ok(dataset) => println(dataset.quads.length())
  Err(msg) => println(msg)
}
```

`Term` = `Iri` / `BNode` / `Literal`（词形 + 语言标签 + 数据类型 + 方向
四槽，RDF 1.2 方向字面量 `@lang--dir`）/ `TripleTerm`（RDF 1.2
`<<(s p o)>>` 三元词，嵌套允许）。

## API 总览

| 入口 | 作用 |
|---|---|
| `parse` | 字符串 → `Document`（NS-aware，实体已展开） |
| `parse_edition` | 全参入口：版次面 + NS 面 + 实体解析器 |
| `decode_source` | `Bytes` → 文本（BOM 嗅探 + 声明面编码决策） |
| `Document::to_xml` | 规范化序列化（往返稳定形） |
| `is_name_start_char_11` 等 | 名字产生式区间表谓词（1.0 四版次 / 1.1 双面） |
| `@rdf.parse_rdf_xml` | RDF/XML 字符串 → `Dataset` |
| `@rdf.parse_rdf_xml_with_base` | 同上 + 基准 IRI（相对引用解析锚） |
| `@rdf.resolve_reference` | RFC 3986 相对引用解析（`//` 网络路径 / 片不继承） |

## 错误面

`XmlError` = `At(error, span)`：`XmlErrorKind` 十变体 ——
`UnexpectedEof` / `InvalidSyntax` / `UnmatchedTag` / `InvalidAttribute` /
`InvalidEntity` / `Encoding` / `IllegalChar` / `IllegalName` /
`Structure` / `External`，位置信息在 `SourceSpan`（行 / 列 / 字节偏移）。

## 设计边界

- 流式（SAX / 增量管线）：不提供，暂不排期；出现官方流式 oracle 套件
  或消费端真实流式需求时重估。
- 全后端可移植：`moon.mod` 不钉 `preferred_target`。
- 底座隔离：解析引擎型不跨入公开 API 面。

定位与边界的完整说明见 `spec.md`。

## 测试与验证

```bash
moon test --target native
```

运行时输出各测试面的计数行（下表实测于 2026-10-24）：

| 面 | 读数 |
|---|---|
| W3C XML Conformance（xmlts20130923，2585 案） | 2572 passed / 13 deferred / 0 failed |
| W3C RDF/XML 套件（rdf11+rdf12，197 案） | 197 judged / 0 deferred / 0 failed |
| 单元与契约门 | 126 / 126 |

测试语料锁版随仓：`.xmlconf/`（W3C XML Conformance Suite，由
`SHA256SUMS` 锁定）、`.xmlnames/`（W3C XML 1.0 4e / 1.1 2e 推荐标准
快照）、`.encodings/`（WHATWG Encoding Standard 索引表）、
`src/rdf/.rdf-tests/`（W3C RDF/XML 套件 rdf11/rdf12 分册，出处注记
见 `src/rdf/.rdf-tests/SOURCE.md`）。

版本沿革见 `CHANGELOG.md`。

## 许可证

- 本项目代码采用 Apache License 2.0（见 `LICENSE`）。
- `.xmlconf/` 内的 W3C 测试文件、`.xmlnames/` 内的 W3C 推荐标准快照按
  W3C 文档许可分发，`.encodings/` 内的 WHATWG 索引表按 CC BY 4.0 分发，
  `src/rdf/.rdf-tests/` 内的 W3C RDF 测试文件按 W3C Test Suite License /
  3-clause BSD 双许可分发；原始文件逐字节未修改，来源与许可细目见
  `THIRD_PARTY_NOTICES.md`。
- 无背书声明：上文套件通过计数是本项目自测结果，只表示本实现能通过相应
  用例，不代表 W3C、WHATWG 认证、合规认定或任何形式的背书。
