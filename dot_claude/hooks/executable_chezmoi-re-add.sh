#!/bin/bash
# PostToolUse hook: Edit/Write で ~/.claude/ 配下のファイルが変更されたら chezmoi re-add
# stdin に tool input の JSON が渡される

# chezmoi が無ければ何もしない
command -v chezmoi &>/dev/null || exit 0

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# file_path が ~/.claude/ または ~/.agents/ 配下かチェック
# （~/.agents/skills は Claude Code / Codex 共有スキルの正本。~/.claude/skills からはシンボリックリンク）
claude_dir="$HOME/.claude"
agents_dir="$HOME/.agents"
if [[ "$file_path" == "$claude_dir"/* || "$file_path" == "$agents_dir"/* ]]; then
    chezmoi re-add 2>/dev/null || true
fi

exit 0
