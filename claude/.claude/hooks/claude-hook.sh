#!/usr/bin/env bash
# Dispatcher dla wszystkich hookow Claude Code.
# Usage: claude-hook.sh <event>
#   eventy: session-start | prompt-submit | stop | notification | session-end

set -u
[ -n "${CLAUDE_HOOK_NO_RECURSE:-}" ] && exit 0

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

EVENT="${1:-}"
INPUT="$(cat || true)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"

case "$EVENT" in
  session-start)
    [ -z "${ZELLIJ:-}" ] && exit 0
    ensure_tab_id "$SESSION_ID" >/dev/null
    rename_for_session "$SESSION_ID" "🤖 Claude"
    write_state "$SESSION_ID" "idle"
    update_zellij_session_icon
    ;;

  prompt-submit)
    [ -z "${ZELLIJ:-}" ] && exit 0
    PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
    ensure_tab_id "$SESSION_ID" >/dev/null
    EXISTING_NAME="$(read_session_field "$SESSION_ID" name)"

    if [ -n "$EXISTING_NAME" ]; then
      rename_for_session "$SESSION_ID" "⚙️ ${EXISTING_NAME}"
      write_state "$SESSION_ID" "working"
      update_zellij_session_icon
      exit 0
    fi

    # Pierwszy prompt — placeholder + bg generacja nazwy.
    rename_for_session "$SESSION_ID" "⚙️ Claude"
    write_state "$SESSION_ID" "working"
    update_zellij_session_icon

    [ -z "$PROMPT" ] && exit 0

    (
      export CLAUDE_HOOK_NO_RECURSE=1
      TITLE="$(
        printf '%s' "$PROMPT" | claude -p \
          "Na podstawie ponizszego promptu wymysl bardzo krotki tytul (2-3 slowa po polsku, bez interpunkcji, bez emoji, bez cudzyslowow). Zwroc TYLKO tytul, nic wiecej." \
          --model claude-haiku-4-5-20251001 2>/dev/null \
          | head -1 \
          | tr -d '\r\n"' \
          | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
          | cut -c1-30
      )"
      if [ -n "$TITLE" ]; then
        write_session_field "$SESSION_ID" "name" "$TITLE"
        rename_for_session "$SESSION_ID" "⚙️ ${TITLE}"
        write_state "$SESSION_ID" "working"
      fi
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
    ;;

  stop)
    [ -z "${ZELLIJ:-}" ] && exit 0
    NAME="$(read_session_field "$SESSION_ID" name)"
    rename_for_session "$SESSION_ID" "✅ ${NAME:-Claude}"
    write_state "$SESSION_ID" "done"
    update_zellij_session_icon
    ;;

  notification)
    [ -z "${ZELLIJ:-}" ] && exit 0
    NAME="$(read_session_field "$SESSION_ID" name)"
    rename_for_session "$SESSION_ID" "🔔 ${NAME:-Claude}"
    write_state "$SESSION_ID" "waiting"
    update_zellij_session_icon
    ;;

  session-end)
    if [ -z "${ZELLIJ:-}" ]; then
      purge_session_markers "$SESSION_ID"
      exit 0
    fi
    rename_for_session "$SESSION_ID" "zsh"
    purge_session_markers "$SESSION_ID"
    update_zellij_session_icon
    ;;

  *)
    exit 0
    ;;
esac

exit 0
