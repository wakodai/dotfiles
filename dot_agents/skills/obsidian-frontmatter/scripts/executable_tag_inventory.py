#!/usr/bin/env python3
"""現在使われているタグを集計する (名寄せ・taxonomy メンテの材料)。

使い方:
  scripts/tag_inventory.py         # 使用頻度順に表示
  scripts/tag_inventory.py --json  # JSON 形式で出力
"""
from __future__ import annotations
import argparse, json, os, re, sys
from collections import Counter
from pathlib import Path

VAULT = Path("/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian")
EXCLUDE_DIRS = {".git", ".obsidian", ".claude", "_templates", "_Pict"}
FM_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n?", re.DOTALL)
TAGS_BLOCK_RE = re.compile(
    r"^tags\s*:([^\n]*)((?:\n[ \t]+-[^\n]*)*)",
    re.MULTILINE,
)


def extract_tags(fm_body: str) -> list[str]:
    m = TAGS_BLOCK_RE.search(fm_body)
    if not m:
        return []
    out: list[str] = []
    inline = m.group(1).strip()
    if inline.startswith("["):
        # `tags: [a, b]` 形式
        inner = inline.strip("[]")
        for t in inner.split(","):
            t = t.strip().strip("'\"")
            if t:
                out.append(t)
    elif inline:
        # `tags: a b` (スペース区切り、稀)
        for t in inline.split():
            if t:
                out.append(t.strip("'\""))
    for line in m.group(2).splitlines():
        line = line.strip()
        if line.startswith("-"):
            t = line[1:].strip().strip("'\"")
            if t:
                out.append(t)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    counter: Counter[str] = Counter()
    for root, dirs, names in os.walk(VAULT):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for n in names:
            if not n.endswith(".md"):
                continue
            p = Path(root) / n
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            m = FM_RE.match(text)
            if not m:
                continue
            for t in extract_tags(m.group(1)):
                counter[t] += 1

    if args.json:
        print(json.dumps(dict(counter.most_common()), ensure_ascii=False, indent=2))
    else:
        for t, c in counter.most_common():
            print(f"{c:5}  {t}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
