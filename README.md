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
**役A1 已落**：编码前端 `decode_source(Bytes)`——BOM 嗅探（UTF-8/
UTF-16 LE/BE）、声明面编码决策（utf-8 严格 / utf-16 BOM 键控 /
iso-8859-1，余者 UnsupportedEncoding 拒）、BOM/声明冲突检测、
版本键控 Char 门（1.0 全表 vs 1.1 restricted-literal）；套件门
读数推进 **2135 passed / 450 deferred / 2585 total**（账见 `ctx.md` §5）。
**役E1 已落**：版本面键控名字段门 + 名字表 gen——W3C XML 1.0 4e/1.1 2e
规范锁版随仓（`.xmlnames/`），区间表 TOML → skelschema 方言三件套 →
`name_tables_gen.mbt`；`parse_edition` 按 1.0 版次面（Editions1to4 全表 /
Edition5 紧凑）键控名字产生式；套件门 EDITION 感知双面裁决，读数推进
**2437 passed / 148 deferred / 2585 total**（账见 `ctx.md` §6）。
**役E2 已落**：判词面勘误——error = XML 1.0 §1.2 可恢复违例，双向可过
（14 案收编）+ D 族根因归位重挂（016/019 四e 面正判、001/002 改挂 B）；
读数推进 **2453 passed / 132 deferred / 2585 total**（账见 `ctx.md` §7）。

### 路线（里程碑）

| 役 | 内容 | 状态 |
|---|---|---|
| M0 | 底座探针：`Milky2018/xml` 0.6.0（事件式 Reader）vs
  `moonbit-community/XMLParser` 0.2.6（解析组合子）vs 自建语法层（moonttl 级） | **已关**：拍板 Milky@0.6.0（R-X1） |
| M1 | Node 适配层 + 数据模型（自有规范型 DOM 树 + 往返门 + 三契约钉） | **已关**（2026-10-15，14/14） |
| G1 | gen 三件套：XML 方言形状表 → 类型化骨架（spec 卷一） | **已关**（2026-10-15，40+15 双仓绿，R-G1a/b/c/d） |
| M2 | xmlconf oracle 层：套件锁版随仓 + file-by-file 双桶门 | **已关**（2026-10-16，2068/517/2585，R-M2a/b） |
| A1 | 编码前端 + 版本键控 Char 门（decode_source） | **已关**（2026-10-16，2135/450/2585，R-A1a/b） |
| E1 | 版本面键控名字段门 + 名字表 gen（parse_edition） | **已关**（2026-10-21，2437/148/2585，R-E1a/b/c/d） |
| E2 | 判词面勘误（error 双向）+ D 族重挂 | **已关**（2026-10-21，2453/132/2585，R-E2a/b） |
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
moon test --target native    # 48/48（M1 往返 6 + 契约/模型 8 + G1 联调 1 + M2 套件门 1 + A1 编码单元 22 + E1 名字段单元 10）
```
黄金门/负例住生成器仓（根仓 `skelschema` 双方言 + `skelgen` 双金门，
schema 49 + link 8）：再生对拍 = `moon run skelgen/xmlregen` /
`moon run skelgen/xmlnameregen` 后逐字节比对。
xmlconf oracle 层：套件锁版随仓 `.xmlconf/`（`sha256sum -c` 可验），
扁平清单再生 = `moon run --target native src/cmd/xmlconf_flatten`
（逐字节稳定，含 EDITION 版次面列）；套件门双面裁决（manifest EDITION
列 → 4e 全表面/5e 紧凑面）deferred 分诊见 `ctx.md` §4/§6；名字区间表
数据真源锁版 `.xmlnames/`（`sha256sum -c` 可验，提取脚本
`tools/extract_name_tables.py`）。

若走 RDF/XML 面，复用 W3C rdf-tests 的 rdf-xml 套件与 jsonld 仓的
`.rdf-tests` 锁版基建（SHA256SUMS + manifest）。

## 许可证

Apache License, Version 2.0。vendor 的第三方源码保持其原许可证并随目录附
原文与出处档（先例：moonmat 的 `cxsparse/PROVENANCE.md`）。
