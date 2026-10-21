# moonxml 战役路线（todo）

版本：v0.1.0（2026-10-10 立卷）
卷面分工：`ctx.md` = 实态与判断；本卷 = 路线（先做什么、什么算完成）；
末尾执行记录滚动追加。

---

## 1. 待役

（空——N1 讫;下一步候选见 §2 N1 条月台）

## 2. 已关战役

- **M0 底座探针（2026-10-10）**：两底座实探，拍板 R-X1 = Milky2018/xml@0.6.0。
  账见 `ctx.md` §1。
- **M1 Node 适配层 + 数据模型（2026-10-15）**：自有规范型树面 + parse +
  to_xml；14/14 绿（往返 6 + 契约/模型 8）。定案 R-M1a/b/c 与底座实报
  勘误账见 `ctx.md` §2。
- **役G1 gen 三件套施工（2026-10-15）**：spec.md 卷一全落地——方言三件套
  `skelgen/schema/xmlschema_toml_gen.mbt` + 试点表 + 双门/负例（40/40）+
  再生命令 `moon run skelgen/xmlregen` + 联调往返（15/15）。`cmd/regen`
  不立（消费仓无 cmd 面,regen 住生成器仓,spec §1.3 已勘误）。定案
  R-G1a/b/c/d（发射器 fmt 规范形五则/门随生成器走/词表封闭收口/产物面）
  账见 `ctx.md` §3。余量三分类:配置类 = 无;外部依赖类 = 无;
  新能力类 = 词表扩容(attrs 默认值/leaf Raw 型/ns 全语义)随消费端立项。
- **役M2 xmlconf oracle 层（2026-10-16）**：W3C XML Conformance Suite
  （xmlts20130923）锁版随仓 `.xmlconf/`（SHA256SUMS + 扁平清单 TSV）+
  扁平器 `src/cmd/xmlconf_flatten/`（dogfood @moonxml）+ file-by-file
  双桶套件门。读数 **2068 passed / 517 deferred / 2585 total**，TSV 再生
  逐字节稳定。定案 R-M2a/b（oracle 形态对齐 jsonld 先例 / invalid-error
  归 plain 桶）与五族分诊（A 编码 29 / B 外挂 61 / C PE·条件段 39 /
  D XML 1.1 68 / E 名字段 320）账见 `ctx.md` §4。
- **役A1 编码前端 + Char 门（2026-10-16）**：M2 五族候拍选役 A,
  施工中定谳真身 = byte→String 前端整层——`decode_source(Bytes)`
  （BOM 嗅探/UTF-16 严格/声明面编码决策/严格 UTF-8/latin-1）+
  版本键控 Char 门（1.0 全表 vs 1.1 restricted-literal）。套件门
  源入口换装，读数 **2135/450/2585**（净关 67,碰绿正判收编 45）。
  定案 R-A1a/b（支持编码集 / Char 门前置版本键控）与 R-M2b 勘误
  （error 实钉必解析）账见 `ctx.md` §5。余账三分类:配置类 = 无;
  外部依赖类 = 无;新能力类 = error 口径翻案(14 案)/日文三码
  (6 案)/四族残部 B 70·C 39·D 23·E 310。
- **役E1 版本面键控名字段门 + 名字表 gen（2026-10-21）**：A1 余账候拍选
  E 族(310,最大桶)。役前探针定谳套件是**版本分裂设计**(同名测试成对,
  4e 判词 vs 5e 判词,官方模型 = TEST 元素 EDITION 属性);施工中金门咬出
  贴邻区间合法(规范原文形),撤「贴邻并一条」判。落地面:`.xmlnames/`
  规范锁版 + `tools/extract_name_tables.py` + `src/xml_name_tables.toml`
  (1.0 4e 五产生式 + 1.1 两产生式) → skelschema 新方言
  `xmlname_toml_gen`(三件套,词表封闭,id 是数据) → 金门+scope 门+负例
  住生成器仓 → `moon run skelgen/xmlnameregen` → 产物
  `src/name_tables_gen.mbt`;手写层 `src/namecheck.mbt`(拼装语义+
  版本/版本面键控)+ `parse_edition`(parse = Edition5 缺省面,旧消费者
  零感知)+ `IllegalName` 新词;套件门 TSV 加 EDITION 列,双面裁决,
  302 漏拒族(EDITION=1 2 3 4 面)以 4e 表门正判入 plain。定案 R-E1a/b/c/d
  (数据面形/门形与策略显式化/EDITION 双面裁决/模拟锁面)账见 ctx §6。
  余账三分类:配置类 = 无;外部依赖类 = 底座名字策略(8 错拒 + D 族
  冒号名同根);新能力类 = PI 目标 xml 保留字规则(套件无判词案,随
  消费端立)/B 70/C 39/D 23 残部/8 位日文三码(可走本役 gen 形)。
- **役N1 NS 模式旗标（2026-10-21）**：E2 月台首选项,E 错拒 8 + D 冒号名
  5 = 13 案唯一闭案径。役前定谳修正 E2 预判:自立 NS 层救不了(同 NCName
  规则),真解 = NS 处理可选(XML 1.0 基础规范与 Namespaces 是两个规范面)。
  落地:`NsMode { On; Off }` + `parse_edition(…, ns~ = On)`;Off 路 =
  raw Reader + 名字原文直通(三字段 None 形)+ xmlns 即普通属性;On 路
  不变(底座 NamespaceReader 承担,无需自研);名字段门两模共用。套件门
  加 NS 列(eduni/namespaces/** 标 ns,59 案,TSV 五列),两轴正交
  (EDITION 选版次面,NS 选规范面)。定案 R-N1a/b/c 账见 ctx §8。
  读数 **2453/132→2466/119**;门 53/53(NS-off 单元 5)。
  月台:D 9(003/004 底座 NS 规则版本键控/char-ref 面 5/E50/006)/
  JIS 三码 gen/B 69/C 39。
- **役E2 判词面勘误 + D 族重挂（2026-10-21）**：A1 月台留拍项(error 判词
  口径)+ E1 关役 D 族残部分诊。定案 R-E2a:error = XML 1.0 §1.2 可恢复
  违例,报错即拒与继续解析都在规范符合带内——error-typed deferred 恰 14 案
  (A6 japanese/B3 bomboom/D5 008·009·055-057)全数收编;R-E2b:016/019
  (版本="1.0" 文档用 1.1-only 名字字符)4e 面 IllegalName 已正判,纯桶
  迁移,001/002(外部子集版本号冲突)改挂 B。读数 **2437/148→2453/132**
  (净关 16,零新代码);桶态 A2/B69/C39/D14/E8。D 族 14 残部根因五类
  账见 ctx §7;月台:NS 模式旗标(E 错拒 8+D 冒号名 6 唯一闭案径)/
  JIS 三码 gen 形(套件零增量但真解码能力)/B 69/C 39 残部。

## 执行记录（滚动追加）

- 2026-10-21：役N1 关役——NS 模式旗标落位(Off 路 = raw Reader 名字原文
  直通,On 路 = 底座 NamespaceReader 不变);套件门 NS 列 + 两轴正交裁决,
  读数 **2453/132→2466/119**;门 53/53。新知三件入 ctx §8:①「自立 NS
  层」是伪径(同 NCName 规则),NS 可选才是真径且比预想轻一个量级
  (Off 路无需自研 NS 解析);②模拟器必须与门码同构——首跑 387/330 假红
  全是探针口径差(定死面/未排 NS 案/未算双向/deferred 未排除);③底座
  属性词法:属性名后必须有等号,孤冒号属性名任何模式不可解析。
- 2026-10-21：役E2 关役——纯门语义+桶表役:error 判词双向(XML 1.0 §1.2
  可恢复违例符合带)收编 14 案,016/019 四e 面正判桶迁移,001/002 根因
  归位改挂 B;读数 **2437/148→2453/132**;零新代码。新知:D 族失败模式
  五类分诊(役前探针定谳)——NS 冒号名是 NS-always-on 与套件非 NS 面的
  结构冲突,自立 NS 层救不了,唯一闭案径 = NS 模式旗标;役前 manifest
  类型全表对账防手滑(E2 桶迁移清单机械定谳,零错配)。
- 2026-10-21：役E1 关役——名字表 gen 链(根仓 skelschema 方言+金门+再生
  命令,消费仓 TOML 表+产物)与版本面键控门(parse_edition,策略显式化)
  落位;套件门 EDITION 感知双面裁决,读数 **2135/450→2437/148**(净关
  302,桶外零破坏);门 48/48 --target native。施工前 python 全量模拟
  锁面(A1 先例二演)与实跑严丝合缝;新知四件入 ctx §6:①套件版本分裂
  真身(同名测试成对,EDITION 属性官方裁决模型);②内部子集 PI 落树
  (M2 已证)是树面全查的覆盖证词;③ 5e 面门 ⊆ 底座,门增量只在 ≤4e 面;
  ④域定门表子模块 gitlink 行前缀不带 /(porcelain「 M moonxml」无斜杠)。

- 2026-10-10：M0 探针役关闭——Milky WF 8/8、畸形拒 5/5、保真 6/6、往返 ok、
  1MB/134ms（XMLParser 8.2× 慢不采用；自建否决）。教训两件入 ctx §1：
  Text 事件按实体边界切分、自闭合根是 Empty 事件（探针首测假阴性根因）。
- 2026-10-15：M1 关役——模型/解析/序列化三件落位（`node/parse/translate/
  serialize.mbt`），占位件退役。门 14/14：字符串定点 + 树等价双判往返
  （定点抓不住系统性丢节点,树等价补判）；三契约钉全咬合。新知入 ctx §2：
  底座错配/未闭合实报 InvalidSyntax（钉实报形）；根元素吃自身声明的缺省 ns
  （测试前提曾写反,实测定谳）；树不带 span 是 Eq 前提,span 只走错误面。
- 2026-10-15：役G1 关役——大 gen 思想跨仓首演（表住消费仓、生成器住根仓
  skelgen、产物再生入消费仓）。fmt 残差五则实测归纳入 R-G1a:发射器不
  fmt 规范形,金门在 fmt 一跑即碎——**再生字节稳定性 = fmt 幂等**,此铁律
  从 moonxt 单线升格为跨方言通则。门 40+15 双仓绿。
- 2026-10-16：役M2 关役——xmlconf oracle 层落位:锁版 3386 文件随仓,
  扁平器 dogfood 自解析 21 分册(sun/ibm 裸片段须剥声明+包合成根),
  套件门双桶三钉。517 败逐案分诊五族全归位(UNCLASSIFIED=0),
  E 族 320 案定谳「1.1 紧凑区间 vs 1.0 全表」双向偏差——漏拒(300 PITarget
  案)与错拒(p04/p05pass1)同根。新知:套件坏 UTF-8 必须 decode_lossy;
  moonxml 模块 wasm 下 async fs 必炸,门一律 --target native。
- 2026-10-16：役A1 关役——编码前端落位:decode_source 一入口收五面
  (BOM/UTF-16/声明决策/严格 UTF-8/latin-1),Char 门版本键控前置整扫。
  施工前 python 全量模拟锁面(plain 零破坏预言→真跑验证);施工两虫
  皆即时探针定谳:UTF-16 循环 4 字节臂非代理路径吞字节(每 BMP 字符丢一,
  单测即抓),error 判词档回挂(门码钉必解析,ctx 勘误)。新知:
  ①十六进制字面量后跟 `.to_byte()` 词法咬人(0x7F. 拆读,须括号);
  ②底座有 decl/内容一致性启发与声明词法面(String 面),UTF-16 声明档
  与 NEL 声明档拒于此,非解码层职责;③「deferred 现在能过」≠「可关」
  ——not-wf 漏拒族能过恰不可关,闭合集必须 verdict 联算。
