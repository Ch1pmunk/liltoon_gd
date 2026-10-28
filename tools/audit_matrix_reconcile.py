"""矩阵对账：查重复登记行、统计与基线的对应关系（只读，不改文件）。"""
import os
import re
import sys
import collections

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MATRIX = os.path.join(PROJECT, "docs", "参数对齐矩阵.md")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_alignment_matrix import DEFAULT_LILTOON, extract_properties

ROW_RE = re.compile(r"^\|\s*`(_[A-Za-z0-9_]+)`\s*\|\s*`([^`]+)`", re.M)


def main() -> int:
    text = open(MATRIX, encoding="utf-8").read()
    rows = ROW_RE.findall(text)
    names = [r[0] for r in rows]
    counts = collections.Counter(names)
    dups = [(k, v) for k, v in counts.items() if v > 1]

    props = set()
    for name in os.listdir(DEFAULT_LILTOON):
        if name.endswith(".shader"):
            props |= set(extract_properties(os.path.join(DEFAULT_LILTOON, name)))

    in_baseline = [n for n in set(names) if n in props]
    not_in_baseline = [n for n in set(names) if n not in props]

    print(f"矩阵登记行      : {len(rows)}")
    print(f"唯一属性        : {len(set(names))}")
    print(f"重复登记        : {len(dups)}")
    for k, v in dups:
        print(f"  {k} x{v}")
    print(f"基线属性总数    : {len(props)}")
    print(f"命中基线        : {len(in_baseline)}")
    print(f"不在基线        : {len(not_in_baseline)}")
    for n in sorted(not_in_baseline):
        print(f"  {n}")
    unregistered = sorted(props - set(names))
    print(f"基线中未登记    : {len(unregistered)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
