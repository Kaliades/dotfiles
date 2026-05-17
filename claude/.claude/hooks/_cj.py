#!/usr/bin/env python3
"""
Helper dla zsh funkcji `cj`. Listuje aktywne sesje Claude'a w formacie pod fzf.

Output: jedna linia per rzad, pola rozdzielone TAB-em:
    <display>\\t<zellij_session>\\t<tab_id>\\t<sid>\\t<pane_id>

Pierwsza kolumna (display) zawiera kolorowany, wyrownany tekst gotowy do
pokazania w fzf. Pozostale kolumny sa ukryte (--with-nth=1) i sluza zsh
do nawigacji:
  - <sid> pusty -> header/spacer (zsh bail-uje)
  - <pane_id> -> zellij action focus-pane-id (jump do konkretnego pane'a)
  - <tab_id> -> legacy, zostaje dla kompatybilnosci ze starymi cache'ami

Filtry:
  - state != "idle"
  - tab_id + zellij_session musza istniec
  - pid musi zyc, plik nie starszy niz TTL (24h) — lazy GC

Sortowanie:
  - Grupowanie po Zellij session (alfabetycznie; current zellij na gorze)
  - W grupie: waiting, working, done; potem alfabetycznie po cwd.
"""

import os
import re
import subprocess
import sys
import time
import unicodedata
from pathlib import Path

# Defensive strip — stare pliki cache (sprzed wywalenia zellij action z hookow)
# moga miec emoji prefix w zellij_session. Bez tego grupowanie pada.
_EMOJI_PREFIX = re.compile(r'^([🔔✅]\s+)+')

CACHE = Path.home() / ".claude" / "cache"
NOW = int(time.time())
TTL = 86400

EMOJI = {"working": "⚙️", "waiting": "🔔", "done": "✅"}
ORDER = {"waiting": 0, "working": 1, "done": 2}

# ANSI kolory (fzf renderuje z --ansi)
DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"
CYAN = "\033[36m"
YELLOW = "\033[33m"
GREEN = "\033[32m"
MAGENTA = "\033[35m"
GREY = "\033[90m"

STATE_COLOR = {"working": YELLOW, "waiting": MAGENTA, "done": GREEN}


def pid_alive(pid: str) -> bool:
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError):
        return False


def lsof_cwd(pid: str) -> str:
    """Lazy fallback: cwd procesu przez lsof (macOS-compatible)."""
    if not pid:
        return ""
    try:
        out = subprocess.run(
            ["lsof", "-a", "-d", "cwd", "-p", pid],
            capture_output=True, text=True, timeout=1,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ""
    lines = [l for l in out.splitlines() if l and not l.startswith("COMMAND")]
    if not lines:
        return ""
    parts = lines[-1].split(None, 8)
    return parts[8].strip() if len(parts) >= 9 else ""


def git_branch(cwd: str) -> str:
    if not cwd or not os.path.isdir(cwd):
        return ""
    try:
        r = subprocess.run(
            ["git", "-C", cwd, "symbolic-ref", "--short", "-q", "HEAD"],
            capture_output=True, text=True, timeout=1,
        )
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
        r = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=1,
        )
        return r.stdout.strip() if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


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


def display_width(s: str) -> int:
    """Szerokosc stringa w komorkach terminala (CJK/emoji = 2)."""
    w = 0
    for ch in s:
        if unicodedata.category(ch).startswith("C"):
            continue
        ea = unicodedata.east_asian_width(ch)
        w += 2 if ea in ("W", "F") else 1
    return w


def pad(s: str, width: int) -> str:
    delta = width - display_width(s)
    return s + (" " * delta if delta > 0 else "")


def shorten_path(cwd: str) -> str:
    """~/foo/bar → ~/bar jezeli zbyt dlugie; basename gdy bardzo dlugie."""
    home = str(Path.home())
    if cwd.startswith(home):
        cwd = "~" + cwd[len(home):]
    if len(cwd) <= 30:
        return cwd
    return Path(cwd).name or cwd[-30:]


def main() -> int:
    if not CACHE.is_dir():
        return 0

    current_zsess = os.environ.get("ZELLIJ_SESSION_NAME", "")
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
        pane_id = d.get("pane_id", "")
        # zsess RAW — to faktyczna nazwa sesji Zellija (z emoji jesli sesja
        # zostala kiedys renameowana). switch-session wymaga dokladnie tej
        # nazwy. Strip robimy tylko w display column nizej.
        zsess = d.get("zellij_session", "")
        sid = d.get("session_id", "")
        cwd = d.get("cwd", "")
        branch = d.get("branch", "")

        if state not in EMOJI:
            continue
        if not zsess or not sid:
            continue

        # Lazy fallback dla sesji sprzed update'a hooka.
        if not cwd:
            cwd = lsof_cwd(pid)
        if cwd and not branch:
            branch = git_branch(cwd)

        rows.append({
            "state": state,
            "tab_id": tab_id,
            "pane_id": pane_id,
            "zsess": zsess,
            "sid": sid,
            "cwd": shorten_path(cwd) if cwd else "",
            "branch": branch,
        })

    if not rows:
        return 0

    # Grupowanie: current zellij session pierwsze, reszta alfabetycznie.
    by_group: dict[str, list] = {}
    for r in rows:
        by_group.setdefault(r["zsess"], []).append(r)

    group_keys = sorted(by_group.keys(), key=lambda k: (k != current_zsess, k.lower()))

    # Wyznacz wspolne szerokosci kolumn (across all rows, dla wyrownania w calej liscie).
    cwd_w = max((display_width(r["cwd"]) for r in rows), default=0)
    branch_w = max((display_width(r["branch"]) for r in rows), default=0)

    # Mini caps zeby header nie ucieklo poza fzf.
    cwd_w = min(cwd_w, 36)
    branch_w = min(branch_w, 22)

    out = []
    for gi, gk in enumerate(group_keys):
        marker = " ← obecna" if gk == current_zsess else ""
        display_gk = _EMOJI_PREFIX.sub("", gk)  # cosmetic strip tylko w header
        header = f"{DIM}{CYAN}── 📺 {BOLD}{display_gk}{RESET}{DIM}{CYAN}{marker} ──{RESET}"
        # Header row: puste sid -> zsh bail.
        out.append(f"{header}\t\t\t\t")

        group_rows = sorted(
            by_group[gk],
            key=lambda r: (ORDER[r["state"]], r["cwd"].lower()),
        )
        for r in group_rows:
            emoji = EMOJI[r["state"]]
            state_col = f"{STATE_COLOR[r['state']]}{emoji}{RESET}"
            cwd_col = f"{GREY}{pad('📁 ' + r['cwd'] if r['cwd'] else '', cwd_w + 3)}{RESET}"
            branch_col = f"{MAGENTA}{pad('  ' + r['branch'] if r['branch'] else '', branch_w + 2)}{RESET}"
            display = f"  {state_col}  {cwd_col}  {branch_col}"
            out.append(f"{display}\t{r['zsess']}\t{r['tab_id']}\t{r['sid']}\t{r['pane_id']}")

        if gi < len(group_keys) - 1:
            out.append(f"{DIM}{GREY}\t\t\t\t{RESET}")  # blank spacer (also non-selectable)

    sys.stdout.write("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
