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
