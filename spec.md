# moonxml 规格卷（spec）

> 版本：**v0.1.0**（2026-10-10 立卷——gen 层设计先行；M0 底座探针未开工）
> 卷位：本卷 = 设计与裁定；纪律卷（const）随首役立；路线卷（todo）随 M0 启动立。
> 表述纪律：本卷记"是什么/怎么定"；"必须/禁止"句式的条款立 `const.md`（随役）。

---

## 卷一：gen 层设计——树递归 TOML 形状表 + 骨架生成器

### 1. 定位裁定（R-G1 [定案]）

gen 层解决的问题是：**XML 方言的"树形状"一旦定型，其类型化包装、解析下降、
序列化上升全是机械骨架**——按 moonrdb gen 哲学（"gen 生成骨架，不生成语义；
表收形状，不收策略"；进表四问）把这些骨架收进 TOML 表、由生成器发射。

- **TOML 表** = 人维护面：方言作者描述"我的 XML 长什么样"（元素树 + 属性 + 文本形）。
- **生成器** = skelgen 方言文件（parse/validate/emit 三件套，base 零改动）。
- **产物** = 消费包里的 `*_gen.mbt`（DO NOT EDIT）：树递归结构体 + `from_tree` /
  `to_tree` 递归下降骨架 + 访问器签名。
- **语义不生成**：值域校验、业务规则留 `stubs.mbt` 用户填空点（与生成物分文件，
  禁止拼接——moonmat 先例同款）。

### 1.1 与 M0 底座探针的解耦（R-G2 [定案]）

emitter 的唯一依赖面 = `@moonxml.Node`（底座树接口）+ `XmlError`。
M0 换底座只改**树适配层**（底座事件/树 → `Node`），gen 面零改。
因此本卷设计与 M0 探针可并行施工——gen 层不押注任何具体底座。

### 1.2 TOML 字段设计（树递归形状表）

体例键三件（对位 moonrdb 全表统一）：`schema_version` / `generator` / `target_package`。
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

**字段设计四原则**（每条挂 moonrdb 先例）：

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
// 递归下降解析骨架：按表逐 attr/child 消费 @moonxml.Element
//（G1 勘误：入参 = Element 非 Node；错型 = String 锚点非 XmlError——
//   R-M1 无 span 语义,先收 String 锚点,span 化是后续战役）
pub fn doc_from_tree(element : @moonxml.Element) -> Result[Doc, String]
// 递归上升序列化骨架（canonical 序 = 表序）
pub fn Doc::to_tree(self : Doc) -> @moonxml.Element
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

### 2. 底座事实(Milky2018/xml@0.6.0,探针实证 + 接面解剖)

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
  entity_expansion_remaining 预算闸,策略对齐 moonrdb D-18 消费端
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
