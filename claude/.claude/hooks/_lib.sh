#!/usr/bin/env bash
# Wspolna biblioteka dla hookow Claude Code.
#
# Hooki utrzymuja TYLKO cache (~/.claude/cache/session-<sid>) — zero
# wywolan zellij. Renamowanie zakladek/sesji zostalo usuniete bo
# rownolegle mutujace 'zellij action' (rename-tab) zatykaja socket
# i tworza wiszace subshelle.
#
# Live metadata (nazwa sesji, tab_name, cwd) bierzemy z `zellij action
# list-panes -a -j` w _cj.py — to live, omija problem stale $ZELLIJ_SESSION_NAME.
# W cache trzymamy tylko CLAUDE-side state ktorego Zellij nie wie:
#   - session_id (Claude'a)
#   - state (idle/working/done/waiting)
#   - branch (git, bo Zellij gita nie zna)
#   - pane_id ($ZELLIJ_PANE_ID, stabilne — join-key do list-panes)
#   - updated_at, pid

_cache_dir() {
  echo "$HOME/.claude/cache"
}

_session_file() {
  printf '%s/session-%s' "$(_cache_dir)" "${1:-unknown}"
}

# read_session_field <sid> <field> -> stdout
read_session_field() {
  local sid="$1"
  local field="$2"
  [ -z "$sid" ] && return 0
  awk -F'\t' -v f="$field" '$1==f{print $2; exit}' "$(_session_file "$sid")" 2>/dev/null
}

# write_session_field <sid> <field> <value>
# Atomowo: load -> set field -> save. Preserves wszystkie inne pola,
# ZAWSZE odswieza meta (updated_at, pid). Wycina stale pola (zellij_session,
# cwd) gdyby ktos uruchomil cj z plikiem cache sprzed migracji.
write_session_field() {
  local sid="$1"
  local field="$2"
  local value="$3"
  [ -z "$sid" ] && return 0
  local file; file="$(_session_file "$sid")"
  local tmp="$file.tmp.$$"
  local ts; ts="$(date +%s)"
  mkdir -p "$(_cache_dir)"
  {
    if [ -f "$file" ]; then
      awk -F'\t' -v skip="$field" '
        $1 == skip { next }
        $1 == "updated_at" || $1 == "pid" || $1 == "session_id" { next }
        # Legacy fields — wycinaj zawsze, juz nie pisane.
        $1 == "zellij_session" || $1 == "cwd" { next }
        { print }
      ' "$file"
    fi
    printf 'session_id\t%s\n' "$sid"
    printf '%s\t%s\n' "$field" "$value"
    printf 'updated_at\t%s\n' "$ts"
    printf 'pid\t%s\n' "${PPID:-}"
  } > "$tmp" 2>/dev/null && mv -f "$tmp" "$file"
}

write_state() {
  write_session_field "$1" "state" "$2"
}

purge_session_markers() {
  local sid="$1"
  [ -z "$sid" ] && return 0
  rm -f "$(_session_file "$sid")" 2>/dev/null || true
}
