# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal dotfiles repository (macOS/Darwin) for Simon Kulinski. Stores configuration for shell, terminal emulator, editor, and git tooling.

## Repo Structure

Each tool gets its own top-level directory mirroring the home directory layout:

- `ghostty/` — Ghostty terminal config (`.config/ghostty/config`)
- `zellij/` — Zellij multiplexer config (`.config/zellij/config.kdl`)
- `git/` — Git config (`.gitconfig`) + Lazygit config (`.config/lazygit/config.yml`)
- `zshrc/` — Zsh config (`.zshrc`)
- `claude/` — Claude Code config (`.claude/statusline-command.sh` + `.claude/hooks/` dispatcher + helpers)
- `nvim/` — Neovim config (`.config/nvim/`) — LazyVim starter with lazy.nvim plugin manager
- `aerospace/` — AeroSpace tiling window manager config (`.aerospace.toml`)
- `starship/` — Starship prompt (`.config/starship.toml`) — **jedyny prompt** (cross-shell, Catppuccin Powerline preset)
- `karabiner/` — Karabiner-Elements config (`.config/karabiner/karabiner.json`) — `automatic_backups/` i `assets/` są ignorowane (Karabiner regeneruje je sam)

New tools should follow the same pattern: `<tool-name>/` containing files in their home-relative paths.

## Key Details

- **Language**: Comments and descriptions in Polish
- **Theme**: cały stack na Catppuccin Mocha (Ghostty / Zellij / Starship / nvim / Yazi / bat / delta). `BAT_THEME` i delta `syntax-theme` = `Catppuccin Mocha` (motyw wbudowany w bat ≥0.26, więc bez doinstalowania)
- **Git pager**: delta with side-by-side, Catppuccin Mocha syntax theme — Lazygit overrides delta to use `--no-gitconfig` with matching flags
- **Terminal session**: Ghostty `command` auto-attacha do sesji Zellij `main` przy starcie. Tmux został wycofany (2026-05).
- **Shell**: Zsh with Oh My Zsh, lazy-loaded NVM and pyenv for fast startup. Prompt: Starship (jedyny)
- **Prompt (starship)**: `.zshrc` ma pusty `ZSH_THEME` (OMZ nie rysuje promptu) i na końcu pliku robi `eval "$(starship init zsh)"` jeśli binarka jest dostępna (jak nieobecna → goły prompt zsh, bez błędów). Config = `catppuccin-powerline` preset (single-line powerline + `line_break` włączony, więc `❯` na osobnej linii). Starship = jeden binarek + jeden TOML, cross-shell (zsh/bash) — instalacja na remote: `brew install starship` lub `curl -sS https://starship.rs/install.sh | sh`. p10k został wycofany (2026-06)
- **Neovim**: LazyVim distro — plugins in `lua/plugins/`, config in `lua/config/` (options, keymaps, autocmds). Custom plugins go in `lua/plugins/` as new `.lua` files
- **Claude Code statusline**: Custom bash script that shows working dir, context remaining %, git branch/status, and API usage with reset timer (cached 60s). Reads OAuth token from macOS Keychain
- **Claude Code hooki**: `claude/.claude/hooks/` zawiera dispatcher (`claude-hook.sh`) wpięty pod 5 eventów (`SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, `SessionEnd`) — **utrzymują tylko cache stanu sesji** w `~/.claude/cache/session-<sid>` (TSV). Zero wywołań `zellij action` (wcześniejsza wersja renameowała tab/sesję ale generowała zombie subshelle przez zatkany socket). Hooki czytają `$ZELLIJ_SESSION_NAME` i `$ZELLIJ_PANE_ID` z env i zapisują do cache — `cj` używa `pane_id` do `focus-pane-id` (jump do konkretnego pane'a Claude'a). Szczegóły: `claude/.claude/hooks/README.md`. Wiring eventów do hooków siedzi w `~/.claude/settings.json` — to plik runtime'owy Claude Code, NIE jest stowowany
- **Funkcje zsh dla Claude'a / Zellija** (`zshrc/.zshrc`): `cj` — fzf-picker aktywnych sesji Claude'a we wszystkich sesjach Zellija; jump-to-pane w obrębie bieżącej sesji (`focus-pane-id`), switch-session cross-session. `claudet [nazwa...]` — funkcja odpalająca claude w nowym tabie Zellija (opcjonalna nazwa taba przez `--name`); musi być funkcją (nie aliasem) i używać absolutnej ścieżki binarki, bo `zellij action new-tab -- <cmd>` używa stale PATH-u zellij-servera (zamrożony przy starcie sesji, często bez `~/.local/bin`). `zt [nazwa...]` — nowy tab Zellija (opcjonalnie z nazwą), bez customowego commandu, więc problem PATH-u nie dotyczy
- **Wymagane narzędzia**: GNU Stow (`brew install stow`), fzf (`brew install fzf`)
- **Instalacja**: `./install.sh stow` — interaktywny wybór pakietów przez fzf, tworzy symlinki do `$HOME` via stow
- **Odinstalowanie**: `./install.sh unstow` — usuwa symlinki wybranych pakietów
- **Status**: `./install.sh status` — pokazuje które pakiety są zainstalowane
