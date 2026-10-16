// ===== M0 底座探针（moonxml 役M0；证据件随仓，报告入 ctx.md）=====
// 口径：native 检查两底座对同一线束的行为；计时 = @async.now()（ms 墙钟），
//       warmup 1 + k=5 取中位数（jsonld 役P1 同款）。
// 自报行：[m0-milky] / [m0-milky-err] / [m0-fidelity] / [m0-roundtrip] /
//         [m0-xmlparser] / [m0-perf] / [m0-summary]

///|
fn main {
  let mut milky_ok = 0
  let wf : Array[(String, String)] = [
    ("basic", "<r><a>1</a><b x=\"2\"/>tail</r>"),
    (
      "decl-doctype-entity", "<?xml version=\"1.0\"?><!DOCTYPE r [<!ENTITY co \"ACME\">]><r>&co;</r>",
    ),
    ("ns", "<p:r xmlns:p=\"urn:x\" p:id=\"1\"><c/></p:r>"),
    ("cdata", "<r><![CDATA[<not-tag> & raw]]></r>"),
    ("comment-pi", "<!--lead--><?pit d1?><r/><!--tail-->"),
    ("unicode", "<r>中文—🎉</r>"),
    ("deep", gen_deep(50)),
    ("big-attrs", "<r a=\"1\" b=\"2\" c=\"3\"><x y=\"4\" z=\"5\">t</x></r>"),
  ]
  for pair in wf {
    let case = pair.0
    let xml = pair.1
    match pull_milky(xml) {
      Ok(n) => {
        milky_ok += 1
        println("[m0-milky] case=\{case} ok=true events=\{n}")
      }
      Err(msg) => println("[m0-milky] case=\{case} ok=false err=\{msg}")
    }
  }
  println("[m0-subtotal] milky_wf=\{milky_ok}/\{wf.length()}")

  let mut milky_rej = 0
  let bad : Array[(String, String)] = [
    ("unclosed", "<r><a></r>"),
    ("mismatched", "<r></x>"),
    ("bad-entity", "<r>&nope;</r>"),
    ("stray-lt", "<r>a < b</r>"),
    ("empty-doc", ""),
  ]
  for pair in bad {
    let case = pair.0
    let xml = pair.1
    let rejected = match pull_milky(xml) {
      Ok(_) => false
      Err(_) => true
    }
    if rejected {
      milky_rej += 1
    }
    println("[m0-milky-err] case=\{case} rejected=\{rejected}")
  }
  println("[m0-subtotal] milky_err=\{milky_rej}/\{bad.length()}")

  fidelity_checks()
  roundtrip_check()

  let mut xp_ok = 0
  for pair in wf {
    let case = pair.0
    let xml = pair.1
    match run_xmlparser(xml) {
      Ok(_) => {
        xp_ok += 1
        println("[m0-xmlparser] case=\{case} ok=true")
      }
      Err(msg) => println("[m0-xmlparser] case=\{case} ok=false err=\{msg}")
    }
  }
  println("[m0-subtotal] xmlparser_wf=\{xp_ok}/\{wf.length()}")

  perf_smoke()
}

///|
/// Milky：拉全部事件，返回事件数；任何 XmlError → Err（span 化错误串）。
fn pull_milky(s : String) -> Result[Int32, String] {
  try {
    let reader = @xml.Reader::from_string(s)
    let mut n = 0
    while true {
      let ev = reader.read_event()
      match ev.kind {
        Eof => break
        _ => n += 1
      }
    }
    Ok(n)
  } catch {
    e => Err(e.to_string())
  }
}

///|
/// 保真断言：底座必须如实上报 XML 的结构语义（entity 展开 / CDATA 分型 /
/// 注释保留 / PI 拆 target,data / Decl 字段 / namespace 解析）。
fn fidelity_checks() -> Unit {
  let mut pass = 0
  let total = 6
  // 1. 内置实体展开
  let t1 = join_texts(pull_kinds("<r>a &lt; b &amp; c</r>"))
  if t1 == "a < b & c" {
    pass += 1
  }
  println("[m0-fidelity] entity-expanded=\{t1 == "a < b & c"}")
  // 2. 自定义 DTD 实体
  let t2 = join_texts(
    pull_kinds("<!DOCTYPE r [<!ENTITY co \"ACME\">]><r>&co;</r>"),
  )
  if t2 == "ACME" {
    pass += 1
  }
  println("[m0-fidelity] dtd-entity=\{t2 == "ACME"}")
  // 3. CDATA 分型
  let c3 = has_cdata(pull_kinds("<r><![CDATA[<x> & raw]]></r>"), "<x> & raw")
  if c3 {
    pass += 1
  }
  println("[m0-fidelity] cdata-typed=\{c3}")
  // 4. 注释保留
  let c4 = has_comment(pull_kinds("<r/><!--note-->"), "note")
  if c4 {
    pass += 1
  }
  println("[m0-fidelity] comment-kept=\{c4}")
  // 5. PI 拆 target,data
  let c5 = has_pi(pull_kinds("<?pit d1?><r/>"), "pit", "d1")
  if c5 {
    pass += 1
  }
  println("[m0-fidelity] pi-split=\{c5}")
  // 6. namespace 解析（NamespaceReader：uri + local_name）
  let mut ns_ok = false
  try {
    let nr = @xml.NamespaceReader::from_string(
      "<p:r xmlns:p=\"urn:x\" p:id=\"1\"/>",
    )
    while true {
      let ev = nr.read_event()
      match ev.kind {
        Start(el) => {
          ns_ok = el.name.namespace_uri == Some("urn:x") &&
            el.name.local_name == "r"
          break
        }
        Empty(el) => {
          ns_ok = el.name.namespace_uri == Some("urn:x") &&
            el.name.local_name == "r"
          break
        }
        Eof => break
        _ => continue
      }
    }
  } catch {
    _ => ns_ok = false
  }
  if ns_ok {
    pass += 1
  }
  println("[m0-fidelity] ns-resolved=\{ns_ok}")
  println("[m0-fidelity] pass=\{pass}/\{total}")
}

///|
fn roundtrip_check() -> Unit {
  let src = "<r a=\"1\"><c>t1</c><e/><!--k--></r>"
  let mut ok = false
  let mut detail = ""
  try {
    let reader = @xml.Reader::from_string(src)
    let w = @xml.Writer::new()
    while true {
      let ev = reader.read_event()
      let stop = ev.kind is Eof
      w.write_event(ev)
      if stop {
        break
      }
    }
    let out = w.to_string()
    let n1 = match pull_milky(src) {
      Ok(n) => n
      Err(m) => {
        detail = m
        -1
      }
    }
    let n2 = match pull_milky(out) {
      Ok(n) => n
      Err(m) => {
        detail = m
        -1
      }
    }
    ok = n1 == n2 && n1 > 0 && out.contains("a=\"1\"")
  } catch {
    e => detail = e.to_string()
  }
  println("[m0-roundtrip] ok=\{ok} \{detail}")
}

///|
/// XMLParser（组合子库）：pub 文档级入口 xml_from_string。
fn run_xmlparser(s : String) -> Result[Unit, String] {
  match @XMLParser.xml_from_string(s) {
    Some(_) => Ok(())
    None => Err("document parse failed")
  }
}

///|
fn gen_deep(depth : Int32) -> String {
  let b = StringBuilder()
  for _ in 0..<depth {
    b.write_string("<l>")
  }
  b.write_string("x")
  for _ in 0..<depth {
    b.write_string("</l>")
  }
  b.to_string()
}

///|
fn gen_big(size_hint : Int32) -> String {
  let b = StringBuilder()
  b.write_string("<log>")
  let mut n = 0
  while b.to_string().length() < size_hint {
    b.write_string(
      "<item id=\"i\{n}\" kind=\"k\{n % 7}\"><msg>entry \{n}</msg></item>",
    )
    n += 1
  }
  b.write_string("</log>")
  b.to_string()
}

///|
fn perf_smoke() -> Unit {
  let doc = gen_big(1_000_000)
  let bytes = doc.length()
  // 结构断言先跑（计错误结果即垃圾读数）
  let sanity = match pull_milky(doc) {
    Ok(n) => n > 40000
    Err(_) => false
  }
  println("[m0-perf] sanity=\{sanity} bytes=\{bytes}")
  if sanity {
    let r1 = time_median(5, fn() { let _ = pull_milky(doc) })
    println(
      "[m0-perf] base=milky bytes=\{bytes} median=\{r1.0}ms k=5 runs=[\{r1.1}]",
    )
    let r2 = time_median(5, fn() { let _ = run_xmlparser(doc) })
    println(
      "[m0-perf] base=xmlparser bytes=\{bytes} median=\{r2.0}ms k=5 runs=[\{r2.1}]",
    )
  }
}

///|
/// 计时轮：warmup 1 + k 次取中位数（jsonld 役P1 同款）。
fn time_median(k : Int32, f : () -> Unit) -> (Int32, String) {
  f()
  let runs : Array[Int32] = []
  for _ in 0..<k {
    let t0 = @async.now()
    f()
    runs.push((@async.now() - t0).to_int())
  }
  runs.sort_by(fn(a, b) { a.compare(b) })
  let disp = StringBuilder()
  for i in 0..<runs.length() {
    if i > 0 {
      disp.write_string(",")
    }
    disp.write_string(runs[i].to_string())
  }
  (runs[runs.length() / 2], disp.to_string())
}

// ===== 保真辅助（拉事件取 kind 串） =====

///|
fn pull_kinds(s : String) -> Array[String] {
  let kinds : Array[String] = []
  try {
    let reader = @xml.Reader::from_string(s)
    while true {
      let ev = reader.read_event()
      match ev.kind {
        Eof => break
        Start(el) => kinds.push("S:" + el.name)
        End(name) => kinds.push("E:" + name)
        Empty(el) => kinds.push("E:" + el.name)
        Text(t) => kinds.push("T:" + t)
        CData(t) => kinds.push("CD:" + t)
        Comment(c) => kinds.push("C:" + c)
        PI(target~, data~) => kinds.push("PI:\{target}:\{data}")
        Decl(version~, encoding~, standalone~) => {
          let enc = match encoding {
            Some(e) => e
            None => "-"
          }
          kinds.push("D:\{version}:\{enc}")
          let _ = standalone
        }
        DocType(d) => kinds.push("DT:" + d)
      }
    }
  } catch {
    _ => ()
  }
  kinds
}

///|
fn join_texts(kinds : Array[String]) -> String {
  let b = StringBuilder()
  for k in kinds {
    if k.has_prefix("T:") {
      b.write_string(k[2:].to_owned())
    }
  }
  b.to_string()
}

///|
fn has_cdata(kinds : Array[String], want : String) -> Bool {
  for k in kinds {
    if k == "CD:" + want {
      return true
    }
  }
  false
}

///|
fn has_comment(kinds : Array[String], want : String) -> Bool {
  for k in kinds {
    if k == "C:" + want {
      return true
    }
  }
  false
}

///|
fn has_pi(kinds : Array[String], target : String, data : String) -> Bool {
  for k in kinds {
    if k == "PI:\{target}:\{data}" {
      return true
    }
  }
  false
}
