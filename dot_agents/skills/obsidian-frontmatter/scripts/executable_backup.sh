#!/usr/bin/env bash
# obsidian-frontmatter: 作業前のバックアップコミット
# 使い方: scripts/backup.sh
# 出力: 最新コミットのハッシュ (後段のverifyでベースとして使う)
set -euo pipefail

VAULT="/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian"
cd "$VAULT"

# main ブランチ確認
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "main" ]; then
  echo "ERROR: 現在のブランチが main ではありません (現在: $branch)" >&2
  exit 1
fi

# 未コミット変更があればまず退避コミット
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  git add -A
  git commit -m "chore: backup before frontmatter maintenance

obsidian-frontmatter スキルによる自動バックアップ" >/dev/null
  echo "BACKUP_COMMIT=$(git rev-parse HEAD)"
else
  echo "BACKUP_COMMIT=$(git rev-parse HEAD)"
  echo "(working tree clean — 新規コミットなし)"
fi
