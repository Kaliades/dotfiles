# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal dotfiles repository (macOS/Darwin) for Simon Kulinski. Stores configuration for shell, terminal emulator, editor, and git tooling.

## Repo Structure

Each tool gets its own top-level directory mirroring the home directory layout:

- `ghostty/` — Ghostty terminal config (`.config/ghostty/config`)
- `git/` — Git config (`.gitconfig`) + Lazygit config (`.config/lazygit/config.yml`)
- `zshrc/` — Zsh config (`.zshrc`, `.p10k.zsh`)
- `claude/` — Claude Code config (`.claude/statusline-command.sh`)
- `nvim/` — Neovim config (`.config/nvim/`) — LazyVim starter with lazy.nvim plugin manager

New tools should follow the same pattern: `<tool-name>/` containing files in their home-relative paths.

## Key Details

- **Language**: Comments and descriptions in Polish
- **Git pager**: delta with side-by-side, gruvbox-dark theme — Lazygit overrides delta to use `--no-gitconfig` with matching flags
- **Shell**: Zsh with Oh My Zsh + Powerlevel10k, lazy-loaded NVM and pyenv for fast startup
- **Neovim**: LazyVim distro — plugins in `lua/plugins/`, config in `lua/config/` (options, keymaps, autocmds). Custom plugins go in `lua/plugins/` as new `.lua` files
- **Claude Code statusline**: Custom bash script that shows working dir, context remaining %, git branch/status, and API usage with reset timer (cached 60s). Reads OAuth token from macOS Keychain
- **Wymagane narzędzia**: GNU Stow (`brew install stow`), fzf (`brew install fzf`)
- **Instalacja**: `./install.sh stow` — interaktywny wybór pakietów przez fzf, tworzy symlinki do `$HOME` via stow
- **Odinstalowanie**: `./install.sh unstow` — usuwa symlinki wybranych pakietów
- **Status**: `./install.sh status` — pokazuje które pakiety są zainstalowane
