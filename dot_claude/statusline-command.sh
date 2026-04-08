#!/bin/sh
# Claude Code status line script

input=$(cat)

# Model display name (shorten to just key part in brackets)
model_full=$(echo "$input" | jq -r '.model.display_name // empty')
# Extract short name: "Claude 3.5 Sonnet" -> "Sonnet", "Claude Opus 4" -> "Opus 4", etc.
model_short=$(echo "$model_full" | sed 's/Claude //I' | sed 's/claude-//I')

# Project directory (basename)
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // empty')
project_name=$(basename "$project_dir")

# Git branch (skip optional locks)
branch=""
if [ -n "$project_dir" ] && [ -d "$project_dir/.git" ]; then
  branch=$(git -C "$project_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$project_dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
fi

# Context window usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build progress bar (10 blocks wide)
progress_bar=""
if [ -n "$used_pct" ]; then
  filled=$(echo "$used_pct" | awk '{printf "%d", int($1 / 10 + 0.5)}')
  if [ "$filled" -gt 10 ]; then filled=10; fi
  empty=$((10 - filled))
  bar_filled=""
  bar_empty=""
  i=0
  while [ $i -lt $filled ]; do
    bar_filled="${bar_filled}█"
    i=$((i + 1))
  done
  i=0
  while [ $i -lt $empty ]; do
    bar_empty="${bar_empty}░"
    i=$((i + 1))
  done
  used_int=$(echo "$used_pct" | awk '{printf "%d", int($1 + 0.5)}')
  # Derive actual token usage from percentage and context window size
  window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
  if [ "$window_size" -gt 0 ]; then
    total_tokens=$(echo "$used_pct $window_size" | awk '{printf "%d", $1 / 100 * $2}')
    if [ "$total_tokens" -ge 1000 ]; then
      tokens_str=$(echo "$total_tokens" | awk '{printf "%.1fk", $1 / 1000}')
    else
      tokens_str="${total_tokens}"
    fi
    progress_bar="${bar_filled}${bar_empty} ${used_int}% (${tokens_str} tokens)"
  else
    progress_bar="${bar_filled}${bar_empty} ${used_int}%"
  fi
fi

# Cost (use the API-provided value if available, otherwise estimate)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$cost" ]; then
  cost=$(echo "$cost" | awk '{printf "%.2f", $1}')
else
  total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
  total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
  cost=$(echo "$total_in $total_out" | awk '{cost = ($1 / 1000000 * 3) + ($2 / 1000000 * 15); printf "%.2f", cost}')
fi

# Elapsed time: derive from transcript path mtime vs now
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
elapsed_str=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  start_mtime=$(stat -f %B "$transcript" 2>/dev/null || stat -c %W "$transcript" 2>/dev/null)
  if [ -z "$start_mtime" ] || [ "$start_mtime" = "0" ]; then
    start_mtime=$(stat -f %m "$transcript" 2>/dev/null || stat -c %Y "$transcript" 2>/dev/null)
  fi
  now=$(date +%s)
  elapsed=$((now - start_mtime))
  if [ $elapsed -lt 0 ]; then elapsed=0; fi
  elapsed_m=$((elapsed / 60))
  elapsed_s=$((elapsed % 60))
  elapsed_str="${elapsed_m}m ${elapsed_s}s"
fi

# Effort level (read from settings.json)
effort=""
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
fi

# ANSI colors
CYAN='\033[36m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Line 1: [Model] folder project | branch
line1=""
if [ -n "$model_short" ]; then
  line1="${BOLD}${CYAN}[${model_short}]${RESET}"
fi
if [ -n "$project_name" ]; then
  line1="${line1} 📁 ${project_name}"
fi
if [ -n "$branch" ]; then
  line1="${line1} | 🌿 ${branch}"
fi
if [ -n "$effort" ]; then
  line1="${line1} | ${DIM}effort:${effort}${RESET}"
fi

# Line 2: progress | $cost | elapsed
line2=""
if [ -n "$progress_bar" ]; then
  line2="${progress_bar}"
fi
if [ -n "$cost" ]; then
  if [ -n "$line2" ]; then
    line2="${line2} | \$${cost}"
  else
    line2="\$${cost}"
  fi
fi
if [ -n "$elapsed_str" ]; then
  if [ -n "$line2" ]; then
    line2="${line2} | 🕐 ${elapsed_str}"
  else
    line2="🕐 ${elapsed_str}"
  fi
fi

printf '%b\n%b' "$line1" "$line2"
