#!/usr/bin/env python3
"""
Helper dla zsh funkcji `cj`. Listuje aktywne sesje Claude'a w formacie pod fzf.

Output: jedna linia per rzad, pola rozdzielone TAB-em:
    <display>\\t<target_session>\\t<my_session>\\t<pane_id>\\t<sid>

Pierwsza kolumna (display) zawiera kolorowany, wyrownany tekst gotowy do
pokazania w fzf. Pozostale kolumny sa ukryte (--with-nth=1) i sluza zsh
do nawigacji:
  - <sid> pusty -> header/spacer (zsh bail-uje)
  - <pane_id> + <target_session> -> `zellij --session <target> action focus-pane-id <id>`
  - <my_session> -> nazwa MOJEJ live-sesji (do --session flag, omija stale env)

Architektura:
  - Cache (~/.claude/cache/session-<sid>): TYLKO claude-side state
    (state, branch, pane_id, session_id, meta).
  - Live z `zellij action list-panes -a -j`: tab_name, pane_cwd, title,
    session_name, is_focused. Join na pane_id.
  - Stale $ZELLIJ_SESSION_NAME nigdy nie czytamy do display'u — szukamy
    mojej sesji po $ZELLIJ_PANE_ID wsrod live pane'ow.
"""

import os
import sys
import time
import unicodedata
from pathlib import Path

# Lokalny import — _zellij.py obok.
sys.path.insert(0, str(Path(__file__).parent))
from _zellij import live_panes_by_session, find_my_session  # noqa: E402


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


def shorten_title(title: str) -> str:
    """Wyciagnij stan z title typu '✳ Fix docker-compose...'."""
    if not title:
        return ""
    # Strip leading status icon (✳ working, ✶, ✻, etc — Claude pulses)
    stripped = title.lstrip("✳✶✻*● ").strip()
    if not stripped or stripped == "Claude Code":
        return ""
    if len(stripped) > 50:
        return stripped[:47] + "..."
    return stripped


def read_claude_cache() -> dict[tuple[str, int], dict]:
    """Czyta cache hookow -> {(zellij_session, pane_id): {state, branch, sid, ...}}.

    Klucz wymaga pary (zellij_session, pane_id) bo pane_id nie jest unikalny
    globalnie — kazda sesja zellij ma swoje pane_id 0,1,2,... Wpisy bez
    zellij_session (legacy / hook fired poza zellijem) sa pomijane.

    Lazy GC: kasuje pliki gdzie pid nie zyje lub starsze niz TTL.
    """
    if not CACHE.is_dir():
        return {}
    out: dict[tuple[str, int], dict] = {}
    for f in CACHE.glob("session-*"):
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
        state = d.get("state", "")
        sid = d.get("session_id", "")
        pane_id_raw = d.get("pane_id", "")
        zellij_session = d.get("zellij_session", "")
        if state not in EMOJI or not sid or not pane_id_raw or not zellij_session:
            continue
        try:
            pane_id = int(pane_id_raw)
        except ValueError:
            continue
        out[(zellij_session, pane_id)] = {
            "state": state,
            "branch": d.get("branch", ""),
            "sid": sid,
        }
    return out


def main() -> int:
    claude = read_claude_cache()
    if not claude:
        return 0

    by_session = live_panes_by_session()
    if not by_session:
        # Zellij niedostepny lub brak sesji — degraded mode bez grupowania.
        # Zostawiamy puste output, cj zglosi "brak Claude'ow".
        return 0

    my_session = find_my_session(by_session, os.environ.get("ZELLIJ_PANE_ID"))

    # Build rows: join claude cache z live panes po (zellij_session, pane_id).
    rows = []
    for sess, panes in by_session.items():
        for p in panes:
            pid = p.get("id")
            if pid is None:
                continue
            c = claude.get((sess, pid))
            if c is None:
                continue
            rows.append({
                "session": sess,
                "tab_name": p.get("tab_name") or "?",
                "pane_id": pid,
                "title": shorten_title(p.get("title") or ""),
                "cwd": p.get("pane_cwd") or "",
                "state": c["state"],
                "branch": c["branch"],
                "sid": c["sid"],
            })

    if not rows:
        return 0

    # Grupowanie po live session_name. My_session na gorze.
    by_group: dict[str, list] = {}
    for r in rows:
        by_group.setdefault(r["session"], []).append(r)

    group_keys = sorted(
        by_group.keys(),
        key=lambda k: (k != my_session, k.lower()),
    )

    # Wyznacz wspolne szerokosci kolumn dla wyrownania.
    tab_w = max((display_width(r["tab_name"]) for r in rows), default=0)
    cwd_display = [shorten_path(r["cwd"]) if r["cwd"] else "" for r in rows]
    cwd_w = max((display_width(c) for c in cwd_display), default=0)
    branch_w = max((display_width(r["branch"]) for r in rows), default=0)

    tab_w = min(tab_w, 24)
    cwd_w = min(cwd_w, 30)
    branch_w = min(branch_w, 22)

    out = []
    for gi, gk in enumerate(group_keys):
        marker = " ← obecna" if gk == my_session else ""
        header = f"{DIM}{CYAN}── 📺 {BOLD}{gk}{RESET}{DIM}{CYAN}{marker} ──{RESET}"
        # Header row: puste sid -> zsh bail.
        out.append(f"{header}\t\t\t\t")

        group_rows = sorted(
            by_group[gk],
            key=lambda r: (ORDER[r["state"]], r["tab_name"].lower()),
        )
        for r in group_rows:
            emoji = EMOJI[r["state"]]
            state_col = f"{STATE_COLOR[r['state']]}{emoji}{RESET}"
            tab_col = f"{BOLD}{pad(r['tab_name'], tab_w)}{RESET}"
            cwd_str = shorten_path(r["cwd"]) if r["cwd"] else ""
            cwd_col = f"{GREY}{pad('📁 ' + cwd_str if cwd_str else '', cwd_w + 3)}{RESET}"
            branch_col = f"{MAGENTA}{pad('  ' + r['branch'] if r['branch'] else '', branch_w + 2)}{RESET}"
            title_col = f"{DIM}{r['title']}{RESET}" if r["title"] else ""
            display = f"  {state_col}  {tab_col}  {cwd_col}  {branch_col}  {title_col}"
            # TSV: display \t target_session \t my_session \t pane_id \t sid
            out.append(
                f"{display}\t{r['session']}\t{my_session or ''}\t{r['pane_id']}\t{r['sid']}"
            )

        if gi < len(group_keys) - 1:
            out.append(f"{DIM}{GREY}\t\t\t\t{RESET}")  # blank spacer

    sys.stdout.write("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
