#!/bin/bash
# Claude Code のプラグイン／マーケットプレースをマシン共通で揃える。
# プラグイン本体は chezmoi 管理外（キャッシュが重い／installed_plugins.json に
# 絶対パスが埋め込まれるため）。代わりに新端末では claude CLI で冪等に入れる。
#
# 配列を書き換えるとこのファイルのハッシュが変わり、chezmoi apply 時に
# run_onchange により自動で再実行される。

set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  # claude 未インストール環境（chezmoi apply の方が先に走った devcontainer など）は何もしない。
  exit 0
fi

# GitHub repo 形式
MARKETPLACES=(
  "anthropics/claude-plugins-official"
  "anthropics/skills"
)

# plugin@marketplace 形式
PLUGINS=(
  "superpowers@claude-plugins-official"
  "document-skills@anthropic-agent-skills"
)

KNOWN_MP="$HOME/.claude/plugins/known_marketplaces.json"
INSTALLED_PL="$HOME/.claude/plugins/installed_plugins.json"

for src in "${MARKETPLACES[@]}"; do
  if [ -f "$KNOWN_MP" ] && grep -qF "\"$src\"" "$KNOWN_MP"; then
    continue
  fi
  echo "adding marketplace: $src"
  claude plugin marketplace add "$src"
done

for p in "${PLUGINS[@]}"; do
  if [ -f "$INSTALLED_PL" ] && grep -qF "\"$p\":" "$INSTALLED_PL"; then
    continue
  fi
  echo "installing plugin: $p"
  claude plugin install "$p"
done
