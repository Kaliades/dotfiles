#!/usr/bin/env bash
# Wspolna biblioteka dla hookow Claude Code.
#
# Hooki utrzymuja TYLKO cache (~/.claude/cache/session-<sid>) — zero
# wywolan zellij. Renamowanie zakladek/sesji zostalo usuniete bo
# rownolegle 'zellij action' zatykaja socket i tworza wiszace subshelle.
#
# Cache TSV: <field>\t<value>, jedno pole na linie.
# Pola: session_id, state, zellij_session, cwd, branch, updated_at, pid

_cache_dir() {
  echo "$HOME/.claude/cache"
}

_session_file() {
  printf '%s/session-%s' "$(_cache_dir)" "${1:-unknown}"
}

# Cache zapisuje $ZELLIJ_SESSION_NAME RAW — to nazwa pod ktora Zellij
# faktycznie trzyma sesje, i 'zellij action switch-session' wymaga
# dokladnie tej nazwy. Jesli env zawiera "🔔 main" bo poprzednie hooki
# renamowaly sesje, to TEZ jest aktualna nazwa sesji i trzeba ja
# zachowac. Strip do "main" robimy tylko cosmetic w _cj.py/display.

# read_session_field <sid> <field> -> stdout
read_session_field() {
  local sid="$1"
  local field="$2"
  [ -z "$sid" ] && return 0
  awk -F'\t' -v f="$field" '$1==f{print $2; exit}' "$(_session_file "$sid")" 2>/dev/null
}

# write_session_field <sid> <field> <value>
# Atomowo: load -> set field -> save. Preserves wszystkie inne pola,
# ZAWSZE odswieza meta (updated_at, pid).
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
      # Wycinamy stare wartosci pol ktore zaraz nadpiszemy. zellij_session
      # wycinamy zawsze (gdy env niepusty) — pane moze zostac przeniesiony,
      # albo sesja moze byc renameowana w przyszlosci.
      awk -F'\t' -v skip="$field" -v refresh_zsess="${ZELLIJ_SESSION_NAME:+1}" '
        $1 == skip { next }
        $1 == "updated_at" || $1 == "pid" || $1 == "session_id" { next }
        $1 == "zellij_session" && refresh_zsess == "1" { next }
        { print }
      ' "$file"
    fi
    printf 'session_id\t%s\n' "$sid"
    printf '%s\t%s\n' "$field" "$value"
    [ -n "${ZELLIJ_SESSION_NAME:-}" ] \
      && [ "$field" != "zellij_session" ] \
      && printf 'zellij_session\t%s\n' "$ZELLIJ_SESSION_NAME"
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
