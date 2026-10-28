#!/usr/bin/env python3
"""校验并重建 CodeBuddy 会话索引（index.json）。

背景：CodeBuddy 的对话正文按消息一文件存放在
    %LOCALAPPDATA%\\CodeBuddyExtension\\Data\\<userId>\\CodeBuddyIDE\\<userId>\\history\\<workspace>\\<conversation>\\messages\\*.json
同级 index.json 只记录“哪些消息属于哪一轮请求”的顺序表。若进程被强杀或系统蓝屏，
index.json 可能被清成全 0（表现为：会话只剩最近几轮、标题异常、上文无法加载），
而 messages/ 里的正文通常仍然完好——此时可用本脚本按正文重建索引。

用法：
    python tools/rebuild_chat_index.py                    # 只体检，不改任何文件
    python tools/rebuild_chat_index.py --apply            # 备份并重写有问题的 index.json
    python tools/rebuild_chat_index.py --backup D:\bak    # 把整个 history 目录复制到 D:\bak

注意：--apply 之前必须完全退出 CodeBuddy，否则运行中的客户端会用内存索引覆盖写入。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime


def history_root() -> str:
    base = os.environ.get("LOCALAPPDATA", "")
    if not base:
        sys.exit("找不到 LOCALAPPDATA 环境变量，无法定位 CodeBuddy 数据目录。")
    return os.path.join(base, "CodeBuddyExtension", "Data")


def find_conversations(root: str) -> list[str]:
    """枚举所有 history/<workspace>/<conversation> 目录（层级因版本而异，用名字定位）。"""
    found: list[str] = []
    for dirpath, dirnames, _ in os.walk(root):
        if os.path.basename(dirpath) != "history":
            continue
        dirnames[:] = []
        for workspace in _subdirs(dirpath):
            for conversation in _subdirs(workspace):
                if os.path.isdir(os.path.join(conversation, "messages")):
                    found.append(conversation)
    return found


def _subdirs(path: str) -> list[str]:
    try:
        names = os.listdir(path)
    except OSError:
        return []
    return [os.path.join(path, name) for name in names
            if os.path.isdir(os.path.join(path, name))]


def read_messages(msg_dir: str) -> tuple[list[dict], int]:
    """读取消息目录，返回按时间排序的条目；第二项是解析失败的数量。"""
    entries: list[dict] = []
    skipped = 0
    for name in sorted(os.listdir(msg_dir)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(msg_dir, name)
        try:
            with open(path, "r", encoding="utf-8") as handle:
                raw = json.load(handle)
        except (OSError, ValueError):
            skipped += 1
            continue
        entries.append({
            "id": name[:-5],
            "role": raw.get("role", "assistant"),
            "createdAt": raw.get("createdAt") or "",
        })
    entries.sort(key=lambda item: item["createdAt"])
    return entries, skipped


def read_index(index_path: str) -> dict | None:
    try:
        with open(index_path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def iso_to_ms(text: str) -> int:
    try:
        return int(datetime.strptime(text[:19], "%Y-%m-%dT%H:%M:%S").timestamp() * 1000)
    except ValueError:
        return 0


def build_index(entries: list[dict]) -> dict:
    """每条 user 消息开启一轮 request，后续 assistant/tool 消息归入该轮。"""
    index = {"messages": [], "requests": []}
    block: list[dict] = []

    def flush() -> None:
        if not block:
            return
        ids = [item["id"] for item in block]
        index["requests"].append({
            "id": hashlib.md5("|".join(ids).encode("utf-8")).hexdigest(),
            "type": "craft",
            "messages": ids,
            "state": "complete",
            "startedAt": iso_to_ms(block[0]["createdAt"]),
        })
        block.clear()

    for entry in entries:
        if entry["role"] == "user":
            flush()
        block.append(entry)
        index["messages"].append({
            "id": entry["id"],
            "type": "text",
            "role": entry["role"],
            "isComplete": True,
        })
    flush()
    return index


def report(conversation: str) -> tuple[bool, int, int]:
    """返回 (是否需要重建, 正文条数, 索引条数)。"""
    msg_dir = os.path.join(conversation, "messages")
    entries, skipped = read_messages(msg_dir)
    index_path = os.path.join(conversation, "index.json")
    current = read_index(index_path)
    if not entries:
        print(f"[空] {conversation}")
        return False, 0, 0
    covered = 0
    if current:
        ids = {item.get("id") for item in current.get("messages", [])}
        covered = sum(1 for entry in entries if entry["id"] in ids)
    healthy = bool(current) and covered >= len(entries) * 0.95
    tag = "正常" if healthy else "异常"
    print(f"[{tag}] {conversation}")
    print(f"        正文 {len(entries)} 条（解析失败 {skipped}），索引覆盖 {covered} 条")
    return (not healthy), len(entries), covered


def rebuild(conversation: str) -> None:
    msg_dir = os.path.join(conversation, "messages")
    entries, _ = read_messages(msg_dir)
    index = build_index(entries)
    index_path = os.path.join(conversation, "index.json")
    if os.path.exists(index_path):
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(index_path, f"{index_path}.bak-{stamp}")
    with open(index_path, "w", encoding="utf-8") as handle:
        json.dump(index, handle, ensure_ascii=False)
    print(f"        已重建：{len(index['messages'])} 条 / {len(index['requests'])} 轮")


def main() -> None:
    parser = argparse.ArgumentParser(description="校验并重建 CodeBuddy 会话索引")
    parser.add_argument("--apply", action="store_true", help="备份并重写异常的 index.json")
    parser.add_argument("--backup", metavar="DIR", help="把 history 目录整体复制到 DIR")
    args = parser.parse_args()

    root = history_root()
    if not os.path.isdir(root):
        sys.exit(f"数据目录不存在：{root}")

    if args.backup:
        dest = os.path.join(args.backup, "CodeBuddyHistory-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
        shutil.copytree(root, dest)
        print(f"已备份到 {dest}")
        return

    conversations = find_conversations(root)
    if not conversations:
        sys.exit("没有找到任何会话目录。")

    broken: list[str] = []
    for conversation in conversations:
        needs_fix, _, _ = report(conversation)
        if needs_fix:
            broken.append(conversation)

    print()
    if not broken:
        print(f"共 {len(conversations)} 个会话，索引全部正常。")
        return

    print(f"共 {len(conversations)} 个会话，其中 {len(broken)} 个索引异常。")
    if not args.apply:
        print("加 --apply 执行重建（执行前请完全退出 CodeBuddy）。")
        return
    for conversation in broken:
        rebuild(conversation)
    print("完成。重新打开 CodeBuddy 即可加载重建后的对话。")


if __name__ == "__main__":
    main()
