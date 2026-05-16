# dotfiles

Moje pliki konfiguracyjne zarządzane przez [GNU Stow](https://www.gnu.org/software/stow/).

## Wymagania

```bash
brew install stow fzf
```

## Instalacja

```bash
git clone https://github.com/simonkulinski/dotfiles.git ~/Workspace/dotfiles
cd ~/Workspace/dotfiles
./install.sh stow      # wybierz pakiety przez fzf
```

## Użycie

| Komenda                | Opis                                      |
|------------------------|-------------------------------------------|
| `./install.sh stow`   | Zainstaluj wybrane pakiety (symlinki → ~) |
| `./install.sh unstow` | Odinstaluj wybrane pakiety                |
| `./install.sh status`  | Pokaż co jest zainstalowane               |

## Pakiety

| Pakiet      | Co zawiera                                              |
|-------------|---------------------------------------------------------|
| `ghostty`   | Konfiguracja terminala Ghostty                          |
| `zellij`    | Konfiguracja multipleksera Zellij                       |
| `git`       | `.gitconfig` (delta, side-by-side) + Lazygit            |
| `zshrc`     | Zsh + Oh My Zsh + Powerlevel10k + lazy-loaded NVM/pyenv; funkcje `cj` (fzf-picker sesji Claude'a) i `claude()` (auto-tab w Zellij) |
| `nvim`      | Neovim z LazyVim                                        |
| `aerospace` | Konfiguracja AeroSpace (tiling WM)                      |
| `claude`    | Claude Code — statusline + Zellij-aware hooki (`SessionStart/UserPromptSubmit/Stop/Notification/SessionEnd` → nazwa zakładki z ikoną stanu) |

## Struktura

Każdy pakiet to katalog odzwierciedlający układ `$HOME`:

```
ghostty/
  .config/ghostty/config    →  ~/.config/ghostty/config

git/
  .gitconfig                →  ~/.gitconfig
  .config/lazygit/config.yml →  ~/.config/lazygit/config.yml
```

Nowy pakiet = nowy katalog z plikami w home-relative paths.
