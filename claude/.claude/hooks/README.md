# Claude Code hooks — Zellij integration

Hooki w tym katalogu kolorują/nazywają zakładki Zellija w zależności od stanu sesji
Claude'a (working / waiting / done) oraz utrzymują cache stanu pod `~/.claude/cache/session-<sid>`,
z którego korzysta zshowa funkcja `cj` (fzf picker) i statusline.

## Pliki

| Plik | Rola |
|---|---|
| `claude-hook.sh` | **Dispatcher** — jeden entry-point dla wszystkich eventów. Bierze nazwę eventu jako `$1`, czyta JSON z stdin. |
| `_lib.sh` | Biblioteka funkcji (cache TSV, `rename-tab`, agregacja ikon sesji Zellija). Source'owana przez dispatcher. |
| `_cj.py` | Helper dla zshowej funkcji `cj` — listuje aktywne sesje w formacie pod fzf. **Nie jest hookiem.** |
| `_others_status.py` | Renderuje sekcję statusline z innymi aktywnymi sesjami. **Nie jest hookiem** (odpalany ze `statusline-command.sh`). |
| `.disabled` *(opcjonalny)* | Kill-switch — jeśli istnieje, `_lib.sh` go source'uje na starcie (np. `ZELLIJ_ACTIONS_DISABLED=1` gdy socket zellija się zatyka). |

## Mapowanie event → Claude Code hook

Dispatcher rozumie 5 eventów; każdy odpowiada jednemu hookowi Claude Code:

| Argument `claude-hook.sh` | Claude Code event | Co robi |
|---|---|---|
| `session-start` | `SessionStart` | Nadaje zakładce `🤖 Claude`, stan `idle`. |
| `prompt-submit` | `UserPromptSubmit` | Stan `working`, ikona `⚙️`. Przy 1. promp­cie odpala w tle Haiku do wygenerowania krótkiego tytułu zakładki. |
| `stop` | `Stop` | Stan `done`, ikona `✅`. |
| `notification` | `Notification` | Stan `waiting`, ikona `🔔` (Claude czeka na input/permission). |
| `session-end` | `SessionEnd` | Przywraca nazwę zakładki na `zsh`, czyści cache sesji. |

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

Claude Code wysyła do każdego hooka JSON-a na stdin (m.in. `session_id`, `cwd`, dla
`UserPromptSubmit` także `prompt`). Dispatcher czyta to przez `jq`.

## Bezpieczeństwo poza Zellijem

Każdy event w dispatcherze ma early-exit `[ -z "${ZELLIJ:-}" ] && exit 0`, więc poza Zellijem
hooki nic nie robią (poza `session-end`, który dodatkowo wyczyści cache). Można je włączyć
globalnie bez ryzyka, że zaszkodzą w gołym terminalu.

## Komplementarna integracja w zsh

Hooki nazywają i kolorują **istniejący** tab/pane Claude'a. O tym **gdzie** Claude w ogóle
ma wystartować decyduje user — w `~/.zshrc` (z dotfiles: `zshrc/.zshrc`) jest tylko alias:

- `claude` → passthrough do binarki w bieżącym pane
- `claudet` → `zellij action new-tab --close-on-exit -- claude` (claude w nowym tabie)

Podział obowiązków: **user wybiera lokalizację (`claude` vs `claudet`), hook nazywa**.
Brak coupling, brak race condition — alias odpala się zanim `SessionStart` w ogóle wystartuje.

## Format cache

`~/.claude/cache/session-<sid>` — TSV, jedno pole na linię:

```
session_id      <sid>
tab_id          <zellij tab id>
name            <tytuł zakładki bez ikony>
state           idle | working | waiting | done
zellij_session  <nazwa sesji Zellija>
updated_at      <epoch>
pid             <ppid hooka>
```

Lazy-GC: wpisy starsze niż 24h albo z martwym PID są pomijane przy agregacji ikony i
filtrowane przez `_cj.py` / `_others_status.py`. Pełne czyszczenie wpisu robi `SessionEnd`.

## Debug

```sh
# podgląd stanu wszystkich sesji
ls -la ~/.claude/cache/session-*
for f in ~/.claude/cache/session-*; do echo "=== $f ==="; cat "$f"; done

# wyłącz akcje zellij (gdy socket zawisł), zachowując zapis do cache
echo 'ZELLIJ_ACTIONS_DISABLED=1' > ~/.claude/hooks/.disabled
# włącz z powrotem
rm ~/.claude/hooks/.disabled

# manualny test eventu (symuluje wywołanie z Claude Code)
echo '{"session_id":"test-123","cwd":"'"$PWD"'","prompt":"napraw bug w X"}' \
  | bash ~/.claude/hooks/claude-hook.sh prompt-submit
```
