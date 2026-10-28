#!/usr/bin/env python3
"""对比 lilToon 属性默认值与本项目 uniform 默认值。

用途：P9 的「命名/默认值语义对齐」。默认值不一致会导致新建材质的外观与原版不同，
这类偏差很难在渲染时看出来（因为大家都以为默认值是对的）。

用法：
    python tools/compare_defaults.py
    python tools/compare_defaults.py --verbose   # 连一致的也列出来
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_alignment_matrix import (  # noqa: E402
    ALIASES,
    DEFAULT_LILTOON,
    SKIP_ATTRS,
    SKIP_PATTERNS,
    to_snake,
)

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIL_SHADER = os.path.join(DEFAULT_LILTOON, "lts.shader")
UNIFORMS = os.path.join(PROJECT, "addons", "liltoon_gd", "shaders", "include", "uniforms.gdshaderinc")

# Properties 行：_Color ("Main Color", Color) = (1,1,1,1)
PROP_RE = re.compile(
    r'^\s*(_[A-Za-z0-9_]+)\s*\(\s*"[^"]*"\s*,\s*([A-Za-z0-9() ,.]+?)\s*\)\s*=\s*(.+?)\s*$',
    re.MULTILINE,
)
# uniform 行：uniform vec4 main_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
UNIFORM_RE = re.compile(
    r"^\s*uniform\s+(\w+)\s+([A-Za-z0-9_]+)[^=;]*=\s*([^;]+);", re.MULTILINE
)


def parse_numbers(text: str):
    # 先去掉 vec2/vec3/vec4 的类型名，否则 "vec4" 里的 4 会被当成数值
    cleaned = re.sub(r"\bvec[234]\b", "", text)
    nums = re.findall(r"-?\d+(?:\.\d+)?", cleaned)
    return [float(n) for n in nums]


def parse_bool(text: str):
    t = text.strip().lower()
    if t in ("true", "1", "1.0"):
        return True
    if t in ("false", "0", "0.0"):
        return False
    return None


def main() -> int:
    verbose = "--verbose" in sys.argv

    props: dict[str, str] = {}
    text = open(LIL_SHADER, encoding="utf-8", errors="replace").read()
    for m in PROP_RE.finditer(text):
        name, _typ, default = m.group(1), m.group(2), m.group(3)
        if name in SKIP_ATTRS or any(p.match(name) for p in SKIP_PATTERNS):
            continue
        props[name] = default.strip()

    uniforms: dict[str, tuple[str, str]] = {}
    utext = open(UNIFORMS, encoding="utf-8", errors="replace").read()
    for m in UNIFORM_RE.finditer(utext):
        utype, name, default = m.group(1), m.group(2), m.group(3).strip()
        uniforms[name] = (utype, default)

    diffs = []
    checked = 0
    for prop, lil_default in sorted(props.items()):
        target = ALIASES.get(prop) or to_snake(prop)
        if target not in uniforms:
            continue
        utype, our_default = uniforms[target]
        if utype.startswith("sampler"):
            continue
        checked += 1

        lil_vals = parse_numbers(lil_default)
        our_vals = parse_numbers(our_default)
        lil_bool = parse_bool(lil_default)
        our_bool = parse_bool(our_default)

        same = False
        if lil_bool is not None and our_bool is not None:
            same = lil_bool == our_bool
        elif lil_vals and our_vals and len(lil_vals) == len(our_vals):
            same = all(abs(a - b) <= 0.011 for a, b in zip(lil_vals, our_vals))
        elif lil_vals and our_vals:
            same = abs(lil_vals[0] - our_vals[0]) <= 0.011

        if not same:
            diffs.append((prop, lil_default, target, our_default))
        elif verbose:
            print(f"  OK  {prop:<32} {lil_default:<22} == {our_default}")

    print(f"\n对比 {checked} 项（跳过 sampler 与未实现项），默认值不一致 {len(diffs)} 项\n")
    for prop, lil_d, target, our_d in diffs:
        print(f"  {prop:<34} liltoon={lil_d:<20} {target}={our_d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
