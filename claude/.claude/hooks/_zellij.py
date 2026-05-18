"""
Shared helper: pobiera LIVE metadata Zellija przez `zellij action list-panes -a -j`.

Dwa konsumenty:
  - _cj.py: picker sesji Claude'a (z fzf)
  - _others_status.py: statusline statusow innych Claude'ow

Dlaczego live zamiast cache: $ZELLIJ_SESSION_NAME w env jest snapshotem z momentu
startu pane'a — po `rename-session` ZELLIJ NIE aktualizuje env w istniejacych
pane'ach (env z definicji jest immutable per-process). Cache hookow zapisywal
stale wartosci -> sztuczne grupowanie. list-panes daje aktualna nazwe sesji +
tab_name + cwd + title.

Side effect renaming: `zellij action <X>` z stale-env pane'a buduje socket path
$ZELLIJ_SOCK_DIR/$ZELLIJ_SESSION_NAME ktory juz nie istnieje -> hangs. Workaround:
ZAWSZE podawac `--session <live_name>` explicit.
"""

import json
import subprocess
from typing import Optional


def list_sessions() -> list[str]:
    """Live nazwy sesji Zellija (raw, read-only, bezpieczne)."""
    try:
        r = subprocess.run(
            ["zellij", "list-sessions", "-n", "-s"],
            capture_output=True, text=True, timeout=2,
        )
        return [l.strip() for l in r.stdout.splitlines() if l.strip()]
    except (OSError, subprocess.SubprocessError):
        return []


def list_panes(session: str) -> list[dict]:
    """JSON dump pane'ow danej sesji. Lista obiektow PaneListEntry.

    Kluczowe pola dla nas:
      id (int), is_plugin (bool), exited (bool), is_focused (bool),
      tab_id, tab_name, tab_position, title, terminal_command,
      pane_command, pane_cwd
    """
    if not session:
        return []
    try:
        r = subprocess.run(
            ["zellij", "--session", session, "action", "list-panes", "-a", "-j"],
            capture_output=True, text=True, timeout=3,
        )
        if r.returncode != 0:
            return []
        return json.loads(r.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return []


def live_panes_by_session() -> dict[str, list[dict]]:
    """{session_name: [PaneListEntry, ...]} — wszystkie zywe sesje.

    Filtruje plugin pane'y i exited — zwraca tylko zywe terminale.
    """
    out: dict[str, list[dict]] = {}
    for s in list_sessions():
        panes = [
            p for p in list_panes(s)
            if not p.get("is_plugin") and not p.get("exited")
        ]
        if panes:
            out[s] = panes
    return out


def find_my_session(
    by_session: dict[str, list[dict]],
    my_pane_id_env: Optional[str],
) -> Optional[str]:
    """Znajdz live-name MOJEJ sesji szukajac pane'a o id == $ZELLIJ_PANE_ID.

    To omija stale env $ZELLIJ_SESSION_NAME — szukamy po pane_id (stable).
    """
    if not my_pane_id_env:
        return None
    try:
        target = int(my_pane_id_env)
    except ValueError:
        return None
    for sess, panes in by_session.items():
        for p in panes:
            if p.get("id") == target and not p.get("is_plugin"):
                return sess
    return None
