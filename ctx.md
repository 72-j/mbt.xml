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

## 6. 役E1:版本面键控名字段门 + 名字表 gen(2026-10-21,已关)

- **起因**:A1 收官余账候拍选 E 族(310,最大桶)。役前探针定谳三层事实:
  ① 漏拒向 P85 族(下标 302)的 PI 住**内部子集**,但底座事件面照发 PI,落树
  prologue/epilogue——树面全查即可及;② 错拒向(8)卡底座
  `split_qualified_name`(首/尾冒号名、组合字符衔接段),树建前即拒,moonxml
  层门不可达;③ **套件本身是版本分裂设计**——同名测试成对
  (`ibm/not-wf/P85/ibm85n03` not-wf vs `eduni/errata-4e/ibm85n03` valid,
  注释自供 "only legal per 5th edition"),官方裁决模型 = TEST 元素
  EDITION 属性按适用版次标注,处理器按面选子集。M2 "1.0 全表 vs 1.1 紧凑
  双向偏差"的判断就此勘误:不是 1.0 vs 1.1,是 **1.0 的 4e 全表面 vs 5e
  紧凑面**(5e 名字段与 1.1 同形),两套判词都在套件里。
- **落地面**:
  - 数据面:`.xmlnames/`(W3C XML 1.0 4e + XML 1.1 2e 规范 HTML 锁版随仓,
    SHA256SUMS 可验)+ `tools/extract_name_tables.py`(规范文本→区间表机械
    翻译)+ `src/xml_name_tables.toml`(人维护面:1.0 4e 五产生式
    base_char/ideographic/combining_char/digit/extender + 1.1 两产生式
    name_start_char/name_char,hex 字面,refs 记产生式引用);
  - gen 链:skelschema 新方言 `xmlname_toml_gen.mbt`(parse/validate/emit
    三件套,base 零改动——“新方言 = 新数据”再演;production id 是数据,
    生成器零硬编码);负例 9 + 形态钉住 `xmlname_toml_gen_test.mbt`
    (49/49);金门 + scope 门住 `skelgen/xmlname_link_test.mbt`
    (重生成 ≡ 入库件逐字节 + 顶层键闭集);再生命令
    `moon run skelgen/xmlnameregen`;产物 `src/name_tables_gen.mbt`
    (区间表 + `is_<id>` 谓词,refs 机械展开为析取,fmt 幂等);
  - 手写层:`src/namecheck.mbt`(拼装语义:1.0 Letter = BaseChar|Ideographic、
    Name/NameChar 组合、版本键控)+ `parse_edition(source, edition~)`
    接线 + `XmlErrorKind::IllegalName(String)` 新词;
  - 套件门:扁平器 TSV 加第 4 列 EDITION(再生逐字节稳定,md5 同);
    门改双面裁决(EDITION=1 2 3 4 → 4e 表面 / =5 → 5e 面 / 缺省 = 两面
    全查)+ no-face 闭钉。
- **门**:moonxml **48/48**(38 旧 + E1 名字段单元 10);套件读数
  **2437 passed / 148 deferred / 2585 total**(自 2135/450:净关 302,
  桶外零破坏)。生成链:skelschema 49/49 + skelgen 8/8(金门咬进域定门)。
- **R-E1a [定案] 名字表 = 规范锁版 + 提取脚本 + TOML 人维护面**:区间形
  照规范原文(贴邻合法,如 4e #x00FF|#x0100——金门咬出后撤销“贴邻并一条”
  判);ref 只记引用不展开(展开是 emit 期机械形);词表封闭,生成器不识
  具体产生式名。
- **R-E1b [定案] 门形 = 策略显式化**:版本(version=1.1/1.0/缺省)选表族,
  版本面(XmlEdition:Editions1to4/Edition5)在 1.0 族内选表;`parse()`
  = Edition5 缺省面(= 现行底座行为,旧消费者零感知);版次敏感消费方走
  `parse_edition`。门在树建后全量行走(DOCTYPE 名/PI 目标/元素名/属性名);
  5e 面门 ⊆ 底座(零新增拒绝,自防底座换面),≤4e 面是门增量所在。
- **R-E1c [定案] 套件门 = EDITION 感知双面裁决**:manifest 第 4 列
  (缺省 = 全版本适用);每案按适用面逐面验,全匹配才过;非 4/5 标注 =
  no-face 闭钉红(防新版次标注静默漏判)。302 漏拒族(EDITION=1 2 3 4)
  以 4e 面门正判入 plain;313+383 标注案读数全咬模拟预言。
- **R-E1d [定案] 施工前 python 全量模拟锁面**(A1 先例二演):真管线倾倒
  1360 parse-ok 案的全名字面,按新表预言翻案——302 全闭 / plain 零破坏
  预言与实跑严丝合缝;模拟器自身三虫(TSV 4 位 hex 正则咬不住 5 位、
  NameChar 忘并 digit、not-wf 判“门拒”误记破坏)皆即地定谳,记此防再犯。
- **事实记账**:
  1. 底座 `split_qualified_name` 名字策略(拒首/尾冒号、拒组合字符衔接段)
     是 8 错拒案与 D 族 1.1-valid 案(P04a/P05 冒号名)的共同根因——待底座
     修或 moonxml 自立名字层(后者的六边形含义:底座降格为纯词法事件源,
     命名空间/名字面收 moonxml 自有)。
  2. 内部子集 PI 落树 prologue/epilogue(M2 已证),E 族正判靠它——树面
     全查的覆盖面证词在此。
  3. 根仓存量红 5(非本役):moonspace gen_gate(已撤出主仓索引的独立
     工作区)/ mooncmd sqlite×3 / rdf trig 金门(rdf/ 无未提交改动)——
     各域自清,不在本役代改。
  4. 域定门表修:子模块 gitlink 行 porcelain 报「 M moonxml」(无斜杠),
     前缀不带 / 才咬得中(moonxml/moonttl 两行改);skelgen 门命令补根包
     (link 金门此前在门命令外)。
- **月台/余账三分类**:配置类 = 无;外部依赖类 = 底座名字策略(8 错拒
  +D 族冒号名同根);新能力类 = ① PI 目标 xml 保留字规则(PITarget -=
  XxMmLl 三连)未查——套件无判词案,消费端出现再立;② B 70/C 39/D 23
  残部照旧候拍;③ 8 位日文三码(JIS 表,亦可走本役 gen 形)。

## 7. 役E2:判词面勘误 + D 族重挂(2026-10-21,已关)

- **起因**:E1 关役余账候拍选小役——error 判词口径翻案(A1 月台留拍项,
  14 案)+ D 族重挂。役前探针定谳:D 族 23 案失败模式五类(NS 冒号名 /
  NS 1.1 解绑 / 底座 char-ref 校验 / 外部实体 / 版本冲突外取),其中
  016/019(文档自declared version="1.0" 而名字用 1.1-only 字符
  U+1D1B2/U+EFFFF)是 **E1 4e 面门已正判的纯桶迁移**,001/002(外部子集
  声明更高版本号)根因是外取改挂 B。
- **落地面**:套件门 error 判词改双向(Ok/Err 皆匹配;valid/invalid/
  not-wf 不变)+ 五桶迁移与注释全刷新。
- **R-E2a [定案] error 判词双向可过**:XML 1.0 §1.2/§5.1——error =
  可恢复违例,处理器报错后可停可续,报错即拒与继续解析都在规范符合带内。
  本引擎对这 14 案的拒因皆为能力边界(编码不支持/外部实体未取/声明
  词法),非无声错续——非放水。error-typed deferred 恰 14 案
  (A6 japanese / B3 bomboom / D5 008·009·055-057)全数收编。
- **R-E2b [定案] 根因归位重挂**:016/019 → plain(4e 面 IllegalName
  正判,零引擎改动——纯桶迁移,EDITION=1 2 3 4 标注与双面裁决自洽);
  001/002 → B 桶(外部子集版本号冲突,须外取才能判,判据外)。
- **门**:套件读数 **2437/132→2453/132/2585**(净关 16);桶态
  A2/B69/C39/D14/E8;门 48/48 --target native。零新代码(纯门语义 +
  桶表)。
- **事实记账(D 族 14 案残部根因五类)**:
  1. NS 冒号名错拒(6:P04a/P05×5 + E 桶 8 同根)——NS-always-on 与套件
     非 NS 面结构冲突:首/尾冒号名、组合字符衔接段在 NCName 规则下必拒,
     而 1.0 非 NS 面合法;闭案须 NS 模式旗标(引擎侧双模:NS-on 缺省/
     NS-off 面向非 NS 消费),自立 NS 层救不了(自有层同规则)。
  2. NS 1.1 解绑错拒(003/004,xmlns:p="" 1.1 合法)——自立 NS 层月台
     (version-keyed 解绑规则,唯一确定的 NS 层收益 2 案)。
  3. 底座 char-ref·实体校验面(043/054/ibm02v02/03/05,1.1 控制字符经
     引用合法)——底座 InvalidEntity 先拒,moonxml 层不可及。
  4. E50——1.1 2e errata 名字字符增补(#x85/#x2028 族),未进 REC 正文,
     引擎按 REC 表。
  5. 006——外部实体 valid 面(B 根因)。
- **月台/余账**:① NS 模式旗标(非 NS 消费面 + E 错拒 8/D 冒号名 6 的
  唯一闭案径;连带事件级名字门+真 span);② JIS 三码 gen 形
  (WHATWG index 表→TOML→skelschema 方言→decode 扩展;套件读数零增量
  ——japanese×6 已以 error 双向闭——但真解码能力是底座仓消费价值);
  ③ B 69/C 39 残部照旧。

## 8. 役N1:NS 模式旗标(2026-10-21,已关)

- **起因**:E2 关役月台首选项——E 错拒 8 + D 冒号名 5 = 13 案的唯一闭案径。
  役前定谳修正了 E2 的一个预判:「自立 NS 层」救不了这批案(自有层同为
  NCName 规则),真解 = **NS 处理本身可选**——XML 1.0 基础规范与
  Namespaces 是两个规范面,非 NS 处理器合法地接受冒号名/组合字符衔接段。
- **落地面**:`NsMode { On; Off }` + `parse_edition(source, edition~,
  ns~ = On)`;Off 路 = 底座 raw Reader(namespace_aware 缺省 false,
  PI 目标/DOCTYPE 名冒号合法)+ 名字原文直通(qualified_name = 原文,
  prefix/local/uri = None——非 NS 面无命名空间语义可记)+ xmlns 即普通
  属性保持原位;On 路不变(NamespaceReader,底座承担 NS 规则,无需自研)。
  名字段门(E1 树面全查)两模共用, editions 语义不变。套件门加 NS 列
  (扁平器按分册径 `eduni/namespaces/**` 标 `ns`,59 案;TSV 五列,再生
  逐字节稳定),NS 测试只对 NS-aware 处理器适用(官方套件独立成节的
  适用性语义),两轴正交:EDITION 选版次面,NS 选规范面。
- **R-N1a [定案] NS-off = 名字原文直通**:非 NS 面无命名空间语义可记,
  prefix/local_name/namespace_uri 三字段 None 形(不发明 NS-ish 结构);
  xmlns 不另眼。On/Off 两模树形状不同模不同树——各自往返自洽,消费方
  按模选径。
- **R-N1b [定案] 模拟镜像门码**:役前探针首跑 387/330 翻红全是探针口径
  差(定死 Edition5、未排 NS 面案、未算 error 双向、deferred 未排除);
  修至镜像门码后三账全绿(plain not-wf 零翻红/其余判词零翻绿/13 目标
  全接)。教训:模拟器必须与门码同构,差一条口径就是假红。
- **R-N1c [事实] 底座属性词法**:任意属性名后必须有 `=`(名字后直接
  `>` = 缺等错)——`tail:` 孤冒号属性名任何模式下都不可解析(与 NS 无关,
  底座词法面);sa/012 的 `:=\"v1\"` 形不受影响(名字 `:` + 等号)。
- **门**:套件读数 **2453/132→2466/119/2585**(净关 13);桶态
  A2/B69/C39/D9/E0(E 桶空壳保留);门 **53/53** --target native
  (NS-off 单元 5:冒号名三处/xmlns 原位/未绑前缀两模对照)。
- **月台/余账**:① D 桶 9:003/004(NS-aware 面内 1.1 解绑,底座 NS
  规则版本键控月台)/043·054·ibm02v02·03·05(底座 char-ref 面)/E50
  (errata 边缘)/006(外部实体);② JIS 三码 gen(真解码能力,套件零
  增量);③ B 69/C 39 残部(重型另立)。

## 9. 役J1:JIS 三码 gen(真解码)(2026-10-22,已关)

N1 月台项②(真解码能力,套件零增量——预判成立)。8 位支持集
utf-8/latin-1 → 扩 JIS 三码:euc-jp(3 标签)/ shift_jis(8)/
iso-2022-jp(2),判词真源 = 锁版 WHATWG Encoding Standard
(`.encodings/encoding-standard.html`,SHA256SUMS 三行;§12.1.1 /
§12.2.1 / §12.3.1 判词 + §4.2 标签表,均自锁版 HTML 逐节提取)。

- **数据面**:JIS X 0208 / JIS X 0212 索引表(WHATWG index,含
  NEC/IBM 扩充指针;11104 / 7211 槽,槽 0 = 未定义)锁版
  `.encodings/index-*.txt` → `tools/extract_encoding_tables.py` 直发
  MoonBit gen 件 `src/jis_tables_gen.mbt`(7730+6073 行)。
- **R-J1a [定案] 冻结规范数据走窄链**:无人维护面的锁版数据不设
  TOML 中间形、不进 skelgen(E1 链的成件条件是手维护表;此处真源
  即 WHATWG 发布物)——链 = extractor → `moon fmt` → 黄金对拍;
  **fmt 是链段**(数组重排非贪心、不可模拟,再生契约三步,CHAIN-STABLE
  两轮已验;extractor 直发 `Array[Int32]` 避 fmt 改型)。
- **判词面**:`src/jisdecode.mbt` 三解码器手写——指数循环 + 引字节
  状态;Shift_JIS 单字节三段(ASCII|0x80 直映 / 半角片假名 0xA1-0xDF /
  引字节 0x81-0x9F|0xE0-0xFC)、双字节 pointer =(lead−leadOffset)×188 +
  byte−offset(leadOffset 按 lead<0xA0 取 0x81/0xC1,offset 按
  byte<0x7F 取 0x40/0x41)、**EUDC 段 8836-10715 → 0xE000−8836+pointer
  先于表查**;EUC-JP 0x8E 半角 / 0x8F 转 jis0212(旗用毕即清);
  ISO-2022-JP 七态机(output 旗钉「转义后须吐码」,连转两次即错;
  ASCII/Roman 态拒 0x0E/0x0F;Roman 0x5C→¥、0x7E→‾)。spec 的
  restore-to-ioQueue 省略 = 错误即拒语义下恢复步无观察面。
  集成:`decode_8bit_document` 声明 match 加 JIS 臂
  (`jis_encoding_of_label` 判别 → `decode_jis` 分派 → gate_chars 照旧);
  **全私有面,.mbti 零差**(decode_source 签名不变,消费者零感知)。
- **门**:套件读数 **2466/119/2585 不动**(预判成立:6 案 japanese
  役E2 已按 error 双向收编 plain,真解码落地判词不变——本役交付
  能力非门数);单元 **72/72**(+19 净:wbtest 机制 15 + decode_test
  集成 4 − 退役 euc-jp 负例 1 + 真解码见证 1);见证钉三套件原件
  (weekly-euc-jp / pr-xml-shift_jis / pr-xml-iso-2022-jp)端到端
  须 Ok(J1 前为 Err,回退即红)。
- **R-J1b [事实] 测试向量两错皆 offset/逃回档**:① EUDC 上界首写
  差 1——trail ≥0x7F 走 offset 0x41 档,python 复算误用 0x40(F9 FB
  →10714,真上界 F9 FC→10715);② iso-2022 集成件首写漏逃回——
  **lead-byte 态吞 ASCII 配对是 spec 正判**(0x21-0x7E 双双入对),
  须 ESC ( B 逃回 ASCII,真套件文件皆带逃回序。两错皆向量错,
  解码器行为即 spec。
- **月台/余账**:A 桶残 2(UTF-16 声明档,底座启发面);B 69 /
  C 39 重型另立;D 9 底座面。日文三码全收,8 位日文编码面饱和。

## 10. 换机迁移清单

纯 MoonBit 仓（无 C stub）：clone 后 `moon install && moon test` 即可；
依赖版本以 `moon.mod` import 钉为准（Milky2018/xml@0.6.0 等）。

## 11. 役B2:外挂面实现(2026-10-22,已关)

B 族 69 案闭案役。架构落地见 spec 卷二 §5(R-B2 定案),此处记实态与
意外发现。

**读数**:套件 **2486/99/2585**(plain 2466→2486,B 桶 69 案 20 案毕业
入 plain,49 案实读分诊留 deferred);单元 **94/94**(新增 14:resolver
面 0/decode 4/doctype 4/subset 5/prepare 7 中并去重);`moon check`
零警零错。

**新件**:`resolver.mbt`(pub(open) trait EntityResolver + 缺省
None = 不取外件)/`external_decode.mbt`(外取件解码 + text decl 剥
除)/`doctype_scan.mbt`(序区 DOCTYPE 扫描)/`subset_parse.mbt`(声明
面收编 + billion-laughs 闸)/`external_prepare.mbt`(预组合 + span
补丁账本 + 错误重定位);`parse_edition` 增 `resolver~` 参,错误词增
`External(String)`(外取面独立语义,D-18 先例)。

**意外发现四则**:
1. **套件门 73% 虚读**:manifest 第 4 列(版次)空 = 1889/2585 案,
   旧 harness 对空列 faces 零迭代**空转判过**——注释写"缺省两面全查"
   而代码没跟上,2466 的读数里大半从未实读。役B2 拨正(空列 = 两面
   全查),134 案实读翻红,逐案分诊后余 48+2 归族留账。教训:**门
   的闭钉钉的是计数不是实读,改 harness 判据必须先审空转路径**。
2. **@fs.walk 按目录回调**(0.22.4):回调收 `(目录全径, 目录内条目
   名)`,条目含子目录名——当文件全径用即对目录 read_file 全炸,catch
   吞掉后 store 恒空(首版 resolver 全程没取到件,"零漂移"实为死接
   线)。async 裸语句调用本身会执行,坑在回调语义不在 await。
3. **注释收口三字组**:`skip_past(t, i+4, '-', '-')` 只咬相邻 `--`,
   把 `-->` 的 `>` 留给下轮 → "unexpected content"误拒(sa/066 族
   12 案实证);序区扫描同病(doctype 前有注释即哑火)。专用
   `skip_comment` 三处统一。**skip_past 只配二字组收口**。
4. **单文件模式丢 import**:`moon test src/probe_x_test.mbt` 判包失
   败后 @moonxml 自包导入不可见([4020]);且黑盒 `*_test.mbt` 各件
   **同命名空间**(与 `_wbtest.mbt` 异伪包相反)——探针 helper 与套
   件件撞名。探针验证一律走全量跑 + grep。

**实体链所有权闭合**(新知):内部字面量链 a→b(外取形)若留底座,
底座展开半路撞我层取走的外取名即 InvEnt(ext-sa/012 族根因)。解法 =
`internal_literals` 值账 + 不动点闭合趟:字面量(传递)引用到本表实体
即整链收归本层展开;不动链留底座,内部优先不扩权。**attr_face 须穿
透展开深度**(ibm41n11 实证:间接字面量把外取件带进属性值同属 WFC
违例,旗标丢一层即静默放行)。

**NoExternal 除名**:B1 拟的缺省拒对象无构造点(缺省走 `None` 径即
零漂移),对象面反添扫描成本,[0009]/[0001] 双警——除名,缺省语义
由 parse_edition 的 None 缺省承担。

**B 残留分族**(49 案,桶内逐族注释):T 文本声明校验闸 27(最大族,
ibm P77 1.1 全系)/P PE 闸 12(C∩B 并 PE 役)/V 外取件版次闸 6/
E 编码闸 1/S standalone 闸 1/G 声明语法闸 1/M manifest 版次标注缺 1
(两面冲突待 manifest 勘正)。ibm41n11 翻案教训:闭合趟上线后该案
从过变挂——**新径上线必须重跑全门,过案不是免检牌**。

## 12. 役B3:外取件准入三闸(2026-10-22,已关)

T 族 27 案(B2 分诊最大族)闭案。落地:`admit_external_text` = text decl
验证剥除(语法闸)+ 版本键控 Char 门;only-later 版次闸;外取子集体内
PI 位 text decl 拒。定案 R-B3a-e 入 spec 卷二 §6。套件 **2486/99/2585
→ 2510/75/2585**(25 案毕业:14 Char + 6 V + 5 text decl 语法),单元
**94/94 → 105/105**,`.mbti` 零差。

**役前普查法**(四轮,案级 triage 是本役根底):役前把 T27+V6 逐案
拆到「violation 住在哪、什么形、引擎在哪一步能看到」——直取案(件首
即 violation)/嵌套案(violation 住引用链第二跳)/PE 载体案(violation
住 PE 件,PE 展开未实现则根本取不到)。T 族由「同族 27」翻案为异质四
族,6 案 PE 载体当场免役留 C 族。**分族的真判据是可见性,不是目录或
命题标签**(n13 住 P77 目录实为 V 案、n14 住 P77 目录实为 G 案)。

**实态三发现**:

1. **has_word 边界集勘误(回归根因)**:`version='1.1'` 紧随形咬不中
   (边界集拒 `=`)→ doc_version 恒 None → 版次闸把 14 案 valid 1.1
   全误拒。定位路径 = 探针读拒因(「entity version 1.1 later」→ 基准
   None → 供词函数逐段核)。**供词函数边界集必须覆盖全部调用位形**
   ——has_word 本为 SYSTEM/PUBLIC 而生,version= 是新位形。
2. **套件自相矛盾案处置法**:ibm03v09 件 text decl 缺 P77 必备
   encoding 而套件判 valid,官方描述自标 "(This test is questionable)";
   dtd07 同由判 not-wf 且文内自注 encoding mandatory。同一条规则不能
   两判——引擎站规范严格面,案入 M 桶挂上游。**B3 前过门 = text decl
   未检视的漏读,不是规范正判;新闸上线前「过案」不背书**。
3. **n17/n18 真身与版次键控口径**:n17 文档无 XMLDecl(1.1 缺声明,
   缺省 1.0 面)→ NEL 分隔拒;n18 文档 1.0 → U+2028 分隔拒。分隔符
   合法性按**文档版次**键控(件在其上下文里被处理),非件自声明版次。

**操作坑一笔**:python 整块替换的 end 锚若含 `\n`,锚前导空格数须与
实文严格一致——差 4 空格即把后续行首并进锚、吃掉换行(P 桶被误删,
门数 12 翻红当场暴露;桶闭钉防呆再立一功)。

## 13. 分册分诊役:deferred 75 案逐案 census(2026-10-22,已关)

B3 后留账 75 案不再按族标签推定,逐案实测:探针复刻门环境(store 预载
+ TSV 五列 + 两面 parse_edition + resolver),对每案跑「摘除后判定」
(门同款规则:invalid/valid 须解析、not-wf 须拒、error 双向)。读数
**36 毕业 / 39 留账 / 0 无面**,摘除后门钉双验:**2510/75/2585 →
2546/39/2585**,单元 110/110。

**分册细账**(案/毕业/留账):ibm 37/22/15、oasis 11/9/2、sun 9/4/5、
eduni 10/1/9、xmltest 8/0/8。

**三案族勘账**(census 对旧账的翻案):

1. **E 桶(外取件编码声明闸,1)清零**:sun/not-wf/encoding07 实测
   过——B3 准入三闸上线后,外取件编码声明核对实已覆盖,旧「decode
   直通 UTF-8 面」注记过时。
2. **A 桶(2)拒点搬家**:utf16b/utf16l 的 decode 在 A1 后已过,拒点
   移至 parse 面(5e 面拒,invalid 案须可解析);旧「decl/内容一致性
   启发拒」注记作废,留账改挂 parse 面勘。
3. **C 族 39 → 5**:34 案毕业是 B2 外取链的白得——外部子集 PE 展开
   实已覆盖(PE 间接展开/条件段 cond01/cond02 过),非新能力落地。
   分族标签会掩白得,案级实测才见真实通过面。

**立项清单**(留账 39 案按处置面四项):

1. **PE/条件段边角**(5):sun decl01(内部子集条件段须拒未拒)/
   pe02(内部子集 PE 须收未收)/E13/ibm62n03/ibm63n03;
2. **XML 1.1 名字段/NS 解绑/控制字符**(8):eduni namespaces 1.1
   003/004(xmlns:p 空串解绑错拒)/xml-1.1 043/054/ibm02v02/03/05
   (1.1 控制字符经引用)/E50(errata 2e 名字字符);
3. **外取件闸精度**(22):P12 + PE 载体 6 + G2 + S2——闸已立,
   位形覆盖未满;
4. **A 编码 parse 面**(2):UTF-16 invalid 档拒点勘。

M 桶(2)不动:ibm77v30(manifest 版次列空)、ibm03v09(套件自相
矛盾),候上游勘正。

**操作法一笔**:新桶表机械拼装(路径集从 census 机械提取,新块写后
断言「块内路径集合 == 留账集合」)——断言当场咬住一处转录错
(xmltest 014-016 真径 valid/not-sa,凭族印象写成了 not-wf/not-sa)。
毕业判据 = probe 绿 + 门钉双验,两验缺一不可。

## §14 PE 位形役(2026-10-22)

**战果**:门 2546/39 → **2562/23/2585**(16 案毕业),unit 114/114,
check 零警告,`.mbti` 零差(全部 priv 面)。毕业案 = 8 计划(P 闸
005/006/E14/014/015/016/022/E18)+ 8 额外(新机使 PE 载体违例可见:
ibm77n03/n04、ibm79n01/n02、ibm77n21、xml-1.1/002、not-sa/002、
decl01 not-wf 正判)。

**机制四件**(subset_parse.mbt,全 priv):

1. **PE 声明立账**:pe_values(字面量值)/ pe_externals(外取 id 随录
   声明位 base)/ pe_depth 环闸。次序律 = 4.4.8 同律:内部子集 PE 值
   优先,外取子集同名让位(cond01/cond02 回归实证:外取 `%MAYBE`
   覆写内部值翻案一处,即修)。
2. **条件段关键词位形**:`<![ %e; [` 走 parse_conditional_pe——关键词
   从 pe_values 取,值带 '[' = 关键词+括号一体;体恒原文零移位
   (INCLUDE 解析体 / IGNORE 跳过体,位形展开不碰 span)。
3. **声明收口位形**:skip_markup_declaration 引号外 PE 引用——值内
   顶层 '>' = 声明在值内闭合(005/E14 补全声明形);值无顶层 '>'
   = 跳引用续扫;未名 PE / 孤 '%' 机械前进防挂。
4. **声明间引用位形**:reference_pe 升级——外取件取件后按外取子集
   解析(件内容里 ENTITY 声明落表,E18 链);字面量值 markup 起
   ('<' 或 '%')按 DTD 片再扫;碎片值机械跳过(pe02 族语义不破)。

**破案一笔(E18 外取链子代基址)**:链 `%pe;` → E18-pe → `%intpe;` →
`%extpe;` → ent 二取即断且无错。根因 = load_external_subset 直传
**生 system_id** 当子代基址——`../` 串在 resolver 面把 doc 目录咬掉
(suite_join 的 ".." 弹栈弹的是 doc 段)。破法 = merge_base_reference
(RFC 3986 §5.2 merge + 点段折叠):子代基址 = 父基址目录面 + 本件
system_id 合成,归一成仍对 doc 可解的相对引用;绝对径/scheme 原样
直传。E18 三跳全通,`ent` 落表展开。

**debug 三层乌龙自警**(役内耗时主因,记账防再犯):

1. 探针 resolver 自带 key 空间错(前缀不符 / 无点段折叠)——链断先疑
   工具再疑引擎;
2. grep 截断 + 多测案 debug 流交错 → 读数自相矛盾(同一探针一会
   3 ASK 一会 2 ASK)——多流输出必打标分 flu(T1|/T2|/BB|),禁 head 截读;
3. 白盒最小复现(内存桩 + 直调 priv 面)是解这类链断的正径——
   collect 直调通、prepare_external 全文档断,分叉一次收窄到位;
   产线临时 debug 钉点(parse_entity_declaration 入口 / fetch 后 /
   subset 装载入口)同 session 即撤,最后一步才用。

**回归钉四件**(subset_parse_wbtest.mbt):条件段 PE 关键词(INCLUDE/
IGNORE/bracket-in-value)/ 值内顶层 '>' 收口 / 外取链子代基址
(E18 形三跳)/ merge_base_reference 单元五形。

**余账**(23 案留账,桶表见 suite 门内注记):

- **配置类可立即清**(候用户令):无——本役余账全数挂外。
- **外部依赖类**(候用户裁):Milky 底座三簇 9 案(UTF-16 启发 2 /
  entity-value Char 5 / NS 解绑 2——fork vs upstream PR vs 留)。
  注意 62n03/63n03 新机下 PARSE-OK-NOW(not-wf 必拒未遂),拒因随
  新机翻新,是否并入底座簇候裁。
- **新能力类**(候单独立项):内部子集 PE 展开(E13/pe02,底座 turf);
  PE 值内 '%' 尾位形(p09fail×2/not-sa 008);S standalone WFC 闸
  (not-sa03/ibm32n09);G 外取子集声明语法闸(ibm68n06/ibm77n14)。
- **数据面**:E50 自 D 桶移入 M 桶(errata 2e 名字增补字符 4e 拒
  5e 许,manifest 版次列空 = 两面全查必翻,非引擎名策略可判)。

## §15 闸补役(2026-10-23)

**战果**:门 2562/23 → **2569/16/2585**(7 案毕业),unit 117/117,
`.mbti` 零差。B 桶 P/G/S 三族清零;留账 16 = A2(编码)+ C4(内部
子集 PE 2 + PE 闸边角 2)+ M3(数据面)+ D7(Milky 底座 NS/Char 簇)。

**三门**(余账新能力类七案,mislabel 案一并清):

1. **闸 S(standalone WFC,2 案)**:not-sa03/ibm32n09/ibm68n06(IBM
   误标 P68,实为 standalone 形)——standalone='yes' + 本表实体正文/
   属性位展开 = WFC 2.9 Entity Declared,expand_entry 顶层展开点拒。
   DoctypeScan 增 standalone_yes 捕获(peek_decl_standalone,判官权
   在底座,只取值)。零误伤根:纯内部文档表空不走预组合,预定义实体
   不入表。
2. **闸 P(实体值引用语法,3 案)**:p09fail1/2、not-sa 008——值内
   孤 '%' / 孤 '&' / 无 ';' 引用 = P09 产生式违例,
   entity_value_refs_wellformed 只核形不核表(声明面 = VC);非 ASCII
   码元概认名字符 = 超收侧保守(拒闸宁漏勿误)。
3. **闸 G(声明名合法性,1 案)**:ibm77n14 `<!ELEMENT 0node>` 数字起
   名——外取子集不进底座,语法判官在本层;名字按文档版次面选表
   (edition 贯通 ExternalLoad + name_predicates)。

**误伤一案自警(021/023 位形)**:闸 G 首版把 ATTLIST **名位 PE 引用**
(`<!ATTLIST %e; "v1">`,名字由 PE 供)误拒——门红 2 案立现,名位
'%' 旁路(合法性随 PE 展开面)复绿。教训:新闸首跑必全量门验,误伤
在门里现形,不在探针里——探针只看目标案,门看 2585 案。

**形法三笔**(役内编译器实证,在册坑的再现):

1. 前导 `&&` 续行 while 条件 = ambiguous_precedence 警——谓词提 fn
   收口(is_hex_digit_unit);
2. struct mut 字段仅 wbtest 改 = [0015] unused_mut——wbtest 改用记录
   更新字面量 `{ ..base, standalone_yes: true, }`,字段复常;
3. wbtest 构造点新字段 = 补 helper(subset_load_with),黑盒调用点
   同笔跟签名(prepare_external +edition 参)。

**余账(16 案,三分类)**:

- **配置类**:无。
- **外部依赖类**(候用户裁):Milky 底座两簇 7 案——NS 空串解绑 2
  (namespace.mbt:154 无条件拒)+ 1.1 控制字符 5(dtd.mbt entity-value
  char ref 1.0 表);A2 UTF-16 启发 2(reader.mbt:917)。fork vs
  upstream PR vs 留,候裁。
- **新能力类**(候单独立项):内部子集 PE 组合(E13/pe02——内部子集
  展开须重写 doctype 子集面 + SpanPatch 进子集,现账本只覆盖内容区);
  ibm62n03/63n03 拒因勘(新机下 PARSE-OK-NOW,须查条件段位形细账)。
- **数据面**:M3 候上游勘正。

## §16 役PE组合(2026-10-23)

**战果**:xmlconf 门 2569/16/2585 → **2572/13/2585**(pe02/ibm62n03/
ibm63n03 三案毕业),unit 117→120(勘误:121 误把探针件计入,2026-10-23 勘);`.mbti` 零差。C 桶只剩 E13(迁底座桶)。

**机制三件**(全 priv,subset_parse.mbt):

1. **子集 PI 闸**(ibm62n03/63n03):`skip_pi_declaration`——P79
   PITarget ::= Name(`<?[` 目标 `[` 非名首即拒)+ `?>` 收口扫描
   (目标后自由数据区不核,只找收口;无收口 = not-wf)。名谓词按版次
   面选表(闸 G 同径)。**首版误伤 311 案自警**:初版闸了数据区
   (skip_doctype_space 后即索 `?>`)= P85/errata-4e PI 带内容族全数
   误拒——PI 数据区是自由内容,闸只核目标+收口两点。全量门当场现形
   (2585 案),探针只看目标案看不出来,闸 G 教训重演。
2. **PE 值 char-ref 引用位收口**(pe02 链第一跳):`pe_value_char_refs`
   + `char_ref_code_point`——PE 值存储保持 raw(声明位不展,4.4.8
   bypass 组),**引用位展开时只解 `&#..;` 形**(`&name;` 保持原样);
   码点域防护(代理区/>0x10FFFF 拒)。十进制基位 bug 一笔:`&#60;`
   曾按 ×16 解(6×16=96='`'),链断在解码——十进制 ×10 十六进制 ×16。
3. **PE 载 GE 声明本层认领**(pe02 链第二跳):parse_entity_declaration
   InternalSubset 臂按 `pe_depth > 0` 分型——PE 值里产的 GE 声明 = 底座
   盲区(底座只见 raw 子集,PE 声明它不认),本层认领装表(first-wins:
   internal_literals/table 同名在前 = 让位);pe_depth == 0 直接字面量
   照旧 internal_literals(底座自持不变)。

**E13 迁桶裁定**:残点 = `&ent2;` 未声明实体豁免(spec 4.1 WFC Entity
Declared 的 PE-refs 豁免:DTD 有 PE 引用则未声明实体降为 VC)——这是
底座 Milky 语义(无条件拒未声明实体),非本层可修;迁 Milky 桶(9 案
同族,fork/upstream 候裁)。pe02 证明本层链路已通,残点单摆浮搁。

**debug 乌龙再添两笔**:(1) 探针 resolver 少拼 doc_dir → 外取 DTD 取
不到 = 假绿 OK 判词,读数怪异先核探针自身键空间(役卷自警三犯);
(2) 本役 Edit/长内容生成通道多次走样(占位符切片、路径咬空格、
heredoc 中断)——切 python 程序化替换(字节级 assert count==1)后
零走样,**长 MoonBit+CJK 内容一律走 python 分块,禁整文件重写**。

**余账三分类**:
- **配置类(可立即清)**:无。
- **外部依赖类(候外部/候裁)**:E13 + Milky 9 案(底座语义面,fork/
  upstream PR/留,候用户裁);M3 数据面候上游。
- **新能力类(候单独立项)**:内部子集 PE 值**声明位**展开(PE 值内
  `<!ENTITY...>` 经 `%pe;` 在声明位形补全——现认领只覆盖 GE 装表,
  PE 值进声明位形位 = E14/005 家族深水区);内部子集条件段
  (InternalSubset policy 下 conditionalSect = VC 域,候裁)。


## §17 役「Milky 13 案三分处置」（2026-10-23）

**裁定**（用户拍方向）：条目清晰、locus 明确、修复手术面小的 → 拟 Milky upstream PR；
套件数据面自相矛盾的 → 留置观望；fork 只在上游无响应且消费端真需时走（本期候而不用）。

**上游坐标**：底座 = Milky2018/xml@0.6.0（mooncakes 锁版）；locus 全部核自 0.6.0 源
（registry cache 拆包比对，moonxml 本仓零涉）。

| 桶 | 案 | locus（0.6.0 实测） | 处置 |
|---|---|---|---|
| A | sun/invalid/utf16b.xml, utf16l.xml | reader.mbt:918-925 | 拟 PR（包 D） |
| C | eduni/errata-3e/E13.xml | dtd.mbt:219 | 拟 PR（包 A） |
| D | eduni/namespaces/1.1/003.xml, 004.xml | namespace.mbt:151-155 | 拟 PR（包 B） |
| D | eduni/xml-1.1/043.xml, 054.xml, ibm/xml-1.1/valid/P02/ibm02v02|03|05.xml | escape.mbt:172-178 | 拟 PR（包 C） |
| M | ibm/xml-1.1/valid/P77/ibm77v30.xml, ibm/xml-1.1/valid/P03/ibm03v09.xml, eduni/errata-2e/E50.xml | —（套件数据面） | 留置观望 |

活证据（探针写跑删，已删）：A 桶两件**本带 UTF-16BE BOM**（fe ff 头，旧 iconv 取证吃掉
BOM 曾误判无 BOM）；四 faces 全拒 `InvalidSyntax("encoding declared as UTF-16 but content
is ASCII/UTF-8")`。根因：Milky 的 null-byte 嗅探跑在**已解码文本**上——BOM 已消费、
null 已不在，纯 ASCII 内容的合法 UTF-16 文档必被拒。勘旧注记：A 桶 locus 非 dtd.mbt
（char 表在 escape.mbt:172），D 桶注记同笔拨正。

### 包 A · E13 — undeclared entity in entity value（1 案）

**Locus**: `src/dtd.mbt:219` `expand_entity_value_with_budget` — `entities.get(name)` 为
None 即 `raise InvalidEntity("undefined entity reference: ...")`，无任何条件豁免。
**Spec**: XML 1.0 §4.1 WFC *Entity Declared*——仅当文档无 DTD、或内部子集不含实体引用、
或引外部子集且 standalone 未标 yes 三条款之一成立时，未声明才是 WFC 违例；PE 出现在
内部子集即破前两条款（E13 位形），非 standalone 时声明检查须让位。
**Repro**: `<!DOCTYPE r [<!ENTITY % pe "<!ENTITY e '&#38;undeclared;'>>%pe;><r>&e;</r>` 位形
（E13.xml 原件，xmlconf 锁版）。**Fix**: 未声明引用在实体值展开位降级为字面保留/跳过，
按三条款判定是否报错；建议线程化「internal subset contains entity references」旗标 +
standalone 声明既有解析结果。
**按语**：修复 = 条件化一处 raise，手术面最小；与 §4.4.4 Included-in-Literal 语义对齐。

### 包 B · NS 1.1 prefixed unbinding（2 案）

**Locus**: `src/namespace.mbt:151-155` — `Some(prefix)` 分支 `uri == ""` 无条件
`raise InvalidSyntax("namespace prefix cannot be bound to an empty URI")`。
**Spec**: Namespaces in XML 1.1 §2.2——`xmlns:p=""` 合法（解绑前缀绑定）；1.0 REC 才禁。
同一函数 default 分支已实现 `scope.remove("")` 解绑语义（1.1 行为），prefixed 分支缺席。
**Repro**: `<root xmlns:p=""/>`（003.xml/004.xml，manifest 版次 1.1）。**Fix**: 解析器
持版次旗标（1.1）时 prefixed 空串走 `scope.remove(prefix)`；1.0 保持现拒。
**按语**：default 分支与 prefixed 分支行为不对称是现成的论证入口；版次旗标 Milky
reader 已有 version 解析可搭。

### 包 C · XML 1.1 Char via character reference（5 案）

**Locus**: `src/escape.mbt:172-178` `is_valid_xml_char` — XML 1.0 Char 产生式硬编码
（#x9|xA|xD|#x20-#xD7FF|#xE000-#xFFFD|#x10000-#x10FFFF），`decode_entity` 数字引用位
无条件套用。
**Spec**: XML 1.1 §2.2——Char 经**字符引用**放宽至 [#x1-#xD7FF]|[#xE000-#xFFFD]|
[#x10000-#x10FFFF]（字面出现仍禁；NEL 0x85/0x2028 归行尾属同族生产式）。043/054/
ibm02v02/03/05 五案 = 控制字符经引用合法位形。
**Repro**: `<!DOCTYPE r [<!ENTITY e "&#x1;">]><r>&e;</r>` 于 version="1.1" 文档（套件
原件）。**Fix**: `unescape`/`decode_entity` 增 edition 参数（1.1 时引用位用放宽域），
字面校验路径不动。
**按语**：放宽**只**适用引用位——恰是 decode_entity 所在；改动面 = 一个布尔穿线。

### 包 D · UTF-16 declared + ASCII content 误杀（2 案）

**Locus**: `src/reader.mbt:918-925` — XML decl 校验位：`self.input[0] != '\u{FEFF}'`
且 `input` 全 ASCII（长度 <100）即拒。`self.input` 是**解码后文本**：真 UTF-16 输入经
解码 BOM 已消费、null 字节已不在——嗅探探的属性在解码后不可能存在，恒误伤。
**Spec**: XML 1.0 §4.3.3/附录 F——UTF-16 实体须带 BOM，检测在**字节面**；decl 与
内容编码一致性对已转码输入无从谈起。
**Repro**: BOM(fe ff) + UTF-16BE 编码的 `<?xml version='1.0' encoding='UTF-16'?>\n<root/>\n`
（sun/invalid/utf16b.xml，98 字节）——任一 ASCII 内容 UTF-16 文档皆拒。
**Fix**: 该检查移到字节解码前（BOM 缺席 + decl UTF-16 才报错），解码后文本上的
null-byte 启发删除；或给已转码输入（external transcoded）一条诚实通路。
**按语**：`length() < 100` 长度门槛说明作者已知启发脆；字节面判定是唯一诚实形。

### 收尾状态

- 桶注记五处落 xmlconf_suite_test.mbt（纯注释，读数不变：2572/13/2585）。
- 四包文本（英文体可直贴 GitHub issue/PR）+ 本表 = 提交材料；**投递动作候用户拍**
  （外发=发布，上游 repo = github.com/Milky2018/xml，GH 走 socks5h 代理）。
- fork 判据挂账：PR 投递后无响应且消费端真需 → 再议 fork；本期不动。


### 施工勘正（.mingspace 施工役回录，2026-10-23）

上游 PR 档案施工役（并行役；档案住 `moonxml/.mingspace/`，git 忽略面）回录三则
勘正 + 坐标面：

1. **上游真身拨正**：上游仓 = `moonbit-community/xml-mbt`
   （github.com/moonbit-community/xml-mbt）。本节上文所记
   `github.com/Milky2018/xml` 是 mooncakes 包名拼形，GitHub 无此仓（404）。
   PR 目标分支 `main`（0.6.1+，四 locus 在 main 均在）。
2. **包 A locus 拨正**：E13 实拒点在**内容位**（reader.mbt `entities.get`
   None 臂），非本节包 A 所记 dtd.mbt:219（实体值位）；同形两处均修。豁免旗 =
   「子集含 `%pe;` 引用 + 非 standalone」双字段线程。
3. **包 C 扩面**：054.xml 套件注释自供语法/意图间隙并判 valid——实体膨胀进
   内容的控制字须在**内容字面校验位**同步放宽（1.1）；注释/PI 保持严格。又
   0x7F（DEL）在 1.0 本属合法（#x20-#xD7FF），1.0 负例须取真受限字（如 0x01）。

施工面：四分支（`pr/entity-value-undeclared-bypass` 40dfc98 /
`pr/ns11-prefix-unbinding` ba8ab02 / `pr/xml11-char-reference` 2690e58 /
`pr/utf16-declaration-heuristic` 7e0fa15；读数 1826/1826 + 1824/1824 + 1826/1826 +
1824/1824，基线 1821）+ 各目录 `patch`（git am 自包含）；克隆在
`~/upstream/xml-mbt`（工作区外，bitbang 三仓零沾染）。四份 PR.md 已追加中文
译文节（英文原文在前，直贴面不动）。投递仍候用户令（外发=发布）。

### 投递回录（2026-10-23）

- **B/D 已投**：PR #13（B 包，`pr/ns11-prefix-unbinding` ba8ab02）+ PR #14
  （D 包，`pr/utf16-declaration-heuristic` 7e0fa15），均 OPEN，目标
  `moonbit-community/xml-mbt@main`。fork = `72-j/xml-mbt`（账号 72-j，token 走
  `GH_TOKEN` env，代理 socks5h://172.27.208.1:1080）。A/C 待令（序 B→D→A→C）。
- 工具面坑账：`gh auth login --with-token` 不收位置参数（令牌走 stdin，arg 形报
  "accepts 0 arg(s), received 1"）；api.github.com 经代理超时 → gh 安装走
  releases 302 定版 + `-C -` 断点续传（v2.103.0 落 `~/.local/bin`）；投递前置 =
  Windows 侧代理进程（TCP 1080 通断是第一判点）。

## §18 性能勘役+折叠层一刀（2026-10-23）

**勘役（只勘未改）**：管道 = Milky Reader 扫描 → 事件数组物化 → moonxml 折叠成树。
探针口径 = 合成语料 1.62MB/8000 元素/168,007 事件，`@async.now()` 墙钟，预热 1 +
5 轮轮内交错（jsonld 役P1/M0 同款），release native。三层拆账（基线中位）：
raw Reader **~72ms（60%）** / +NS **~82ms（8%）** / +moonxml 折叠 **~120ms（32%）**。
优化候选排序：① 折叠层 append_text O(n²) 拼接（自家）② 事件数组直拉（自家）
③ Reader 逐字 Option 装箱热环（上游，moonttl P4 同族，走上游 PR 渠道）④ NS 8% 不动。

**折叠层一刀已落**（两刀并一役，纯内部重构，`.mbti` 零差）：

1. `append_text` 逐段 `previous + content` 重拼（O(n²) 向量）→ **段列表惰性收口**
   `flush_pending_text`：单段零拷贝直通、多段一次 StringBuilder 会合；结构事件前
   `if !(event.kind is @xml.Text(_))` 统一 flush，EOF 臂 flush+break（尾文本不再丢）。
2. `read_events_until_eof` 事件数组物化（168k 箱全落再折叠）→ **`read_event()` 直拉
   流式折叠**（`for ;;` + 逐事件折叠，NamespaceReader/Reader 均有 pub 单拉口，
   零上游改动）。两折叠面（NS/ns_off）同刀。

**读数**（同协议两跑，N 跑定稳）：wrap 全链 **119–126 → 96–104ms（−17%±3，带不交
叠）**；对照组 raw（71–76→75±噪声）与 ns（82–85→86±噪声）同带佐证机态未漂。
内存面 = 168k 事件箱不再整批驻留（直拉即弃）。门 = deny-warn 0 + 模块全域
120/120 + 套件 2572/13/2585（deferred 13 未动）。

**余账**：上游 Reader 逐字环刀（候选③）候拍——与 Milky PR A/C 同渠道排队；
`moon test --profile`（Linux perf）可作动刀火焰图入口。勘役探针已依律删净
（写-跑-删同会话）。

**上游 Reader 逐字环刀（同日实验役，分支留库不投）**：`~/upstream/xml-mbt`
分支 `pr/reader-hotloop`（7e9c6c3，基于 main@1e1defd）：advance_bounded 核
（Option 拆核）+ 五热环直引下标（skip_whitespace×2/read_while/read_name/
read_text 主环——原每内容字 peek+advance 双 Some 装箱）+ 名字符 BMP 表
（15 比较链→一次查表，`*_class` 链保留为表源真身，星域码点走范围回退）。
门 = 上游 1821/1821 同数 + deny-warn 0。**判读 = 不发 PR**：上游自带 bench
交错 A/B（2×2 轮）带全交叠；扫描层探针 bench（names 60k/text 2MB）min-of-N
差 −2~3%，带仍交叠——按「读数不交叠才下结论」纪律不构成可投读数。MoonBit
native 的 Some 装箱成本远低于预估（P4 刀的 moonttl 红利在 XML 底座不复现——
那边词法占端到端 ~19% 且 battery 口径；XML 底座扫描占比同量级但装箱非热点）。
真热点嫌疑 = 实体机器（ref-queue 16384 = 715ns/ref，unescape/子 reader 重建）
与 StringBuilder 每文本节点构造——候 perf 火焰图另役。分支留库作实验记录，
不推不远。

### §18.2 数字字符引用快径刀（2026-10-23，上游 pr/charref-fastpath）

perf 役开局验家伙：perf/valgrind 双缺（WSL2），但**不需要**——既有 bench 已喊出
热点：ref-queue 16384 = 715ns/引用（82KB 文档 11.75ms），纯文本 180MB/s——
实体路径每字节贵 ~1000×，刀向钉死数字字符引用。

**刀形**（`Reader::try_scan_numeric_char_ref`，read_text `'#'` 臂头）：
前瞻只读扫描（input 直索引不动 pos），`&#NN;`/`&#xHH;` 全合法（≥1 位数字、
`;` 收口、≤0x10FFFF、is_valid_xml_char）才一次性 commit 推进（advance 逐字符
簿记同原路径）；**一步不合返 None 原样落回慢径**——`&#;`/`&#X41;`/`&#0;`/
代理区/越界/未收口全走原 read_while+unescape，错误消息逐字节保真。
跳掉的分配：read_while SB+闭包+to_string、"&"+name+";" 双 concat、
unescape 的 to_array 全文重扫+substring+decode+SB ≈ 8-10 次/引用。
`in_entity_content` 两态同形（decoded 面原路径也走 unescape，只差
consume_entity_output 补偿——快径照抄）；`in_reference` 唯一消费点
（177 行行尾归一化门）臂头已设、emit 处清，快径期无观察点。

**读数**（交错 A/B/A'，`moon bench --target native`，上游自带 bench）：

| bench | 基线 B | 快径 A | A' 复跑 | 判 |
|---|---|---|---|---|
| reference queue 16384 | 11.68ms ±0.73 | **3.95ms ±0.55** | 3.94ms ±0.59 | **2.96×（−66%），带完全不交叠** |
| large document 2 MiB text | 12.32ms | 11.68ms | 12.82ms | 对照零伤（带交叠=机器态噪声） |
| nested entity markup | 15.67ms | 15.82ms | 16.14ms | 对照零伤（named 面本刀不触碰） |

per-ref 715ns → 241ns。A' 逐位复现 A。门：1821/1821 绿 + deny-warn 0 +
`.mbti` 零差（priv fn 不外漏）。分支 pr/charref-fastpath（基 1e1defd），
未提交未推。上一役 micro 刀（pr/reader-hotloop）噪声内不投的教训在此役
兑现为正面读数：**先找到真热点（每字节 1000× 不对称）再下刀**。

### §18.3 named 实体双小刀（2026-10-23，同分支续）

**刀 2a 纯文本值直出**：`try_plain_entity_value(content)` 顶级纯函数——值无
`&`/`<`/`\r`、全字符过 is_valid_xml_content_char、非空（空值在慢径是
"malformed entity replacement text" 错，雷点）时跳 `parse_entity_content`
的**子 Reader 全量重建**，直出 `Text(content)`（零拷贝引用共享）。
**预算雷**：首版两红（output budget 双测）——计费点不在 Some 臂，在
**advance 里**（`in_entity_content && !in_reference` 逐字符 consume(1)，
子 Reader 逐字读替换文本即逐字计费）。修法=快径迭代数码点，push 前
`consume_entity_output(code_points)`（先判后扣同原语义，超限同消息；
raise 后预算无观察面）。按码点非 UTF-16 长度（对齐子 Reader advance
计费口径）。递归/深度守卫不复制——不符即落慢径由慢径守卫报。
**刀 2b 预定义五件 match 直出**：`"lt"=>"<"…` 替 `unescape("&"+name+";")`
的串拼+全文重扫；catch-all 保留 undefined-entity 原错（消息/raise 位逐字）。
is_predefined_entity 有 dtd.mbt 第二用点，不 dead。consume_entity_output
照调（预算面不变）。

**读数**（交错中撞机器态漂移：ref-queue 同码三轮 3.46/6.74/4.45ms 波段，
2MiB text 全轮稳 11.7-12.2 锚——**绝对读数本轮污染，比值法定谳**）：
同轮 nested/text 比 = 基线 1.27-1.35 vs 三刀 1.06-1.20，带不交叠，
**nested 相对改善 ~12%**（bench 为嵌套链，纯文本值仅尾部命中，量级合理）。
绝对数候静窗复测再投。门：1821/1821 + deny-warn 0 + `.mbti` 零差。
self 未用警（unused_value deny-warn 红）→ try_plain_entity_value 收顶级
纯函数（不碰 Reader 态，诚实形）。diff reader.mbt +81/−27（含第一刀）。

### §18.4 双刀绝对读数定谳（2026-10-23 续，五轮堆积判）

静窗复测两轮（Q1/Q2）：机器态持续波浪（nested 11.85→13.83，σ 0.9-1.9），
单轮交错抓不到静窗——改**轮次堆积判**：基线码 nested 跨四轮全稳
15.67-16.14（早晨静窗 B1 + numeric 刀轮 A/A'，numeric 不触碰 nested 面=
基线对照），三刀码跨五轮全落 11.85-14.31（Q1/Q2/A1/A3/A4，跨波峰波谷）。
**两带不交叠（N=5 vs N=4）→ 双刀 nested −9~−26%，中位 ~17%**，绝对数
定谳，替代 §18.3 比值法临时读数（~12% 低估——污染轮拉低）。

**B2 整轮作废**：基线码 ref-queue 读 4.95ms（真值 11.68）——stash 后
读数与两套码全不吻合，判构建缓存混合态（stash 改文件构建未正确失效）。
教训：**stash/checkout 换码跑 bench 后，首读数与任一码的已知带都不吻合
即整轮作废，先冷跑复核再采数**（同「regen 后首跑红=陈旧二进制假象」族）。
text 锚全轮稳（11.44-13.33，九轮），机器态波浪只打实体 corpus。
