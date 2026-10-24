///|
/// 套件 harness（jsonld 桶宪法）：manifest 落账 197 案，组桶判定——
/// plain 组 = X2 主链覆盖（组名单逐组注记）；其余组 = deferred（X3 面）。
/// 判定 = 四元组多重集对拍（bnode 双射回溯兜底）；负例族 = 必须 Err。

///|
/// rdf11 按 action 目录、rdf12 按文件名族段提特征组。
fn suite_feature_group(suite_case : @rdf.SuiteCase) -> String {
  if suite_case.family == "rdf11" {
    action_dir(suite_case.action)
  } else {
    let stem = if suite_case.action.has_prefix("rdf12-xml-") {
      suite_case.action[10:].to_owned()
    } else {
      suite_case.action
    }
    let mut cut = -1
    for i in 0..<stem.length() {
      if stem[i] == 45 {
        cut = i
      }
    }
    if cut > 0 {
      stem[:cut].to_owned()
    } else {
      stem
    }
  }
}

///|
fn action_dir(action : String) -> String {
  let parts : Array[StringView] = action.split("/").collect()
  parts[0].to_owned()
}

///|
/// 盘上词面路径（包内相对径）。
fn suite_file_path(suite_case : @rdf.SuiteCase) -> String {
  if suite_case.family == "rdf11" {
    "./src/rdf/.rdf-tests/rdf11/rdf-xml/" + suite_case.action
  } else {
    "./src/rdf/.rdf-tests/rdf12/rdf-xml/eval/" + suite_case.action
  }
}

///|
/// 套件 base（相对引用解析锚 = .rdf 注记的 w3c.github.io 根）。
fn suite_base(suite_case : @rdf.SuiteCase) -> String {
  if suite_case.family == "rdf11" {
    "https://w3c.github.io/rdf-tests/rdf/rdf11/rdf-xml/" + suite_case.action
  } else {
    "https://w3c.github.io/rdf-tests/rdf/rdf12/rdf-xml/eval/" +
    suite_case.action
  }
}

///|
/// 16 进制位值（.nt \uXXXX 解）。
fn hex_digit_value(d : Int32) -> Int32 {
  if d >= 48 && d <= 57 {
    d - 48
  } else if d >= 97 && d <= 102 {
    d - 87
  } else if d >= 65 && d <= 70 {
    d - 55
  } else {
    0
  }
}

///|
/// .nt 词项反转义（\n \t \r \" \\ \uXXXX）。
fn nt_unescape(text : String) -> String {
  let mut out = ""
  let mut i = 0
  let len = text.length()
  while i < len {
    let ch = text[i].to_int()
    if ch == 92 && i + 1 < len {
      let nxt = text[i + 1].to_int()
      if nxt == 110 {
        out = out + "\n"
        i = i + 2
        continue
      }
      if nxt == 116 {
        out = out + "\t"
        i = i + 2
        continue
      }
      if nxt == 114 {
        out = out + "\r"
        i = i + 2
        continue
      }
      if nxt == 34 || nxt == 92 {
        out = out + Int32::unsafe_to_char(nxt).to_string()
        i = i + 2
        continue
      }
      if nxt == 117 && i + 5 < len {
        let mut code = 0
        let mut j = i + 2
        while j < i + 6 {
          code = code * 16 + hex_digit_value(text[j].to_int())
          j = j + 1
        }
        out = out + Int32::unsafe_to_char(code).to_string()
        i = i + 6
        continue
      }
      out = out + Int32::unsafe_to_char(ch).to_string()
      i = i + 1
    } else {
      out = out + Int32::unsafe_to_char(ch).to_string()
      i = i + 1
    }
  }
  out
}

///|
/// .nt 行 → 三词项规范串表（注释/空行返空表；规约 = 反转义后重壳）。
fn parse_nt_line(line : String) -> Array[String] {
  let trimmed = line.trim().to_owned()
  if trimmed == "" || trimmed.has_prefix("#") {
    return []
  }
  let terms : Array[String] = []
  let mut i = 0
  let len = trimmed.length()
  while i < len {
    let ch = trimmed[i].to_int()
    if ch == 32 || ch == 9 {
      i = i + 1
      continue
    }
    if ch == 46 && i == len - 1 {
      break
    }
    if ch == 60 {
      let mut close = i
      let mut j = i + 1
      while j < len {
        if trimmed[j].to_int() == 62 {
          close = j
          break
        }
        j = j + 1
      }
      terms.push("<" + nt_unescape(trimmed[i + 1:close].to_owned()) + ">")
      i = close + 1
      continue
    }
    if ch == 95 {
      let mut end = i + 1
      let mut j = i + 2
      while j < len {
        if trimmed[j].to_int() == 32 || trimmed[j].to_int() == 9 {
          break
        }
        end = j
        j = j + 1
      }
      terms.push("_:" + trimmed[i + 2:end + 1].to_owned())
      i = end + 1
      continue
    }
    if ch == 34 {
      let mut j = i + 1
      while j < len {
        if trimmed[j].to_int() == 92 {
          j = j + 2
          continue
        }
        if trimmed[j].to_int() == 34 {
          break
        }
        j = j + 1
      }
      let literal = "\"" + nt_unescape(trimmed[i + 1:j].to_owned()) + "\""
      let mut end = j + 1
      let mut term = literal
      if end < len && trimmed[end].to_int() == 64 {
        let mut k = end + 1
        while k < len && trimmed[k].to_int() != 32 && trimmed[k].to_int() != 9 {
          k = k + 1
        }
        term = literal + "@" + trimmed[end + 1:k].to_owned()
        end = k
      } else if end + 2 < len &&
        trimmed[end].to_int() == 94 &&
        trimmed[end + 1].to_int() == 94 &&
        trimmed[end + 2].to_int() == 60 {
        let mut k = end + 3
        while k < len && trimmed[k].to_int() != 62 {
          k = k + 1
        }
        term = literal + "^^<" + trimmed[end + 3:k].to_owned() + ">"
        end = k + 1
      }
      terms.push(term)
      i = end
      continue
    }
    i = i + 1
  }
  terms
}

///|
/// .nt 全文 → 规范三元组表（"s","p","o" 反转义后重壳形）。
fn parse_nt_document(text : String) -> Array[(String, String, String)] {
  let out : Array[(String, String, String)] = []
  for line_view in text.split("\n") {
    let terms = parse_nt_line(line_view.to_owned())
    if terms.length() == 3 {
      out.push((terms[0], terms[1], terms[2]))
    }
  }
  out
}

///|
/// 我方词项 → 规范串（与 .nt 解壳形同构）。
fn suite_term_canonical(term : @rdf.Term) -> String {
  match term {
    @rdf.Iri(iri) => "<" + iri + ">"
    @rdf.BNode(label) => "_:" + label
    @rdf.Literal(value, lang, datatype) => {
      let mut out = "\"" + value + "\""
      match lang {
        Some(l) => out = out + "@" + l
        None => ()
      }
      match datatype {
        Some(d) => out = out + "^^<" + d + ">"
        None => ()
      }
      out
    }
  }
}

///|
/// 规范串 → 词项（双射器内部桥）。
fn suite_canonical_to_term(canonical : String) -> @rdf.Term {
  if canonical.has_prefix("<") && canonical.has_suffix(">") {
    return @rdf.Iri(canonical[1:canonical.length() - 1].to_owned())
  }
  if canonical.has_prefix("_:") {
    return @rdf.BNode(canonical[2:].to_owned())
  }
  let mut i = 1
  let len = canonical.length()
  while i < len {
    if canonical[i].to_int() == 92 {
      i = i + 2
      continue
    }
    if canonical[i].to_int() == 34 {
      break
    }
    i = i + 1
  }
  let literal_value = canonical[1:i].to_owned()
  let rest_start = i + 1
  let mut lang : String? = None
  let mut datatype : String? = None
  if rest_start < len {
    let rest = canonical[rest_start:].to_owned()
    if rest.has_prefix("@") {
      lang = Some(rest[1:].to_owned())
    } else if rest.has_prefix("^^<") {
      datatype = Some(rest[3:rest.length() - 1].to_owned())
    }
  }
  @rdf.Literal(literal_value, lang, datatype)
}

///|
/// 词项等（IRI/字面量精确；bnode 由双射器统管）。
fn suite_term_equal(left : @rdf.Term, right : @rdf.Term) -> Bool {
  match (left, right) {
    (@rdf.Iri(a), @rdf.Iri(b)) => a == b
    (@rdf.Literal(v1, l1, d1), @rdf.Literal(v2, l2, d2)) =>
      v1 == v2 && l1 == l2 && d1 == d2
    _ => false
  }
}

///|
/// 双射绑定一致性（副本上绑定，冲突返 None）。
fn suite_bind(
  left : (@rdf.Term, @rdf.Term, @rdf.Term),
  right : (@rdf.Term, @rdf.Term, @rdf.Term),
  l2r : Map[String, String],
  r2l : Map[String, String],
) -> Map[String, String]? {
  let next_l2r : Map[String, String] = Map([])
  let next_r2l : Map[String, String] = Map([])
  for key, value in l2r {
    next_l2r[key] = value
  }
  for key, value in r2l {
    next_r2l[key] = value
  }
  for pos in 0..<3 {
    let left_term = if pos == 0 {
      left.0
    } else if pos == 1 {
      left.1
    } else {
      left.2
    }
    let right_term = if pos == 0 {
      right.0
    } else if pos == 1 {
      right.1
    } else {
      right.2
    }
    let left_label = match left_term {
      @rdf.BNode(label) => Some(label)
      _ => None
    }
    let right_label = match right_term {
      @rdf.BNode(label) => Some(label)
      _ => None
    }
    match (left_label, right_label) {
      (Some(a), Some(b)) => {
        match next_l2r.get(a) {
          Some(existing) => if existing != b { return None }
          None => ()
        }
        match next_r2l.get(b) {
          Some(existing) => if existing != a { return None }
          None => ()
        }
        match next_l2r.get(a) {
          Some(_) => ()
          None => next_l2r[a] = b
        }
        match next_r2l.get(b) {
          Some(_) => ()
          None => next_r2l[b] = a
        }
      }
      (None, None) =>
        if !suite_term_equal(left_term, right_term) {
          return None
        }
      _ => return None
    }
  }
  Some(next_l2r)
}

///|
/// 多重集对拍（bnode 双射回溯；套件图小，纯回溯可行）。
fn suite_quads_match(
  ours : Array[(@rdf.Term, @rdf.Term, @rdf.Term)],
  theirs : Array[(String, String, String)],
) -> Bool {
  if ours.length() != theirs.length() {
    return false
  }
  let parsed_theirs : Array[(@rdf.Term, @rdf.Term, @rdf.Term)] = []
  for triple in theirs {
    parsed_theirs.push(
      (
        suite_canonical_to_term(triple.0),
        suite_canonical_to_term(triple.1),
        suite_canonical_to_term(triple.2),
      ),
    )
  }
  fn backtrack(
    index : Int32,
    l2r : Map[String, String],
    r2l : Map[String, String],
  ) -> Bool {
    if index == ours.length() {
      return true
    }
    for j in 0..<parsed_theirs.length() {
      match suite_bind(ours[index], parsed_theirs[j], l2r, r2l) {
        Some(next_l2r) => {
          let next_r2l : Map[String, String] = Map([])
          for key, value in next_l2r {
            next_r2l[value] = key
          }
          if backtrack(index + 1, next_l2r, next_r2l) {
            return true
          }
        }
        None => ()
      }
    }
    false
  }
  backtrack(0, Map([]), Map([]))
}

///|
/// 期望面规范串 → 词项三元组（对拍 dump 用）。
fn suite_expect_terms(
  triples : Array[(String, String, String)],
) -> Array[(@rdf.Term, @rdf.Term, @rdf.Term)] {
  let out : Array[(@rdf.Term, @rdf.Term, @rdf.Term)] = []
  for triple in triples {
    out.push(
      (
        suite_canonical_to_term(triple.0),
        suite_canonical_to_term(triple.1),
        suite_canonical_to_term(triple.2),
      ),
    )
  }
  out
}

///|
async test "rdf/xml suite harness: 组桶判定" {
  let cases = @rdf.suite_cases()
  // ---- X2 主链覆盖组（组名 + 一句理由）----
  let plain_groups : Array[String] = [
    // 名称合法性双面（怪合法名/禁词负例）
    "rdfms-rdf-names-use",
    // xml:base 叠加解析主战场
     "xmlbase",
    // 无前缀属性禁令 + 前缀形态
     "rdf-ns-prefix-confusion",
    // 匿名节点 fresh bnode
     "rdfms-identity-anon-resources",
    // xml:lang 继承
     "rdfms-xmllang",
    // ID/about 定位差
     "rdfms-difference-between-ID-and-about",
    // 未知 xml:* 忽略
     "unrecognised-xml-attributes",
    // 常规 eval（绝对 IRI 面）
     "rdfs-domain-and-range",
    // IRI 中字符引用
     "rdf-charmod-uris",
    // rdf:datatype 型化字面量
     "datatypes",
    // rdf:type 断言
     "rdfms-uri-substructure",
    // 大整数词形
     "rdfms-para196",
    // li 拨号计数
     "rdfms-duplicate-member-props",
    // & 转义字面量
     "amp-in-url",
    // 字面量内字符引用
     "rdf-charmod-literals",
    // 顶层裸节点元素（rdf:RDF 非强制）
     "rdf-element-not-mandatory",
    // 节点元素产物面
     "rdf-node-element",
    // 1.0 除名词 aboutEach 负例双 err
     "rdfms-abouteach",
    // ID+resource 互斥判读
     "rdfms-not-id-and-resource-attr",
    // rdf:ID 具化正例（emit_reification 通）
     "rdfms-reification-required",
    // rdf:ID 词形（NCName）/全文查重负例族
     "rdfms-rdf-id",
    // nodeID 词形+互斥负例族（error001-006）+ 正例四案
     "rdfms-syntax-incomplete",
    // 容器拨号主面（li 按父元素现访计，test008 钉）
     "rdf-containers-syntax-vs-schema",
    // 空属性元素五形（真空形=空字面量；resource/属性属性形）
     "rdfms-empty-property-elements",
  ]
  // 逐案缓名单（组桶内个案，逐案注记；X3 面回收时逐案拨回）
  // 组级缓注：rdfms-seq-representation 双案全用 parseType="Collection" → X3
  let per_case_deferred : Array[String] = [
    // parseType="Literal"（X3）
    "rdf-ns-prefix-confusion-test0005",
    // parseType="Resource"（X3）
     "rdf-containers-syntax-vs-schema-test004",
    // parseType="Resource"（X3）
     "rdfms-empty-property-elements-test004", "rdfms-empty-property-elements-test006",
    "rdfms-empty-property-elements-test010", "rdfms-empty-property-elements-test012",
  ]
  let mut judged = 0
  let mut failed = 0
  let deferred_groups : Array[String] = []
  for suite_case in cases {
    let group = suite_feature_group(suite_case)
    if plain_groups.contains(group) &&
      !per_case_deferred.contains(suite_case.name) {
      judged = judged + 1
      let xml = @utf8.decode(
        @fs.read_file(suite_file_path(suite_case)).binary(),
      )
      match suite_case.kind {
        "negative_syntax" => {
          let base = suite_base(suite_case)
          match @rdf.parse_rdf_xml_with_base(xml, base~) {
            Err(_) => ()
            Ok(_) => {
              failed = failed + 1
              fail("\{suite_case.name}: 负例意外全绿")
            }
          }
        }
        _ => {
          let base = suite_base(suite_case)
          match @rdf.parse_rdf_xml_with_base(xml, base~) {
            Err(msg) => {
              failed = failed + 1
              fail("\{suite_case.name}: 正例报错 \{msg}")
            }
            Ok(dataset) => {
              let expect_path = match suite_case.result {
                Some(r) => r
                None => fail("\{suite_case.name}: eval 无 result")
              }
              let expect_text = @utf8.decode(
                @fs.read_file(
                  "./src/rdf/.rdf-tests/rdf11/rdf-xml/" + expect_path,
                ).binary(),
              )
              let ours : Array[(@rdf.Term, @rdf.Term, @rdf.Term)] = []
              for quad in dataset.quads {
                ours.push((quad.subject, quad.predicate, quad.object))
              }
              let expected = parse_nt_document(expect_text)
              if !suite_quads_match(ours, expected) {
                failed = failed + 1
                let theirs_terms = suite_expect_terms(expected)
                let mut dump = "\{suite_case.name}: 对拍不一致"
                for t in ours {
                  dump = dump +
                    "\n  ours: " +
                    suite_term_canonical(t.0) +
                    " " +
                    suite_term_canonical(t.1) +
                    " " +
                    suite_term_canonical(t.2)
                }
                for t in theirs_terms {
                  dump = dump +
                    "\n  want: " +
                    suite_term_canonical(t.0) +
                    " " +
                    suite_term_canonical(t.1) +
                    " " +
                    suite_term_canonical(t.2)
                }
                fail(dump)
              }
            }
          }
        }
      }
    } else if !deferred_groups.contains(group) {
      deferred_groups.push(group)
    }
  }
  let deferred = cases.length() - judged
  // ---- pin（绝对计数 + 闭包）----
  assert_eq(cases.length(), 197)
  assert_eq(judged + deferred, 197)
  assert_eq(judged, 156)
  assert_eq(deferred, 41)
  assert_eq(failed, 0)
  println(
    "[rdf-xml] entries=\{cases.length()} judged=\{judged} deferred=\{deferred} groups=\{deferred_groups.length()}",
  )
}
