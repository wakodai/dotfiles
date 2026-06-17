#!/bin/sh
# Claude Code status line script

input=$(cat)

# ANSI colors
CYAN='\033[36m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# --- Pattern 4 helpers: fine-grained bar + truecolor gradient ---

# truecolor gradient escape for a percentage (green -> yellow -> red)
grad() {
  awk -v pct="$1" 'BEGIN{
    if (pct < 50) { r = int(pct * 5.1); printf "\033[38;2;%d;200;80m", r }
    else { g = int(200 - (pct - 50) * 4); if (g < 0) g = 0; printf "\033[38;2;255;%d;60m", g }
  }'
}

# fine-grained progress bar (8-step partial blocks)
make_bar() {
  awk -v pct="$1" -v width="${2:-10}" 'BEGIN{
    split(" |▏|▎|▍|▌|▋|▊|▉|█", blocks, "|");
    if (pct < 0) pct = 0; if (pct > 100) pct = 100;
    filled = pct * width / 100;
    full = int(filled);
    frac = int((filled - full) * 8);
    b = "";
    for (i = 0; i < full; i++) b = b "█";
    if (full < width) {
      b = b blocks[frac + 1];
      for (i = 0; i < width - full - 1; i++) b = b "░";
    }
    printf "%s", b;
  }'
}

# "label <colored-bar> NN%"
fmt_metric() {
  label="$1"
  pct="$2"
  p=$(echo "$pct" | awk '{printf "%d", $1 + 0.5}')
  printf '%s %s%s %s%%%s' "$label" "$(grad "$pct")" "$(make_bar "$pct")" "$p" "$RESET"
}

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

# Metrics: context window + rate limits (5h / 7d)
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

metrics=""
if [ -n "$ctx_pct" ]; then
  metrics=$(fmt_metric "ctx" "$ctx_pct")
fi
if [ -n "$five_pct" ]; then
  m=$(fmt_metric "5h" "$five_pct")
  if [ -n "$metrics" ]; then metrics="${metrics} ${DIM}│${RESET} ${m}"; else metrics="$m"; fi
fi
if [ -n "$week_pct" ]; then
  m=$(fmt_metric "7d" "$week_pct")
  if [ -n "$metrics" ]; then metrics="${metrics} ${DIM}│${RESET} ${m}"; else metrics="$m"; fi
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

# Line 1: [Model] folder project | branch | effort
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

# Line 2: ctx | 5h | 7d | $cost | elapsed
line2="$metrics"
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
