# mbt.xml

`thy1016/moonxml` 是一个用 MoonBit 编写的 **XML 底座仓**（立仓阶段）：
为 MoonBit 生态提供通用 XML 解析与数据模型层，消费方向中立——
RDF/XML 映射、化学标记语言（CML）、通用结构化数据均可依赖。

## 定位与现状

本仓处于**立仓占位阶段**：模块面已立（`thy1016/moonxml` v0.1.0），
实现尚未开工。第一役为 **M0 探针役**——底座验证报告拍板技术路线后才立算法/模型层役。

### 路线（里程碑）

| 役 | 内容 | 状态 |
|---|---|---|
| M0 | 底座探针：`Milky2018/xml` 0.2.0（事件式 Reader）vs
  `moonbit-community/XMLParser` 0.2.5（解析组合子）vs 自建语法层（moonttl 级） | 未开工 |
| M1+ | XML 数据模型（DOM 树，树递归纯函数架构）+ well-formedness 门 | 待 M0 拍板 |
| 应用语义层 | RDF/XML 映射、CML 等——独立战线另立仓或归口，仓位随消费端拍 | 未立项 |

### 分层裁决预立

- **流式（SAX/增量管线）**：沿 jsonld 同款纪律——`[立案] 不排期`；
  触发条件二选一即重估：① 出现官方流式 oracle 套件；② 消费端出现真实流式需求。
- **目标后端**：全后端可移植（`moon.mod` 不钉 `preferred_target`）。

## 体例

- 模块：`thy1016/moonxml`（仓 `mbt.xml`，体例对齐 `thy1016/jsonld`）。
- 依赖：零依赖立仓；底座依赖待 M0 探针拍板后再进 `import`。
- 工程纪律：通用 MoonBit 纪律由工作区根 `AGENTS.md` 级联；仓内卷族
  spec.md 已立（gen 层设计卷一），const / ctx / todo 随 M0 立卷——
  先例见 `jsonld/`、`moonrdb/`。

## 安装

未发布。M0 探针拍板并首个能力役收口后，按 jsonld 同款上 mooncakes 注册表
（`moon add thy1016/moonxml`）。

## 测试与验证

```bash
moon check   # 当前：0 errors（占位件）
moon test    # M0 起随役累进
```

oracle 规划：语法层对标 W3C XML Conformance Suite（xmlconf）锁版接入；
若走 RDF/XML 面，复用 W3C rdf-tests 的 rdf-xml 套件与 jsonld 仓的
`.rdf-tests` 锁版基建（SHA256SUMS + manifest）。

## 许可证

Apache License, Version 2.0。vendor 的第三方源码保持其原许可证并随目录附
原文与出处档（先例：moonmat 的 `cxsparse/PROVENANCE.md`）。
