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
## cargo
[[ ! -f "$HOME/.cargo/env" ]] || source "$HOME/.cargo/env"
