#!/usr/bin/env python3
"""フロントマターに tags フィールドを設定する (機械的操作のみ)。

使い方:
  scripts/update_tags.py <file> tag1 tag2 tag3 ...

挙動:
- tags がすでにある場合は、指定されたタグ集合で置き換える
  (完全上書き。追加したい場合は呼び出し側でマージしてから渡すこと)
- tags がない場合は、フロントマターの末尾に追加する
- フロントマターがない場合はエラー (先に fix_created.py を実行しておくこと)

出力形式 (Obsidian 互換):
  tags:
    - tag1
    - tag2
"""
from __future__ import annotations
import argparse, re, sys
from pathlib import Path

FM_RE = re.compile(r"\A(---\r?\n)(.*?)(\r?\n---\r?\n?)", re.DOTALL)
# tags ブロック (YAMLのリスト記法、1段) を検出
TAGS_BLOCK_RE = re.compile(
    r"^tags\s*:[^\n]*(?:\n[ \t]+-[^\n]*)*\n?",
    re.MULTILINE,
)


def format_tags(tags: list[str]) -> str:
    lines = ["tags:"]
    for t in tags:
        lines.append(f"  - {t}")
    return "\n".join(lines) + "\n"


def update_one(path: Path, tags: list[str]) -> str:
    original = path.read_text(encoding="utf-8")
    m = FM_RE.match(original)
    if m is None:
        raise SystemExit(f"ERROR: {path} にフロントマターがありません。先に fix_created.py を実行してください。")

    fm_open, fm_body, fm_close = m.group(1), m.group(2), m.group(3)
    rest = original[m.end():]

    new_tags_block = format_tags(tags).rstrip("\n")
    if TAGS_BLOCK_RE.search(fm_body):
        new_body = TAGS_BLOCK_RE.sub(new_tags_block + "\n", fm_body, count=1).rstrip("\n")
        action = "REPLACED"
    else:
        new_body = fm_body.rstrip("\r\n") + "\n" + new_tags_block
        action = "ADDED"

    path.write_text(fm_open + new_body + fm_close + rest, encoding="utf-8")
    return action


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("tags", nargs="+")
    args = ap.parse_args()
    # 重複を除去しつつ順序保持
    seen: set[str] = set()
    tags: list[str] = []
    for t in args.tags:
        t = t.strip()
        if t and t not in seen:
            seen.add(t)
            tags.append(t)
    action = update_one(Path(args.file), tags)
    print(f"{action}\t{args.file}\t{','.join(tags)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
