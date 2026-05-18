# ============================================================================
# Powerlevel10k Instant Prompt (musi być na samej górze)
# ============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================================
# Oh My Zsh — konfiguracja
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

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

path=(
  "$HOME/.local/bin"
  "$HOME/.composer/vendor/bin"
  "$HOME/Library/pnpm"
  "$HOME/.pyenv/bin"
  $path
)

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"

# ============================================================================
# NVM — lazy loading (~400ms szybszy start)
# ============================================================================
export NVM_DIR="$HOME/.nvm"

# Eager PATH do domyślnego node — Neovim (Mason/LSP) potrzebuje node na PATH
if [[ -f "$NVM_DIR/alias/default" ]]; then
  _nvm_default=$(cat "$NVM_DIR/alias/default")
  _nvm_default_path=$(ls -d "$NVM_DIR/versions/node/v${_nvm_default}"* 2>/dev/null | sort -V | tail -1)
  [[ -n "$_nvm_default_path" ]] && path=("$_nvm_default_path/bin" $path)
  unset _nvm_default _nvm_default_path
fi

nvm() {
  unfunction nvm node npm npx 2>/dev/null
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
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

# ============================================================================
# Środowisko
# ============================================================================
export ENABLE_LSP_TOOL=1
export XDG_CONFIG_HOME="$HOME/.config"
export BAT_THEME="gruvbox-dark"

# Sekrety (upewnij się: chmod 600 ~/.secrets)
[[ -f ~/.secrets ]] && source ~/.secrets

# Powerlevel10k config
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
## custom
[[ ! -f "$HOME/.custom" ]] || source "$HOME/.custom"
