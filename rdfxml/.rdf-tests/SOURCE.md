# 语料出处与合规（.rdf-tests）

- 上游：https://github.com/w3c/rdf-tests（W3C 官方 RDF 测试套件仓）。
- 收编范围：`rdf/rdf11/rdf-xml` + `rdf/rdf12/rdf-xml`（含各自 README /
  manifest.ttl）+ 上游仓根 `LICENSE.md`；TESTS 归档 / reports / 其他
  方言 / ruby 工装未收。
- 取件日期：2026-10-24（新鲜下载，经 moonxml/.rdf-tests/rdf-tests 中转
  剔冗后收编；上游 commit 号未随件——本仓定针 = SHA256SUMS）。
- 许可：随 `LICENSE.md` 双许可（W3C Test Suite License + 3-clause
  BSD），本仓分发保留其全文与各 README 内许可指针。
- 完整性：`SHA256SUMS`（371 项，模块根相对路径）钉死收编面；复核：
  `cd rdfxml && sha256sum -c .rdf-tests/SHA256SUMS`（2026-10-24 收编
  验 371/371 OK）。
- manifest 落账：rdf11 166 案（126 TestXMLEval + 40
  TestXMLNegativeSyntax）+ rdf12 31 案（全 TestXMLEval，dir/tt/an 三
  族）= **197 案**；用例表见仓内 `case_table_gen.mbt`（黄金门
  regen ≡ 盘上）。语料另有上游未引用件（.rdf 204 / .nt 161 > manifest
  action/result 引用数），属上游附带，随 SHA256SUMS 一并钉存。
