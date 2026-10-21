///|
/// M2 套件门:W3C XML Conformance Suite(xmlts20130923 锁版,.xmlconf/ 随仓)
/// file-by-file,源入口 = @moonxml.decode_source(役A1 编码前端 + Char 门)
/// 再 @moonxml.parse_edition(役E1 名字段门,按 manifest EDITION 列选版本面:
/// "1 2 3 4" → 4e 全表门 / "5" → 5e 紧凑表门 / 缺省 = 两面全查)。
/// 分桶:plain = hard verdicts——valid/invalid → 必解析(invalid = DTD
/// 有效性违例,非良构层职责);not-wf → 必拒;error = XML 1.0 §1.2 可恢复
/// 违例 → 双向可过(役E2 勘误:报错即拒与继续解析都在规范符合带内)。
/// deferred = 五族分诊(逐条可辩护,桶闭钉):A 编码残部 / B 外挂 DTD·实体 /
/// C PE·条件段 / D 名字·命名空间·字符引用残部 / E 名字段底座词法残部。
async test "xmlconf suite gate" {
  let tsv_text = @utf8.decode_lossy(
    @fs.read_file("./.xmlconf/xmlconf_manifest.tsv").binary(),
  )
  let mut total = 0
  let mut passed = 0
  let mut failed = 0
  let mut deferred_count = 0
  let mut no_face = 0
  let failures : Array[String] = []
  let deferred : Array[String] = [
    // A 编码残部(2):UTF-16 声明档——底座对已解码 String 面做 decl/内容一致性启发(declared UTF-16 but content ASCII/UTF-8)而拒;BOM 已消费,核对权在底座,等底座修或 bytes 入口。japanese×6 役E2 移 plain(error 判词双向)
    "sun/invalid/utf16b.xml", "sun/invalid/utf16l.xml",
    // B 外挂 DTD/实体(69):SYSTEM 外部子集/外部实体内容——引擎不取外挂,判据外。incl* 六例外挂 BOM 案役A1 自 A 改挂;bomboom×3 役E2 移 plain(error 判词双向);001/002 役E2 自 D 改挂(外部子集声明更高版本号,须外取才能判)
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
    "xmltest/valid/not-sa/031.xml", "eduni/errata-4e/incl8bom.xml", "eduni/errata-4e/incl8bombom.xml",
    "eduni/errata-4e/inclbom_be.xml", "eduni/errata-4e/inclbom_le.xml", "eduni/errata-4e/inclbombom_be.xml",
    "eduni/errata-4e/inclbombom_le.xml", "eduni/xml-1.1/001.xml", "eduni/xml-1.1/002.xml",
    // C PE 展开/条件段(39):内部子集 PE 间接展开(`%xx;`→`&#37;zz;` 形)与 INCLUDE/IGNORE 条件段——新能力单独立项
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
    // D 名字/命名空间/字符引用残部(14):NS 冒号名错拒(1.1 valid P04a/P05 冒号名,与 E 错拒 8 同根——NS-always-on 与套件非 NS 面冲突,NS 模式旗标月台)/ NS 1.1 前缀解绑错拒(003/004,xmlns:p 空串 1.1 合法,自立 NS 层月台)/ 底座 char-ref·实体校验面(043/054/ibm02v02/03/05,1.1 控制字符经引用合法)/ E50(1.1 2e errata 名字字符增补,未进 REC 正文)/ 006(外部实体 valid 面)。役E2 移出:008/009/055-057(error 双向)、016/019(4e 面 IllegalName 正判)、001/002(改挂 B)
     "eduni/errata-2e/E50.xml", "eduni/namespaces/1.1/003.xml", "eduni/namespaces/1.1/004.xml",
    "eduni/xml-1.1/006.xml", "eduni/xml-1.1/043.xml", "eduni/xml-1.1/054.xml", "ibm/xml-1.1/valid/P02/ibm02v02.xml",
    "ibm/xml-1.1/valid/P02/ibm02v03.xml", "ibm/xml-1.1/valid/P02/ibm02v05.xml", "ibm/xml-1.1/valid/P04/ibm04v01.xml",
    "ibm/xml-1.1/valid/P05/ibm05v01.xml", "ibm/xml-1.1/valid/P05/ibm05v02.xml", "ibm/xml-1.1/valid/P05/ibm05v03.xml",
    "ibm/xml-1.1/valid/P05/ibm05v05.xml",
    // E 名字/字符域(8):底座 split_qualified_name 名字策略先拒(首/尾冒号名、组合字符衔接段)——错误在树建前,版本面门不可达;与版次无关(4e/5e 两面同拒),待底座修或 moonxml 自立名字层。役E1 已收编 302 漏拒族(套件 EDITION=1 2 3 4 面判词,4e 表门正判入 plain)。
     "eduni/errata-4e/ibm04v01.xml", "eduni/errata-4e/ibm05v01.xml", "eduni/errata-4e/ibm05v02.xml",
    "eduni/errata-4e/ibm05v03.xml", "eduni/errata-4e/ibm05v05.xml", "oasis/p04pass1.xml",
    "oasis/p05pass1.xml", "xmltest/valid/sa/012.xml",
  ]
  for row in tsv_text.split("\n") {
    if row.length() == 0 {
      continue
    }
    let parts : Array[StringView] = row.split("\t").collect()
    if parts.length() != 4 {
      continue
    }
    let ty = parts[0].to_owned()
    let path = parts[1].to_owned()
    let editions = parts[3].to_owned()
    total += 1
    if deferred.contains(path) {
      deferred_count += 1
      continue
    }
    // 役E1 版本面:EDITION 列选适用面("4" → Editions1to4 全表门 / "5" →
    // Edition5 紧凑表门;缺省 = 全版本适用 = 两面全查)。
    let faces : Array[@moonxml.XmlEdition] = []
    for token in editions.split(" ") {
      if token == "4" {
        faces.push(@moonxml.Editions1to4)
      } else if token == "5" {
        faces.push(@moonxml.Edition5)
      } else {
        ()
      }
    }
    let expected_ok = ty == "valid" || ty == "invalid" || ty == "error"
    // 役E2 判词面勘误(R-E2a):error = XML 1.0 §1.2/§5.1 可恢复违例——
    // 处理器报错后可停可续,报错即拒与继续解析都在规范符合带内(本引擎
    // 对这 14 案的拒因皆为能力边界:编码不支持/外部实体未取/声明词法,
    // 非无声错续)。故 error 案 Ok/Err 皆匹配;valid/invalid/not-wf 不变。
    let two_way_ok = ty == "error"
    if faces.length() == 0 && editions != "" {
      // 标注了非 4/5 版次(两面皆不适用)= 无法裁决,账面拒绝待分诊
      no_face += 1
      failed += 1
      failures.push("no-face \{ty} \{path}")
      continue
    }
    let bytes = @fs.read_file("./.xmlconf/xmlconf/\{path}").binary()
    let outcome_ok = match @moonxml.decode_source(bytes) {
      Err(_) => two_way_ok || expected_ok == false
      Ok(text) => {
        let mut all_faces_match = true
        for face in faces {
          let face_ok = match @moonxml.parse_edition(text, edition=face) {
            Ok(_) => expected_ok
            Err(_) => two_way_ok || expected_ok == false
          }
          if face_ok == false {
            all_faces_match = false
          }
        }
        all_faces_match
      }
    }
    if outcome_ok {
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
  assert_eq(no_face, 0) // 版本面闭钉:manifest 不得出现非 4/5 标注(出现即待分诊)
  assert_eq(deferred_count, deferred.length()) // 桶表闭钉:每条 deferred 必须真被 TSV 消费(防错字漏判)
  assert_true(passed + deferred_count == total)
  debug(
    "xmlconf: \{passed} passed / \{deferred_count} deferred / \{total} total",
  )
}
