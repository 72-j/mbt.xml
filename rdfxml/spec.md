# rdfxml —— RDF/XML 解析器 立案卷

> 立案日 2026-10-24。族内最后一块序列化拼图：moonxml（XML 基座）之上的
> RDF/XML（RDF 1.1 XML 语法）解析器，W3C rdf-tests 官套作验收门。
> 本文 = 立案卷；役 X1 立户时随模块入库，定案候选经用户拍板后拨正为定案。

## 1. 背景与动机

RDF 解析库项目族现状：moonttl（Turtle / TriG / N-Quads，W3C 89/89）、
jsonld（JSON-LD 1.1，官套 1437）、moonxml（XML 1.0/1.1 基座，xmlts
2572/2585）。W3C 官方 RDF 序列化中唯一缺口 = **RDF/XML**。

基座已就位，难点恰好都长在 XML 层且已被 moonxml 兑现：

- NS-aware 解析（QName → IRI 展开的前提）；
- `NsMode::Off` 宽名口——`src/parse.mbt:380` 注释明写 RDF/XML 旧系
  （首/尾冒号名、组合字符衔接段）是预留消费方；
- `xml:lang` 在 DOM 属性面可得；billion-laughs 防护、版次键控、
  规范化序列化（`parseType="Literal"` 的子树序列化底子）。

## 2. 目标与非目标

**目标**

- G1 解析方向：RDF/XML 文档 → RDF 数据集（RDF/XML 是 triple 语法，
  数据集 = 单一默认图；词形与 moonttl 家族 N-Triples/N-Quads 格式一致）；
- G2 W3C rdf-tests 官套全案入账：**manifest 落账 = 197 案**（rdf11
  166 = 126 TestXMLEval + 40 TestXMLNegativeSyntax；rdf12 31 全
  TestXMLEval，dir/tt/an 三族）——用例表生成件
  `case_table_gen.mbt`（opself/rdfxml_casegen 自吃狗粮 regen，黄金门
  regen ≡ 盘上；rdfxml 模块零 moonttl 依赖），
  plain / deferred 双桶 pin 闭包（家族套件宪法）；
- G3 数据集级对拍门：正例解析结果与套件期望输出按**四元组多重集**
  对拍（.nt 是集合不是字节序，不做逐字节）。

**非目标（挂账后续役）**

- RDF/XML 写出方向（serializer）；
- 流式（SAX 形）解析——首版 DOM 全量走映射，perf 刀后议；
- moonxml 的接口变更（见 D-3，首版零涟漪）。

## 3. 定案（2026-10-24 五条全拍，含细化）

- **D-1 落位**：新顶层独立模块 `rdfxml`（`thy1016/rdfxml`）。
  理由：家族先例 jsonld 与 moonttl 是**格式一致**而非代码耦合；
  住 moonttl 否决双理由——迫使 submodule 引 moonxml 依赖改变其
  依赖姿态 + **污染 moonttl 依赖图**。
- **D-2 依赖面**：moonxml（parse + DOM）唯一硬依赖 +
  moonbitlang/async（套件 harness fs 面），**版本精确钉**；
  零 C 零 native-stub，全后端 NFR 家族红线不破。
- **D-3 xml:base**：映射层自处理——DOM 属性面读 `xml:base` 维护
  base 栈；**RFC 3986 相对解析 = 自写**（D-2 钉死依赖面，jsonld 的
  解析器不引入；口径与 jsonld / moonttl 既有实现逐例一致——家族
  格式一致纪律，对拍校准用 jsonld 侧语料抽验）。moonxml 0.1.0
  已发布面零改动。**「用得痛」量化判据（X2 末核）**：映射侧 base
  处理代码 > 100 行，或套件红案中 base 因果 ≥ 5 案 → 立项给
  moonxml 提 base 解析面（上游 PR 候选，另立笔）。
- **D-4 判据分层**：正例 parse 成功 + .nt **数据集对拍 = 四元组多重集
  相等，实现为逐四元组匹配消去 + 计数相等**（禁整体排序逐字节）；
  负例 must-error；deferred 逐案留账；`pin=true` 断言 failed==0 且
  桶闭包——任何案漂出桶列表即红。
- **D-5 版次**：RDF 1.1 XML 语法（https://www.w3.org/TR/rdf11-xml/）
  为本体；rdf12 33 案为扩展面，**deferred / 差异逐案说明必须写明：
  属于 1.2 的哪条新特性 + 1.1 下是否可通过**。

## 4. 役次划分

| 役 | 内容 | 门槛 |
|---|---|---|
| X1 | 立户（moon.mod / git 形 / moon.work 成员关系）+ 数据模型（Term/Quad，N-Quads 同构词形）+ moonxml 接入 + 套件 harness（manifest.ttl 解析——moonttl 自吃狗粮——桶账骨架 + 语料随仓锁版 SHA256SUMS） | 现状读数入账 |
| X2 | 主链映射：node/property 元素走树 + rdf:about/ID/nodeID + 属性属性 + xml:lang / xml:base 栈 + QName 展开 | 正例主链绿 |
| X3 | 语义难点：parseType Resource / Literal / Collection + rdf:li 容器成员序号 + reification + datatype 面 | 全正例 |
| X4 | 负例逐案（约 41 案）+ .nt 数据集对拍门 | 套件闭包 pin |
| X5 | 收官：README 家族体例 + 发布预备 + mooncakes 上架候令 | RELEASE:PASS |

每役出 commit（一句话主题）；役前 `git status` 快照，役毕即入。

## 5. 风险与坑账预判

- **xml:base 栈语义**：嵌套元素继承与重置（§5.3），与相对 IRI 解析
  顺序耦合——X2 先写判点自测再上套件；
- **parseType="Literal"**：词形 = 子树序列化，moonxml `to_xml`
  规范化形与套件期望的规范化口径可能差一字节级细节（属性序/引号形），
  预留 deferred 后路，逐案论证后收；
- **amp-in-url 族**：QName 展开 + percent-encoding 交互；
- **rdf:li 序号**：容器成员属性 `rdf:_1..` 按文档序生成，重复序号
  语义按规范裁；
- **对拍粒度**：.nt 期望是多重集，禁逐字节门（字节门留给家族格式
  一致性自测，不是套件判据）；
- **家族纪律衔接**：nquads 验证分层宪法（词法无脑扫 / 引擎尾点归位 /
  组装后 validate）、套件双桶 pin、探针件当日废弃、停手判据。

## 6. 起跑基线

- 语料：`.bak/rdf-tests/rdf/rdf11/rdf-xml` + `rdf12/rdf-xml`——X1 收编
  入模块 `.rdf-tests/` **随仓入库** + SHA256SUMS（jsonld 先例：语料本体
  跟踪入库，独立 clone 门才能跑套件；moonxml 的 `.rdf-tests/` 是未跟踪
  本地卷，不作范式）；
- 基座：moonxml 0.1.0 已发布（mooncakes），`NsMode::Off` / `to_xml`
  规范化形为映射层两个既知接口依赖；
- 格式基准：moonttl N-Triples/N-Quads 词形 + jsonld toRDF 通道同构。
