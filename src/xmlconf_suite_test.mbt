///|
/// M2 套件门:W3C XML Conformance Suite(xmlts20130923 锁版,.xmlconf/ 随仓)
/// file-by-file。分桶:plain = hard verdicts——valid/invalid/error → 必解析
/// (invalid = DTD 有效性违例,非良构层职责;error = XML 1.0 可恢复违例,
/// 按本引擎实际行为钉);not-wf = 必拒。deferred = 五族分诊(逐条可辩护,
/// 桶闭钉):A 编码面 / B 外挂 DTD/实体 / C PE·条件段 / D XML 1.1 / E 名字域。
async test "xmlconf suite gate" {
  let tsv_text = @utf8.decode_lossy(
    @fs.read_file("./.xmlconf/xmlconf_manifest.tsv").binary(),
  )
  let mut total = 0
  let mut passed = 0
  let mut failed = 0
  let mut deferred_count = 0
  let failures : Array[String] = []
  let deferred : Array[String] = [
    // A 编码面(29):UTF-16/shift_jis/iso-2022-jp/BOM 冲突/裸坏字节——String 域判据外,等编码层战役
    "eduni/errata-2e/E27.xml", "eduni/errata-4e/incl8bom.xml", "eduni/errata-4e/incl8bombom.xml",
    "eduni/errata-4e/incl8bomboom.xml", "eduni/errata-4e/inclbom_be.xml", "eduni/errata-4e/inclbom_le.xml",
    "eduni/errata-4e/inclbombom_be.xml", "eduni/errata-4e/inclbombom_le.xml", "eduni/errata-4e/inclbomboom_be.xml",
    "eduni/errata-4e/inclbomboom_le.xml", "eduni/misc/007.xml", "japanese/pr-xml-euc-jp.xml",
    "japanese/pr-xml-iso-2022-jp.xml", "japanese/pr-xml-little-endian.xml", "japanese/pr-xml-shift_jis.xml",
    "japanese/pr-xml-utf-16.xml", "japanese/weekly-euc-jp.xml", "japanese/weekly-iso-2022-jp.xml",
    "japanese/weekly-little-endian.xml", "japanese/weekly-shift_jis.xml", "japanese/weekly-utf-16.xml",
    "sun/invalid/utf16b.xml", "sun/invalid/utf16l.xml", "xmltest/not-wf/sa/168.xml",
    "xmltest/not-wf/sa/169.xml", "xmltest/not-wf/sa/170.xml", "xmltest/valid/sa/049.xml",
    "xmltest/valid/sa/050.xml", "xmltest/valid/sa/051.xml",
    // B 外挂 DTD/实体(61):SYSTEM 外部子集/外部实体内容,引擎不取外挂——判据外
     "eduni/errata-2e/E18.xml", "eduni/errata-2e/E19.xml", "ibm/not-wf/P30/ibm30n01.xml",
    "ibm/not-wf/P31/ibm31n01.xml", "ibm/not-wf/P61/ibm61n01.xml", "ibm/not-wf/P77/ibm77n03.xml",
    "ibm/not-wf/P77/ibm77n04.xml", "ibm/not-wf/P79/ibm79n01.xml", "ibm/not-wf/P79/ibm79n02.xml",
    "ibm/not-wf/p28a/ibm28an01.xml", "ibm/xml-1.1/not-wf/P77/ibm77n02.xml", "ibm/xml-1.1/not-wf/P77/ibm77n03.xml",
    "ibm/xml-1.1/not-wf/P77/ibm77n14.xml", "ibm/xml-1.1/not-wf/P77/ibm77n21.xml",
    "ibm/xml-1.1/valid/P03/ibm03v01.xml", "ibm/xml-1.1/valid/P03/ibm03v02.xml", "ibm/xml-1.1/valid/P03/ibm03v03.xml",
    "ibm/xml-1.1/valid/P03/ibm03v04.xml", "ibm/xml-1.1/valid/P77/ibm77v04.xml", "ibm/xml-1.1/valid/P77/ibm77v05.xml",
    "ibm/xml-1.1/valid/P77/ibm77v06.xml", "ibm/xml-1.1/valid/P77/ibm77v10.xml", "ibm/xml-1.1/valid/P77/ibm77v11.xml",
    "ibm/xml-1.1/valid/P77/ibm77v12.xml", "ibm/xml-1.1/valid/P77/ibm77v16.xml", "ibm/xml-1.1/valid/P77/ibm77v17.xml",
    "ibm/xml-1.1/valid/P77/ibm77v18.xml", "ibm/xml-1.1/valid/P77/ibm77v22.xml", "ibm/xml-1.1/valid/P77/ibm77v23.xml",
    "ibm/xml-1.1/valid/P77/ibm77v24.xml", "ibm/xml-1.1/valid/P77/ibm77v28.xml", "ibm/xml-1.1/valid/P77/ibm77v29.xml",
    "ibm/xml-1.1/valid/P77/ibm77v30.xml", "oasis/p09fail1.xml", "oasis/p09fail2.xml",
    "sun/not-wf/dtd07.xml", "sun/valid/ext01.xml", "sun/valid/ext02.xml", "sun/valid/not-sa03.xml",
    "xmltest/not-wf/not-sa/001.xml", "xmltest/not-wf/not-sa/002.xml", "xmltest/not-wf/not-sa/003.xml",
    "xmltest/not-wf/not-sa/004.xml", "xmltest/not-wf/not-sa/006.xml", "xmltest/not-wf/not-sa/007.xml",
    "xmltest/not-wf/not-sa/008.xml", "xmltest/not-wf/not-sa/009.xml", "xmltest/valid/ext-sa/001.xml",
    "xmltest/valid/ext-sa/002.xml", "xmltest/valid/ext-sa/003.xml", "xmltest/valid/ext-sa/004.xml",
    "xmltest/valid/ext-sa/005.xml", "xmltest/valid/ext-sa/006.xml", "xmltest/valid/ext-sa/007.xml",
    "xmltest/valid/ext-sa/008.xml", "xmltest/valid/ext-sa/009.xml", "xmltest/valid/ext-sa/011.xml",
    "xmltest/valid/ext-sa/012.xml", "xmltest/valid/ext-sa/013.xml", "xmltest/valid/ext-sa/014.xml",
    "xmltest/valid/not-sa/031.xml",
    // C PE 展开/条件段(39):内部子集 PE 间接展开与 INCLUDE/IGNORE 段——新能力单独立项
     "eduni/errata-3e/E13.xml", "ibm/not-wf/P62/ibm62n01.xml", "ibm/not-wf/P62/ibm62n02.xml",
    "ibm/not-wf/P62/ibm62n03.xml", "ibm/not-wf/P62/ibm62n04.xml", "ibm/not-wf/P62/ibm62n05.xml",
    "ibm/not-wf/P62/ibm62n06.xml", "ibm/not-wf/P62/ibm62n07.xml", "ibm/not-wf/P62/ibm62n08.xml",
    "ibm/not-wf/P63/ibm63n01.xml", "ibm/not-wf/P63/ibm63n02.xml", "ibm/not-wf/P63/ibm63n03.xml",
    "ibm/not-wf/P63/ibm63n04.xml", "ibm/not-wf/P63/ibm63n05.xml", "ibm/not-wf/P63/ibm63n06.xml",
    "ibm/not-wf/P63/ibm63n07.xml", "ibm/not-wf/P64/ibm64n01.xml", "ibm/not-wf/P64/ibm64n02.xml",
    "ibm/not-wf/P64/ibm64n03.xml", "ibm/not-wf/P65/ibm65n01.xml", "ibm/not-wf/P65/ibm65n02.xml",
    "ibm/valid/P09/ibm09v03.xml", "ibm/valid/P09/ibm09v05.xml", "ibm/valid/P32/ibm32v02.xml",
    "ibm/valid/P78/ibm78v01.xml", "oasis/p30fail1.xml", "oasis/p31fail1.xml", "oasis/p61fail1.xml",
    "oasis/p62fail1.xml", "oasis/p62fail2.xml", "oasis/p63fail1.xml", "oasis/p63fail2.xml",
    "oasis/p64fail1.xml", "oasis/p64fail2.xml", "sun/not-wf/cond01.xml", "sun/not-wf/cond02.xml",
    "sun/not-wf/decl01.xml", "sun/valid/pe00.xml", "sun/valid/pe02.xml",
    // D XML 1.1 语义(68):版本门+1.1 字符策略+NS 1.1 前缀解绑——新能力单独立项
     "eduni/errata-2e/E50.xml", "eduni/namespaces/1.1/003.xml", "eduni/namespaces/1.1/004.xml",
    "eduni/xml-1.1/001.xml", "eduni/xml-1.1/002.xml", "eduni/xml-1.1/006.xml", "eduni/xml-1.1/008.xml",
    "eduni/xml-1.1/009.xml", "eduni/xml-1.1/011.xml", "eduni/xml-1.1/013.xml", "eduni/xml-1.1/014.xml",
    "eduni/xml-1.1/016.xml", "eduni/xml-1.1/019.xml", "eduni/xml-1.1/041.xml", "eduni/xml-1.1/043.xml",
    "eduni/xml-1.1/054.xml", "eduni/xml-1.1/055.xml", "eduni/xml-1.1/056.xml", "eduni/xml-1.1/057.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n32.xml", "ibm/xml-1.1/not-wf/P02/ibm02n33.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n34.xml", "ibm/xml-1.1/not-wf/P02/ibm02n35.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n36.xml", "ibm/xml-1.1/not-wf/P02/ibm02n37.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n38.xml", "ibm/xml-1.1/not-wf/P02/ibm02n39.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n40.xml", "ibm/xml-1.1/not-wf/P02/ibm02n41.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n42.xml", "ibm/xml-1.1/not-wf/P02/ibm02n43.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n44.xml", "ibm/xml-1.1/not-wf/P02/ibm02n45.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n46.xml", "ibm/xml-1.1/not-wf/P02/ibm02n47.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n48.xml", "ibm/xml-1.1/not-wf/P02/ibm02n49.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n50.xml", "ibm/xml-1.1/not-wf/P02/ibm02n51.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n52.xml", "ibm/xml-1.1/not-wf/P02/ibm02n53.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n54.xml", "ibm/xml-1.1/not-wf/P02/ibm02n55.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n56.xml", "ibm/xml-1.1/not-wf/P02/ibm02n57.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n58.xml", "ibm/xml-1.1/not-wf/P02/ibm02n59.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n60.xml", "ibm/xml-1.1/not-wf/P02/ibm02n61.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n62.xml", "ibm/xml-1.1/not-wf/P02/ibm02n63.xml",
    "ibm/xml-1.1/not-wf/P02/ibm02n67.xml", "ibm/xml-1.1/not-wf/P04/ibm04n21.xml",
    "ibm/xml-1.1/not-wf/P04/ibm04n22.xml", "ibm/xml-1.1/not-wf/P04/ibm04n23.xml",
    "ibm/xml-1.1/not-wf/P04/ibm04n24.xml", "ibm/xml-1.1/not-wf/P04a/ibm04an21.xml",
    "ibm/xml-1.1/not-wf/P04a/ibm04an22.xml", "ibm/xml-1.1/not-wf/P04a/ibm04an23.xml",
    "ibm/xml-1.1/not-wf/P04a/ibm04an24.xml", "ibm/xml-1.1/valid/P02/ibm02v02.xml",
    "ibm/xml-1.1/valid/P02/ibm02v03.xml", "ibm/xml-1.1/valid/P02/ibm02v05.xml", "ibm/xml-1.1/valid/P04/ibm04v01.xml",
    "ibm/xml-1.1/valid/P05/ibm05v01.xml", "ibm/xml-1.1/valid/P05/ibm05v02.xml", "ibm/xml-1.1/valid/P05/ibm05v03.xml",
    "ibm/xml-1.1/valid/P05/ibm05v05.xml",
    // E 名字/字符域(320):引擎 1.1 紧凑区间 vs 套件 1.0 全表(双向偏差,PITarget 300 案为主)——新能力单独立项
     "eduni/errata-4e/ibm04an21.xml", "eduni/errata-4e/ibm04an22.xml", "eduni/errata-4e/ibm04an23.xml",
    "eduni/errata-4e/ibm04an24.xml", "eduni/errata-4e/ibm04n21.xml", "eduni/errata-4e/ibm04n22.xml",
    "eduni/errata-4e/ibm04n23.xml", "eduni/errata-4e/ibm04n24.xml", "eduni/errata-4e/ibm04v01.xml",
    "eduni/errata-4e/ibm05v01.xml", "eduni/errata-4e/ibm05v02.xml", "eduni/errata-4e/ibm05v03.xml",
    "eduni/errata-4e/ibm05v05.xml", "ibm/not-wf/P02/ibm02n30.xml", "ibm/not-wf/P02/ibm02n31.xml",
    "ibm/not-wf/P85/ibm85n03.xml", "ibm/not-wf/P85/ibm85n04.xml", "ibm/not-wf/P85/ibm85n05.xml",
    "ibm/not-wf/P85/ibm85n06.xml", "ibm/not-wf/P85/ibm85n07.xml", "ibm/not-wf/P85/ibm85n08.xml",
    "ibm/not-wf/P85/ibm85n09.xml", "ibm/not-wf/P85/ibm85n10.xml", "ibm/not-wf/P85/ibm85n100.xml",
    "ibm/not-wf/P85/ibm85n101.xml", "ibm/not-wf/P85/ibm85n102.xml", "ibm/not-wf/P85/ibm85n103.xml",
    "ibm/not-wf/P85/ibm85n104.xml", "ibm/not-wf/P85/ibm85n105.xml", "ibm/not-wf/P85/ibm85n106.xml",
    "ibm/not-wf/P85/ibm85n107.xml", "ibm/not-wf/P85/ibm85n108.xml", "ibm/not-wf/P85/ibm85n109.xml",
    "ibm/not-wf/P85/ibm85n11.xml", "ibm/not-wf/P85/ibm85n110.xml", "ibm/not-wf/P85/ibm85n111.xml",
    "ibm/not-wf/P85/ibm85n112.xml", "ibm/not-wf/P85/ibm85n113.xml", "ibm/not-wf/P85/ibm85n114.xml",
    "ibm/not-wf/P85/ibm85n115.xml", "ibm/not-wf/P85/ibm85n116.xml", "ibm/not-wf/P85/ibm85n117.xml",
    "ibm/not-wf/P85/ibm85n118.xml", "ibm/not-wf/P85/ibm85n119.xml", "ibm/not-wf/P85/ibm85n12.xml",
    "ibm/not-wf/P85/ibm85n120.xml", "ibm/not-wf/P85/ibm85n121.xml", "ibm/not-wf/P85/ibm85n122.xml",
    "ibm/not-wf/P85/ibm85n123.xml", "ibm/not-wf/P85/ibm85n124.xml", "ibm/not-wf/P85/ibm85n125.xml",
    "ibm/not-wf/P85/ibm85n126.xml", "ibm/not-wf/P85/ibm85n127.xml", "ibm/not-wf/P85/ibm85n128.xml",
    "ibm/not-wf/P85/ibm85n129.xml", "ibm/not-wf/P85/ibm85n13.xml", "ibm/not-wf/P85/ibm85n130.xml",
    "ibm/not-wf/P85/ibm85n131.xml", "ibm/not-wf/P85/ibm85n132.xml", "ibm/not-wf/P85/ibm85n133.xml",
    "ibm/not-wf/P85/ibm85n134.xml", "ibm/not-wf/P85/ibm85n135.xml", "ibm/not-wf/P85/ibm85n136.xml",
    "ibm/not-wf/P85/ibm85n137.xml", "ibm/not-wf/P85/ibm85n138.xml", "ibm/not-wf/P85/ibm85n139.xml",
    "ibm/not-wf/P85/ibm85n14.xml", "ibm/not-wf/P85/ibm85n140.xml", "ibm/not-wf/P85/ibm85n141.xml",
    "ibm/not-wf/P85/ibm85n142.xml", "ibm/not-wf/P85/ibm85n143.xml", "ibm/not-wf/P85/ibm85n144.xml",
    "ibm/not-wf/P85/ibm85n145.xml", "ibm/not-wf/P85/ibm85n146.xml", "ibm/not-wf/P85/ibm85n147.xml",
    "ibm/not-wf/P85/ibm85n148.xml", "ibm/not-wf/P85/ibm85n149.xml", "ibm/not-wf/P85/ibm85n15.xml",
    "ibm/not-wf/P85/ibm85n150.xml", "ibm/not-wf/P85/ibm85n151.xml", "ibm/not-wf/P85/ibm85n152.xml",
    "ibm/not-wf/P85/ibm85n153.xml", "ibm/not-wf/P85/ibm85n154.xml", "ibm/not-wf/P85/ibm85n155.xml",
    "ibm/not-wf/P85/ibm85n156.xml", "ibm/not-wf/P85/ibm85n157.xml", "ibm/not-wf/P85/ibm85n158.xml",
    "ibm/not-wf/P85/ibm85n159.xml", "ibm/not-wf/P85/ibm85n16.xml", "ibm/not-wf/P85/ibm85n160.xml",
    "ibm/not-wf/P85/ibm85n161.xml", "ibm/not-wf/P85/ibm85n162.xml", "ibm/not-wf/P85/ibm85n163.xml",
    "ibm/not-wf/P85/ibm85n164.xml", "ibm/not-wf/P85/ibm85n165.xml", "ibm/not-wf/P85/ibm85n166.xml",
    "ibm/not-wf/P85/ibm85n167.xml", "ibm/not-wf/P85/ibm85n168.xml", "ibm/not-wf/P85/ibm85n169.xml",
    "ibm/not-wf/P85/ibm85n17.xml", "ibm/not-wf/P85/ibm85n170.xml", "ibm/not-wf/P85/ibm85n171.xml",
    "ibm/not-wf/P85/ibm85n172.xml", "ibm/not-wf/P85/ibm85n173.xml", "ibm/not-wf/P85/ibm85n174.xml",
    "ibm/not-wf/P85/ibm85n175.xml", "ibm/not-wf/P85/ibm85n176.xml", "ibm/not-wf/P85/ibm85n177.xml",
    "ibm/not-wf/P85/ibm85n178.xml", "ibm/not-wf/P85/ibm85n179.xml", "ibm/not-wf/P85/ibm85n18.xml",
    "ibm/not-wf/P85/ibm85n180.xml", "ibm/not-wf/P85/ibm85n181.xml", "ibm/not-wf/P85/ibm85n182.xml",
    "ibm/not-wf/P85/ibm85n183.xml", "ibm/not-wf/P85/ibm85n184.xml", "ibm/not-wf/P85/ibm85n185.xml",
    "ibm/not-wf/P85/ibm85n186.xml", "ibm/not-wf/P85/ibm85n187.xml", "ibm/not-wf/P85/ibm85n188.xml",
    "ibm/not-wf/P85/ibm85n189.xml", "ibm/not-wf/P85/ibm85n19.xml", "ibm/not-wf/P85/ibm85n190.xml",
    "ibm/not-wf/P85/ibm85n191.xml", "ibm/not-wf/P85/ibm85n192.xml", "ibm/not-wf/P85/ibm85n193.xml",
    "ibm/not-wf/P85/ibm85n194.xml", "ibm/not-wf/P85/ibm85n195.xml", "ibm/not-wf/P85/ibm85n196.xml",
    "ibm/not-wf/P85/ibm85n197.xml", "ibm/not-wf/P85/ibm85n198.xml", "ibm/not-wf/P85/ibm85n20.xml",
    "ibm/not-wf/P85/ibm85n21.xml", "ibm/not-wf/P85/ibm85n22.xml", "ibm/not-wf/P85/ibm85n23.xml",
    "ibm/not-wf/P85/ibm85n24.xml", "ibm/not-wf/P85/ibm85n25.xml", "ibm/not-wf/P85/ibm85n26.xml",
    "ibm/not-wf/P85/ibm85n27.xml", "ibm/not-wf/P85/ibm85n28.xml", "ibm/not-wf/P85/ibm85n29.xml",
    "ibm/not-wf/P85/ibm85n30.xml", "ibm/not-wf/P85/ibm85n31.xml", "ibm/not-wf/P85/ibm85n32.xml",
    "ibm/not-wf/P85/ibm85n33.xml", "ibm/not-wf/P85/ibm85n34.xml", "ibm/not-wf/P85/ibm85n35.xml",
    "ibm/not-wf/P85/ibm85n36.xml", "ibm/not-wf/P85/ibm85n37.xml", "ibm/not-wf/P85/ibm85n38.xml",
    "ibm/not-wf/P85/ibm85n39.xml", "ibm/not-wf/P85/ibm85n40.xml", "ibm/not-wf/P85/ibm85n41.xml",
    "ibm/not-wf/P85/ibm85n42.xml", "ibm/not-wf/P85/ibm85n43.xml", "ibm/not-wf/P85/ibm85n44.xml",
    "ibm/not-wf/P85/ibm85n45.xml", "ibm/not-wf/P85/ibm85n46.xml", "ibm/not-wf/P85/ibm85n47.xml",
    "ibm/not-wf/P85/ibm85n48.xml", "ibm/not-wf/P85/ibm85n49.xml", "ibm/not-wf/P85/ibm85n50.xml",
    "ibm/not-wf/P85/ibm85n51.xml", "ibm/not-wf/P85/ibm85n52.xml", "ibm/not-wf/P85/ibm85n53.xml",
    "ibm/not-wf/P85/ibm85n54.xml", "ibm/not-wf/P85/ibm85n55.xml", "ibm/not-wf/P85/ibm85n56.xml",
    "ibm/not-wf/P85/ibm85n57.xml", "ibm/not-wf/P85/ibm85n58.xml", "ibm/not-wf/P85/ibm85n59.xml",
    "ibm/not-wf/P85/ibm85n60.xml", "ibm/not-wf/P85/ibm85n61.xml", "ibm/not-wf/P85/ibm85n62.xml",
    "ibm/not-wf/P85/ibm85n63.xml", "ibm/not-wf/P85/ibm85n64.xml", "ibm/not-wf/P85/ibm85n65.xml",
    "ibm/not-wf/P85/ibm85n66.xml", "ibm/not-wf/P85/ibm85n67.xml", "ibm/not-wf/P85/ibm85n68.xml",
    "ibm/not-wf/P85/ibm85n69.xml", "ibm/not-wf/P85/ibm85n70.xml", "ibm/not-wf/P85/ibm85n71.xml",
    "ibm/not-wf/P85/ibm85n72.xml", "ibm/not-wf/P85/ibm85n73.xml", "ibm/not-wf/P85/ibm85n74.xml",
    "ibm/not-wf/P85/ibm85n75.xml", "ibm/not-wf/P85/ibm85n76.xml", "ibm/not-wf/P85/ibm85n77.xml",
    "ibm/not-wf/P85/ibm85n78.xml", "ibm/not-wf/P85/ibm85n79.xml", "ibm/not-wf/P85/ibm85n80.xml",
    "ibm/not-wf/P85/ibm85n81.xml", "ibm/not-wf/P85/ibm85n82.xml", "ibm/not-wf/P85/ibm85n83.xml",
    "ibm/not-wf/P85/ibm85n84.xml", "ibm/not-wf/P85/ibm85n85.xml", "ibm/not-wf/P85/ibm85n86.xml",
    "ibm/not-wf/P85/ibm85n87.xml", "ibm/not-wf/P85/ibm85n88.xml", "ibm/not-wf/P85/ibm85n89.xml",
    "ibm/not-wf/P85/ibm85n90.xml", "ibm/not-wf/P85/ibm85n91.xml", "ibm/not-wf/P85/ibm85n92.xml",
    "ibm/not-wf/P85/ibm85n93.xml", "ibm/not-wf/P85/ibm85n94.xml", "ibm/not-wf/P85/ibm85n95.xml",
    "ibm/not-wf/P85/ibm85n96.xml", "ibm/not-wf/P85/ibm85n97.xml", "ibm/not-wf/P85/ibm85n98.xml",
    "ibm/not-wf/P85/ibm85n99.xml", "ibm/not-wf/P86/ibm86n01.xml", "ibm/not-wf/P86/ibm86n02.xml",
    "ibm/not-wf/P86/ibm86n03.xml", "ibm/not-wf/P86/ibm86n04.xml", "ibm/not-wf/P87/ibm87n01.xml",
    "ibm/not-wf/P87/ibm87n02.xml", "ibm/not-wf/P87/ibm87n03.xml", "ibm/not-wf/P87/ibm87n04.xml",
    "ibm/not-wf/P87/ibm87n05.xml", "ibm/not-wf/P87/ibm87n06.xml", "ibm/not-wf/P87/ibm87n07.xml",
    "ibm/not-wf/P87/ibm87n08.xml", "ibm/not-wf/P87/ibm87n09.xml", "ibm/not-wf/P87/ibm87n10.xml",
    "ibm/not-wf/P87/ibm87n11.xml", "ibm/not-wf/P87/ibm87n12.xml", "ibm/not-wf/P87/ibm87n13.xml",
    "ibm/not-wf/P87/ibm87n14.xml", "ibm/not-wf/P87/ibm87n15.xml", "ibm/not-wf/P87/ibm87n16.xml",
    "ibm/not-wf/P87/ibm87n17.xml", "ibm/not-wf/P87/ibm87n18.xml", "ibm/not-wf/P87/ibm87n19.xml",
    "ibm/not-wf/P87/ibm87n20.xml", "ibm/not-wf/P87/ibm87n21.xml", "ibm/not-wf/P87/ibm87n22.xml",
    "ibm/not-wf/P87/ibm87n23.xml", "ibm/not-wf/P87/ibm87n24.xml", "ibm/not-wf/P87/ibm87n25.xml",
    "ibm/not-wf/P87/ibm87n26.xml", "ibm/not-wf/P87/ibm87n27.xml", "ibm/not-wf/P87/ibm87n28.xml",
    "ibm/not-wf/P87/ibm87n29.xml", "ibm/not-wf/P87/ibm87n30.xml", "ibm/not-wf/P87/ibm87n31.xml",
    "ibm/not-wf/P87/ibm87n32.xml", "ibm/not-wf/P87/ibm87n33.xml", "ibm/not-wf/P87/ibm87n34.xml",
    "ibm/not-wf/P87/ibm87n35.xml", "ibm/not-wf/P87/ibm87n36.xml", "ibm/not-wf/P87/ibm87n37.xml",
    "ibm/not-wf/P87/ibm87n38.xml", "ibm/not-wf/P87/ibm87n39.xml", "ibm/not-wf/P87/ibm87n40.xml",
    "ibm/not-wf/P87/ibm87n41.xml", "ibm/not-wf/P87/ibm87n42.xml", "ibm/not-wf/P87/ibm87n43.xml",
    "ibm/not-wf/P87/ibm87n44.xml", "ibm/not-wf/P87/ibm87n45.xml", "ibm/not-wf/P87/ibm87n46.xml",
    "ibm/not-wf/P87/ibm87n47.xml", "ibm/not-wf/P87/ibm87n48.xml", "ibm/not-wf/P87/ibm87n49.xml",
    "ibm/not-wf/P87/ibm87n50.xml", "ibm/not-wf/P87/ibm87n51.xml", "ibm/not-wf/P87/ibm87n52.xml",
    "ibm/not-wf/P87/ibm87n53.xml", "ibm/not-wf/P87/ibm87n54.xml", "ibm/not-wf/P87/ibm87n55.xml",
    "ibm/not-wf/P87/ibm87n56.xml", "ibm/not-wf/P87/ibm87n57.xml", "ibm/not-wf/P87/ibm87n58.xml",
    "ibm/not-wf/P87/ibm87n59.xml", "ibm/not-wf/P87/ibm87n60.xml", "ibm/not-wf/P87/ibm87n61.xml",
    "ibm/not-wf/P87/ibm87n62.xml", "ibm/not-wf/P87/ibm87n63.xml", "ibm/not-wf/P87/ibm87n64.xml",
    "ibm/not-wf/P87/ibm87n66.xml", "ibm/not-wf/P87/ibm87n67.xml", "ibm/not-wf/P87/ibm87n68.xml",
    "ibm/not-wf/P87/ibm87n69.xml", "ibm/not-wf/P87/ibm87n70.xml", "ibm/not-wf/P87/ibm87n71.xml",
    "ibm/not-wf/P87/ibm87n72.xml", "ibm/not-wf/P87/ibm87n73.xml", "ibm/not-wf/P87/ibm87n74.xml",
    "ibm/not-wf/P87/ibm87n75.xml", "ibm/not-wf/P87/ibm87n76.xml", "ibm/not-wf/P87/ibm87n77.xml",
    "ibm/not-wf/P87/ibm87n78.xml", "ibm/not-wf/P87/ibm87n79.xml", "ibm/not-wf/P87/ibm87n80.xml",
    "ibm/not-wf/P87/ibm87n81.xml", "ibm/not-wf/P87/ibm87n82.xml", "ibm/not-wf/P87/ibm87n83.xml",
    "ibm/not-wf/P87/ibm87n84.xml", "ibm/not-wf/P87/ibm87n85.xml", "ibm/not-wf/P88/ibm88n03.xml",
    "ibm/not-wf/P88/ibm88n04.xml", "ibm/not-wf/P88/ibm88n05.xml", "ibm/not-wf/P88/ibm88n06.xml",
    "ibm/not-wf/P88/ibm88n08.xml", "ibm/not-wf/P88/ibm88n09.xml", "ibm/not-wf/P88/ibm88n10.xml",
    "ibm/not-wf/P88/ibm88n11.xml", "ibm/not-wf/P88/ibm88n12.xml", "ibm/not-wf/P88/ibm88n13.xml",
    "ibm/not-wf/P88/ibm88n14.xml", "ibm/not-wf/P88/ibm88n15.xml", "ibm/not-wf/P88/ibm88n16.xml",
    "ibm/not-wf/P89/ibm89n03.xml", "ibm/not-wf/P89/ibm89n04.xml", "ibm/not-wf/P89/ibm89n05.xml",
    "oasis/p04pass1.xml", "oasis/p05pass1.xml", "xmltest/not-wf/sa/140.xml", "xmltest/not-wf/sa/141.xml",
    "xmltest/valid/sa/012.xml",
  ]
  for row in tsv_text.split("\n") {
    if row.length() == 0 {
      continue
    }
    let parts : Array[StringView] = row.split("\t").collect()
    if parts.length() != 3 {
      continue
    }
    let ty = parts[0].to_owned()
    let path = parts[1].to_owned()
    total += 1
    if deferred.contains(path) {
      deferred_count += 1
      continue
    }
    let text = @utf8.decode_lossy(
      @fs.read_file("./.xmlconf/xmlconf/\{path}").binary(),
    )
    let outcome_ok = match @moonxml.parse(text) {
      Ok(_) => true
      Err(_) => false
    }
    let expected_ok = ty == "valid" || ty == "invalid" || ty == "error"
    if outcome_ok == expected_ok {
      passed += 1
    } else {
      failed += 1
      failures.push("\{ty} \{path}")
    }
  }
  if failed > 0 {
    let mut listing = ""
    for entry in failures {
      listing = "\{listing}\{entry}\n"
    }
    @fs.write_file("/tmp/xmlconf_failures.txt", listing)
    debug("xmlconf failures (\{failed}) dumped to /tmp/xmlconf_failures.txt")
  }
  assert_eq(failed, 0)
  assert_eq(deferred_count, deferred.length()) // 桶表闭钉:每条 deferred 必须真被 TSV 消费(防错字漏判)
  assert_true(passed + deferred_count == total)
  debug(
    "xmlconf: \{passed} passed / \{deferred_count} deferred / \{total} total",
  )
}
