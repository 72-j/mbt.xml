# moonxml 战役路线（todo）

版本：v0.1.0（2026-10-10 立卷）
卷面分工：`ctx.md` = 实态与判断；本卷 = 路线（先做什么、什么算完成）；
末尾执行记录滚动追加。

---

## 1. 待役

（空——A1 讫;下一步候选见 §2 A1 条月台与 M2 条五族残部）

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

## 执行记录（滚动追加）

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
