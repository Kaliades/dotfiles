#!/usr/bin/env bash
# Dispatcher dla wszystkich hookow Claude Code.
# Usage: claude-hook.sh <event>
#   eventy: session-start | prompt-submit | stop | notification | session-end
#
# Hook TYLKO utrzymuje cache (~/.claude/cache/session-<sid>). Zero wywolan
# zellij — to byl zrodlo zombie subshelli i zatkanego socketa. Nazywaniem
# zakladek nie zajmujemy sie; cj() w zshrc nawiguje samodzielnie korzystajac
# z cache.

set -u

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

EVENT="${1:-}"
INPUT="$(cat || true)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$CWD" ] && CWD="${PWD:-}"

# Synchronicznie pisze pane_id + branch (jesli pane jest w git repo).
# Bez bg subshelli — git symbolic-ref to <50ms, lepiej splacic ten koszt
# niz wisiec na disown'd subshellach. pane_id z $ZELLIJ_PANE_ID (stable)
# to join-key do `zellij action list-panes -j` w _cj.py.
# cwd JUZ NIE zapisujemy — zellij sam wie przez list-panes.pane_cwd.
capture_pane_and_branch() {
  local sid="$1"
  [ -z "$sid" ] && return 0
  [ -n "${ZELLIJ_PANE_ID:-}" ] && write_session_field "$sid" "pane_id" "$ZELLIJ_PANE_ID"
  if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    local br
    br="$(git -C "$CWD" symbolic-ref --short -q HEAD 2>/dev/null)"
    [ -z "$br" ] && br="$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)"
    [ -n "$br" ] && write_session_field "$sid" "branch" "$br"
  fi
}

case "$EVENT" in
  session-start)
    write_state "$SESSION_ID" "idle"
    capture_pane_and_branch "$SESSION_ID"
    ;;

  prompt-submit)
    write_state "$SESSION_ID" "working"
    capture_pane_and_branch "$SESSION_ID"
    ;;

  stop)
    write_state "$SESSION_ID" "done"
    ;;

  notification)
    write_state "$SESSION_ID" "waiting"
    ;;

  session-end)
    purge_session_markers "$SESSION_ID"
    ;;

  *)
    exit 0
    ;;
esac

exit 0
