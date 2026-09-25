#!/usr/bin/env python3
"""フロントマターの created フィールドを整備する (機械的変換のみ)。

変換ルール:
- created がすでにある場合: 何もしない
- created_at / creation_date / date_created のいずれかがある場合: キー名を created に変更
  (値はそのまま)
- 上記のどれもない場合: ファイルの birth time (stat -f %B) を使って
  `created: YYYY-MM-DD HH:mm` を追加
  - フロントマターがない場合は新規に `---\\n created: ...\\n---\\n` を先頭に付与
  - フロントマターがあるが created 系がない場合は、フロントマターの末尾に追加

tags その他のフィールドには一切触らない。
フロントマター外の本文も一切変更しない。

使い方:
  scripts/fix_created.py path1.md path2.md ...          # 指定ファイルを修正
  scripts/fix_created.py --stdin < file_list.txt        # stdin からパスを読む
  scripts/fix_created.py --dry-run path.md              # 変更内容だけ表示
"""
from __future__ import annotations
import argparse, os, re, subprocess, sys
from datetime import datetime
from pathlib import Path

CREATED_ALIASES = ("created_at", "creation_date", "date_created")
FM_RE = re.compile(r"\A(---\r?\n)(.*?)(\r?\n---\r?\n?)", re.DOTALL)


def birth_time(path: Path) -> str:
    """macOS の stat で birth time を取得。取れない場合は mtime にフォールバック。"""
    try:
        out = subprocess.check_output(
            ["stat", "-f", "%SB", "-t", "%Y-%m-%d %H:%M", str(path)],
            text=True,
        ).strip()
        if out and out != "0":
            # バリデーション: ちゃんとパースできるか確認
            datetime.strptime(out, "%Y-%m-%d %H:%M")
            return out
    except (subprocess.CalledProcessError, ValueError):
        pass
    # フォールバック: mtime
    mtime = path.stat().st_mtime
    return datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")


def fix_one(path: Path) -> tuple[bool, str]:
    """戻り値: (変更したか, 説明文字列)"""
    try:
        original = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as e:
        return False, f"READ_ERROR: {e}"

    m = FM_RE.match(original)
    if m is None:
        # フロントマターなし → 新規作成
        ts = birth_time(path)
        new = f"---\ncreated: {ts}\n---\n\n{original}"
        path.write_text(new, encoding="utf-8")
        return True, f"ADDED_FM (created: {ts})"

    fm_open, fm_body, fm_close = m.group(1), m.group(2), m.group(3)
    rest = original[m.end():]

    # created がすでにある?
    if re.search(r"^created\s*:", fm_body, re.MULTILINE):
        return False, "OK (created already present)"

    # alias キーを探してリネーム
    for alias in CREATED_ALIASES:
        alias_re = re.compile(rf"^(\s*){alias}(\s*:)", re.MULTILINE)
        if alias_re.search(fm_body):
            new_body = alias_re.sub(r"\1created\2", fm_body, count=1)
            new = fm_open + new_body + fm_close + rest
            path.write_text(new, encoding="utf-8")
            return True, f"RENAMED {alias} -> created"

    # フロントマターはあるが created 系がまったくない → birth time を追加
    ts = birth_time(path)
    # 末尾に改行があるかどうかを判定して追加
    trimmed = fm_body.rstrip("\r\n")
    new_body = trimmed + f"\ncreated: {ts}"
    new = fm_open + new_body + fm_close + rest
    path.write_text(new, encoding="utf-8")
    return True, f"ADDED created: {ts}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--stdin", action="store_true", help="stdin からパスを1行ずつ読む")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    targets: list[Path] = [Path(p) for p in args.paths]
    if args.stdin:
        targets.extend(Path(l.rstrip("\n")) for l in sys.stdin if l.strip())

    if not targets:
        ap.error("ファイルパスが指定されていません")

    changed = 0
    for p in targets:
        if not p.exists():
            print(f"[skip] {p}: not found", file=sys.stderr)
            continue
        if args.dry_run:
            # dry-run: 読み取りだけ
            original = p.read_text(encoding="utf-8", errors="replace")
            m = FM_RE.match(original)
            if m is None:
                print(f"[would add FM] {p} (created: {birth_time(p)})")
            else:
                fm_body = m.group(2)
                if re.search(r"^created\s*:", fm_body, re.MULTILINE):
                    print(f"[skip] {p}: already has created")
                else:
                    for alias in CREATED_ALIASES:
                        if re.search(rf"^\s*{alias}\s*:", fm_body, re.MULTILINE):
                            print(f"[would rename {alias}] {p}")
                            break
                    else:
                        print(f"[would add created] {p} ({birth_time(p)})")
        else:
            did, msg = fix_one(p)
            if did:
                changed += 1
            print(f"{msg}\t{p}")

    if not args.dry_run:
        print(f"\n{changed} / {len(targets)} files changed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
