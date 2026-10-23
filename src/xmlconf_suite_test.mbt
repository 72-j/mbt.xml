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
    // 役PE位形+闸补役(2026-10-22/23):PE 声明立账 + 三处位形展开 + 外取
    // 链子代基址合成(16 案毕业);三门上线——闸 S(standalone WFC,2)/
    // 闸 P(实体值引用语法,3)/ 闸 G(声明名合法性,1)+ PE 载体额外 1
    // (ibm68n06 实为 standalone 形)= 又 7 案毕业,B 桶 P/G/S 清零。
    // 役PE组合(2026-10-23):内部子集 PE 组合立(PE 值 char-ref 引用位
    // 收口 + PE 载 GE 声明本层认领)+ 子集 PI 闸(目标名核 + ?> 收口)。
    // pe02/ibm62n03/ibm63n03 三案毕业,13 案留账。
    // A 编码残部(2):UTF-16 invalid 档——census 勘账:A1 后 decode 已过,
    // 拒点移至 parse 面(5e 面拒,invalid 案须可解析);旧「decl/内容一致性
    // 启发拒」注记作废。japanese×6 役E2 移 plain(error 判词双向)。
    "sun/invalid/utf16b.xml", "sun/invalid/utf16l.xml",
    // C PE/条件段残留(1):E13 = 底座语义账——内部子集 PE 组合本层已立
    //   (役PE组合,pe02 链全通),残 = 未声明实体豁免(spec 4.1 WFC
    //   Entity Declared 的 PE-refs 豁免:底座 Milky 无条件拒未声明实体,
    //   fork/upstream 候裁,随 Milky 9 案同桶)。
     "eduni/errata-3e/E13.xml",
    // M manifest/套件数据面(3,上游自相矛盾,候上游勘正)——ibm77v30
    //   案依 1.1(&#x0001; 经引用 1.0 拒 1.1 许)而 manifest 版次列空 =
    //   两面全查必翻;ibm03v09 件缺 P77 必备 encoding 而套件判 valid,
    //   官方自标 "(This test is questionable)";E50(errata 2e 名字增补
    //   字符 4e 面拒 5e 面许,manifest 版次列空 = 两面全查必翻,自 D 桶
    //   移入——非引擎名策略可判,是数据面矛盾):
     "ibm/xml-1.1/valid/P77/ibm77v30.xml", "ibm/xml-1.1/valid/P03/ibm03v09.xml",
    "eduni/errata-2e/E50.xml",
    // D 名字/命名空间/字符引用残留(7):NS 1.1 前缀解绑错拒(003/004,
    //   xmlns:p 空串 1.1 合法,Milky namespace.mbt 无条件拒空 URI)/
    //   1.1 控制字符经引用合法(043/054/ibm02v02/03/05,Milky dtd.mbt
    //   entity-value char ref 1.0 表)。役E2 移出 008/009/055-057/001/002;
    //   役N1 移出冒号名 5(NS 模式旗标非 NS 面正判)。
     "eduni/namespaces/1.1/003.xml", "eduni/namespaces/1.1/004.xml", "eduni/xml-1.1/043.xml",
    "eduni/xml-1.1/054.xml", "ibm/xml-1.1/valid/P02/ibm02v02.xml", "ibm/xml-1.1/valid/P02/ibm02v03.xml",
    "ibm/xml-1.1/valid/P02/ibm02v05.xml",
    // E 名字段(0,桶空役N1 清):底座 split_qualified_name 名字策略先拒族
    //   已由 NS 模式旗标非 NS 面全数正判入 plain;桶壳保留——新名字域败案
    //   先归此再分诊。
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
