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

## 3. 役G1:xmlschema 方言三件套 + 试点联调(2026-10-15,已关)

- **落地面**(生成器侧住根仓 `skelgen/`,消费件住本仓):表
  `src/example/catalog/catalog_schema.toml`(spec §1.2 原表 + author 叶行补齐);
  生成器 `skelgen/schema/xmlschema_toml_gen.mbt`(parse/validate/emit 三件套,
  `toml_gen_base.mbt` 零改动——"新方言 = 新数据"照题兑现);再生命令
  `moon run skelgen/xmlregen`(根仓可执行包);产物
  `src/example/catalog/schema_gen.mbt`;联调门
  `src/example/catalog/catalog_contract_test.mbt`。
- **门**:双门 + 负例住生成器仓 `skelgen/schema/xmlschema_toml_gen_test.mbt`
  (金门逐字节 + scope 门 + validate 负例四钉,**40/40**);本仓
  `moon test` **15/15**(M1 14 + G1 联调 1)。
- **R-G1a [定案] 发射器铁律兑现**(moonxt 先例跨线复用):再生件必须
  `moon fmt` 幂等(再生成 → fmt → diff = 0),否则黄金门在 fmt 一跑即碎。
  fmt 规范形五则(本次 fmt 残差实测归纳):裸臂(单语句臂块折叠为表达式体)/
  结构体字面量 shorthand+尾逗号/80 列宽行判据(≤80 单行,超长括号续行)/
  缩进随宿主语境(顶层 2 空格,循环体 4 空格)/helper 签名 ≤80 收单行。
  签名宽行决策按**实宽**不按参数个数(make_attribute 单行 82 字符 → fmt
  保持展开;attr_find 79 字符 → 收单行)。
- **R-G1b [定案] 门随生成器走**:双门 + 负例住生成器仓(读 `./moonxml/...`
  径,jelly/bm25 金门先例),钉的是生成器不是产物;消费仓不放门的复印件,
  消费仓只放联调门(真 XML 往返:值级 Eq + 字符串定点)。
- **R-G1c [定案] 词表封闭收口**:kind 词表 node|leaf|any;基元词表
  String|Int|Double|Bool(spec 表样的 Raw 除名——无消费端不进词表,validate
  红 `unknown text_type`/`unknown type`);ref 键 → 字段 `ref_id`(ref 保留字)。
- **R-G1d [定案] 产物面**:pub(all) 结构体(门面测试跨包构造)+ derive(Eq)
  + 显式 `pub extend`(derive 隐式晋升 [0079] 弃用面);from_tree 收
  `@moonxml.Element` 返 `Result[T,String]`(R-M1 无 span,错型先收 String
  锚点);to_tree 返 Element(canonical 序 = 表序);helper 按用量条件发射
  (消费包 unused 警告面归零)。
- **月台**:spec §1.2/§1.3 勘误已同笔(target_package 真径/表样补 author 行/
  Raw 除名/产物形实态/门与再生入口归位);`skelgen/` 树内先期迁移态
  (散件→子目录)系未提交在途件,本役未动——提交时须整树同笔或分笔,待拍。

## 4. 役M2:xmlconf oracle 层(2026-10-16,已关)

- **落地面**:套件锁版 `.xmlconf/`(xmlconf/ 树 3386 文件 + SHA256SUMS +
  扁平清单 TSV);扁平器 `src/cmd/xmlconf_flatten/`(dogfood @moonxml 自解析
  21 本分册);套件门 `src/xmlconf_suite_test.mbt`(file-by-file 双桶钉);
  `src/moon.pkg` 补 test 导入(async/fs + utf8)。
- **门**:`moon test` **16/16**(M1 14 + G1 1 + M2 1);套件读数
  **2068 passed / 517 deferred / 2585 total**。TSV 再生逐字节稳定
  (md5 前后同);SHA256SUMS 在 `.xmlconf/` 内 `sha256sum -c` 可验。
- **R-M2a [定案] oracle 形态对齐 jsonld 先例**:锁版随仓(不 download)+
  扁平清单为桶表真源 + plain 桶 hard verdicts + deferred 桶逐条可辩护 +
  桶闭三钉(failed==0 ∧ deferred 全消费 ∧ passed+deferred==total)。
- **R-M2b [定案] invalid/error 归 plain 桶**:invalid = DTD 有效性违例,
  非良构层职责 → 必解析;error = XML 1.0 可恢复违例 → 按引擎实际行为钉
  (本引擎全拒,即 error 案全走必拒判)。
- **五族分诊定谳**(517 案逐条入 deferred 桶,家族↔样张校准后机械分类,
  UNCLASSIFIED=0):
  - **A 编码面(29)**:UTF-16/japanese 双字节(euc-jp/shift_jis/iso-2022-jp)/
    BOM 冲突/裸坏字节——String 域判据外;等编码层战役。
  - **B 外挂 DTD/实体(61)**:SYSTEM 外部子集/外部实体内容,引擎不取外挂——
    判据外。官方聚合清单 xmlconf.xml 本身即外部参数实体聚合体,不可直解,
    扁平器以「组→分册」映射绕行。
  - **C PE 展开/条件段(39)**:内部子集 PE 间接展开(`%xx;`→`&#37;zz;` 形)
    与 INCLUDE/IGNORE 条件段——新能力单独立项。
  - **D XML 1.1 语义(68)**:版本门+1.1 字符策略+NS 1.1 前缀解绑
    (`xmlns:a=""`)——新能力单独立项。
  - **E 名字/字符域(320)**:引擎名字符用 1.1 紧凑区间,套件 1.0 面要求
    1.0 全表——**双向偏差**:PITarget 300 案(1.1 区间放行 1.0 非法字符,
    漏拒)+ oasis p04/p05pass1(1.0 合法组合字符/中点被拒,错拒)同根。
    新能力单独立项(1.0/1.1 双表策略)。
- **事实记账**:
  1. 分册 sun×4/ibm×6 是裸 TEST/TESTCASES 片段(多顶层素)——扁平器
     剥前置声明 + 包合成根再解析;xmltest.xml 带声明,剥声明是前置条件。
  2. 套件文件有非法 UTF-8——harness 走 `@utf8.decode_lossy(binary())`,
     `.text()` 会在坏字节档整门炸。
  3. moonxml 模块默认 target wasm,async fs 必炸(`unreachable`)——
     套件门/扁平器一律 `--target native`(与域定门表 moonxml 行一致)。
  4. not-wf 的 BOM 档案"碰绿"(decode_lossy 坏字节→拒,verdict 观测面
     正确但机制非编码判据)——记账不拔钉,编码层立项时一并正判。
  5. deferred 桶表错字会静默漏判(条目不消费,桶闭仍可过)——
     `assert_eq(deferred_count, deferred.length())` 桶表闭钉防漂移。
- **月台/余账三分类**:配置类 = 无;外部依赖类 = 无;新能力类 = 五族
  deferred 对应五项(A 编码层/B 外部实体解析器+catalog/C PE·条件段/
  D XML 1.1 面/E 1.0 名字全表),均单独立项候拍。

## 5. 役A1:编码前端 + 版本键控 Char 门(2026-10-16,已关)

- **起因**:M2 收官五族候拍,选役 A(编码面)——五族中唯一全在
  moonxml 自有层(不动底座)的战役;施工中定谳其真身不止「换码」
  而是「byte→String 前端 + 版本键控 Char 门」一整层。
- **落地面**:`src/decode.mbt`(pub `decode_source(Bytes)` + 内部
  BOM 嗅探/UTF-16 严格解码/声明嗅探/严格 UTF-8/latin-1/Char 门);
  `src/decode_test.mbt`(机制单元 22);错误词表新二词
  `XmlErrorKind::Encoding(String)` / `IllegalChar(Int)`(node.mbt);
  套件门源入口改 `decode_source → parse`(decode_lossy 退役)。
- **门**:`moon test --target native` **38/38**(M1 14 + G1 1 + M2 套件 1
  + A1 单元 22);套件读数 **2135 passed / 450 deferred / 2585 total**
  (自 2068/517:净关 67)。
- **R-A1a [定案] 支持编码集 = {UTF-8(严格,BOM 剥)/ UTF-16(BOM 键控
  LE/BE,代理配对严格)/ ISO-8859-1 / ASCII 同族}**,其余编码名=
  UnsupportedEncoding 拒(对位 R-M2b「按引擎实际行为钉」——8 位日文
  三码不进支持集,japanese error 族正判)。BOM/声明双向冲突 = 错
  (UTF-8 BOM+latin-1 声 / UTF-16 BOM+utf-8 声)。
- **R-A1b [定案] Char 门 = 解码层前置、版本键控**:1.0 全表
  ([#x9|#xA|#xD|#x20-#xD7FF|#xE000-#xFFFD|#x10000-#x10FFFF])vs
  1.1 restricted-literal([#x1-#x8|#xB-#xC|#xE-#x1F|#x7F-#x84|#x86-#x9F]
  须走字符引用;NEL 字面合法);版本取自声明嗅探。Char 生产约束
  一切产生式,前置整扫是正判据非碰绿——底座不做此面,本层补位。
- **闭合账(67)**:valid 面 7(japanese UTF-16 ×4 + xmltest 049-051
  UTF-16LE 无声明);拒面 60——严格 UTF-8(168-170/E27/02n30/31/
  errata-4e ibm04 ×8/xml-1.1 P04 ×8/n58/n67)、1.1 字面门
  (ibm02n32-63 ×32、eduni 011/013/041)、UnsupportedEncoding 门
  (japanese 8 位 ×6)、BOM/声冲突(misc/007)、底座声明词法
  (055/008/009)。**碰绿正判收编**:plain 桶 oasis p02fail*31
  (UTF-16LE + C0/非法字)与 iso-8859-1 系 13 档(NS IRI/NEL)自
  lossy 碰绿转正判。
- **勘误(入账)**:R-M2b 括注「error 案全走必拒判」与门码不符——
  门码实钉 **error → 必解析**(expected_ok 含 error),实况 32 案
  error 档全在 plain(18 过 14 拒);14 拒者回挂 deferred
  (japanese 8 位 6 + bomboom 3 + 008/009/055-057 5)。若改钉
  「error 双向可过」此 14 案即闭——月台留拍,不在 A1 内翻案。
- **事实记账(底座/套件)**:
  1. 底座对已解码 String 面做 decl/内容一致性启发
  (「declared UTF-16 but content is ASCII/UTF-8」)——UTF-16 声明档
  (sun utf16b/l)解码正确仍被拒;BOM 已消费,核对权在底座,
  A 残留桶待底座修或 bytes 入口。
  2. 底座声明词法拒 NEL/伪属性间隔(055「whitespace required
  between XML declaration pseudo-attributes」)与非常规 version
  (008「invalid version」)——error 判词档按必解析钉则恒挂。
  3. moonxml 模块默认 target wasm 下 async fs 仍必炸——套件门/
  扁平器一律 `--target native`(不变);decode 面本身全后端可移植。
- **月台/余账三分类**:配置类 = 无;外部依赖类 = 无;新能力类 =
  ① error 判词改「双向可过」的口径翻案(14 案);② 8 位日文三码
  (euc-jp/shift_jis/iso-2022-jp)进支持集(需 JIS 表,6+案);
  ③ 四族 B/C/D/E 残部照旧候拍(B 70/C 39/D 23/E 310)。

## 6. 换机迁移清单

纯 MoonBit 仓（无 C stub）：clone 后 `moon install && moon test` 即可；
依赖版本以 `moon.mod` import 钉为准（Milky2018/xml@0.6.0 等）。
