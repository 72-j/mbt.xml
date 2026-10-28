# 第三方来源与许可（THIRD_PARTY_NOTICES）

本仓本体以 **Apache License 2.0** 发布（全文见 `LICENSE`，Copyright 2026 thy1016）。
本节是**随仓语料**与**运行时依赖**的来源/许可单一事实源；语料或依赖变更须同笔更新本节。

## 一、随仓语料（锁版快照，本仓不改写其内容）

| 路径 | 材料 | 来源 | 许可 | 遵守方式 |
|---|---|---|---|---|
| `.xmlconf/`（3388 件 · 17M） | W3C XML Conformance Test Suite（xmlts20130923） | W3C XML Test Suite 发行 | **W3C Test Suite License**（2008-04-14）+ **W3C Document License**（2002-12-31） | 随仓快照、目录内不改写；`SHA256SUMS` 锁版；`xmlconf_manifest.tsv` 记测试 ID ↔ 路径；文件内版权声明保留 |
| `.xmlnames/`（3 件 · 444K） | W3C XML 1.0（4th ed., 2006-08-16）与 XML 1.1（2nd ed., 2006-08-16）推荐标准快照 | W3C Recommendation 原文 | **W3C Document License**（2002-12-31） | 原样快照；名字表抽取件由 `tools/extract_name_tables.py` 生成，**派生件属本仓 Apache-2.0** |
| `.encodings/`（4 件 · 1.1M） | WHATWG Encoding Standard 索引表（`index-jis0208.txt` / `index-jis0212.txt`）+ 标准快照 | WHATWG Encoding Standard | **Creative Commons Attribution 4.0**（版权 © WHATWG：Apple, Google, Mozilla, Microsoft） | 原样快照；`SHA256SUMS` 锁版；出处与许可全文见目录内 `encoding-standard.html` 页脚；抽取件由 `tools/extract_encoding_tables.py` 生成，**派生件属本仓 Apache-2.0** |
| `src/rdf/.rdf-tests/`（371 件 · 1.7M） | W3C RDF 测试套件 RDF/XML 分册（rdf11/rdf-xml + rdf12/rdf-xml，manifest 落账 197 案） | [w3c/rdf-tests](https://github.com/w3c/rdf-tests)（GitHub） | **W3C Test Suite License**（2008-04-14）+ **3-clause BSD** 双许可（全文随目录 `LICENSE.md`） | 原样快照；目录 `SHA256SUMS` 锁版（371 项）；出处/收编范围/复核径见目录 `SOURCE.md` |

规范链接（供复核）：

- W3C Test Suite License：<https://www.w3.org/Consortium/Legal/2008/04-testsuite-license>
- W3C Document License：<https://www.w3.org/Consortium/Legal/2002/copyright-documents-20021231>
- WHATWG Encoding Standard：<https://encoding.spec.whatwg.org/>（CC BY 4.0：<https://creativecommons.org/licenses/by/4.0/>）
- w3c/rdf-tests 上游仓：<https://github.com/w3c/rdf-tests>（RDF/XML 分册随目录 `LICENSE.md` 双许可）

## 二、运行时依赖（不随仓再分发）

| 包 | 版本 | 许可 | 用途 |
|---|---|---|---|
| `Milky2018/xml` | 0.6.1 | Apache-2.0 | StAX 式拉取底座（经本仓适配层收口，公开面零底座型泄露） |
| `moonbitlang/async` | 0.22.4 | Apache-2.0 | 异步运行时（IO / 测试面） |

依赖经 mooncakes 分发，本仓不复制其源码：`.mooncakes/` **不入跟踪面、不入发布包**
（`.gitignore` 已列）。

## 三、维护条件与重评估

- **语料升级**：任何语料增删/换版 = 同笔更新本表 + 重生成该目录 `SHA256SUMS` + 在 CHANGELOG 记一笔。
- **许可变更**：上游许可改版（如 W3C 文档许可迁移、WHATWG 许可变更）须重评估本表并同步 README §许可证。
- **依赖变更**：`moon.mod` 的 import 变动须同步第二节（不随仓再分发，但披露面保持可比）。
- **重评估触发**：每次发版前评审一次；语料或依赖每次变更时各一次。
