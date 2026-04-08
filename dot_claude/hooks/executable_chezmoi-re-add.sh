#!/bin/bash
# PostToolUse hook: Edit/Write で ~/.claude/ 配下のファイルが変更されたら chezmoi re-add
# stdin に tool input の JSON が渡される

# chezmoi が無ければ何もしない
command -v chezmoi &>/dev/null || exit 0

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# file_path が ~/.claude/ 配下かチェック
claude_dir="$HOME/.claude"
if [[ "$file_path" == "$claude_dir"/* ]]; then
    chezmoi re-add 2>/dev/null || true
fi

exit 0
