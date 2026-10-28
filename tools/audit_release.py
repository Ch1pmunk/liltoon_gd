#!/usr/bin/env python3
"""发布前静态审计：资源路径、类名、文档死链、未完成标记。

只做静态检查，不启动 Godot、不碰 GPU。渲染相关的问题查不出来，这里也不假装能查。

用法：
    python tools/audit_release.py
    python tools/audit_release.py --verbose
"""
from __future__ import annotations

import os
import re
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN = os.path.join(PROJECT, "addons", "liltoon_gd")

RES_PATH = re.compile(r'(?:preload|load)\(\s*"(res://[^"]+)"')
EXT_RES = re.compile(r'\[ext_resource[^\]]*path="(res://[^"]+)"')
CLASS_NAME = re.compile(r"^class_name\s+([A-Za-z0-9_]+)", re.MULTILINE)
# 不含 TEMP：`$env:TEMP` 之类会误命中
TODO = re.compile(r"\b(TODO|FIXME|XXX|HACK)\b", re.IGNORECASE)
# 第三方工具与自引用不参与审计
EXCLUDE_PARTS = {"godot_mcp", "audit_release.py"}
MD_LINK = re.compile(r"`((?:docs|addons|tools)/[A-Za-z0-9_./\u4e00-\u9fff-]+\.(?:md|gd|py|ps1|tscn|gdshader))`")


def read(path: str) -> str:
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def walk(*suffixes: str):
    for dirpath, _, files in os.walk(PROJECT):
        parts = set(dirpath.replace(os.sep, "/").split("/"))
        if ".git" in parts or "evidence" in parts or (parts & EXCLUDE_PARTS):
            continue
        for name in files:
            if any(p in name for p in EXCLUDE_PARTS):
                continue
            if name.endswith(suffixes):
                yield os.path.join(dirpath, name)


def main() -> int:
    verbose = "--verbose" in sys.argv
    problems = 0

    # 1. res:// 路径存在性
    missing = {}
    for path in list(walk(".gd", ".tscn", ".gdshader", ".gdshaderinc", ".tres")):
        text = read(path)
        refs = set(RES_PATH.findall(text)) | set(EXT_RES.findall(text))
        for ref in refs:
            target = os.path.join(PROJECT, ref[len("res://"):].replace("/", os.sep))
            if not os.path.exists(target):
                missing.setdefault(os.path.relpath(path, PROJECT), []).append(ref)
    if missing:
        problems += sum(len(v) for v in missing.values())
        print(f"== 引用了不存在的 res:// 路径（{len(missing)} 个文件）==")
        for src, refs in sorted(missing.items()):
            for ref in refs:
                print(f"  {src}\n    -> {ref}")
        print()

    # 2. class_name 唯一性
    seen = {}
    dup = []
    for path in walk(".gd"):
        for name in CLASS_NAME.findall(read(path)):
            rel = os.path.relpath(path, PROJECT)
            if name in seen:
                dup.append((name, seen[name], rel))
            else:
                seen[name] = rel
    if dup:
        problems += len(dup)
        print(f"== 重复的 class_name（{len(dup)}）==")
        for name, a, b in dup:
            print(f"  {name}: {a} / {b}")
        print()
    if verbose:
        print(f"class_name 共 {len(seen)} 个，无重名" if not dup else "")

    # 3. plugin.cfg 的入口脚本
    cfg = os.path.join(PLUGIN, "plugin.cfg")
    if os.path.exists(cfg):
        m = re.search(r'^script="([^"]+)"', read(cfg), re.MULTILINE)
        if m:
            script = os.path.join(PLUGIN, m.group(1))
            if not os.path.exists(script):
                problems += 1
                print(f"== plugin.cfg 指向的入口脚本不存在：{m.group(1)} ==\n")

    # 4. 文档里的文件引用
    dead = {}
    for path in list(walk(".md")):
        for ref in MD_LINK.findall(read(path)):
            if not os.path.exists(os.path.join(PROJECT, ref.replace("/", os.sep))):
                dead.setdefault(os.path.relpath(path, PROJECT), set()).add(ref)
    if dead:
        problems += sum(len(v) for v in dead.values())
        print(f"== 文档里引用了不存在的文件（{len(dead)} 个文档）==")
        for src, refs in sorted(dead.items()):
            for ref in sorted(refs):
                print(f"  {src}\n    -> {ref}")
        print()

    # 5. 未完成标记
    todos = {}
    for path in walk(".gd", ".gdshader", ".gdshaderinc", ".py", ".ps1"):
        for i, line in enumerate(read(path).splitlines(), 1):
            if TODO.search(line):
                todos.setdefault(os.path.relpath(path, PROJECT), []).append((i, line.strip()[:100]))
    if todos:
        problems += sum(len(v) for v in todos.values())
        print(f"== 未完成标记（{sum(len(v) for v in todos.values())} 处）==")
        for src, items in sorted(todos.items()):
            for lineno, line in items:
                print(f"  {src}:{lineno}: {line}")
        print()

    print(f"问题合计：{problems}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
