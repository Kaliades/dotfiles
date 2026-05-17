#!/usr/bin/env python3
"""
Renderuje sekcje statusline z innymi aktywnymi sesjami Claude'a, pogrupowanymi per
sesja Zellija. Czyta pliki ~/.claude/cache/session-* (TSV key<TAB>value).

Filtry:
  - pominiecie wlasnej sesji (env CLAUDE_OTHERS_MY_SID)
  - pominiecie stanu "idle"
  - lazy GC: kasuje pliki gdzie PID nie zyje albo wpis starszy niz TTL (24h)

Wyjscie: jedna linia per sesja Zellija, format:
    <BOLD>sesja:</BOLD> ⚙️N · 🔔N · ✅N

Sortowanie sesji: z "waiting" na pierwszym miejscu, potem alfabetycznie.
Pusty stdout = nic do dorzucenia.
"""

import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

# Defensive strip dla starych plikow cache z emoji prefixem w zellij_session.
_EMOJI_PREFIX = re.compile(r'^([🔔✅]\s+)+')

CACHE = Path.home() / ".claude" / "cache"
MY_SID = os.environ.get("CLAUDE_OTHERS_MY_SID", "")
NOW = int(time.time())
TTL = 86400  # 24h

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

    by_session: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    sessions_with_waiting: set[str] = set()

    for f in sorted(CACHE.glob("session-*")):
        d = parse(f)
        if not d:
            continue

        sid = d.get("session_id", "")
        state = d.get("state", "")
        pid = d.get("pid", "")
        ts_raw = d.get("updated_at", "0")
        # zsess RAW do grupowania (zeby sesje o tej samej faktycznej nazwie
        # ladowaly razem); strip emoji tylko cosmetic w printowaniu nazwy.
        zsess = d.get("zellij_session", "") or "?"

        try:
            age = NOW - int(ts_raw)
        except ValueError:
            age = 0

        # Lazy GC
        if age > TTL or (pid and not pid_alive(pid)):
            try:
                f.unlink()
            except OSError:
                pass
            continue

        if sid and sid == MY_SID:
            continue
        if state not in EMOJI:  # filtruje idle i smieci
            continue

        by_session[zsess][state] += 1
        if state == "waiting":
            sessions_with_waiting.add(zsess)

    if not by_session:
        return 0

    sorted_sessions = sorted(
        by_session.keys(),
        key=lambda s: (s not in sessions_with_waiting, s.lower()),
    )

    sep = f"{GRAY} · {RESET}"
    for zsess in sorted_sessions:
        parts = []
        for state in ORDER:
            cnt = by_session[zsess].get(state, 0)
            if cnt > 0:
                parts.append(f"{COLOR[state]}{EMOJI[state]}{cnt}{RESET}")
        if parts:
            display = _EMOJI_PREFIX.sub("", zsess)  # cosmetic strip
            print(f"{BOLD}{display}:{RESET} " + sep.join(parts))

    return 0


if __name__ == "__main__":
    sys.exit(main())
