#!/usr/bin/env python3
"""extract_name_tables.py — 从 W3C 规范 HTML 提取 XML 名字产生式字符区间表。

数据真源(锁版随仓 .xmlnames/,SHA256SUMS 可验):
  - rec-xml-20060816.html   XML 1.0 (4th ed) 产生式 [85]-[89]
      BaseChar / Ideographic / CombiningChar / Digit / Extender
      (Letter = BaseChar | Ideographic,拼装侧手写,不在此表)
  - rec-xml11-20060816.html XML 1.1 (2nd ed) 产生式 [4]-[5]
      NameStartChar / NameChar(NameChar 对 NameStartChar 的引用记入 refs)

用法:
  python3 tools/extract_name_tables.py > src/xml_name_tables.toml

产物为 TOML 形状表(人维护面);生成链见根仓 skelgen 方言 xmlname_toml_gen。
本脚本只做规范文本 → 区间表的机械翻译,不做任何字符判定逻辑。
"""

import html
import re
import sys

# 规范文件 → (文件名, 待提取的产生式名集合)
SOURCES = [
    (".xmlnames/rec-xml-20060816.html",
     ["BaseChar", "Ideographic", "CombiningChar", "Digit", "Extender"]),
    (".xmlnames/rec-xml11-20060816.html",
     ["NameStartChar", "NameChar"]),
]

# 产生式 → TOML production id(生成器词表封闭,拼装语义在消费侧手写 namecheck.mbt)
PRODUCTION_IDS = {
    "BaseChar": "base_char_10",
    "Ideographic": "ideographic_10",
    "CombiningChar": "combining_char_10",
    "Digit": "digit_10",
    "Extender": "extender_10",
    "NameStartChar": "name_start_char_11",
    "NameChar": "name_char_11",
}

# 产生式 → 源产生式编号(入表注记,审计用)
PRODUCTION_NOS = {
    "BaseChar": "[85]",
    "Ideographic": "[86]",
    "CombiningChar": "[87]",
    "Digit": "[88]",
    "Extender": "[89]",
    "NameStartChar": "[4]",
    "NameChar": "[5]",
}

# NameChar(1.1) 对 NameStartChar 的引用:记入 refs,不展开为区间
REF_TOKENS = {"NameChar": ["NameStartChar"]}

TOKEN_RE = re.compile(
    r"\[#x([0-9A-Fa-f]+)-#x([0-9A-Fa-f]+)\]"  # 区间
    r"|#x([0-9A-Fa-f]+)"                       # 单码点
    r"|\[([A-Za-z0-9])-([A-Za-z0-9])\]"        # 字面字符区间 [0-9] [A-Z]
    r"|\[([^\[\]]+)\]"                          # 其它方括号(字面字符类,如 [A-Z])
    r"|\"(.)\""                                  # 引号字面 ":" "-" "." "_"
    r"|([A-Za-z]+)"                             # 产生式引用
)


def scrape_productions(path, wanted):
    text = open(path, encoding="utf-8", errors="replace").read()
    found = {}
    for row in re.finditer(r'<tr valign="baseline">(.*?)</tr>', text, re.S):
        body = row.group(1)
        name_match = re.search(r"<code>([A-Za-z]+)</code>", body)
        if not name_match or name_match.group(1) not in wanted:
            continue
        name = name_match.group(1)
        cells = re.findall(r"<td>(.*?)</td>", body, re.S)
        rhs = re.sub(r"<[^>]+>", "", cells[-1])
        rhs = html.unescape(rhs).replace("\xa0", " ")
        found[name] = " ".join(rhs.split())
    missing = [w for w in wanted if w not in found]
    if missing:
        sys.exit(f"productions missing from {path}: {missing}")
    return found


def parse_rhs(rhs, name):
    ranges = []
    refs = []
    pos = 0
    for match in TOKEN_RE.finditer(rhs):
        gap = rhs[pos:match.start()]
        if gap.strip(" |") != "":
            sys.exit(f"{name}: unparsed segment {gap!r}")
        pos = match.end()
        lo_hi_lo, lo_hi_hi, single_hex, lit_lo, lit_hi, bracket, quoted, ref = match.groups()
        if lo_hi_lo:
            ranges.append((int(lo_hi_lo, 16), int(lo_hi_hi, 16)))
        elif single_hex:
            cp = int(single_hex, 16)
            ranges.append((cp, cp))
        elif lit_lo:
            ranges.append((ord(lit_lo), ord(lit_hi)))
        elif bracket is not None:
            # 字面字符类:逐字符展开("-" 在首/尾时为字面)
            items = re.findall(r".-.|.", bracket)
            for item in items:
                if len(item) == 3 and item[1] == "-":
                    ranges.append((ord(item[0]), ord(item[2])))
                else:
                    ranges.append((ord(item), ord(item)))
        elif quoted is not None:
            ranges.append((ord(quoted), ord(quoted)))
        elif ref:
            if ref in PRODUCTION_IDS:
                refs.append(PRODUCTION_IDS[ref])
            else:
                sys.exit(f"{name}: unknown production reference {ref!r}")
    tail = rhs[pos:]
    if tail.strip(" |") != "":
        sys.exit(f"{name}: trailing unparsed {tail!r}")
    return ranges, refs


def format_ranges(ranges):
    lo, hi = ranges
    if lo == hi:
        return f'"{lo:04X}"'
    return f'"{lo:04X}-{hi:04X}"'


def main():
    productions = {}
    for path, wanted in SOURCES:
        productions.update(scrape_productions(path, wanted))

    print('# XML 名字产生式字符区间表(生成数据:tools/extract_name_tables.py)')
    print('# 数据真源:W3C XML 1.0 4th ed + XML 1.1 2nd ed(锁版 .xmlnames/,SHA256SUMS 可验)')
    print('# 人维护面:区间修订改本表再走 skelgen/xmlnameregen 再生;拼装语义(Name/Letter)')
    print('# 在 src/namecheck.mbt 手写,不进本表。')
    print('schema_version = "1.0"')
    print('generator = "xmlname_toml_gen"')
    print('target_package = "moonxml/src"')
    print()
    for name in ["BaseChar", "Ideographic", "CombiningChar", "Digit", "Extender",
                 "NameStartChar", "NameChar"]:
        ranges, refs = parse_rhs(productions[name], name)
        ordered = sorted(ranges)
        for (_, prev_hi), (next_lo, _) in zip(ordered, ordered[1:]):
            if next_lo <= prev_hi:
                sys.exit(f"{name}: overlapping ranges at #{next_lo:04X}")
        pid = PRODUCTION_IDS[name]
        print("[[production]]")
        print(f'id = "{pid}"')
        print(f'source = "XML {"1.0 4e" if pid.endswith("_10") else "1.1 2e"}'
              f' production {PRODUCTION_NOS[name]}"')
        if refs:
            print("refs = [" + ", ".join(f'"{r}"' for r in refs) + "]")
        print("ranges = [")
        line = "  "
        for entry in ordered:
            piece = format_ranges(entry)
            if len(line) + len(piece) + 2 > 78:
                print(line.rstrip())
                line = "  "
            line += piece + ", "
        if line.strip():
            print(line.rstrip())
        print("]")
        print()


if __name__ == "__main__":
    main()
