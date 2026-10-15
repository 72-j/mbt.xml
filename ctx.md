# moonxml 即时账本（ctx）

版本：v0.1.0（2026-10-10 立卷）
本卷定位：**有时效、只对本文件夹有效、可修改**；记录役实态与判断，不记录 ADR；
战役关闭后刷新或归档。

---

## 1. M0 底座探针役（2026-10-10，已关）

- **起因**：XML 底座选型。两候选 + 自建参照；探针件随仓（`src/probe/`，
  体例对齐 moonxr 探针件），证据快照 `probe/M0_OUTPUT.txt`（35 行自报）。
- **实探版本**（moon add 实解析，比缓存认知新，按实解析记账）：
  `Milky2018/xml@0.6.0` / `moonbit-community/XMLParser@0.2.6`。
- **结果**：

| 维度 | Milky2018/xml 0.6.0 | XMLParser 0.2.6 |
|---|---|---|
| 语料 well-formed（8 例：嵌套/声明+DTD 实体/ns/CDATA/注释+PI/unicode/深 50 层/多属性） | **8/8** | 8/8 |
| 畸形拒绝（未闭合/错配/坏实体/游离 `</`/空文档） | **5/5**（XmlError 带 SourceSpan） | 失败仅 None（无位置信息） |
| 保真（内置实体展开/DTD 自定实体/CDATA 分型/注释保留/PI 拆 target,data/namespace 解析 uri+local+prefix） | **6/6** | 未逐项验（DOM 面等价） |
| Writer 往返（parse→write→re-parse 事件数等） | **ok** | —（无 writer） |
| 性能（1MB 合成档，中位 k=5，native） | **134ms（~7.4MB/s）** | 1105ms（8.2× 慢） |
| 形态 | StAX 式拉取 + NamespaceReader + Writer + 多后端 | 解析组合子库 + XMLDocument DOM |
| 自带测试族 | W3C conformance / property / bench / audit 随包 | quickcheck |

- **拍板 [定案] R-X1**：底座 = **Milky2018/xml 0.6.0（钉版本）**。
  - XMLParser 不采用：组合子定位是自定义语法拼装，非通用 XML 底座；错误面弱。
  - 自建路线否决：moonttl 级成本，而 Milky 已自带 W3C 一致性/property/bench
    测试族与 writer——无重建收益。
- **注意点（消费方契约，进 Node 适配层设计）**：
  1. 相邻 `Text` 事件按实体边界**切分多段**（quick-xml 风格）——消费方必须
     自行拼接相邻 Text（保真探针首测假阴性的根因，教训入案）。
  2. 自闭合根元素的事件是 `Empty` 不是 `Start`+`End`——适配层两臂都要接。
  3. `XmlError` 带 `SourceSpan`——moonxml 错误面直接透传位置信息。
- **月台遗留**：`src/xml.mbt` 占位件待 M1 换成真面；`@async` 依赖为探针计时引入，
  M1 后如无他用可撤。

## 2. 役M1:Node 适配层 + 数据模型(2026-10-15,已关)

- **落地面**:`src/node.mbt`(模型)/ `parse.mbt`(适配折叠)/ `translate.mbt`
  (错误/位置翻译)/ `serialize.mbt`(发射器);占位件 `xml.mbt` 退役。
  门:`roundtrip_test.mbt`(6)+ `contract_test.mbt`(8)= **14/14 绿**。
- **R-M1a [定案] 模型全自有规范型**:XmlName/XmlDecl/Attribute/Element/Node/
  Document/SourceSpan/XmlError* 全为本包 `pub(all)`——底座型零泄露,
  R-G2"依赖面 = @moonxml.Node + XmlError"兑现(换底座只改适配层)。
- **R-M1b [定案] xmlns 并回属性面**:底座把 xmlns 声明与普通属性分离
  (`namespace_declarations`),适配层并回队尾统一按属性发——序列化→再解析
  字符串定点成立(普通属性在前,xmlns 按底座序随后)。
- **R-M1c [定案] 序列化 = 自有发射器**(`Document::to_xml`,纯函数无 raise):
  底座 Writer 是事件形,且 Event/SourceSpan 底座侧 `pub`(只读)不可跨包
  构造,合成事件此路不通;树形发射自控保真(声明/DOCTYPE/PI 原形发,
  文本与属性值 `@xml.escape` 复用底座;无子元素自闭合 = 规范形)。
- **事实记账(底座行为,消费方须知道)**:
  1. 树节点不带 span——往返等价(Eq)比较才成立;span 只走错误面
     (契约三=XmlError.At 透传行列,钉 col=7 实报形)。
  2. **实报勘误**:错配闭标/未闭合/空文档,底座实报 **InvalidSyntax**
     (带行列);`UnmatchedTag`/`UnexpectedEof` 词表在但此形不走——
     错误分型测试钉实报形,不钉词表许愿形。
  3. DocType 只保**名字**(底座事件面只暴露名);内部子集在解析期展开,
     往返在展开文本上等价(实体语料 14 门内已钉)。
  4. Text 相邻拼接(契约一),CDATA 不并入文本(分型保留,保真钉)。
  5. 缺省命名空间作用于声明所在元素自身(root 吃默认 ns——测试前提
     曾写反,实测定谳拨正)。
- **月台**:根槽/根前/根后三区由(根槽长 + 栈深)推导,无阶段枚举;
  `probe/pkg.generated.mbti` 为探针包接口再生,随 M0 探针件留仓。

## 3. 换机迁移清单

纯 MoonBit 仓（无 C stub）：clone 后 `moon install && moon test` 即可；
依赖版本以 `moon.mod` import 钉为准（Milky2018/xml@0.6.0 等）。
