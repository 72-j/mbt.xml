# mbt.xml

`thy1016/moonxml` 是一个用 MoonBit 编写的 **XML 底座仓**（立仓阶段）：
为 MoonBit 生态提供通用 XML 解析与数据模型层，消费方向中立——
RDF/XML 映射、化学标记语言（CML）、通用结构化数据均可依赖。

## 定位与现状

底座已定（M0 探针拍板 Milky2018/xml@0.6.0），**M1 树面已落**：自有规范型
数据模型 + parse（命名空间已解析、实体已展开）+ `Document::to_xml`
规范化序列化，往返门与三契约钉 14/14 绿（账见 `ctx.md`）。
**役G1 已落**：TOML 形状表 → 类型化骨架三件套（parse/validate/emit）——
试点 catalog 表经 `moon run skelgen/xmlregen`（根仓）再生成
`src/example/catalog/schema_gen.mbt`，真 XML 值级往返联调绿；再生件
fmt 幂等（黄金门穿 fmt 稳定）。
**役M2 已落**：W3C XML Conformance Suite（xmlts20130923）锁版随仓
（`.xmlconf/`，SHA256SUMS 可验），file-by-file 双桶套件门
**2068 passed / 517 deferred / 2585 total**（deferred 五族逐条可辩护，
账见 `ctx.md` §4）。

### 路线（里程碑）

| 役 | 内容 | 状态 |
|---|---|---|
| M0 | 底座探针：`Milky2018/xml` 0.6.0（事件式 Reader）vs
  `moonbit-community/XMLParser` 0.2.6（解析组合子）vs 自建语法层（moonttl 级） | **已关**：拍板 Milky@0.6.0（R-X1） |
| M1 | Node 适配层 + 数据模型（自有规范型 DOM 树 + 往返门 + 三契约钉） | **已关**（2026-10-15，14/14） |
| G1 | gen 三件套：XML 方言形状表 → 类型化骨架（spec 卷一） | **已关**（2026-10-15，40+15 双仓绿，R-G1a/b/c/d） |
| M2 | xmlconf oracle 层：套件锁版随仓 + file-by-file 双桶门 | **已关**（2026-10-16，2068/517/2585，R-M2a/b） |
| 应用语义层 | RDF/XML 映射、CML 等——独立战线另立仓或归口，仓位随消费端拍 | 未立项 |

### 分层裁决预立

- **流式（SAX/增量管线）**：沿 jsonld 同款纪律——`[立案] 不排期`；
  触发条件二选一即重估：① 出现官方流式 oracle 套件；② 消费端出现真实流式需求。
- **目标后端**：全后端可移植（`moon.mod` 不钉 `preferred_target`）。

## 体例

- 模块：`thy1016/moonxml`（仓 `mbt.xml`，体例对齐 `thy1016/jsonld`）。
- 依赖：底座 `Milky2018/xml@0.6.0`（R-X1 钉版；公开面零底座型泄露，
  R-G2 适配层收口）。
- 工程纪律：通用 MoonBit 纪律由工作区根 `AGENTS.md` 级联；仓内卷族
  spec.md 已立（gen 层设计卷一），const / ctx / todo 随 M0 立卷——
  先例见 `jsonld/`、`moonrdb/`。

## 安装

未发布。M0 探针拍板并首个能力役收口后，按 jsonld 同款上 mooncakes 注册表
（`moon add thy1016/moonxml`）。

## 测试与验证

```bash
moon test --target native    # 16/16（M1 往返 6 + 契约/模型 8 + G1 联调 1 + M2 套件门 1）
```
黄金门/负例住生成器仓（根仓 `skelgen/schema`,40/40）:
再生对拍 = `moon run skelgen/xmlregen` 后逐字节比对。
xmlconf oracle 层：套件锁版随仓 `.xmlconf/`（`sha256sum -c` 可验），
扁平清单再生 = `moon run --target native src/cmd/xmlconf_flatten`（逐字节
稳定）；套件门 defer 五族分诊见 `ctx.md` §4。

若走 RDF/XML 面，复用 W3C rdf-tests 的 rdf-xml 套件与 jsonld 仓的
`.rdf-tests` 锁版基建（SHA256SUMS + manifest）。

## 许可证

Apache License, Version 2.0。vendor 的第三方源码保持其原许可证并随目录附
原文与出处档（先例：moonmat 的 `cxsparse/PROVENANCE.md`）。
