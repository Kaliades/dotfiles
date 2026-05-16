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

# cj — picker sesji Claude'a w Zellij (fzf + go-to-tab-by-id / switch-session)
# Output _cj.py: <display>\t<zsess>\t<tab_id>\t<sid>. Header rows maja puste tab_id.
cj() {
  [[ -z "$ZELLIJ" ]] && { print -u2 "cj: wymaga Zellija"; return 1 }
  command -v fzf >/dev/null || { print -u2 "cj: wymagany fzf"; return 1 }

  local rows picked display zsess tab_id sid
  rows="$(python3 "$HOME/.claude/hooks/_cj.py" 2>/dev/null)"
  [[ -z "$rows" ]] && { print -u2 "cj: brak aktywnych Claude'ów"; return 1 }

  picked="$(printf '%s\n' "$rows" \
    | fzf --ansi --with-nth=1 --delimiter=$'\t' \
          --prompt='Claude > ' --height=60% --reverse \
          --no-hscroll --tiebreak=index)" || return 0

  IFS=$'\t' read -r display zsess tab_id sid <<< "$picked"
  [[ -z "$tab_id" || -z "$zsess" ]] && return 0  # header / spacer

  if [[ "$zsess" == "$ZELLIJ_SESSION_NAME" ]]; then
    zellij action go-to-tab-by-id "$tab_id"
  else
    zellij -s "$zsess" action go-to-tab-by-id "$tab_id" 2>/dev/null
    zellij action switch-session "$zsess"
  fi
}

# claude — jak aktualny tab Zellija ma >1 pane, odpal Claude w nowym tabie.
# Poza Zellijem albo gdy NOCLAUDETAB=1: passthrough do binarki bez magii.
claude() {
  if [[ -z "$ZELLIJ" ]] || [[ -n "$NOCLAUDETAB" ]]; then
    command claude "$@"
    return
  fi

  local panes
  panes=$(zellij action dump-layout 2>/dev/null | awk '
    /^[[:space:]]*tab[[:space:]{]/                       { in_tab = 0 }
    /^[[:space:]]*tab[[:space:]{].*focus=true/           { in_tab = 1 }
    in_tab && /^[[:space:]]*pane([[:space:]{]|$)/        { count++ }
    END                                                  { print count + 0 }
  ')

  if (( panes > 1 )); then
    zellij run --new-tab --close-on-exit -- claude "$@"
  else
    command claude "$@"
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
