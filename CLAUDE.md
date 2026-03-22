# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal dotfiles repository (macOS/Darwin) for Simon Kulinski. Stores configuration for shell, terminal emulator, and git tooling. Planned to expand with more configs (e.g. Neovim).

## Repo Structure

Each tool gets its own top-level directory mirroring the home directory layout:

- `ghostty/` — Ghostty terminal config (`.config/ghostty/config`)
- `git/` — Git config (`.gitconfig`) + Lazygit config (`.config/lazygit/config.yml`)
- `zshrc/` — Zsh config (`.zshrc`, `.p10k.zsh`)
- `claude/` — Claude Code config (`.claude/statusline-command.sh`)

New tools should follow the same pattern: `<tool-name>/` containing files in their home-relative paths.

## Key Details

- **Language**: Comments and descriptions in Polish
- **Git pager**: delta with side-by-side, gruvbox-dark theme — Lazygit overrides delta to use `--no-gitconfig` with matching flags
- **Shell**: Zsh with Oh My Zsh + Powerlevel10k, lazy-loaded NVM and pyenv for fast startup
- **Claude Code statusline**: Custom bash script that shows working dir, context remaining %, git branch/status, and API usage with reset timer (cached 60s). Reads OAuth token from macOS Keychain
- **No install script yet** — files are meant to be symlinked manually to `$HOME`
