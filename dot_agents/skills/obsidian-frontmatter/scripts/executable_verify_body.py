#!/usr/bin/env python3
"""対象ファイルについて、フロントマター以外の本文がバックアップコミットから変わっていないことを検証する。

使い方:
  scripts/verify_body.py <backup_commit>                     # 変更のあった全 .md を検証
  scripts/verify_body.py <backup_commit> path1.md path2.md   # 指定ファイルのみ検証

戻り値:
  0: すべて OK
  1: 本文に差分を検出 (致命的 — ロールバックを検討)
"""
from __future__ import annotations
import argparse, re, subprocess, sys
from pathlib import Path

VAULT = Path("/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian")
FM_RE = re.compile(r"\A---\r?\n.*?\r?\n---(?:\r?\n)*", re.DOTALL)


def strip_fm(text: str) -> str:
    """フロントマター部分を除去し、先頭空行を正規化する。
    FM 付与時に本文先頭の空行が増減する (片側だけで) と誤検知するため、両側とも
    lstrip で比較する。"""
    return FM_RE.sub("", text, count=1).lstrip("\r\n")


def git_show(commit: str, relpath: str) -> str | None:
    try:
        return subprocess.check_output(
            ["git", "-C", str(VAULT), "show", f"{commit}:{relpath}"],
            stderr=subprocess.DEVNULL,
        ).decode("utf-8", errors="replace")
    except subprocess.CalledProcessError:
        return None  # 当時存在しなかったファイル


def changed_files(commit: str) -> list[str]:
    # -z で NULL 区切り & core.quotePath=false で UTF-8 そのまま出力
    out = subprocess.check_output(
        ["git", "-c", "core.quotePath=false", "-C", str(VAULT),
         "diff", "--name-only", "-z", commit, "--", "*.md"],
        text=True,
    )
    return [p for p in out.split("\0") if p.endswith(".md")]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("commit")
    ap.add_argument("paths", nargs="*")
    args = ap.parse_args()

    if args.paths:
        rels = [str(Path(p).resolve().relative_to(VAULT.resolve())) for p in args.paths]
    else:
        rels = changed_files(args.commit)

    bad: list[str] = []
    missing: list[str] = []
    for rel in rels:
        before = git_show(args.commit, rel)
        if before is None:
            missing.append(rel)
            continue
        after_path = VAULT / rel
        if not after_path.exists():
            missing.append(rel)
            continue
        after = after_path.read_text(encoding="utf-8", errors="replace")
        if strip_fm(before) != strip_fm(after):
            bad.append(rel)

    print(f"checked: {len(rels)} files")
    print(f"new/removed: {len(missing)}")
    print(f"body-diff detected: {len(bad)}")
    for r in bad:
        print(f"  BODY CHANGED: {r}")
    for r in missing:
        print(f"  NEW/REMOVED : {r}")

    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
