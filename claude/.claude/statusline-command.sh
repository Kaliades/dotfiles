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

# --- Usage reset timer (5h rolling window from Anthropic API) ---
# Cache API response for 60 seconds to avoid rate limiting
block_part=""
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=60
now_epoch=$(date +%s)

use_cache=false
if [ -f "$CACHE_FILE" ]; then
  cache_age=$((now_epoch - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
  if [ "$cache_age" -lt "$CACHE_MAX_AGE" ]; then
    use_cache=true
  fi
fi

if [ "$use_cache" = true ]; then
  usage_json=$(cat "$CACHE_FILE")
else
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null |
    python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    usage_json=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
      -H "Authorization: Bearer $TOKEN" \
      -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
    # Only cache valid responses (not errors)
    if echo "$usage_json" | jq -e '.five_hour' >/dev/null 2>&1; then
      echo "$usage_json" >"$CACHE_FILE"
    elif [ -f "$CACHE_FILE" ]; then
      # Fall back to stale cache on error
      usage_json=$(cat "$CACHE_FILE")
    fi
  fi
fi

if [ -n "$usage_json" ]; then
  util=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  resets_at=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
  if [ -n "$util" ] && [ -n "$resets_at" ]; then
    util_int=$(echo "$util" | awk '{printf "%.0f", $1}')
    # Calculate time until reset
    reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${resets_at%%.*}" +%s 2>/dev/null)
    if [ -n "$reset_epoch" ] && [ "$reset_epoch" -gt "$now_epoch" ]; then
      diff=$((reset_epoch - now_epoch))
      rh=$((diff / 3600))
      rm=$(((diff % 3600) / 60))
      if [ "$rh" -gt 0 ]; then
        reset_str=$(printf "%dh %02dm" $rh $rm)
      else
        reset_str=$(printf "%dm" $rm)
      fi
    else
      reset_str="now"
    fi
    # Color based on utilization
    if [ "$util_int" -ge 80 ]; then
      usage_color="$RED"
    elif [ "$util_int" -ge 50 ]; then
      usage_color="$ORANGE"
    else
      usage_color="$GREEN"
    fi
    block_part="${PURPLE}${BOLD}󱑎 ${RESET}${PURPLE}${reset_str}${RESET}${SEP}${usage_color}${util_int}% used${RESET}"
  fi
fi

# --- Output ---
if [ -n "$block_part" ]; then
  echo -e "${top_line}\n${block_part}"
else
  echo -e "${top_line}"
fi
