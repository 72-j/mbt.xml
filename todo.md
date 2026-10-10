# moonxml 战役路线（todo）

版本：v0.1.0（2026-10-10 立卷）
卷面分工：`ctx.md` = 实态与判断；本卷 = 路线（先做什么、什么算完成）；
末尾执行记录滚动追加。

---

## 1. 待役

- **役M1：Node 适配层 + 数据模型**。底座事件（Milky Reader/NamespaceReader）
  → `@moonxml.Node` 树 + `XmlError` 错误面（spec.md 卷一 R-G2 的依赖面）。
  完成门：`Node` 往返（parse→Node→serialize→re-parse 等价）+ ctx.md §1 三条
  消费方契约各有用例钉住（Text 拼接 / Empty 臂 / span 透传）。
- **役G1：gen 三件套施工**（spec.md 卷一；与 M1 可并行——纯字符串进出）。
  skelgen 方言 `xmlschema_toml_gen.mbt` + 试点表（catalog 例）+ 双门 +
  `cmd/regen`。完成门：试点表黄金门绿 + Node 联调往返（待 M1）。

## 2. 已关战役

- **M0 底座探针（2026-10-10）**：两底座实探，拍板 R-X1 = Milky2018/xml@0.6.0。
  账见 `ctx.md` §1。

## 执行记录（滚动追加）

- 2026-10-10：M0 探针役关闭——Milky WF 8/8、畸形拒 5/5、保真 6/6、往返 ok、
  1MB/134ms（XMLParser 8.2× 慢不采用；自建否决）。教训两件入 ctx §1：
  Text 事件按实体边界切分、自闭合根是 Empty 事件（探针首测假阴性根因）。
