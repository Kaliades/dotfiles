#!/usr/bin/env python3
"""
Renderuje sekcje statusline z innymi aktywnymi sesjami Claude'a, pogrupowanymi
per LIVE Zellij session. Cache (~/.claude/cache/session-*) trzyma tylko
claude-side state, live metadata (nazwa sesji) bierzemy z `list-panes`.

Filtry:
  - pominiecie wlasnej sesji Claude'a (env CLAUDE_OTHERS_MY_SID)
  - pominiecie stanu "idle"
  - lazy GC: kasuje pliki gdzie pid nie zyje albo wpis starszy niz TTL (24h)

Wyjscie: jedna linia per Zellij-sesja, format:
    <BOLD>sesja:</BOLD> ⚙️N · 🔔N · ✅N
"""

import os
import sys
import time
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _zellij import live_panes_by_session  # noqa: E402


CACHE = Path.home() / ".claude" / "cache"
MY_SID = os.environ.get("CLAUDE_OTHERS_MY_SID", "")
NOW = int(time.time())
TTL = 86400

RESET = "\033[0m"
BOLD = "\033[1m"
GRAY = "\033[38;5;244m"
BLUE = "\033[38;5;39m"
ORANGE = "\033[38;5;215m"
GREEN = "\033[38;5;114m"

EMOJI = {"working": "⚙️", "waiting": "🔔", "done": "✅"}
COLOR = {"working": BLUE, "waiting": ORANGE, "done": GREEN}
ORDER = ["working", "waiting", "done"]


def pid_alive(pid: str) -> bool:
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError):
        return False


def parse(path: Path) -> dict:
    out = {}
    try:
        with open(path, "r") as f:
            for line in f:
                k, _, v = line.rstrip("\n").partition("\t")
                if k:
                    out[k] = v
    except OSError:
        return {}
    return out


def main() -> int:
    if not CACHE.is_dir():
        return 0

    # Cache -> {pane_id: (state, sid)}, filtrowane przez TTL/pid/idle/my-sid.
    by_pane: dict[int, tuple[str, str]] = {}
    for f in sorted(CACHE.glob("session-*")):
        d = parse(f)
        if not d:
            continue
        pid = d.get("pid", "")
        try:
            age = NOW - int(d.get("updated_at", "0"))
        except ValueError:
            age = 0
        if age > TTL or (pid and not pid_alive(pid)):
            try:
                f.unlink()
            except OSError:
                pass
            continue
        sid = d.get("session_id", "")
        state = d.get("state", "")
        pane_id_raw = d.get("pane_id", "")
        if state not in EMOJI:  # idle + smieci
            continue
        if sid == MY_SID:
            continue
        try:
            pid_int = int(pane_id_raw)
        except ValueError:
            continue
        by_pane[pid_int] = (state, sid)

    if not by_pane:
        return 0

    # Join z live Zellij sessions po pane_id.
    by_session = live_panes_by_session()
    if not by_session:
        return 0

    counts: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    sessions_with_waiting: set[str] = set()

    for sess, panes in by_session.items():
        for p in panes:
            pid = p.get("id")
            if pid is None or pid not in by_pane:
                continue
            state, _ = by_pane[pid]
            counts[sess][state] += 1
            if state == "waiting":
                sessions_with_waiting.add(sess)

    if not counts:
        return 0

    sorted_sessions = sorted(
        counts.keys(),
        key=lambda s: (s not in sessions_with_waiting, s.lower()),
    )

    sep = f"{GRAY} · {RESET}"
    for sess in sorted_sessions:
        parts = []
        for state in ORDER:
            cnt = counts[sess].get(state, 0)
            if cnt > 0:
                parts.append(f"{COLOR[state]}{EMOJI[state]}{cnt}{RESET}")
        if parts:
            print(f"{BOLD}{sess}:{RESET} " + sep.join(parts))

    return 0


if __name__ == "__main__":
    sys.exit(main())
