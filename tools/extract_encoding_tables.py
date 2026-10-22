#!/usr/bin/env python3
"""extract_encoding_tables.py — 从 WHATWG Encoding Standard 索引表提取 JIS 映射表。

数据真源(锁版随仓 .encodings/,SHA256SUMS 可验):
  - index-jis0208.txt  shift_jis / euc-jp / iso-2022-jp 三码共用的双字节面
  - index-jis0212.txt  euc-jp 三字节面(JIS X 0212)

用法(仓根起跑):
  python3 tools/extract_encoding_tables.py > src/jis_tables_gen.mbt

产物为 MoonBit 纯数据表(稀疏指针→码点数组,未定义槽 = 0,Int32);指针公式与
状态机(shift_jis/euc-jp 的 lead×trail 换算、iso-2022-jp 转义序列)手写于
消费包 jisdecode.mbt。本脚本只做规范文本 → 数据表的机械翻译,不做任何
解码判定逻辑。产物冻结数据无 TOML 维护面(R-J1a:再锁 = 重取 .txt 再跑)。
链含 fmt 段:python 不模拟 fmt 数组重排,再生契约 = extractor → moon fmt →
黄金门字节对拍(fmt 自身幂等,重排只发生一次)。
"""

import sys

# 锁定文件 → (产物表名, 文档行)
SOURCES = [
    (".encodings/index-jis0208.txt", "jis0208_index",
     "WHATWG index-jis0208 — shift_jis/euc-jp/iso-2022-jp 共用双字节面"),
    (".encodings/index-jis0212.txt", "jis0212_index",
     "WHATWG index-jis0212 — euc-jp 三字节面(JIS X 0212)"),
]


def parse_index(path):
    """规范索引文本 → {pointer: codepoint};列形 pointer\\t0xNNNN\\t<字> (<注>)。"""
    identifier = None
    entries = {}
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith("# Identifier: "):
                identifier = line[len("# Identifier: "):]
                continue
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) < 2:
                raise SystemExit(f"{path}: unexpected line: {line!r}")
            pointer = int(fields[0])
            codepoint = int(fields[1], 16)
            if pointer in entries:
                raise SystemExit(f"{path}: duplicate pointer {pointer}")
            entries[pointer] = codepoint
    if identifier is None:
        raise SystemExit(f"{path}: missing WHATWG Identifier header")
    return identifier, entries


def emit_array(name, doc, identifier, entries):
    size = max(entries) + 1
    lines = [
        "///|",
        f"/// {doc}(机械直发;DO NOT EDIT)。",
        f"/// WHATWG Identifier: {identifier};稀疏数组,槽值 0 = 指针未定义(解码侧须拒)。",
        f"let {name} : Array[Int32] = [",
    ]
    for pointer in range(size):
        lines.append(f"  {entries.get(pointer, 0)},")
    lines.append("]")
    return "\n".join(lines)


def main():
    header = [
        "// ===== GENERATED FILE — DO NOT EDIT(生成物禁手写,const.md §7)=====",
        "// 源表:.encodings/ 锁版(WHATWG Encoding Standard 索引,SHA256SUMS 可验)",
        "// 再生:python3 tools/extract_encoding_tables.py > src/jis_tables_gen.mbt",
        "//       (仓根起跑;再生 → moon fmt → 黄金门字节对拍)",
        "// 面:JIS 解码数据面。指针公式与状态机(shift_jis/euc-jp 换算、",
        "// iso-2022-jp 转义序列)手写于 jisdecode.mbt,不在此表。",
        "",
    ]
    blocks = []
    for path, name, doc in SOURCES:
        identifier, entries = parse_index(path)
        blocks.append(emit_array(name, doc, identifier, entries))
        print(
            f"extract_encoding_tables: {path} -> {name} "
            f"({len(entries)} defined / size {max(entries) + 1})",
            file=sys.stderr,
        )
    print("\n".join(header))
    print("\n\n".join(blocks))


if __name__ == "__main__":
    main()
