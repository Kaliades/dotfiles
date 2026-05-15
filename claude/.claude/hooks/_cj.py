#!/usr/bin/env python3
"""
Helper dla zsh funkcji `cj`. Listuje aktywne sesje Claude'a z stabilnym tab_id
w formacie TSV pod fzf.

Output (jedna linia per Claude):
    <emoji>\\t<zellij_session>\\t<tab_id>\\t<name>\\t<state>\\t<sid>

Filtry:
  - state != "idle"
  - tab_id + zellij_session musza istniec (bez nich nie ma jak przeskoczyc)
  - pid musi zyc, plik nie starszy niz TTL (24h) — lazy GC

Sortowanie: waiting, working, done; w grupach alfabetycznie po zellij_session, potem name.
"""

import os
import sys
import time
from pathlib import Path

CACHE = Path.home() / ".claude" / "cache"
NOW = int(time.time())
TTL = 86400

EMOJI = {"working": "⚙️", "waiting": "🔔", "done": "✅"}
ORDER = {"waiting": 0, "working": 1, "done": 2}


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

    rows = []
    for f in CACHE.glob("session-*"):
        d = parse(f)
        if not d:
            continue

        pid = d.get("pid", "")
        ts_raw = d.get("updated_at", "0")
        try:
            age = NOW - int(ts_raw)
        except ValueError:
            age = 0

        if age > TTL or (pid and not pid_alive(pid)):
            try:
                f.unlink()
            except OSError:
                pass
            continue

        state = d.get("state", "")
        tab_id = d.get("tab_id", "")
        zsess = d.get("zellij_session", "")
        sid = d.get("session_id", "")
        name = d.get("name", "") or "Claude"

        if state not in EMOJI:
            continue
        if not tab_id or not zsess:
            continue

        rows.append((ORDER[state], zsess.lower(), name.lower(),
                     EMOJI[state], zsess, tab_id, name, state, sid))

    rows.sort()
    for r in rows:
        print("\t".join(r[3:]))

    return 0


if __name__ == "__main__":
    sys.exit(main())
