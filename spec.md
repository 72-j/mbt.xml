# moonxml 规格卷（spec）

> 版本：**v0.1.0**（2026-10-10 立卷——gen 层设计先行；M0 底座探针未开工）
> 卷位：本卷 = 设计与裁定；纪律卷（const）随首役立；路线卷（todo）随 M0 启动立。
> 表述纪律：本卷记"是什么/怎么定"；"必须/禁止"句式的条款立 `const.md`（随役）。

---

## 卷一：gen 层设计——树递归 TOML 形状表 + 骨架生成器

### 1. 定位裁定（R-G1 [定案]）

gen 层解决的问题是：**XML 方言的"树形状"一旦定型，其类型化包装、解析下降、
序列化上升全是机械骨架**——按同门引擎的 gen 哲学（"gen 生成骨架，不生成语义；
表收形状，不收策略"；进表四问）把这些骨架收进 TOML 表、由生成器发射。

- **TOML 表** = 人维护面：方言作者描述"我的 XML 长什么样"（元素树 + 属性 + 文本形）。
- **生成器** = skelgen 方言文件（parse/validate/emit 三件套，base 零改动）。
- **产物** = 消费包里的 `*_gen.mbt`（DO NOT EDIT）：树递归结构体 + `from_tree` /
  `to_tree` 递归下降骨架 + 访问器签名。
- **语义不生成**：值域校验、业务规则留 `stubs.mbt` 用户填空点（与生成物分文件，
  禁止拼接——moonmat 先例同款）。
- **挂点机制（评7 落地 2026-10-22）**：骨架逐 node 元素调用 `stub_validate_<id>`
  （from_tree 组装尾点，Err 带元素前缀透出）；生成器直发 `xmlschema_hook_names()`
  （调用点数据孪生）；消费包 `stubs.mbt` = 唯一手写语义区（缺省直通体，regen
  不碰）。接口一致门（catalog_interface_gate_test，jsonld interface_gate 先例）
  钉 stubs 声明面 ≡ 骨架调用面——多一（孤儿 stub）少一即红；缺 stub/形失配由
  编译器红（[4021]）。变异探针双类验毒：改名 stub = 编译红；孤儿 stub = 门红
  （2≠1）。发射形经 fmt 复跑哈希不变（正典）。
- **形状语义裁定（评8 两拍一核，2026-10-22）**：
  ① **拍1 node 内散文本 = 红**：from_tree 子分派 `_` 臂不再静默——
  Text/CData 非空白 = Err（`<id>: stray text`）；空白（XML S 产生式
  #x20 #x9 #xD #xA，含 CR）容忍排版。旧 `_ => ()` 与「未知子元素 = 错」
  严格性不一致，本拍拨正。
  ② **拍2 CDATA 叶 = 文本**（卷面显式裁定）：XML infoset 中 CDATA 与
  文本等价——leaf_text 按 Text|CData 按序拼合；夹非文本子 = 红；零载荷
  = 红。旧拒绝（恰一 Text 子）是有意的最小机械骨架（非 infoset 立场），
  真方言 CDATA 常见会整链拒，故升级；canonical 发射仍纯 Text（to_tree
  不产 CData）。
  ③ **核3 NS 按原文匹配 = 现状自洽**:分派/attr_find 按 qualified_name,
  xml: 前缀特判钉 URI;NS 重组方言(RDF/XML)扩充点已核——解析器未知键
  忽略(向前兼容),表加 `namespace_uri` 键不破旧表。
  ④ **D3 namespace_uri 键落地(2026-10-23,勘③「生成器零改」预判)**:
  向前兼容机制(未知键忽略)成立,键的语义面仍是生成器实作——解析两行
  (元素/属性)可选键;匹配面按 (uri, local) 键控(`attr_find_ns` + 子
  分派 URI 条件),构造面 XmlName 携带 URI(`make_{element,leaf,attribute}_ns`
  按用量条件发射);validate 空串红 / any 携 ns 红 / 重名改 (uri, xml_name)
  配对键(同名异域放行)。**边界两则**:序列化面仍写 qualified_name,
  xmlns 声明发射(前缀策略)随真 NS 重方言另拍;ns 行发射的 fmt 幂等
  锚定随首张 NS 表金门做(嵌套表达式折行 = fmt 递归形,R-G1a 经验法;
  试点表 ns 自由,产物零差已 regen 重写机械证明)。
- **型别实弹 + 依赖面(用例役,2026-10-22)**:catalog 表上三型别属性
  (year:Int required / price:Double 0..1 / in_print:Bool required)+
  pages 型别叶——转换 helper 首次实弹即揭生成器三债:① to_tree 属性面
  零转换(叶面有 to_string、属性面漏;试点全 String 故从未暴露)——
  补对称转换(String 直通、型别 to_string);② push_arm 宽度判据在
  4 空格内联形上算宽,fmt 把超宽臂体拆自行行后 ≤80 单行放下——改三形
  判宽(内联 → 拆行 → 尾逗号展开);③ helper 死形首验:转换面原为
  从未编译的 `text.view().parse_int()`(StringView 无此方法)——正调形
  `@string.parse_int/parse_double`(core/string 包自由函数),消费包
  moon.pkg 依赖面随之 +`moonbitlang/core/string`;Int32 发射拼写随
  fmt 迁移正典(词表仍收 Int,发射面 bit_type_of 映射)。挂点第一件
  真语义:stub_validate_book isbn 非空形校验(stubs.mbt,regen 不碰);
  转换负例三钉(not an int/double/bool)+ 挂点 Err 前缀透出钉。

### 1.1 与 M0 底座探针的解耦（R-G2 [定案]）

emitter 的唯一依赖面 = `@base.Node`（底座树接口）+ `XmlError`。
M0 换底座只改**树适配层**（底座事件/树 → `Node`），gen 面零改。
因此本卷设计与 M0 探针可并行施工——gen 层不押注任何具体底座。

### 1.2 TOML 字段设计（树递归形状表）

体例键三件（对位同门全表统一）：`schema_version` / `generator` / `target_package`。
面界（scope 门）：**本表只许 `[xml]`（含 `[[xml.elements]]`）节**。

```toml
schema_version = "1.0"
generator = "xmlschema_toml_gen"
target_package = "moonxml/src/example/catalog"

[xml]
root = "doc"                          # 根元素 id（必填，validator 查存在）

# 树递归核心：elements 以 id 互引；环必须经过 optional/repeated 边才合法
#（validator 查：引用可达 / 无未定义 id / 纯 required 环 = 红 / xml_name 冲突 / 保留字撞名）
[[xml.elements]]
id = "doc"                            # MoonBit 类型名 = Pascal(id)（如 Doc）
xml_name = "catalog"                  # 标签名（缺省 = id）
kind = "node"                         # 封闭词表：node | leaf | any
attrs = [
  { name = "version", xml_name = "version", type = "String", required = true },
  { name = "lang",    xml_name = "xml:lang", type = "String", required = false },
]
children = [
  { ref = "book", repeated = true },  # 0..n
  { ref = "meta", optional = true },  # 0..1；缺省 = 恰一
]

[[xml.elements]]
id = "book"
kind = "node"
attrs = [{ name = "isbn", type = "String", required = true }]
children = [
  { ref = "title",  repeated = false },
  { ref = "author", repeated = true },
]

[[xml.elements]]
id = "title"
kind = "leaf"                         # 纯文本叶
text_type = "String"                  # 基元词表：String | Int | Double | Bool
                                      #（G1 落地勘误：Raw 除名——无消费端不进词表；
                                      #   validate 钉封闭词表，Raw 入表即红）

[[xml.elements]]
id = "author"
kind = "leaf"                         # G1 落地勘误：原表样漏 author 行（book.ref 悬空
text_type = "String"                  # = validator 红）；试点表已补，表样同笔对齐

[[xml.elements]]
id = "meta"
kind = "any"                          # 通配子树（保留原始 Node）——逃生门，慎用
```

**字段设计四原则**（每条挂同门先例）：

1. **名实分立**：`id`（MoonBit 名源）与 `xml_name`（标签名）分立——
   同 `vector_ffi.toml` 的 `c_name`/`moon_name` 分立。
2. **词表封闭**：`kind` / `type` 是封闭枚举，词表封闭进方言文件
   （base 不含任何一张表的语义——skelgen 纪律）。
3. **递归经引用，不经嵌套**：TOML 无递归，树的递归性由 `children[].ref`
   引用其他 `id` 表达；嵌套字面量**禁止**——形状是图，发射才是树。
4. **值/形状分立**：默认值、编码策略、校验阈值**一律不进表**（收形状不收策略）；
   `required` 是形状（出现性）不是策略，故可进。

### 1.3 生成器设计（三件套 + 双门）

**绑定器**：skelgen 兄弟模块新增方言文件 `xmlschema_toml_gen.mbt`
（`toml_gen_base.mbt` 零改动——"新方言 = 新数据不改生成器"照题验证）：

```moonbit
fn parse_xmlschema(String) -> Result[XmlSchemaDef, String]   // 读表：缺键给默认、型错必红
fn validate_xmlschema(XmlSchemaDef) -> Result[Unit, String]  // 树递归五查（见 1.2 注）+ 错误字面稳定
fn emit_xmlschema_skeleton(XmlSchemaDef) -> String           // 产 MoonBit 源码字符串
```

**产物形态**（`<target_package>/schema_gen.mbt`，DO NOT EDIT 头）：

```moonbit
// 树递归结构体（occurrence → 类型）；pub(all) 供门面测试跨包构造
pub(all) struct Doc {
  version : String
  lang : Option[String]
  book : Array[Book]      // 字段名 = children[].ref（id 原文），非复数自创
  meta : Option[Meta]
} derive(Eq)
// 递归下降解析骨架：按表逐 attr/child 消费 @base.Element
//（G1 勘误：入参 = Element 非 Node；错型 = String 锚点非 XmlError——
//   R-M1 无 span 语义,先收 String 锚点,span 化是后续战役）
pub fn doc_from_tree(element : @base.Element) -> Result[Doc, String]
// 递归上升序列化骨架（canonical 序 = 表序）
pub fn Doc::to_tree(self : Doc) -> @base.Element
```

**双门**（G1 落地勘误：门随生成器走不随产物走——
`skelgen/schema/xmlschema_toml_gen_test.mbt`,仓根跑读 `./moonxml/...` 径,
jelly/bm25 金门先例;门钉的是生成器不是产物,消费仓不放门的复印件）：

| 门 | 判据 |
|---|---|
| 黄金门 | 重生成 ≡ 入库件**逐字节**（`assert_eq(regenerated, committed)`） |
| scope 门 | 本表只许体例键三件 + `[xml]` 节；混入越界节即红 |
| validator 查（emit 前置） | 树递归五查，错误字面为稳定 grep 锚点 |

**再生入口**（G1 勘误：`moonxml/cmd/regen` 不立——moonxml 是消费仓无 cmd 面；
regen 可执行包住生成器仓）：
`moon run skelgen/xmlregen`（仓根起跑;读试点表 → parse/validate/emit →
落盘 `<target_package>/schema_gen.mbt`;改表 → 再生 → 金门对拍）。

### 1.4 不进表清单（进表四问否决记录）

| 事项 | 否决理由 |
|---|---|
| 解析底座选择 | M0 探针事（R-G2 已解耦）；表不押注底座 |
| namespace 全语义 | 底座层职责；表内仅 `xml_name` 前缀记账（如 `xml:lang`），解析语义归 Node 适配层 |
| 值域校验 / 业务规则 | 语义不生成——stubs.mbt 填空 |
| 流式事件形 | jsonld 同款：`[立案] 不排期`，双触发器 |
| XPath / 查询 | 独立战线，无消费端不立 |

### 1.5 施工序（G1 讫：①②④ 一步全收，③ = 底座 @moonxml 本身已先行）

gen 层与 M0 **可并行**：① skelgen 方言三件套 + 单测（纯字符串进出，无底座依赖）
→ ② 试点表（catalog 例，即本卷 1.2 原表）+ 黄金门/scope 门 → ③ `Node` 适配层
（待 M0）→ ④ from_tree/to_tree 联调（试点表跑通真 XML 往返）。

**G1 落地实录**（2026-10-15）：① `skelgen/schema/xmlschema_toml_gen.mbt`
（parse/validate/emit 三件套 + 4 负例钉）→ ② 试点表
`moonxml/src/example/catalog/catalog_schema.toml` + 双门
（`skelgen/schema/xmlschema_toml_gen_test.mbt`，40/40）→ ④ 联调门
（`catalog_contract_test.mbt`：真 XML 值级往返 Eq + 字符串定点，15/15）。
**发射器铁律兑现**：fmt 规范形五则（裸臂 / shorthand+尾逗号 / 80 列宽行判据 /
缩进随宿主语境 / helper 签名宽行化）——再生件 `moon fmt` 幂等（fmt-diff = 0),
黄金门穿过 fmt 稳定。

---

## 卷二：外挂面设计——外部子集/实体 + EntityResolver 端口(役B1 立项论证)

### 0. 范围与产因

B 族 69 案(deferred 桶 B 组)的闭案论证。产因:M2 五族分诊 B「外挂
DTD/实体——引擎不取外挂,判据外」。本卷记论证与裁定;实现 = 役B2
(候拍)。

### 1. 案情分诊(机械扫描,UNCLASSIFIED = 0)

- **B-pure 57**:外取目标零 PE 零条件段——B 面机械可闭,不依赖 C 族
  (PE·条件段)机制。内含 ibm28an01(外取目标 ibm29v01.txt 套件装配
  缺盘,p28a 目录无此件;取件失败即拒 = not-wf 正当闭合径)与
  incl*bom 6 案(invalid 判词 = 本门须解析 Ok,BOM 容错解码即可)。
- **B∩C 10**:外取目标内用 PE(8)或条件段(3,交叠 1)——随 C 族
  机制落地后闭合,役B2 不啃。
- **C 误挂 1**:xmltest/not-wf/not-sa/002.xml 无外挂引用,真身 =
  内部子集 PE(%e; 展开出 text decl)——役B2 时纯桶迁移 B→C。

### 2. 底座事实(Milky2018/xml@0.6.1 基；F1–F5 为 0.6.0 选型探针实证，0.6.1 差量 = Int→Int32 正典迁移波，零语义变化，事实沿用)

- **F1 无外挂钩子**:无 resolver trait/回调;`DocType(String)` 事件只带
  根名,SYSTEM/PUBLIC id 不出线;`&x;` 由底座 entities map 内联展开,
  未定义即 InvalidEntity 拒。
- **F2 entities 缝开但不覆写**:`Reader.entities` 为 pub struct 字段
  (外包不可重赋值/构造),但 Map 引用可穿,`set` 注入实存(探针绿);
  底座内部子集解析对同名键**不覆写**(探针:预注入值存活)。
- **F3 属性缺省缝闭**:`default_attributes`/`attr_types` 值型
  `XmlAttribute` 外包不可构造([4036])——属性缺省注入不能走底座。
- **F4 展开是文本级**:实体替换按 String 展开,12 案外取实体含标记
  (sun/ext、ext-sa、incl* 族)——直注入会坏树。
- **F5 内部子集惰性解析**:parse_internal_subset 在 DocType 事件读取时
  执行——注入时窗 = 我们的事件循环截 DocType 处(含 F2 的正判接线)。

### 3. 架构裁定(R-B1 [定案])

- **R-B1a [定案] resolver = 消费方端口,缺省即拒**: trait
  EntityResolver(resolve(system_id, public_id, base) -> Bytes?)+
  缺省实现 NoExternal(None)——现状语义零漂移;套件门注入仓内本地
  文件 resolver(相对 sibling 路径拼接,无 URI 库)。**本仓不携网络
  resolver**;网络面=消费方实现者自担(XXE 防御 = 缺省关 + 底座
  entity_expansion_remaining 预算闸,策略对齐同门 D-18 消费端
  政策参数先例,禁止污染编解码——此处=解析错误语义)。
- **R-B1b [定案] 实体双径**:无标记外取实体 → DocType 截点注入
  entities(F2 缝);**注入前 contains-check,已存在即跳过**——底座
  「无覆写」quirk 恰钉出 spec 4.4.8 内部优先正判(注入时窗在
  parse_internal_subset 之后,F5)。含标记外取实体 → 我层预组合:
  解码输出文本上预展开指向外部实体的引用(查表=内部优先),组合文
  本喂底座;内部实体仍由底座原生展开,两径正交。
- **R-B1c [定案] 属性缺省走我层**:外取子集 ATTLIST 缺省值在我方
  建节点层施加(F3 底座缝闭,不绕)。
- **R-B1d [定案] 外取件解码面**:外取实体/子集按外部件解码(BOM
  容错、text decl 编码名识别,复用 decode 前端;incl*bom 6 案 invalid
  型 = 容错 Ok 即过)。外取子集声明(ENTITY/ATTLIST/ELEMENT/
  NOTATION)由自持声明解析器 WF 级收编——not-wf 族(dtd07 等)的
  拒因落在声明语法面。
- **R-B1e [事实] 判词预期**:役B2 落地后 plain 增量上界 = 57
  (2466→2523);B∩C 10 案留 deferred 待 C;桶表 B 组同役重写
  (闭钉自动咬漏字)。

### 4. 役B2 待探清单(实现前置→实现后拨正)

① span/行号漂移面——**已实现**(R-B2d 补丁账本);② PUBLIC id 69 案
零出现(已核),签名保留参数仅透传,**维持不实现**目录解析;③
standalone 语义——实读分诊归 S 族留账 1 案(sun/not-wf/not-sa03,
2.9 语义闸未实现),ext-sa 族 standalone 越权案归 T 族(text decl
校验面),attribute 缺省改写面随属性缺省役。

### 5. 役B2 实现定案(R-B2 [定案] 2026-10-22)

**R-B2a 单径预组合(R-B1b 双径翻案)**:外取实体统一文本预组合后喂
底座,实体表注入径废弃。缘由:NS 模式 parse_into 包 reader,注入
entities 表不对称(非 NS 面才可达);且注入依赖底座无覆写 quirk 与
晚注入时窗——quirk 依赖即脆弱面。spec 4.4.8 内部优先不靠注入而是
账本制:内部子集字面量实体入 `internal_literals` 值账,外部子集同名
声明让位。

**R-B2b 链所有权闭合**:字面量实体(传递)引用到本层收编实体者,
整链收归本层展开(否则底座展开半路撞本层取走的外取名 InvEnt,
ext-sa/012 族);不动链留底座。不动点迭代,账序无关。

**R-B2c 属性位 WFC 按可达性**:外取件引用在属性值位 = 违例我层直拒
(底座对属性位未声明实体放行,不能赖它);旗标穿透展开深度——间接
字面量链带外取件入属性值同拒(ibm41n11 实证翻案驱动)。

**R-B2d span 补丁账本**:顶层(depth 0)展开记 SpanPatch(组合跨度
↔原文引用跨度),嵌套不记(账本不重叠);错误重映射 = 账前段累计
平移,账内归引用位(报位诚实);relocate_error 按原文重算行列
(char_span 口径)。补丁空 = 逐字节零漂移。

**R-B2e 缺省闭与取件语义**:parse_edition `resolver~ : &EntityResolver?
= None`,None = 不取外件原文直通(XXE 防御缺省关,D-18 先例);取件
None = 该实体视同未声明(引用处底座 InvalidEntity 拒 = fetch-fail
reject);取件有而解码败 = External 错(件破即拒)。B1 拟的
NoExternal 对象除名(无构造点,双警,缺省由 None 径承担)。

**R-B2f billion-laughs 闸**:EXTERNAL_EXPANSION_DEPTH=32(递归)+
EXTERNAL_EXPANSION_BUDGET=1000000(累计插入字符);错误归引用位。

**R-B2g 套件门实读化**:manifest 版次列空 = 两面全查(旧空转判过,
73% 案虚读,役B2 拨正);deferred 桶闭钉(计数 + 逐条 TSV 消费)维持。

**遗留面**(B 残留 49 案分族入桶,详见桶内注释):T 文本声明校验闸 27
(最大族,候选次役)/P PE 闸 12(C∩B 并 PE 役)/V 外取件版次闸 6/
E 编码闸 1/S standalone 闸 1/G 声明语法闸 1/M manifest 版次标注缺 1
(两面冲突,待 manifest 勘正或版次双向容忍语义立项)。

### 6. 役B3 定案(R-B3 [定案] 2026-10-22)

**R-B3a 准入三闸**:`admit_external_text(text, doc_version)` = text decl
验证剥除 + 版本键控 Char 门,取件两步的第二步(decode_source 解码面之后
的校验面)。①**语法闸**(P77:仅文首触发——`<?xml` 后随 S 或 `?>`;
缺 encoding/序位倒置(version 后于 encoding)/standalone 越权/版本词形
∉{1.0,1.1}/伪属性集封闭({version,encoding} 外即拒)/分隔符版次键控
(NEL·U+2028 仅 1.1 文档面合法)皆拒;违例一律 `External` 域——件破即拒,
R-B1d 延伸)。②**only-later 版次闸**(XML 1.1 §4.3.4):件 text decl
版次晚于文档版次即拒(1.1 件在 1.0 文档 = 违例);1.0 件在 1.1 文档
**合法**——单向规则,非等值核对。③**Char 门**(复用 [gate_chars],
`doc_version == Some("1.1")` 键控):外取件按文档版本规则做字面受限区
扫描;字符引用是 ASCII 文本天然放行(ibm77v22-29 校准)。

**R-B3b doc_version 基准与只取不判**:`peek_decl_version` 只读 XMLDecl
version 引号值,无 XMLDecl = None = 1.0 缺省;语法面归底座判官。勘误账:
`has_word` 词边界初版拒 `=` 作后随符——`version='1.1'` 紧随形(标准形)
咬不中 → doc_version 恒 None → 版次闸全误拒(valid 14 案回归);边界集
补 `=`(Eq 紧随词是词法正形)。**供词函数的边界集必须覆盖全部调用位形**。

**R-B3c T 族翻案分诊(普查驱动)**:T27 实为异质四族——14 案 Char 门
(字面控制字符 #x7F/#x80-#x9F 住外取子集/实体内容,含注释/PI 内;
n15/n19/n20 嵌套引用同拒)+ 6 案 V 闸(n13 虽住 P77 目录实为 1.0 文档引
1.1 件;eduni/xml-1.1/001-005、E38 = 1.0 文档引 1.1 外取子集)+ 5 案
text decl 语法(dtd07 缺 encoding/ext-sa/002 standalone 越权/ibm30n01
声明住体中/n17·n18 NEL·U+2028 分隔)。n14 翻案归 G(真身 `<!ELEMENT
0node>` 非法名);ibm32n09 翻案归 S(真身 standalone WFC)。6 案 PE 载体
(1.0 面 n03/n04、ibm79n01/n02、1.1 n21、eduni 002)violation 住外取 PE
件,PE 展开未实现取不到——留 C 族役并。

**R-B3d 件体 PI 位 text decl 拒**:text decl 只许住件首;外取子集体内
`<?xml …?>` 形按 P79/2.8 拒(`has_xml_target` 大小写不敏感三字 + 边界
核——PI 目标 xmlfoo 不咬)。ibm30n01(声明住 `<!ELEMENT` 后)实证。

**R-B3e ibm03v09 反向入账**:件 text decl 缺 P77 必备 encoding 而套件
判 valid——官方描述自标 "(This test is questionable)",与 dtd07(同由
判 not-wf,文内自注 encoding mandatory)自相矛盾。引擎站 P77 严格面,
案入 M 桶(套件数据面)挂上游;B3 前过门 = text decl 未检视的漏读,
非规范正判。

**读数**:套件 2486/99/2585 → **2510/75/2585**(25 案毕业 + ibm03v09
反向入账);单元 94/94 → **105/105**(外取件准入 wbtest 14 案);
`.mbti` 零差(全部新增面私有)。
