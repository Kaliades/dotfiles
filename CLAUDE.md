# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal dotfiles repository (macOS/Darwin) for Simon Kulinski. Stores configuration for shell, terminal emulator, editor, and git tooling.

## Repo Structure

Each tool gets its own top-level directory mirroring the home directory layout:

- `ghostty/` — Ghostty terminal config (`.config/ghostty/config`)
- `zellij/` — Zellij multiplexer config (`.config/zellij/config.kdl`)
- `git/` — Git config (`.gitconfig`) + Lazygit config (`.config/lazygit/config.yml`)
- `zshrc/` — Zsh config (`.zshrc`, `.p10k.zsh`)
- `claude/` — Claude Code config (`.claude/statusline-command.sh` + `.claude/hooks/` dispatcher + helpers)
- `nvim/` — Neovim config (`.config/nvim/`) — LazyVim starter with lazy.nvim plugin manager
- `aerospace/` — AeroSpace tiling window manager config (`.aerospace.toml`)

New tools should follow the same pattern: `<tool-name>/` containing files in their home-relative paths.

## Key Details

- **Language**: Comments and descriptions in Polish
- **Theme**: cały stack na Catppuccin Mocha (Ghostty / Zellij / Helix / Zed / nvim / Yazi / delta przez bat)
- **Git pager**: delta with side-by-side, Catppuccin Mocha syntax theme — Lazygit overrides delta to use `--no-gitconfig` with matching flags
- **Terminal session**: Ghostty `command` auto-attacha do sesji Zellij `main` przy starcie. Tmux został wycofany (2026-05).
- **Shell**: Zsh with Oh My Zsh + Powerlevel10k, lazy-loaded NVM and pyenv for fast startup
- **Neovim**: LazyVim distro — plugins in `lua/plugins/`, config in `lua/config/` (options, keymaps, autocmds). Custom plugins go in `lua/plugins/` as new `.lua` files
- **Claude Code statusline**: Custom bash script that shows working dir, context remaining %, git branch/status, and API usage with reset timer (cached 60s). Reads OAuth token from macOS Keychain
- **Claude Code hooki**: `claude/.claude/hooks/` zawiera dispatcher (`claude-hook.sh`) wpięty pod 5 eventów (`SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, `SessionEnd`) — **utrzymują tylko cache stanu sesji** w `~/.claude/cache/session-<sid>` (TSV). Zero wywołań `zellij action` (wcześniejsza wersja renameowała tab/sesję ale generowała zombie subshelle przez zatkany socket). Hooki czytają `$ZELLIJ_SESSION_NAME` i `$ZELLIJ_PANE_ID` z env i zapisują do cache — `cj` używa `pane_id` do `focus-pane-id` (jump do konkretnego pane'a Claude'a). Szczegóły: `claude/.claude/hooks/README.md`. Wiring eventów do hooków siedzi w `~/.claude/settings.json` — to plik runtime'owy Claude Code, NIE jest stowowany
- **Funkcje zsh dla Claude'a** (`zshrc/.zshrc`): `cj` — fzf-picker aktywnych sesji Claude'a we wszystkich sesjach Zellija; jump-to-pane w obrębie bieżącej sesji (`focus-pane-id`), switch-session cross-session. `claudet` — funkcja odpalająca claude w nowym tabie Zellija; musi być funkcją (nie aliasem) i używać absolutnej ścieżki binarki, bo `zellij action new-tab -- <cmd>` używa stale PATH-u zellij-servera (zamrożony przy starcie sesji, często bez `~/.local/bin`)
- **Wymagane narzędzia**: GNU Stow (`brew install stow`), fzf (`brew install fzf`)
- **Instalacja**: `./install.sh stow` — interaktywny wybór pakietów przez fzf, tworzy symlinki do `$HOME` via stow
- **Odinstalowanie**: `./install.sh unstow` — usuwa symlinki wybranych pakietów
- **Status**: `./install.sh status` — pokazuje które pakiety są zainstalowane
