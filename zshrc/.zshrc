# ============================================================================
# Oh My Zsh — konfiguracja
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
# Prompt = Starship (init na dole pliku). ZSH_THEME pusty — OMZ nie rysuje promptu.
ZSH_THEME=""

# Pluginy — dodaj zsh-autosuggestions i zsh-syntax-highlighting:
#   git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
#   git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
plugins=(
  git
  zsh-autosuggestions        # podpowiedzi z historii (szare ghost text)
  zsh-syntax-highlighting    # kolorowanie komend w czasie pisania
  extract                    # `extract plik.tar.gz` — rozpakowuje wszystko
  sudo                       # podwójne ESC dodaje sudo przed komendą
)

source "$ZSH/oh-my-zsh.sh"

# ============================================================================
# PATH — ustawiony raz, bez duplikatów
# ============================================================================
typeset -U path  # automatyczna deduplikacja PATH

# pnpm — macOS trzyma w ~/Library, Linux w XDG data dir. Liczone przed `path`,
# bo wstawiamy $PNPM_HOME do PATH.
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
fi

path=(
  "$HOME/.local/bin"
  "$HOME/.composer/vendor/bin"
  "$PNPM_HOME"
  "$HOME/.pyenv/bin"
  $path
)

# ============================================================================
# NVM — lazy loading (~400ms szybszy start)
# ============================================================================
export NVM_DIR="$HOME/.nvm"

# Eager PATH do domyślnego node — Neovim (Mason/LSP) potrzebuje node na PATH
if [[ -f "$NVM_DIR/alias/default" ]]; then
  _nvm_default=$(<"$NVM_DIR/alias/default")
  # default bywa aliasem (np. „lts/*", „node") zamiast numeru wersji — wtedy
  # spadamy do najnowszej zainstalowanej. (N) = NULL_GLOB: brak dopasowania daje
  # pustą listę zamiast zsh-owego błędu „no matches found" (którego 2>/dev/null
  # by NIE złapało — to błąd globa, nie polecenia).
  if [[ "$_nvm_default" == <->* ]]; then
    _nvm_cand=("$NVM_DIR"/versions/node/v${_nvm_default}*(N))
  else
    _nvm_cand=("$NVM_DIR"/versions/node/v*(N))
  fi
  _nvm_default_path=$(print -l "${_nvm_cand[@]}" | sort -V | tail -1)
  [[ -n "$_nvm_default_path" ]] && path=("$_nvm_default_path/bin" $path)
  unset _nvm_default _nvm_cand _nvm_default_path
fi

# Sourcing z wielu lokalizacji — pokrywa brew-mac, linuxbrew i klasyczny
# curl-install ($NVM_DIR/nvm.sh). Źródłuje pierwszy istniejący plik.
nvm() {
  unfunction nvm node npm npx 2>/dev/null
  local _c
  for _c in "$NVM_DIR/nvm.sh" \
            "/opt/homebrew/opt/nvm/nvm.sh" \
            "/usr/local/opt/nvm/nvm.sh" \
            "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh"; do
    [ -s "$_c" ] && { \. "$_c"; break; }
  done
  for _c in "$NVM_DIR/bash_completion" \
            "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" \
            "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm"; do
    [ -s "$_c" ] && { \. "$_c"; break; }
  done
  nvm "$@"
}

node() { nvm --version >/dev/null 2>&1; unfunction node 2>/dev/null; command node "$@"; }
npm()  { nvm --version >/dev/null 2>&1; unfunction npm  2>/dev/null; command npm  "$@"; }
npx()  { nvm --version >/dev/null 2>&1; unfunction npx  2>/dev/null; command npx  "$@"; }

# ============================================================================
# pyenv — lazy loading
# ============================================================================
export PYENV_ROOT="$HOME/.pyenv"

pyenv() {
  unfunction pyenv 2>/dev/null
  eval "$(command pyenv init -)"
  pyenv "$@"
}

python()  { pyenv --version >/dev/null 2>&1; unfunction python  2>/dev/null; command python  "$@"; }
# ============================================================================
# Aliasy — nawigacja
# ============================================================================
alias ws="cd ~/Workspace"


# ============================================================================
# Aliasy — narzędzia
# ============================================================================
alias ls="eza --icons --grid --group-directories-first"
alias lt="eza --icons --tree --level=2 --group-directories-first"
alias grep="grep --color=auto"
alias ports="lsof -i -P -n | grep LISTEN"
alias myip="curl -s ifconfig.me"
alias cls="clear"

# ============================================================================
# Przydatne funkcje
# ============================================================================

# Utwórz katalog i wejdź do niego
mkcd() { mkdir -p "$1" && cd "$1"; }

# Szybki serwer HTTP w bieżącym katalogu
serve() { python3 -m http.server "${1:-8000}"; }

# Znajdź plik po nazwie
ff() { find . -type f -iname "*$1*" 2>/dev/null; }

# cj — picker sesji Claude'a w Zellij.
# Output _cj.py: <display>\t<target_session>\t<my_session>\t<pane_id>\t<sid>
# Header/spacer rows maja puste sid -> bail.
#
# Live metadata (nazwa sesji, tab, cwd) bierzemy z `zellij action list-panes -j`
# w _cj.py, nie z env $ZELLIJ_SESSION_NAME (stale po rename). Stad target_session
# i my_session sa zawsze aktualne. Zellij CLI z stale env failuje cicho —
# uzywamy `--session <live_name>` zeby ominac stale socket path.
cj() {
  [[ -z "$ZELLIJ" ]] && { print -u2 "cj: wymaga Zellija"; return 1 }
  command -v fzf >/dev/null || { print -u2 "cj: wymagany fzf"; return 1 }

  local rows picked display target my_sess pane_id sid
  rows="$(python3 "$HOME/.claude/hooks/_cj.py" 2>/dev/null)"
  [[ -z "$rows" ]] && { print -u2 "cj: brak aktywnych Claude'ów"; return 1 }

  picked="$(printf '%s\n' "$rows" \
    | fzf --ansi --with-nth=1 --delimiter=$'\t' \
          --prompt='Claude > ' --height=60% --reverse \
          --no-hscroll --tiebreak=index)" || return 0

  IFS=$'\t' read -r display target my_sess pane_id sid <<< "$picked"
  [[ -z "$sid" ]] && return 0  # header / spacer

  # Same session: focus-pane-id w mojej live-sesji. --session explicit
  # zeby ominac stale env (po rename-session bez tego CLI hangs/fails).
  if [[ -n "$my_sess" && "$target" == "$my_sess" ]]; then
    zellij --session "$my_sess" action focus-pane-id "$pane_id" 2>/dev/null
    return $?
  fi

  # Cross-session: switch do target. switch-session wykonuje sie w MOJEJ
  # sesji (mial mnie do targetu przeniesc), wiec --session=my_sess.
  if [[ -n "$target" ]]; then
    if [[ -n "$my_sess" ]]; then
      zellij --session "$my_sess" action switch-session "$target"
    else
      # Brak my_sess — fallback do env (moze byc stale, ale czesto OK).
      zellij action switch-session "$target"
    fi
    return $?
  fi

  print -u2 "cj: brak target_session w wyborze (bug?)"
  return 1
}

# claudet — odpal Claude'a w nowym tabie Zellija.
# UWAGA: nie moze byc aliasem ani uzywac samego "claude" jako commandu, bo
# `zellij action new-tab -- <cmd>` spawnuje proces uzywajac PATH-u zellij-servera
# (zamrozonego w momencie startu sesji), a nie PATH-u Twojego shella. Server
# czesto nie ma ~/.local/bin -> claude command not found -> tab otwiera sie pusty.
# Dwa fixy:
#   1) Rezolwuj binarke tu (w shellu wywolujacym, gdzie .zshrc juz poprawil PATH)
#      i podaj absolutna sciezke -> binarka sie odpala.
#   2) Przekaz PATH przez `env`, bo claude sprawdza wewnetrznie czy ~/.local/bin
#      jest w PATH i bez tego wypluwa ostrzezenie "Native installation exists
#      but ~/.local/bin is not in your PATH".
claudet() {
  local bin name
  bin="$(command -v claude 2>/dev/null)"
  [[ -z "$bin" ]] && { print -u2 "claudet: claude nie znaleziony w PATH"; return 127 }
  name="$*"
  if [[ -z "$name" ]]; then
    zellij action new-tab --close-on-exit --cwd "$PWD" -- /usr/bin/env "PATH=$PATH" "$bin"
  else
    zellij action new-tab --close-on-exit --cwd "$PWD" --name "$name" -- /usr/bin/env "PATH=$PATH" "$bin"
  fi
}

# zt — nowy tab Zellija z nazwa. Uzycie: `zt Nowy Tab` albo `zt`.
# Bez argumentu otwiera nienazwany tab. Tu PATH server-a nie ma znaczenia, bo
# nie odpalamy customowego commandu (tylko domyslny shell wg zellij config).
zt() {
  local name="$*"
  if [[ -z "$name" ]]; then
    zellij action new-tab --cwd "$PWD"
  else
    zellij action new-tab --cwd "$PWD" --name "$name"
  fi
}

# wt — zarządzanie git worktree. fzf-picker + subkomendy.
# Nowe worktree lądują w ../<repo>.worktrees/<branch> (katalog-siostra repo),
# liczone zawsze od GŁÓWNEGO worktree (pierwsza linia `git worktree list`),
# więc działa spójnie niezależnie od tego, w którym worktree teraz siedzisz.
#   wt              — fzf-picker istniejących worktree → cd
#   wt add <branch> — utwórz worktree → cd. Branch lokalny → checkout;
#                     tylko na origin → checkout śledzący origin/<branch>;
#                     nigdzie → nowy branch od HEAD
#   wt rm           — fzf-picker → usuń worktree (git worktree remove)
#   wt ls           — lista worktree
wt() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { print -u2 "wt: nie jesteś w repo gita"; return 1 }

  local main_root repo wt_dir cmd
  main_root="$(git worktree list --porcelain | awk 'NR==1{sub(/^worktree /,""); print}')"
  repo="${main_root:t}"
  wt_dir="${main_root:h}/${repo}.worktrees"

  cmd="${1:-}"; (( $# )) && shift
  case "$cmd" in
    add)
      # UWAGA: NIE używać zmiennej `path` — w zsh jest powiązana z $PATH
      # (lokalny `local path` też!), przypisanie ścieżki skasowałoby PATH.
      local branch="$1" dest
      [[ -z "$branch" ]] && { print -u2 "wt add: podaj nazwę brancha"; return 1 }
      dest="$wt_dir/${branch//\//-}"  # spłaszcz feature/x -> feature-x
      [[ -e "$dest" ]] && { print -u2 "wt add: $dest już istnieje"; return 1 }
      if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$dest" "$branch" || return $?   # istniejący branch lokalny
      elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        git worktree add "$dest" -b "$branch" --track "origin/$branch" || return $? # śledzi origin/<branch>
      else
        git worktree add -b "$branch" "$dest" || return $? # nowy branch od HEAD
      fi
      cd "$dest"
      ;;
    rm|remove)
      command -v fzf >/dev/null || { print -u2 "wt: wymagany fzf"; return 1 }
      local picked
      picked="$(git worktree list | fzf --prompt='rm worktree > ' --height=40% --reverse)" || return 0
      [[ -n "${picked%% *}" ]] && git worktree remove "${picked%% *}"
      ;;
    ls|list)
      git worktree list
      ;;
    "")
      command -v fzf >/dev/null || { print -u2 "wt: wymagany fzf"; return 1 }
      local picked
      picked="$(git worktree list | fzf --prompt='worktree > ' --height=40% --reverse)" || return 0
      [[ -n "${picked%% *}" ]] && cd "${picked%% *}"
      ;;
    *)
      print -u2 "wt: nieznana komenda '$cmd' (add | rm | ls | <brak>)"
      return 1
      ;;
  esac
}

# ============================================================================
# Środowisko
# ============================================================================
export ENABLE_LSP_TOOL=1
export XDG_CONFIG_HOME="$HOME/.config"
# bat (i delta — dziedziczy BAT_THEME, bo .gitconfig nie ustawia syntax-theme) za
# przełącznikiem `theme`. Wartość trzyma lokalny plik ~/.config/theme-bat (poza repo);
# odświeżamy co prompt (precmd), więc po `theme` następne bat/fzf-preview/git diff łapią motyw.
_theme_bat() { cat ~/.config/theme-bat 2>/dev/null || echo "Catppuccin Mocha"; }
_theme_refresh_bat() { export BAT_THEME="$(_theme_bat)"; }
_theme_refresh_bat
autoload -Uz add-zsh-hook && add-zsh-hook precmd _theme_refresh_bat

# SSH agent + tmux (tylko sesje zdalne — na macOS launchd ogarnia agenta sam):
# stabilna ścieżka do forwardowanego socketu agenta, żeby shelle w długo żyjącej
# sesji tmux przeżywały reconnect (SSH_AUTH_SOCK zmienia się przy każdym logowaniu).
# Świeży login ma żywy socket → odświeża symlink; shell w tmuxie ma martwą starą
# wartość → warunek nie przechodzi i tylko przestawia się na symlink.
if [[ -n "$SSH_CONNECTION" ]]; then
  if [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]]; then
    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
  fi
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi

# Sekrety (upewnij się: chmod 600 ~/.secrets)
[[ -f ~/.secrets ]] && source ~/.secrets

# Prompt — Starship (cross-shell). Config przekierowany na lokalny, generowany plik
# (~/.cache/starship-active.toml), żeby skrypt `theme` mógł przełączać paletę
# (gruvbox_dark ⇄ catppuccin_mocha) BEZ churnu w gicie. Stowowany ~/.config/starship.toml
# jest szablonem; gdy brak aktywnego pliku (świeży shell/maszyna) — seedujemy go domyślną paletą.
export STARSHIP_CONFIG="${XDG_CACHE_HOME:-$HOME/.cache}/starship-active.toml"
[[ -f $STARSHIP_CONFIG ]] || { mkdir -p "${STARSHIP_CONFIG:h}" && cp ~/.config/starship.toml "$STARSHIP_CONFIG" 2>/dev/null }
command -v starship &>/dev/null && eval "$(starship init zsh)"
## custom
[[ ! -f "$HOME/.custom" ]] || source "$HOME/.custom"
