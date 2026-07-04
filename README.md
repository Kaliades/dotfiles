# dotfiles

Moje pliki konfiguracyjne zarządzane przez [GNU Stow](https://www.gnu.org/software/stow/).

## Instalacja

```bash
git clone https://github.com/simonkulinski/dotfiles.git ~/Workspace/dotfiles
cd ~/Workspace/dotfiles
./install.sh setup     # świeży Mac: Homebrew + Brewfile + Oh My Zsh + pluginy
./install.sh stow      # wybierz pakiety przez fzf (symlinki → ~)
```

Na maszynie z już zainstalowanym Homebrew i Oh My Zsh wystarczy `brew install stow fzf` i od razu `./install.sh stow`.

## Użycie

| Komenda                | Opis                                       |
|------------------------|--------------------------------------------|
| `./install.sh setup`  | Bootstrap świeżego Maca (Homebrew + Brewfile + Oh My Zsh) |
| `./install.sh macos`  | Ustawienia systemowe macOS (`defaults`)    |
| `./install.sh stow`   | Zainstaluj wybrane pakiety (symlinki → ~)  |
| `./install.sh unstow` | Odinstaluj wybrane pakiety                 |
| `./install.sh status` | Pokaż co jest zainstalowane                |

## Pakiety

| Pakiet      | Co zawiera                                              |
|-------------|---------------------------------------------------------|
| `ghostty`   | Konfiguracja terminala Ghostty                          |
| `zellij`    | Konfiguracja multipleksera Zellij                       |
| `git`       | `.gitconfig` (delta, side-by-side, split tożsamości) + Lazygit |
| `zshrc`     | Zsh + Oh My Zsh + lazy-loaded NVM/pyenv; funkcje `work` (attach do Zellija), `claudet`/`zt` (nowy tab Zellija) i `wt` (git worktree z fzf) |
| `starship`  | Prompt Starship (cross-shell, jedyny prompt)            |
| `nvim`      | Neovim z LazyVim                                        |
| `aerospace` | Konfiguracja AeroSpace (tiling WM)                      |
| `karabiner` | Konfiguracja Karabiner-Elements                         |
| `bin`       | Skrypty w `~/.local/bin` — m.in. `theme` (przełącznik motywu day/night/light) |
| `claude`    | Claude Code — statusline (working dir, kontekst, git, limity API) |
| `cmux`      | Konfiguracja cmux                                       |

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
