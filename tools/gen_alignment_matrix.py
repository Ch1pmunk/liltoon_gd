#!/usr/bin/env python3
"""重新统计 docs/参数对齐矩阵.md 的口径。

背景：这份矩阵一直是手工维护的，参数数量一变统计就失效（"98 项"拖到实际只剩
27 项才被发现）。这个脚本把统计改成可重算的：

  1. 从 lilToon 的 lts.shader 提取全部属性（基线，516 项）
  2. 从 uniforms.gdshaderinc 提取全部 uniform
  3. 解析矩阵已有的「已对齐」表，得到 属性 -> uniform 的映射
  4. 输出：已对齐 / 未对齐 / 项目特有，以及按前缀分组的未对齐清单

用法：
    python tools/gen_alignment_matrix.py                # 只报告
    python tools/gen_alignment_matrix.py --write        # 把统计写回矩阵头部
    python tools/gen_alignment_matrix.py --liltoon PATH # 指定 lilToon 源码目录
"""
from __future__ import annotations

import argparse
import os
import re
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# lilToon 2.4.1 源码随项目分发在 lilToon-2.4.1/；可用环境变量覆盖。
DEFAULT_LILTOON = os.environ.get(
    "LILTOON_SHADER_DIR",
    os.path.join(PROJECT, "lilToon-2.4.1", "Assets", "lilToon", "Shader"),
)
UNIFORMS = os.path.join(PROJECT, "addons", "liltoon_gd", "shaders", "include", "uniforms.gdshaderinc")
OUTLINE = os.path.join(PROJECT, "addons", "liltoon_gd", "shaders", "include", "outline_common.gdshaderinc")
MATRIX = os.path.join(PROJECT, "docs", "参数对齐矩阵.md")

ATTR_RE = re.compile(r"^\s*(?:\[[^\]]*\]\s*)*(_[A-Za-z0-9_]+)\s*\(", re.MULTILINE)
UNIFORM_RE = re.compile(r"^\s*uniform\s+\w+\s+([A-Za-z0-9_]+)", re.MULTILINE)
# 矩阵表格：| `_Prop` | `uniform` | 关系 |
ROW_RE = re.compile(r"^\|\s*`(_[A-Za-z0-9_]+)`\s*\|", re.MULTILINE)

SKIP_ATTRS = {"_DummyProperty"}
# lilToon 的表情动画占位参数（_e2ga0 / _ega0 ...），不是材质参数
SKIP_PATTERNS = [re.compile(r"^_e2?g[ac]", re.IGNORECASE)]

# 命名差异较大、自动蛇形匹配够不到的手工别名（左边是 lilToon，右边是本项目）
ALIASES = {
    "_BaseColor": "main_color",
    "_BaseMap": "main_texture",
    "_Ramp": "shade_ramp",
    "_BumpMap": "normal_texture",
    "_BumpScale": "normal_strength",
    "_Smoothness": "smoothness_texture",
    "_AlphaMask": "alpha_mask_texture",
    "_AlphaMaskMode": "alpha_mask_strength",
    "_GlitterColorTex": "glitter_color_texture",
    "_GlitterColorTex_UVMode": "glitter_color_uv_mode",
    "_GlitterParams1": "glitter_scale",
    "_GlitterParams2": "glitter_sensitivity",
}


def extract_properties(shader_path: str) -> list[str]:
    text = open(shader_path, encoding="utf-8", errors="replace").read()
    box = _properties_block(text)
    names = {m.group(1) for m in ATTR_RE.finditer(box)}
    names = {n for n in names if n not in SKIP_ATTRS
             and not any(p.match(n) for p in SKIP_PATTERNS)}
    return sorted(names)


def _properties_block(text: str) -> str:
    start = text.find("Properties")
    if start < 0:
        return ""
    brace = text.find("{", start)
    if brace < 0:
        return ""
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[brace:i]
    return text[brace:]


def extract_uniforms(path: str) -> list[str]:
    text = open(path, encoding="utf-8", errors="replace").read()
    return sorted({m.group(1) for m in UNIFORM_RE.finditer(text)})


def extract_mapped(matrix_text: str) -> set[str]:
    return set(ROW_RE.findall(matrix_text))


# 被误拆的缩写：先转蛇形，再把拆开的部分合回去
_GLUE = [
    ("mat_cap", "matcap"),
    ("audio_link", "audiolink"),
    ("u_d_i_m", "udim"),
    ("uv_1", "uv1"),
    ("uv_2", "uv2"),
    ("hsv_g", "hsvg"),
    ("g_s_a_a", "gsaa"),
]


def to_snake(prop: str) -> str:
    """_MatCapApplyTransparency -> matcap_apply_transparency"""
    s = prop.lstrip("_")
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    s = re.sub(r"([A-Za-z])([0-9])", r"\1_\2", s)
    s = re.sub(r"([0-9])([A-Za-z])", r"\1_\2", s)
    s = re.sub(r"_+", "_", s).lower()
    for a, b in _GLUE:
        s = s.replace(a, b)
    # matcap2_nd_blend_uv1 -> matcap_2nd_blend_uv1
    s = s.replace("_2_nd", "_2nd").replace("_3_rd", "_3rd")
    return s


def auto_match(props: list[str], uniforms: set[str]) -> dict[str, str]:
    """返回 属性 -> uniform 的自动匹配结果（仅当蛇形名确实存在）。"""
    found: dict[str, str] = {}
    for prop in props:
        alias = ALIASES.get(prop)
        if alias and alias in uniforms:
            found[prop] = alias
            continue
        for candidate in (to_snake(prop), to_snake(prop).replace("_2nd", "2nd").replace("_3rd", "3rd")):
            if candidate in uniforms:
                found[prop] = candidate
                break
    return found


def group_prefix(props: list[str]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for name in props:
        # _MatCap2ndVRParallaxStrength -> MatCap
        stem = name.lstrip("_")
        m = re.match(r"([A-Z][a-z0-9]*(?:[A-Z][a-z0-9]*)?)", stem)
        key = m.group(1) if m else stem
        groups.setdefault(key, []).append(name)
    return groups


def _rewrite(matrix_text: str, aligned: list[str], missing: list[str], props: list[str],
             auto_only: list[str], auto: dict[str, str], param_line: str) -> list[str]:
    stamp = "2026-10-28"
    lines = matrix_text.splitlines(keepends=True)

    for i, line in enumerate(lines):
        if line.startswith("- 生成时间："):
            lines[i] = f"- 生成时间：{stamp}（tools/gen_alignment_matrix.py 重算）\n"
        elif line.startswith("- liltoon 属性："):
            lines[i] = f"- liltoon 属性：{len(props)} 项（不含 _e*g* 表情动画占位与 _DummyProperty）\n"
        elif line.startswith("- 本插件参数："):
            lines[i] = param_line
        elif line.startswith("- 已对齐："):
            lines[i] = f"- 已对齐：{len(aligned)} 项\n"
        elif line.startswith("- 未对齐："):
            lines[i] = f"- 未对齐：{len(missing)} 项\n"

    # 把自动匹配到、但表里没有的行补进「已对齐」表尾
    if auto_only:
        body = "".join(lines)
        marker = "## 未对齐（按类别）"
        idx = body.find(marker)
        if idx > 0:
            rows = "".join(f"| `{p}` | `{auto[p]}` | 自动匹配 |\n" for p in auto_only)
            head = body[:idx].rstrip("\n")
            body = head + "\n" + rows + "\n" + body[idx:]
            lines = body.splitlines(keepends=True)

    return lines


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--liltoon", default=DEFAULT_LILTOON)
    ap.add_argument("--write", action="store_true", help="把统计写回矩阵头部")
    args = ap.parse_args()

    shader = os.path.join(args.liltoon, "lts.shader")
    if not os.path.exists(shader):
        print(f"找不到 {shader}", file=sys.stderr)
        return 1

    # 2026-10-28 复查：此前只统计 lts.shader，漏掉了 gem / ref / fakeshadow / overlay
    # 以及毛发线的特有属性。改为遍历**全部** shader，用 set 自动去重（`_Pre*` 这类
    # 在多个变体里重复出现的属性只会算一次）。
    props_set = set()
    shader_dir = os.path.dirname(shader)
    for name in os.listdir(shader_dir):
        if name.endswith(".shader"):
            props_set |= set(extract_properties(os.path.join(shader_dir, name)))
    props = sorted(props_set)

    uniforms_list = extract_uniforms(UNIFORMS)
    uniforms = set(uniforms_list)
    matrix_text = open(MATRIX, encoding="utf-8").read()
    mapped = extract_mapped(matrix_text)

    auto = auto_match(props, uniforms)
    registered = [p for p in props if p in mapped]
    auto_only = [p for p in props if p not in mapped and p in auto]
    aligned = [p for p in props if p in mapped or p in auto]
    missing = [p for p in props if p not in mapped and p not in auto]

    print(f"lilToon 属性      : {len(props)}")
    print(f"本项目 uniform    : {len(uniforms_list)}")
    print(f"已对齐            : {len(aligned)}  (矩阵登记 {len(registered)} + 自动匹配 {len(auto_only)})")
    print(f"未对齐            : {len(missing)}")
    print()

    if auto_only:
        print(f"== 已实现但矩阵未登记（{len(auto_only)} 项，建议补进已对齐表）==")
        for name in auto_only:
            print(f"  {name:<34} -> {auto[name]}")
        print()

    if missing:
        print("== 未对齐（按前缀分组）==")
        for key, items in sorted(group_prefix(missing).items(), key=lambda kv: -len(kv[1])):
            print(f"  {key:<18} {len(items):3d}  " + ", ".join(x.lstrip("_") for x in items))
        print()

    unregistered = [p for p in aligned if p not in props]
    if unregistered:
        print("== 矩阵里登记了、但 lilToon 主 shader 里没有 ==")
        for name in unregistered[:10]:
            print("  " + name)
        print()

    print(f"提示：uniform 总数 {len(uniforms)}，其中项目特有（小写开头）"
          f" {sum(1 for u in uniforms if not u.startswith('_'))} 个")

    if args.write:
        outline_uniforms = extract_uniforms(OUTLINE) if os.path.exists(OUTLINE) else []
        sampler_n = len(re.findall(r"^\s*uniform\s+sampler", open(UNIFORMS, encoding="utf-8").read(), re.M))
        total = len(uniforms_list) + len(outline_uniforms)
        param_line = (
            f"- 本插件参数：{total} 项（主材质 {len(uniforms_list)} + 描边 {len(outline_uniforms)}，"
            f"含 {sampler_n} 个 sampler；去重 sampler 后 {total - sampler_n} 项）\n"
        )
        updated = _rewrite(matrix_text, aligned, missing, props, auto_only, auto, param_line)
        open(MATRIX, "w", encoding="utf-8").writelines(updated)
        print(f"已写回：已对齐 {len(aligned)} / 未对齐 {len(missing)}，"
              f"新增 {len(auto_only)} 行自动匹配登记")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
