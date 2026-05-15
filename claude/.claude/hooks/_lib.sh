#!/usr/bin/env bash
# Wspolna biblioteka dla hookow Claude Code.
#
# Format cache: jeden plik per sesja Claude'a: ~/.claude/cache/session-<sid>
# Plik to TSV: <field>\t<value>, po jednym polu na linie.
# Pola: session_id, tab_id, name, state, zellij_session, updated_at, pid

_cache_dir() {
  echo "$HOME/.claude/cache"
}

# Kill-switch dla zellij action (gdy socket zakorkowany).
if [ -f "$HOME/.claude/hooks/.disabled" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.claude/hooks/.disabled"
fi

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
# Atomowo: load -> set field -> save. Preserves wszystkie inne pola, ZAWSZE odswieza meta (updated_at, pid).
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
        $1 != skip && $1 != "updated_at" && $1 != "pid" && $1 != "session_id" { print }
      ' "$file"
    fi
    printf 'session_id\t%s\n' "$sid"
    printf '%s\t%s\n' "$field" "$value"
    [ -n "${ZELLIJ_SESSION_NAME:-}" ] \
      && [ "$field" != "zellij_session" ] \
      && [ -z "$(awk -F'\t' '$1=="zellij_session"{print $2; exit}' "$file" 2>/dev/null)" ] \
      && printf 'zellij_session\t%s\n' "$ZELLIJ_SESSION_NAME"
    printf 'updated_at\t%s\n' "$ts"
    printf 'pid\t%s\n' "${PPID:-}"
  } > "$tmp" 2>/dev/null && mv -f "$tmp" "$file"
}

# write_state <sid> <state>  — uzywany przez hooki.
write_state() {
  write_session_field "$1" "state" "$2"
}

# purge_session_markers <sid> — usuwa cale session-<sid>.
purge_session_markers() {
  local sid="$1"
  [ -z "$sid" ] && return 0
  rm -f "$(_session_file "$sid")" 2>/dev/null || true
}

# ensure_tab_id <sid> -> stdout tab_id (lub pusto).
# Capture w tle (zellij socket potrafi zawisnac).
ensure_tab_id() {
  local sid="$1"
  [ -z "$sid" ] && return 0
  local existing; existing="$(read_session_field "$sid" tab_id)"
  if [ -z "$existing" ] && [ -z "${ZELLIJ_ACTIONS_DISABLED:-}" ]; then
    (
      id="$(zellij action current-tab-info 2>/dev/null | awk -F': *' '/^id:/{print $2; exit}')"
      [ -n "$id" ] && write_session_field "$sid" "tab_id" "$id"
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
  read_session_field "$sid" tab_id
}

# rename_for_session <sid> <full_name>
# Wszystko w tle — nigdy nie blokuje hook'a.
rename_for_session() {
  local sid="$1"
  local name="$2"
  [ -z "${ZELLIJ:-}" ] && return 0
  [ -n "${ZELLIJ_ACTIONS_DISABLED:-}" ] && return 0
  local tab_id; tab_id="$(ensure_tab_id "$sid")"
  if [ -n "$tab_id" ]; then
    ( zellij action rename-tab-by-id "$tab_id" "$name" >/dev/null 2>&1 ) &
  else
    ( zellij action rename-tab "$name" >/dev/null 2>&1 ) &
  fi
  disown 2>/dev/null || true
}

# Agregat ikony dla biezacej sesji Zellija: 🔔 jesli ktokolwiek waiting,
# ✅ jesli wszyscy done, inaczej pusto.
_aggregate_zellij_session_icon() {
  [ -z "${ZELLIJ_SESSION_NAME:-}" ] && return 0
  local cache_dir; cache_dir="$(_cache_dir)"
  local now; now="$(date +%s)"
  local has_waiting=0 has_active=0 has_done=0
  local f zsess state pid ts age
  for f in "$cache_dir"/session-*; do
    [ -f "$f" ] || continue
    zsess="$(awk -F'\t' '$1=="zellij_session"{print $2; exit}' "$f")"
    [ "$zsess" = "$ZELLIJ_SESSION_NAME" ] || continue
    state="$(awk -F'\t' '$1=="state"{print $2; exit}' "$f")"
    pid="$(awk -F'\t' '$1=="pid"{print $2; exit}' "$f")"
    ts="$(awk -F'\t' '$1=="updated_at"{print $2; exit}' "$f")"
    if [ -n "$ts" ]; then
      age=$((now - ts))
      [ "$age" -gt 86400 ] && continue
    fi
    [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && continue
    case "$state" in
      waiting) has_waiting=1 ;;
      done)    has_done=1 ;;
      working|idle) has_active=1 ;;
    esac
  done
  if [ "$has_waiting" -eq 1 ]; then
    printf '🔔 '
  elif [ "$has_done" -eq 1 ] && [ "$has_active" -eq 0 ]; then
    printf '✅ '
  fi
}

_get_current_zellij_session_name() {
  zellij list-sessions 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk -F' \\[Created' '/\(current\)/{print $1; exit}'
}

# Aktualizuje nazwe sesji Zellija (cala w tle).
update_zellij_session_icon() {
  [ -z "${ZELLIJ_SESSION_NAME:-}" ] && return 0
  [ -n "${ZELLIJ_ACTIONS_DISABLED:-}" ] && return 0
  (
    icon="$(_aggregate_zellij_session_icon)"
    current="$(_get_current_zellij_session_name)"
    [ -z "$current" ] && exit 0
    base="$(printf '%s' "$current" | sed -E 's/^(🔔 |✅ )//')"
    target="${icon}${base}"
    [ -z "$target" ] && exit 0
    if [ "$target" != "$current" ]; then
      zellij action rename-session "$target" >/dev/null 2>&1 || true
    fi
  ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
}
