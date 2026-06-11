#!/bin/bash

# ANSI color codes
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Foreground colors
BLUE="\033[38;5;39m"
CYAN="\033[38;5;80m"
GREEN="\033[38;5;114m"
YELLOW="\033[38;5;221m"
RED="\033[38;5;203m"
ORANGE="\033[38;5;215m"
PURPLE="\033[38;5;141m"
WHITE="\033[38;5;252m"
GRAY="\033[38;5;244m"

SEP="${GRAY} │ ${RESET}"

input=$(cat)

# --- Current dir ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
if [[ "$cwd" == "$HOME/Workspace/"* ]]; then
  dir_icon=""
  display_dir="${cwd#$HOME/Workspace/}"
elif [[ "$cwd" == "$HOME"/* ]]; then
  dir_icon="󰉋"
  display_dir="~/${cwd#$HOME/}"
else
  dir_icon="󰉋"
  display_dir="$cwd"
fi
dir_part="${BLUE}${BOLD}${dir_icon} ${display_dir}${RESET}"

# --- Context remaining ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$remaining" ]; then
  remaining_int=$(printf "%.0f" "$remaining")
  if [ "$remaining_int" -le 15 ]; then
    ctx_color="$RED"
  elif [ "$remaining_int" -le 35 ]; then
    ctx_color="$ORANGE"
  else
    ctx_color="$GREEN"
  fi
  ctx_part="${ctx_color}󰾅 ${remaining_int}%${RESET}"
else
  ctx_part=""
fi

# --- Git branch and status ---
git_part=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if git -C "$cwd" status --porcelain 2>/dev/null | grep -q .; then
      git_part="${YELLOW} ${branch}${RESET} ${RED}✚${RESET}"
    else
      git_part="${YELLOW} ${branch}${RESET}"
    fi
  fi
fi

# --- Build top line ---
top_line="$dir_part"
[ -n "$ctx_part" ] && top_line="${top_line}${SEP}${ctx_part}"
[ -n "$git_part" ] && top_line="${top_line}${SEP}${git_part}"

# --- Usage limits (natywne `rate_limits` ze stdin status line'a) ---
# Claude Code (≥ ~2.1.x) przekazuje five_hour/seven_day wprost w JSON-ie wejściowym;
# wcześniejsze podejście (curl na api.anthropic.com/api/oauth/usage) kończyło się
# permanentnym 429 — endpoint jest ostro rate-limitowany per IP.
block_part=""
util_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty') # epoch
util_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

if [ -n "$util_5h" ] && [ -n "$resets_5h" ]; then
  util_int=$(printf "%.0f" "$util_5h")
  now_epoch=$(date +%s)
  diff=$((resets_5h - now_epoch))
  [ "$diff" -lt 0 ] && diff=0
  total_min=$((diff / 60))
  h=$((total_min / 60))
  m=$((total_min % 60))
  if [ "$h" -gt 0 ]; then
    reset_remaining=$(printf '%dh%02dm' "$h" "$m")
  else
    reset_remaining="${m}m"
  fi
  reset_time=$(date -d "@$resets_5h" +%H:%M 2>/dev/null || date -r "$resets_5h" +%H:%M 2>/dev/null)
  reset_str="${reset_time:-"--:--"} (${reset_remaining})"
  # Color based on utilization
  if [ "$util_int" -ge 80 ]; then
    usage_color="$RED"
  elif [ "$util_int" -ge 50 ]; then
    usage_color="$ORANGE"
  else
    usage_color="$GREEN"
  fi
  block_part="${PURPLE}${BOLD}󱑎 ${RESET}${PURPLE}${reset_str}${RESET}${SEP}${usage_color}${util_int}% used${RESET}"
  if [ -n "$util_7d" ]; then
    util_7d_int=$(printf "%.0f" "$util_7d")
    block_part="${block_part}${SEP}${GRAY}7d ${util_7d_int}%${RESET}"
  fi
fi

# Starsza wersja Claude Code bez rate_limits w stdin — powiedz to wprost.
if [ -z "$block_part" ]; then
  block_part="${GRAY}󱑎 brak danych o limicie${RESET}"
fi

# --- Output ---
out="$top_line"
[ -n "$block_part" ] && out="${out}\n${block_part}"
echo -e "$out"
