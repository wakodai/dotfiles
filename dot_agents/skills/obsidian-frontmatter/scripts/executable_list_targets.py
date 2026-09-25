#!/usr/bin/env python3
"""処理対象の .md ファイルを分類して列挙する。

カテゴリ:
  NO_FM       : フロントマターなし (created も tags もなし)
  NEEDS_RENAME: created_at 等の別名キーがあり、created がない
  NO_TAGS     : created は揃っているが tags がない
  OK          : created も tags も既にある (処理不要)

使い方:
  scripts/list_targets.py                    # 全ファイル分類して件数表示
  scripts/list_targets.py --category NO_FM   # 特定カテゴリのパスだけ出力
  scripts/list_targets.py --limit 20 -c NO_FM  # 先頭20件のみ
"""
from __future__ import annotations
import argparse, os, re, sys
from pathlib import Path

VAULT = Path("/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian")
EXCLUDE_DIRS = {".git", ".obsidian", ".claude", "_templates", "_Pict"}
CREATED_ALIASES = ("created_at", "creation_date", "date_created")

FM_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n?", re.DOTALL)


def parse_fm_keys(text: str) -> set[str] | None:
    """フロントマターから最上位キーだけ抜き出す。フロントマターがなければ None。"""
    m = FM_RE.match(text)
    if not m:
        return None
    keys: set[str] = set()
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*)\s*:", line)
        if km:
            keys.add(km.group(1))
    return keys


def categorize(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return "ERROR"
    keys = parse_fm_keys(text)
    if keys is None:
        return "NO_FM"
    has_created = "created" in keys
    has_alias = any(a in keys for a in CREATED_ALIASES)
    has_tags = "tags" in keys
    if not has_created and has_alias:
        return "NEEDS_RENAME"
    if not has_created and not has_alias:
        return "NO_FM"  # フロントマターはあるが created 系が欠落 — NO_FM扱いで created を追加
    if not has_tags:
        return "NO_TAGS"
    return "OK"


def iter_targets() -> list[Path]:
    files: list[Path] = []
    for root, dirs, names in os.walk(VAULT):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for n in names:
            if n.endswith(".md"):
                files.append(Path(root) / n)
    return files


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("-c", "--category", choices=["NO_FM", "NEEDS_RENAME", "NO_TAGS", "OK"])
    ap.add_argument("-l", "--limit", type=int, default=0)
    ap.add_argument("--under", help="このサブディレクトリ配下に限定 (vault からの相対パス)")
    args = ap.parse_args()

    targets = iter_targets()
    if args.under:
        base = (VAULT / args.under).resolve()
        targets = [p for p in targets if str(p.resolve()).startswith(str(base))]

    if not args.category:
        buckets: dict[str, int] = {}
        for p in targets:
            buckets[categorize(p)] = buckets.get(categorize(p), 0) + 1
        for k in ("NO_FM", "NEEDS_RENAME", "NO_TAGS", "OK", "ERROR"):
            print(f"{buckets.get(k, 0):5}  {k}")
        print(f"{sum(buckets.values()):5}  TOTAL")
        return 0

    out = [p for p in targets if categorize(p) == args.category]
    if args.limit:
        out = out[: args.limit]
    for p in out:
        print(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
