# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal dotfiles repository (macOS/Darwin) for Simon Kulinski. Stores configuration for shell, terminal emulator, editor, and git tooling.

## Repo Structure

Each tool gets its own top-level directory mirroring the home directory layout:

- `ghostty/` — Ghostty terminal config (`.config/ghostty/config`)
- `zellij/` — Zellij multiplexer config (`.config/zellij/config.kdl`)
- `git/` — Git config (`.gitconfig` + `.gitconfig-work`) + Lazygit config (`.config/lazygit/config.yml`)
- `zshrc/` — Zsh config (`.zshrc`)
- `claude/` — Claude Code config (`.claude/statusline-command.sh`)
- `cmux/` — cmux config (`.config/cmux/cmux.json`)
- `nvim/` — Neovim config (`.config/nvim/`) — LazyVim starter with lazy.nvim plugin manager
- `aerospace/` — AeroSpace tiling window manager config (`.aerospace.toml`)
- `starship/` — Starship prompt (`.config/starship.toml`) — **jedyny prompt** (cross-shell, Catppuccin Powerline preset)
- `karabiner/` — Karabiner-Elements config (`.config/karabiner/karabiner.json`) — `automatic_backups/` i `assets/` są ignorowane (Karabiner regeneruje je sam)
- `bin/` — skrypty użytkownika (`.local/bin/`) — m.in. `theme` (przełącznik motywu dzień/noc)

New tools should follow the same pattern: `<tool-name>/` containing files in their home-relative paths.

**Wyjątek poza stow** — `raycast.rayconfig` (plik w korzeniu repo): eksport ustawień Raycast (binarny). NIE jest stowowany (to jednorazowy import/eksport, nie żywy config) — leży jako plik w korzeniu, więc `install.sh` (szuka tylko katalogów) nie pokaże go w pickerze. Import ręczny: Raycast → Settings → Advanced → Import. Aktualizacja: re-eksport i podmiana pliku.

**Wyjątek poza stow** — `macos.sh` (plik w korzeniu repo): ustawienia systemowe macOS przez `defaults` (Dock, Finder, wygląd). macOS trzyma je w bazie `defaults`, nie w plikach tekstowych — więc to skrypt do odpalenia, nie config do symlinkowania (plik w korzeniu = poza pickerem stow). Odpalanie: `./install.sh macos`. Dwie sekcje: WIERNE (zrzut z maca) + QoL (zakomentowane dodatki). Aktualizacja: dopisz `defaults write …` po odczytaniu wartości `defaults read <domain> <key>`.

## Key Details

- **Language**: Comments and descriptions in Polish
- **Theme — przełącznik 3 trybów** (`bin/.local/bin/theme`): jeden skrypt przełącza **day = Gruvbox Dark Hard / night = Catppuccin Mocha / light = Gruvbox Light Hard** (pełne słońce, jasne tło) w całym stacku (Ghostty / nvim / Starship / Zellij / bat / delta), BEZ ruszania trybu jasny/ciemny macOS. Użycie: `theme [day|night|light|toggle|status]`. `toggle` przełącza tylko codzienną parę day ⇄ night; `light` jest zawsze jawny (z lighta toggle wraca do day). **Mechanizm = dyrygent + dyrygowani:**
  - **Dyrygent** = skrypt `theme` (stowowany pakiet `bin/`, w PATH). Zapisuje 3 pliki stanu **POZA repo** (per-urządzenie, zero churnu w gicie): `~/.config/theme-mode` (nvim), `~/.config/ghostty-theme.local` (Ghostty), `~/.config/theme-bat` (bat/delta) + regeneruje `~/.cache/starship-active.toml` i `~/.cache/zellij-active.kdl` (z szablonów w repo, podmieniając linię palety/motywu). Potem szturcha Ghostty (reload przez osascript Cmd+Shift+,); Zellij sam obserwuje swój plik configu → żywe sesje przemalowują się bez szturchania
  - **Dyrygowani** = wiring w trackowanych configach (nie zmienia się przy toggle): `ghostty/config` (default + `config-file = ?~/.config/ghostty-theme.local`); `nvim` watcher pliku `theme-mode` (VimEnter + poll 2 s) + plugin `gruvbox.nvim` `contrast=hard` (stan `gruvbox-light` = umowna nazwa: ten sam plugin + `background=light`); `starship.toml` palety `gruvbox_dark`/`gruvbox_light` (te same nazwy kluczy co catppuccin) + `STARSHIP_CONFIG` przekierowany na lokalny plik; `zellij/config.kdl` = szablon, `.zshrc` kieruje `ZELLIJ_CONFIG_FILE` na generowany `~/.cache/zellij-active.kdl` (pełne 3 motywy: day → gruvbox-dark, night → catppuccin-mocha, light → gruvbox-light). **Celowo BEZ slotów `theme_dark`/`theme_light`**: z oboma slotami Zellij przy każdym attachu pyta terminal HOSTA o jasność (CSI 996/2031) i sam przełącza motyw sesji, a Ghostty na macOS raportuje jasność SYSTEMU (nie motywu terminala) — attach po SSH wciskał gruvbox-light mimo trybu day. Po edycji szablonu zellija odpal `theme`, żeby przegenerować aktywny plik (jak w starshipie); `.zshrc` `BAT_THEME` z `~/.config/theme-bat` odświeżane co prompt (precmd); `.gitconfig` BEZ jawnego `syntax-theme` → delta dziedziczy `BAT_THEME` (lazygit analogicznie, `--no-gitconfig`)
  - fzf/eza/grep/git itd. dziedziczą paletę ANSI Ghostty → przełączają się **za darmo**, bez wiringu
  - **Świeża maszyna**: po `stow` wszystko działa od ręki (dyrygent jedzie z `bin/`); brak plików stanu = każde narzędzie spada na swój default (Catppuccin), `theme day` ustawia resztę
- **Git pager**: delta with side-by-side, Catppuccin Mocha syntax theme — Lazygit overrides delta to use `--no-gitconfig` with matching flags
- **Git — split tożsamości (3 warstwy)**: `.gitconfig` trzyma wspólne ustawienia (delta, merge, rerere, diff) + **domyślną tożsamość prywatną** (gmail). Dwie nakładki:
  - `~/.gitconfig-work` (stowowany, **trackowany**) — tożsamość firmowa (getprintbox). Ładowany przez `[includeIf "hasconfig:remote.*.url:git@git.getprintbox.com:*/**"]`, czyli **po hoście remote'a**, nie po katalogu (`~/Workspace` jest mieszane). Glob: `**` musi być otoczone slashem (`:*/**`) żeby przeszło przez `/` w `grupa/repo.git` — bez slasha git traktuje `**` jak zwykłe `*` i match nie zadziała. Trackowany = jedzie na każdy komp, firmowy email „za darmo" po `stow`
  - `~/.gitconfig.local` (**NIE w repo**, per-urządzenie) — dołączany `[include]` na końcu `.gitconfig`, nadpisuje wszystko. Tu rzeczy specyficzne dla maszyny: podpis SSH przez 1Password (`gpg.ssh.program=op-ssh-sign`, `signingkey`, `commit.gpgsign`). Nie może być trackowany, bo na maszynie bez 1Password pod tą ścieżką każdy commit by failował. Wzorzec do skopiowania: `git/.gitconfig.local.example`. Git po cichu ignoruje brak tego pliku
  - **Dwie osie**: `-work` = per-kontekst (które repo, to samo na każdym kompie), `.local` = per-urządzenie (która maszyna). Dlatego oba mają sens jednocześnie
- **Przenośność (Linux)**: repo jest macOS-first, ale rdzeń (`starship`, `nvim`, `git`, `zellij`, `zshrc`) ma fallbacki na Linux — **gałąź macOS zawsze pierwsza/niezmieniona**:
  - `zshrc`: `PNPM_HOME` per-OS (macOS `~/Library/pnpm`, Linux `${XDG_DATA_HOME:-~/.local/share}/pnpm`); funkcja `nvm()` źródłuje `nvm.sh` z wielu lokalizacji (`$NVM_DIR`, brew-mac, `/usr/local`, linuxbrew) — pierwszy istniejący
  - `zellij`: cheatsheet-bind (`Alt Shift /`) owinięty w `sh -c`, bo KDL nie rozwija `~`/`$HOME`; `bat` rezolwowany po PATH (prepend brew/linuxbrew), ścieżka cheatsheetu z `$HOME`
  - `statusline`: jedyna zależność to `jq` — limity czyta z natywnego `rate_limits` podawanego przez Claude Code na stdin (zero tokenów/Keychaina/API), więc działa identycznie na macOS i Linux
  - **macOS-only z definicji**: `aerospace` (AeroSpace WM) i `karabiner` (Karabiner-Elements) — brak buildów na Linux, po prostu nie wybieraj ich w `install.sh`. `ghostty`: klucze `macos-*` są na Linuksie ignorowane (no-op), reszta configu działa
- **Terminal session**: Ghostty startuje goły shell — auto-attach do Zellija został usunięty z configu (2026-07; historia w gicie). Do Zellija wchodzi się świadomie funkcją `work` (`zellij attach -c main` — attach do sesji `main`, tworzy jeśli nie istnieje). Tmux został wycofany (2026-05).
- **Shell**: Zsh with Oh My Zsh, lazy-loaded NVM and pyenv for fast startup. Prompt: Starship (jedyny)
- **Prompt (starship)**: `.zshrc` ma pusty `ZSH_THEME` (OMZ nie rysuje promptu) i na końcu pliku robi `eval "$(starship init zsh)"` jeśli binarka jest dostępna (jak nieobecna → goły prompt zsh, bez błędów). Config = `catppuccin-powerline` preset (single-line powerline + `line_break` włączony, więc `❯` na osobnej linii). Starship = jeden binarek + jeden TOML, cross-shell (zsh/bash) — instalacja na remote: `brew install starship` lub `curl -sS https://starship.rs/install.sh | sh`. p10k został wycofany (2026-06)
- **Neovim**: LazyVim distro — plugins in `lua/plugins/`, config in `lua/config/` (options, keymaps, autocmds). Custom plugins go in `lua/plugins/` as new `.lua` files
- **Claude Code statusline**: własny skrypt bash (working dir, % kontekstu, branch/status gita, limity API z timerem resetu). Wszystko czyta z JSON-a podawanego przez Claude Code na stdin (w tym natywne `rate_limits`) — zero wywołań API, tokenów i cache. Rejestrację `statusLine` w `~/.claude/settings.json` (plik runtime'owy, NIE stowowany) domergowuje `install.sh` po stow pakietu `claude`. Hooki Claude Code + picker `cj` zostały wycofane (2026-07) — hooki utrzymywały cache sesji dla `cj`, generowały więcej problemów niż wartości
- **Funkcje zsh dla Claude'a / Zellija** (`zshrc/.zshrc`): `work` — wejście do Zellija (attach do sesji `main`, tworzy jeśli brak; guard na brak binarki i na bycie już w Zelliju). `claudet [nazwa...]` — funkcja odpalająca claude w nowym tabie Zellija (opcjonalna nazwa taba przez `--name`); musi być funkcją (nie aliasem) i używać absolutnej ścieżki binarki, bo `zellij action new-tab -- <cmd>` używa stale PATH-u zellij-servera (zamrożony przy starcie sesji, często bez `~/.local/bin`). `zt [nazwa...]` — nowy tab Zellija (opcjonalnie z nazwą), bez customowego commandu, więc problem PATH-u nie dotyczy
- **Funkcja zsh `wt` (git worktree)** (`zshrc/.zshrc`): zarządzanie worktree z fzf-pickerem. `wt` (bez argumentu) — picker istniejących worktree → `cd`. `wt add <branch>` — tworzy worktree i wchodzi do niego (istniejący branch → `git worktree add`, nieistniejący → `-b` od HEAD; `feature/x` spłaszczane do `feature-x`). `wt rm` — picker → `git worktree remove`. `wt ls` — lista. Nowe worktree lądują w `../<repo>.worktrees/<branch>` (katalog-siostra), liczone zawsze od głównego worktree (pierwsza linia `git worktree list`), więc działa spójnie z wnętrza dowolnego worktree
- **Wymagane narzędzia**: GNU Stow (`brew install stow`), fzf (`brew install fzf`)
- **Bootstrap świeżego Maca**: `./install.sh setup` — Xcode CLT → Homebrew → `brew bundle` (Brewfile) → Oh My Zsh + pluginy (autosuggestions, syntax-highlighting). Bez tego kroku stowowany `.zshrc` sypie błędami (brak OMZ/eza/starship)
- **Instalacja**: `./install.sh stow` — interaktywny wybór pakietów przez fzf, tworzy symlinki do `$HOME` via stow
- **Odinstalowanie**: `./install.sh unstow` — usuwa symlinki wybranych pakietów
- **Status**: `./install.sh status` — pokazuje które pakiety są zainstalowane
