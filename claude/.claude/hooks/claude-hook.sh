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
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$CWD" ] && CWD="${PWD:-}"

# capture_cwd_and_branch <sid>
# Zapisuje cwd i branch (jesli to repo) do cache. Branch w tle bo git moze byc wolny.
capture_cwd_and_branch() {
  local sid="$1"
  [ -z "$sid" ] && return 0
  [ -n "$CWD" ] && write_session_field "$sid" "cwd" "$CWD"
  (
    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
      local br
      br="$(git -C "$CWD" symbolic-ref --short -q HEAD 2>/dev/null)"
      [ -z "$br" ] && br="$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)"
      [ -n "$br" ] && write_session_field "$sid" "branch" "$br"
    fi
  ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

case "$EVENT" in
  session-start)
    [ -z "${ZELLIJ:-}" ] && exit 0
    ensure_tab_id "$SESSION_ID" >/dev/null
    rename_for_session "$SESSION_ID" "🤖 Claude"
    write_state "$SESSION_ID" "idle"
    capture_cwd_and_branch "$SESSION_ID"
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
      capture_cwd_and_branch "$SESSION_ID"
      update_zellij_session_icon
      exit 0
    fi

    # Pierwszy prompt — placeholder + bg generacja nazwy.
    rename_for_session "$SESSION_ID" "⚙️ Claude"
    write_state "$SESSION_ID" "working"
    capture_cwd_and_branch "$SESSION_ID"
    update_zellij_session_icon

    [ -z "$PROMPT" ] && exit 0

    (
      export CLAUDE_HOOK_NO_RECURSE=1
      CWD_NAME="$(basename "${PWD:-?}")"

      # Skroc input dla Haiku do ~800 znakow, zwin whitespace.
      PROMPT_SHORT="$(printf '%s' "$PROMPT" | perl -CSD -e 'local $/; $_=<STDIN>//q(); s/\s+/ /g; s/^\s+//; print substr($_, 0, 800)')"

      TITLE="$(
        printf '%s' "$PROMPT_SHORT" | claude -p \
          "Wymyśl krótki tytuł zakładki terminala (max 4 słowa po polsku) streszczający TEMAT poniższego zadania. NIE kopiuj tekstu dosłownie — streszczaj. Bez interpunkcji, emoji, cudzysłowów, markdownu, prefixów (Tytuł:, Title:). Zwróć TYLKO sam tytuł, nic więcej.

Kontekst projektu (katalog): ${CWD_NAME}

Przykłady:
Wejście: Czy mógłbyś naprawić błąd w teście logowania na CI który flakuje?
Tytuł: Fix flaky logowania CI

Wejście: zrób mi review tego MR z walidacją koszyka
Tytuł: Review walidacji koszyka

Wejście: Dobra, zróbmy sobie skrypt do nazywania zakładek żeby ładniej wyglądały
Tytuł: Skrypt nazwy taba

Wejście: pomóż mi napisać query do BigQuery zliczające unique users per dzień
Tytuł: BQ unique users" \
          --model claude-haiku-4-5-20251001 2>/dev/null \
          | perl -CSD -e '
              use utf8;
              local $/; my $s = <STDIN> // q();
              $s = (split /\n/, $s)[0] // q();
              $s =~ s/^\s*(?:Tyt(?:uł|ul)|Title|Wyj(?:ście|scie)|Output|Name|Nazwa)\s*[:：]\s*//i;
              $s =~ s/[\x60*_]//g;
              $s =~ s/[\x{0022}\x{0027}\x{2018}\x{2019}\x{201C}\x{201D}\x{00AB}\x{00BB}]//g;
              $s =~ s/^[\s.,;:!?\-–—]+//;
              $s =~ s/[\s.,;:!?\-–—]+$//;
              print substr($s, 0, 40);
            '
      )"

      # Fallback: pierwsze ~35 znakow promptu (oczyszczone) gdy Haiku nie pomogl.
      if [ -z "$TITLE" ]; then
        TITLE="$(
          printf '%s' "$PROMPT" | perl -CSD -e '
            use utf8;
            local $/; my $s = <STDIN> // q();
            $s =~ s/\s+/ /g;
            $s =~ s/[\x60*_\x{0022}\x{0027}\x{2018}\x{2019}\x{201C}\x{201D}]//g;
            $s =~ s/^\s+//; $s =~ s/\s+$//;
            print substr($s, 0, 35);
          '
        )"
      fi

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
