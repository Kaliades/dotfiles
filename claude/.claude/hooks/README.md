# Claude Code hooks — cache stanu sesji

Hooki utrzymują **wyłącznie** plikowy cache stanu sesji Claude'a pod
`~/.claude/cache/session-<sid>`. Z tego cache korzysta zshowa funkcja `cj`
(fzf picker do przełączania sesji Claude'a) i `statusline-command.sh`.

**Brak wywołań `zellij action`** — wcześniejsza wersja renameowała tab/sesję
Zellija, ale równoległe `zellij action` zatykały socket i zostawiały wiszące
background subshelle (zombie procesy). Sygnał stanu (kolory/ikonki) trzeba
dostarczyć innym kanałem albo zaakceptować że tab nie informuje o stanie.

Hooki **odczytują** envy `$ZELLIJ_SESSION_NAME` i `$ZELLIJ_PANE_ID` (Zellij
sam je ustawia przy starcie pane'a) i zapisują do cache. To czysty read env,
bez wywołań do zellij socketa — `cj` używa `pane_id` żeby zrobić
`focus-pane-id` (jump do konkretnego pane'a Claude'a w obrębie sesji).

## Pliki

| Plik | Rola |
|---|---|
| `claude-hook.sh` | **Dispatcher** — jeden entry-point dla wszystkich eventów. Bierze nazwę eventu jako `$1`, czyta JSON z stdin, synchronicznie pisze cache. |
| `_lib.sh` | Biblioteka I/O na TSV cache + normalizacja `$ZELLIJ_SESSION_NAME`. Source'owana przez dispatcher. |
| `_cj.py` | Helper dla zshowej funkcji `cj` — listuje aktywne sesje w formacie pod fzf. **Nie jest hookiem.** |

## Mapowanie event → Claude Code hook

| Argument `claude-hook.sh` | Claude Code event | Co robi |
|---|---|---|
| `session-start` | `SessionStart` | Stan `idle`, zapis `cwd` + `branch`. |
| `prompt-submit` | `UserPromptSubmit` | Stan `working`, refresh `cwd` + `branch`. |
| `stop` | `Stop` | Stan `done`. |
| `notification` | `Notification` | Stan `waiting` (Claude czeka na input/permission). |
| `session-end` | `SessionEnd` | Cache sesji wyczyszczony (`rm` pliku). |

Hook zwykle wykonuje się w 30-80ms (synchroniczne `awk` + `mv` + ewentualne `git symbolic-ref`).

## Konfiguracja w `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart":     [{ "hooks": [{ "type": "command", "command": "bash /Users/simon/.claude/hooks/claude-hook.sh session-start"  }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash /Users/simon/.claude/hooks/claude-hook.sh prompt-submit" }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "bash /Users/simon/.claude/hooks/claude-hook.sh stop"           }] }],
    "Notification":     [{ "hooks": [{ "type": "command", "command": "bash /Users/simon/.claude/hooks/claude-hook.sh notification"   }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "bash /Users/simon/.claude/hooks/claude-hook.sh session-end"    }] }]
  }
}
```

Claude Code wysyła do każdego hooka JSON-a na stdin (m.in. `session_id`, `cwd`).
Dispatcher czyta to przez `jq`.

## Format cache

`~/.claude/cache/session-<sid>` — TSV, jedno pole na linię:

```
session_id      <sid>
state           idle | working | waiting | done
zellij_session  <nazwa sesji Zellija z env, bez emoji prefixu>
pane_id         <numer pane'a Zellija z env, np. 28>
cwd             <pelna sciezka cwd Claude'a>
branch          <git branch jesli repo>
updated_at      <epoch>
pid             <ppid hooka>
```

Lazy-GC: wpisy starsze niż 24h albo z martwym PID są filtrowane przez
`_cj.py` i kasowane przy odczycie. Pełne czyszczenie wpisu robi `SessionEnd`.

## Komplementarna integracja w zsh

W `~/.zshrc` (z dotfiles: `zshrc/.zshrc`) są:

- funkcja `claudet` — Claude w nowym tabie (`zellij action new-tab` z absolutną
  ścieżką binarki claude, żeby ominąć stale-PATH zellij-servera)
- funkcja `cj` — fzf picker z `_cj.py`:
  - same-session → `zellij action focus-pane-id <pane_id>` (jump do pane'a Claude'a)
  - cross-session → `zellij action switch-session` (po switch user sam dojeżdża do taba)

## Debug

```sh
# podgląd stanu wszystkich sesji
ls -la ~/.claude/cache/session-*
for f in ~/.claude/cache/session-*; do echo "=== $f ==="; cat "$f"; done

# manualny test eventu (symuluje wywołanie z Claude Code)
echo '{"session_id":"test-123","cwd":"'"$PWD"'"}' \
  | bash ~/.claude/hooks/claude-hook.sh prompt-submit
cat ~/.claude/cache/session-test-123

# cleanup zombie hookow z poprzedniej generacji (gdy renameowala zellija)
pkill -9 -f 'claude-hook\.sh'
```
