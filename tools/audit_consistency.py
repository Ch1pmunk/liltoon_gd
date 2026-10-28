#!/usr/bin/env python3
"""自审：矩阵 / §9 / 预设 / 代码 四者的一致性。

冒烟只保证「每个 uniform 有描述且进了预设」，但保证不了：
  - 矩阵里登记的 uniform 是否真的存在（文档写了代码没有）
  - 代码里有的参数是否都在矩阵或 §9 里登记过（代码有文档没有）
  - §9 里点名的参数是否还存在（改名后文档残留）

用法：
    python tools/audit_consistency.py
"""
from __future__ import annotations

import os
import re
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNIFORMS = os.path.join(PROJECT, "addons", "liltoon_gd", "shaders", "include", "uniforms.gdshaderinc")
OUTLINE = os.path.join(PROJECT, "addons", "liltoon_gd", "shaders", "include", "outline_common.gdshaderinc")
EXTRA_DIR = os.path.join(PROJECT, "addons", "liltoon_gd", "shaders", "extra")
PRESET = os.path.join(PROJECT, "addons", "liltoon_gd", "editor", "preset_library.gd")
MATRIX = os.path.join(PROJECT, "docs", "参数对齐矩阵.md")
PRINCIPLES = os.path.join(PROJECT, "addons", "liltoon_gd", "DEVELOPMENT_PRINCIPLES.md")

UNIFORM_RE = re.compile(r"^\s*uniform\s+\w+\s+([A-Za-z0-9_]+)", re.MULTILINE)
SAMPLER_RE = re.compile(r"^\s*uniform\s+sampler\w+\s+([A-Za-z0-9_]+)", re.MULTILINE)
TICK_RE = re.compile(r"`([a-z][a-z0-9_]{2,})`")
ROW_RE = re.compile(r"^\|\s*`(_[A-Za-z0-9_]+)`\s*\|\s*(.+?)\s*\|", re.MULTILINE)


def read(path: str) -> str:
    return open(path, encoding="utf-8", errors="replace").read()


def main() -> int:
    code = set(UNIFORM_RE.findall(read(UNIFORMS)))
    code |= set(UNIFORM_RE.findall(read(OUTLINE)))
    for extra_file in os.listdir(EXTRA_DIR):
        if extra_file.endswith(".gdshader"):
            code |= set(UNIFORM_RE.findall(read(os.path.join(EXTRA_DIR, extra_file))))
    # 字典键 "k": v 与数组元素 "k", 都算已登记
    preset = set(re.findall(r'"([A-Za-z0-9_]+)"\s*[,:]', read(PRESET)))
    _full_matrix = read(MATRIX)
    # 只取「已对齐」段：后面的「未对齐」章节里也有表格，那些是**未实现**的清单，
    # 当成已登记会误报（2026-10-28：毛发 6 项遗漏就是这样被误判的）。
    _m_start = _full_matrix.find("## 已对齐")
    _m_end = _full_matrix.find("## 未对齐")
    matrix = _full_matrix[_m_start:_m_end] if 0 <= _m_start < _m_end else _full_matrix
    principles = read(PRINCIPLES)

    problems = 0

    # 1. 矩阵里登记的目标参数是否真实存在
    ghost = []
    for prop, cell in ROW_RE.findall(matrix):
        if "切换" in cell:      # 例如 _AlphaToMask：切 shader 实现，本就没有同名 uniform
            continue
        names = [t for t in TICK_RE.findall(cell)]
        real = [n for n in names if n in code]
        if not real:
            ghost.append((prop, cell[:60]))
    if ghost:
        problems += len(ghost)
        print(f"== 矩阵登记了、但代码里找不到（{len(ghost)}）==")
        for prop, cell in ghost[:20]:
            print(f"  {prop:<34} {cell}")
        print()

    # 2. 代码里有的参数，矩阵和 §9 都没提
    # 「代码有 → 矩阵无」这个方向要用**全文**：未对齐章节里点了名的属性也算已覆盖，
    # 只有「矩阵有 → 代码无」才需要限定在已对齐段。
    matrix_ticks = set(TICK_RE.findall(_full_matrix))
    principle_ticks = set(TICK_RE.findall(principles))
    # 辅助参数不单列：启用开关、UV 拆分项、运行时参数
    AUX = [
        re.compile(r"^use_"),                 # 启用开关，矩阵按 lilToon 属性级登记
        re.compile(r"_uv_(rotate|scroll)$"),  # ScrollRotate 的拆分项
        re.compile(r"^fur_layer$"),           # 运行时层索引（INSTANCE_CUSTOM）
        re.compile(r"^matcap_3rd_"),          # 第三槽是项目扩展，原版无 _MatCap3rd*
        re.compile(r"_parallax_texture$"),    # 视差高度贴图，替代原版借 EmissionMap 的做法
    ]
    undocumented = sorted(
        n for n in code
        if n not in matrix_ticks and n not in principle_ticks
        and not any(p.search(n) for p in AUX)
    )
    if undocumented:
        problems += len(undocumented)
        print(f"== 代码有、矩阵与 §9 都未提及（{len(undocumented)}）==")
        for name in undocumented:
            print(f"  {name}")
        print()

    # 3. 未登记的代码参数里，哪些能反查到 lilToon 属性（= 真漏登记）
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        from gen_alignment_matrix import DEFAULT_LILTOON, extract_properties, to_snake
        props = extract_properties(os.path.join(DEFAULT_LILTOON, "lts.shader"))
        reverse = {to_snake(p): p for p in props}
        real_miss = [(reverse[n], n) for n in undocumented if n in reverse]
        if real_miss:
            print(f"== 真漏登记：有对应 lilToon 属性但矩阵没写（{len(real_miss)}）==")
            for prop, name in real_miss:
                print(f"  {prop:<34} -> {name}")
            print()
    except Exception as exc:  # 缺 lilToon 源码时跳过
        print(f"(反查跳过：{exc})")

    # 4. 预设覆盖：sampler 按原则不进 BASE，只查标量/布尔/枚举
    samplers = set(SAMPLER_RE.findall(read(UNIFORMS))) | set(SAMPLER_RE.findall(read(OUTLINE)))
    for extra_file in os.listdir(EXTRA_DIR):
        if extra_file.endswith(".gdshader"):
            samplers |= set(SAMPLER_RE.findall(read(os.path.join(EXTRA_DIR, extra_file))))
    # fur_layer 由 MultiMesh 的 INSTANCE_CUSTOM 逐实例传入，不进预设
    # 假阴影/折射/宝石是独立 shader，参数不进主材质预设
    RUNTIME_ONLY = {"fur_layer", "invisible", "shadow_color", "shadow_texture", "shadow_uv_scale",
                    "fake_shadow_vector", "light_direction",
                    "refraction_screen_texture", "gem_screen_texture",
                    "fur_noise_mask_uv_scale", "fur_touch_position", "fur_touch_range"}
    missing_preset = sorted(n for n in code - samplers - RUNTIME_ONLY if n not in preset)
    if missing_preset:
        problems += len(missing_preset)
        print(f"== 未进预设 BASE（{len(missing_preset)}）==")
        for name in missing_preset:
            print(f"  {name}")
        print()

    print(f"代码参数 {len(code)} / 预设键 {len(preset)} / 矩阵登记属性 {len(ROW_RE.findall(matrix))}")
    print(f"问题合计 {problems}")
    return 0 if problems == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
