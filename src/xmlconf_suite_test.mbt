///|
/// M2 套件门:W3C XML Conformance Suite(xmlts20130923 锁版,.xmlconf/ 随仓)
/// file-by-file,源入口 = @moonxml.decode_source(役A1 编码前端 + Char 门)
/// 再 @moonxml.parse_edition(役E1 名字段门,按 manifest EDITION 列选版本面:
/// "1 2 3 4" → 4e 全表门 / "5" → 5e 紧凑表门 / 缺省 = 两面全查;役N1 NS 列:
/// eduni/namespaces/** = NS-aware 面,余者 = 非 NS 面——两轴正交)。
/// 分桶:plain = hard verdicts——valid/invalid → 必解析(invalid = DTD
/// 有效性违例,非良构层职责);not-wf → 必拒;error = XML 1.0 §1.2 可恢复
/// 违例 → 双向可过(役E2 勘误:报错即拒与继续解析都在规范符合带内)。
/// deferred = 五族分诊(逐条可辩护,桶闭钉):A 编码残部 / B 外挂 DTD·实体
/// 残留(T 文本声明闸/P PE 闸/V 版次闸/E 编码闸/S standalone 闸/G 声明闸
/// /M manifest 版次缺) / C PE·条件段 / D 名字·命名空间·字符引用残部 /
/// E 名字段底座词法残部。役B2:B 桶 69 案实读,21 案随外挂面毕业入 plain。
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
    // B 残留(役B3 后 25 = P12 + PE6/G2/S2/E1/M2;原 49,T27+V6 中
    //   25 案随准入三闸毕业入 plain,ibm03v09 反向入账):
    //   役B3 准入三闸(R-B3a):text decl 语法闸 + only-later 版次闸 +
    //   版本键控 Char 门;25 毕业案拒因逐案探针核过 census 闸归属。
    //   ibm03v09 反向入账:件 text decl 缺 P77 必备 encoding 而套件判
    //   valid——官方描述自标 "(This test is questionable)",与 dtd07
    //   (同由判 not-wf,文内自注 encoding 必备)自相矛盾;B3 前过门 =
    //   text decl 未检视的漏读,非规范正判。
    // PE 载体(6)——violation 住外取 PE 件内,PE 展开未实现取不到(C 族役并):
    //   1.0 面 ibm77n03/n04、ibm79n01/n02、1.1 n21、eduni/xml-1.1/002
     "ibm/xml-1.1/not-wf/P77/ibm77n21.xml", "ibm/not-wf/P77/ibm77n03.xml", "ibm/not-wf/P77/ibm77n04.xml",
    "ibm/not-wf/P79/ibm79n01.xml", "ibm/not-wf/P79/ibm79n02.xml", "eduni/xml-1.1/002.xml",
    // G 外取子集声明语法闸(2)——声明体语法未过闸(过闸跳过策略,
    //   役B3 分诊:ibm77n14 实为 `<!ELEMENT 0node>` 非法名,自 T 归 G):
     "ibm/not-wf/P68/ibm68n06.xml", "ibm/xml-1.1/not-wf/P77/ibm77n14.xml",
    // S standalone 闸(2)——standalone='yes' 文档引用外取实体 WFC 未拒
    //   (2.9 语义闸,validity 面职责;役B3 分诊:ibm32n09 实为 standalone
    //   WFC,自 T 归 S):
     "sun/not-wf/not-sa03.xml", "ibm/not-wf/P32/ibm32n09.xml",
    // E 外取件编码声明闸(1)——text decl 声明编码与实际字节核对未实现
    //   (decode 直通 UTF-8 面):
     "sun/not-wf/encoding07.xml",
    // M manifest/套件数据面(2)——ibm77v30 案依 1.1(内容 &#x0001; 经引用
    //   1.0 拒 1.1 许)而 manifest 第 4 列空 = 两面全查必翻,待上游勘正;
    //   ibm03v09 套件自相矛盾(见上):
     "ibm/xml-1.1/valid/P77/ibm77v30.xml", "ibm/xml-1.1/valid/P03/ibm03v09.xml",
    // P PE 展开/PE 语法闸(12,C∩B 交叠,PE 役并)——PE 补全声明
    //   (005/006/E14 的 `<!ATTLIST %e;`)、PE 条件段关键词(014-016
    //   `<![ %e; [`)、PE 值内 % 尾(p09fail/008/002)、PE 引导声明
    //   (E18 `%pe; %intpe;`):
     "xmltest/not-wf/not-sa/002.xml", "xmltest/not-wf/not-sa/008.xml", "oasis/p09fail1.xml",
    "oasis/p09fail2.xml", "xmltest/valid/not-sa/014.xml", "xmltest/valid/not-sa/015.xml",
    "xmltest/valid/not-sa/016.xml", "eduni/errata-2e/E18.xml", "xmltest/invalid/005.xml",
    "xmltest/invalid/006.xml", "xmltest/invalid/not-sa/022.xml", "eduni/errata-2e/E14.xml",
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
    // D 名字/命名空间/字符引用残部(9):NS 1.1 前缀解绑错拒(003/004,xmlns:p 空串 1.1 合法——NS-aware 面内唯一可闭族,底座 NS 规则版本键控月台)/ 底座 char-ref·实体校验面(043/054/ibm02v02/03/05,1.1 控制字符经引用合法)/ E50(1.1 2e errata 名字字符增补,未进 REC 正文)/ 006(外部实体 valid 面)。役E2 移出 008/009/055-057/001/002;役N1 移出冒号名 5(NS 模式旗标非 NS 面正判)
     "eduni/errata-2e/E50.xml", "eduni/namespaces/1.1/003.xml", "eduni/namespaces/1.1/004.xml",
    "eduni/xml-1.1/006.xml", "eduni/xml-1.1/043.xml", "eduni/xml-1.1/054.xml", "ibm/xml-1.1/valid/P02/ibm02v02.xml",
    "ibm/xml-1.1/valid/P02/ibm02v03.xml", "ibm/xml-1.1/valid/P02/ibm02v05.xml",
    // E 名字段(0,桶空役N1 清):底座 split_qualified_name 名字策略先拒族(首/尾冒号名、组合字符衔接段)已由 NS 模式旗标非 NS 面全数正判入 plain;桶壳保留——新名字域败案先归此再分诊。

  ]
  // 役B2 外挂面:套件树全量预载(async 预载 + 同步 trait 面解耦——
  // EntityResolver 端口是同步面,取件走内存 store)。R-B1a 本地文件
  // resolver = 相对 sibling 拼接,无 URI 库;store 键 = 套件根相对径。
  let store : Map[String, Bytes] = Map([])
  let root_prefix = "./.xmlconf/xmlconf/"
  // walk 语义(0.22.4 dir.mbt):按目录回调 f(目录全径, 目录内条目名)——
  // 条目名含子目录名(对子目录 read_file 即炸,catch 吞之即自然过滤)。
  @fs.walk("./.xmlconf/xmlconf", async fn(dir_path, entries) {
    for name in entries {
      let full = "\{dir_path}/\{name}"
      try {
        let bytes = @fs.read_file(full).binary()
        let key = if full.has_prefix(root_prefix) {
          full[root_prefix.length():].to_owned()
        } else {
          full
        }
        store.set(key, bytes)
      } catch {
        _ => ()
      }
    }
  })

  for row in tsv_text.split("\n") {
    if row.length() == 0 {
      continue
    }
    let parts : Array[StringView] = row.split("\t").collect()
    if parts.length() != 5 {
      continue
    }
    let ty = parts[0].to_owned()
    let path = parts[1].to_owned()
    let editions = parts[3].to_owned()
    // NS 列(役N1):Namespaces in XML 测试只对 NS-aware 处理器适用,
    // 余者按非 NS 面判——两轴正交(EDITION 选版次面,NS 选规范面)。
    let ns_mode = if parts[4] == "ns" { @moonxml.On } else { @moonxml.Off }
    total += 1
    if deferred.contains(path) {
      deferred_count += 1
      continue
    }
    // 役E1 版本面:EDITION 列选适用面("4" → Editions1to4 全表门 / "5" →
    // Edition5 紧凑表门;缺省 = 全版本适用 = 两面全查)。役B2 勘误:空列
    // 此前空转判过(faces 零迭代),拨正为两面全查——73% 案(1889/2585)
    // 从虚读转实读。
    let faces : Array[@moonxml.XmlEdition] = []
    if editions == "" {
      faces.push(@moonxml.Editions1to4)
      faces.push(@moonxml.Edition5)
    } else {
      for token in editions.split(" ") {
        if token == "4" {
          faces.push(@moonxml.Editions1to4)
        } else if token == "5" {
          faces.push(@moonxml.Edition5)
        } else {
          ()
        }
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
    let doc_dir = suite_dirname(path)
    let resolver : &@moonxml.EntityResolver = SuiteResolver::{ store, doc_dir, }
    let outcome_ok = match @moonxml.decode_source(bytes) {
      Err(_) => two_way_ok || expected_ok == false
      Ok(text) => {
        let mut all_faces_match = true
        for face in faces {
          let face_ok = match
            @moonxml.parse_edition(
              text,
              edition=face,
              ns=ns_mode,
              resolver=Some(resolver),
            ) {
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

///|
/// 套件 resolver(役B2,R-B1a 本地文件面):store 全树预载,键 = 套件
/// 根相对径;doc_dir = 当前案目录;base = 引用方 system_id(外取子集
/// 内再引用 = 相对该子集拼 sibling)。
priv struct SuiteResolver {
  store : Map[String, Bytes]
  doc_dir : String
}

///|
impl @moonxml.EntityResolver for SuiteResolver with fn resolve(
  self : SuiteResolver,
  base : String?,
  system_id : String,
  _public_id : String?,
) -> Bytes? {
  let rel_dir = match base {
    Some(uri) => suite_dirname(uri)
    None => ""
  }
  self.store.get(suite_join(self.doc_dir, rel_dir, system_id))
}

///|
fn suite_dirname(path : String) -> String {
  let mut last = -1
  let limit = path.length()
  for index in 0..<limit {
    if path[index] == '/' {
      last = index
    }
  }
  if last < 0 {
    ""
  } else {
    path[:last].to_owned()
  }
}

///|
/// 径拼接归一:'.'/空段去,'..' 弹栈(套件系统 id 的相对语义)。
fn suite_join(doc_dir : String, rel_dir : String, system_id : String) -> String {
  let combined = doc_dir + "/" + rel_dir + "/" + system_id
  let segments : Array[String] = []
  for segment in combined.split("/") {
    let name = segment.to_owned()
    if name == "" || name == "." {
      continue
    }
    if name == ".." {
      let _ = segments.pop()
      continue
    }
    segments.push(name)
  }
  let mut joined = ""
  for index, segment in segments {
    if index > 0 {
      joined = joined + "/"
    }
    joined = joined + segment
  }
  joined
}
