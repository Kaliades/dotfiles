#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME"

# ============================================================================
# Kolory
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================================
# Helpers
# ============================================================================
info()  { echo -e "${CYAN}${BOLD}::${RESET} $1"; }
ok()    { echo -e "${GREEN}${BOLD}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}${BOLD}!${RESET} $1"; }
err()   { echo -e "${RED}${BOLD}✗${RESET} $1"; }

check_dep() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 nie znaleziony. Zainstaluj: ${BOLD}brew install $1${RESET}"
    exit 1
  fi
}

# Pobierz listę pakietów (katalogi z pominięciem ukrytych i samego skryptu)
get_packages() {
  find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.*' \
    -exec basename {} \; | sort
}

# Sprawdź czy pakiet jest już zastowowany
# Stow linkuje katalogi lub pliki — sprawdzamy symlinki na każdym poziomie ścieżki
is_stowed() {
  local pkg="$1"
  local found=false
  while IFS= read -r -d '' file; do
    local rel="${file#$DOTFILES_DIR/$pkg/}"
    local target="$TARGET_DIR/$rel"
    # Sprawdź symlinki na każdym poziomie ścieżki (stow linkuje katalogi, nie tylko pliki)
    local check_path="$TARGET_DIR"
    local IFS='/'
    for part in $rel; do
      check_path="$check_path/$part"
      if [[ -L "$check_path" ]]; then
        local resolved
        resolved="$(realpath "$check_path" 2>/dev/null)" || continue
        if [[ "$resolved" == "$DOTFILES_DIR/$pkg/"* ]]; then
          found=true
          break 2
        fi
      fi
    done
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
  $found
}

# Post-install dla pakietu `claude`: dopnij `statusLine` do ~/.claude/settings.json.
# settings.json celowo NIE jest stowowany (trzyma lokalne klucze jak model/theme),
# więc rejestrację status line trzeba domergować idempotentnie po stow.
claude_postinstall() {
  local settings="$TARGET_DIR/.claude/settings.json"
  local script="$TARGET_DIR/.claude/statusline-command.sh"
  local statusline='{"type":"command","command":"bash ~/.claude/statusline-command.sh"}'

  # Skrypt wykonywalny (przydatne też przy bezpośrednim uruchomieniu, nie tylko `bash …`)
  [[ -e "$script" ]] && chmod +x "$(realpath "$script")" 2>/dev/null || true

  if ! command -v jq &>/dev/null; then
    warn "jq nie znaleziony — pomijam wpięcie statusLine. Dodaj ręcznie do ${BOLD}$settings${RESET}:"
    echo "      \"statusLine\": $statusline"
    return 0
  fi

  mkdir -p "$(dirname "$settings")"
  [[ -f "$settings" ]] || echo '{}' > "$settings"

  if ! jq -e . "$settings" >/dev/null 2>&1; then
    err "$settings to niepoprawny JSON — pomijam wpięcie statusLine (nie nadpisuję)."
    return 0
  fi

  if jq -e '.statusLine' "$settings" >/dev/null 2>&1; then
    ok "statusLine już skonfigurowany — zostawiam bez zmian."
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  if jq --argjson sl "$statusline" '.statusLine = $sl' "$settings" > "$tmp" && mv "$tmp" "$settings"; then
    ok "Wpięto statusLine do settings.json"
  else
    rm -f "$tmp"
    err "Nie udało się zaktualizować settings.json"
  fi
}

# ============================================================================
# Komendy
# ============================================================================

# Bootstrap świeżego Maca: Xcode CLT → Homebrew → brew bundle (Brewfile) → Oh My Zsh.
# Każdy krok idempotentny (sprawdza czy już zainstalowane), więc można puszczać wielokrotnie.
# Po nim: ./install.sh stow (symlinki configów).
cmd_setup() {
  if [[ "$(uname)" != "Darwin" ]]; then
    err "setup jest tylko dla macOS (wykryto: $(uname))."
    exit 1
  fi

  # 1. Xcode Command Line Tools — wymagane przez Homebrew (git, kompilatory)
  if ! xcode-select -p &>/dev/null; then
    info "Instaluję Xcode Command Line Tools…"
    xcode-select --install || true
    warn "Dokończ instalację CLT w oknie GUI, potem uruchom ${BOLD}./install.sh setup${RESET} ponownie."
    exit 0
  else
    ok "Xcode Command Line Tools już zainstalowane."
  fi

  # 2. Homebrew
  if ! command -v brew &>/dev/null; then
    info "Instaluję Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon: /opt/homebrew, Intel: /usr/local — załaduj brew do bieżącej sesji
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ok "Homebrew zainstalowany."
  else
    ok "Homebrew już zainstalowany."
  fi

  # 3. brew bundle — wszystkie pakiety/caski/npm z Brewfile
  if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    info "Instaluję pakiety z Brewfile (brew bundle)…"
    brew bundle --file="$DOTFILES_DIR/Brewfile"
    ok "Pakiety z Brewfile zainstalowane."
  else
    warn "Brak $DOTFILES_DIR/Brewfile — pomijam brew bundle."
  fi

  # 4. Oh My Zsh — bez auto-chsh i bez odpalania nowego shella w trakcie skryptu;
  #    KEEP_ZSHRC=yes żeby nie nadpisać .zshrc (i tak podmienia go potem `stow zshrc`)
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh już zainstalowany."
  else
    info "Instaluję Oh My Zsh…"
    # `|| true`: instalator OMZ pod RUNZSH=no potrafi zwrócić niezerowy kod
    # (pomija końcowe `exec zsh`), co przy `set -e` ubiłoby skrypt PRZED krokiem
    # 4b (klonowanie pluginów). Realny stan i tak weryfikujemy poniżej.
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      ok "Oh My Zsh zainstalowany."
    else
      err "Instalacja Oh My Zsh nie powiodła się — pomijam pluginy. Sprawdź sieć i odpal ${BOLD}./install.sh setup${RESET} ponownie."
      return 1
    fi
  fi

  # 4b. Zewnętrzne pluginy OMZ (git, extract, sudo są wbudowane — te dwa nie).
  #     .zshrc je włącza w plugins=(...), ale OMZ ich sam nie klonuje.
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  declare -a omz_plugins=(
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting"
  )
  for entry in "${omz_plugins[@]}"; do
    local name="${entry%%|*}" url="${entry##*|}"
    if [[ -d "$zsh_custom/plugins/$name" ]]; then
      ok "Plugin $name już sklonowany."
    else
      info "Klonuję plugin $name…"
      if git clone --depth=1 "$url" "$zsh_custom/plugins/$name"; then
        ok "$name sklonowany."
      else
        warn "Nie udało się sklonować $name — doklonuj ręcznie później."
      fi
    fi
  done

  echo ""
  ok "Bootstrap gotowy."
  info "Następny krok: ${BOLD}./install.sh stow${RESET} (symlinki configów do \$HOME)."
  info "Git per-urządzenie: skopiuj ${BOLD}git/.gitconfig.local.example${RESET} → ${BOLD}~/.gitconfig.local${RESET}."
}

# Ustawienia systemowe macOS przez `defaults` (Dock, Finder, wygląd…).
# Delegacja do macos.sh — patrz tam po szczegóły i sekcję QoL do podrasowania.
cmd_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    err "macos jest tylko dla macOS (wykryto: $(uname))."
    exit 1
  fi
  if [[ ! -f "$DOTFILES_DIR/macos.sh" ]]; then
    err "Brak $DOTFILES_DIR/macos.sh"
    exit 1
  fi
  info "Stosuję ustawienia macOS (defaults)…"
  bash "$DOTFILES_DIR/macos.sh"
  ok "Ustawienia macOS zastosowane."
}

cmd_stow() {
  check_dep stow
  check_dep fzf

  local packages
  packages=$(get_packages)

  # Buduj listę z oznaczeniem statusu
  local items=()
  while IFS= read -r pkg; do
    if is_stowed "$pkg"; then
      items+=("$pkg  [zainstalowany]")
    else
      items+=("$pkg")
    fi
  done <<< "$packages"

  info "Wybierz pakiety do zainstalowania (TAB = zaznacz, ENTER = potwierdź):"
  echo ""

  local selected
  selected=$(printf '%s\n' "${items[@]}" \
    | fzf --multi \
          --header="󰒓  stow → $TARGET_DIR" \
          --prompt="instaluj> " \
          --marker="✓" \
          --border=rounded \
          --height=~50% \
          --reverse \
    | sed 's/  \[zainstalowany\]//' \
  ) || { info "Anulowano."; exit 0; }

  echo ""
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    info "Stow: ${BOLD}$pkg${RESET}"
    # `claude`: wymuś realny ~/.claude PRZED stow. Bez tego (świeży komp, gdy
    # katalog nie istnieje) stow zrobiłby fold — podlinkowałby CAŁY ~/.claude na
    # repo, a Claude Code zacząłby pisać runtime (sessions/cache/projects/…) do
    # repo. Realny katalog zmusza stow do linkowania per-plik (tylko hooks/ +
    # statusline-command.sh), runtime zostaje poza repo.
    [[ "$pkg" == "claude" ]] && mkdir -p "$TARGET_DIR/.claude"
    if stow -v -d "$DOTFILES_DIR" -t "$TARGET_DIR" "$pkg" 2>&1; then
      ok "$pkg zainstalowany"
    else
      err "$pkg — błąd podczas stow (może konflikt plików?)"
    fi
    # Pakiet `claude` wymaga dopięcia statusLine do (niestowowanego) settings.json
    [[ "$pkg" == "claude" ]] && claude_postinstall
  done <<< "$selected"
}

cmd_unstow() {
  check_dep stow
  check_dep fzf

  local packages
  packages=$(get_packages)

  # Pokaż tylko zainstalowane pakiety
  local installed=()
  while IFS= read -r pkg; do
    if is_stowed "$pkg"; then
      installed+=("$pkg")
    fi
  done <<< "$packages"

  if [[ ${#installed[@]} -eq 0 ]]; then
    warn "Brak zainstalowanych pakietów."
    exit 0
  fi

  info "Wybierz pakiety do odinstalowania (TAB = zaznacz, ENTER = potwierdź):"
  echo ""

  local selected
  selected=$(printf '%s\n' "${installed[@]}" \
    | fzf --multi \
          --header="󰩺  unstow ← $TARGET_DIR" \
          --prompt="odinstaluj> " \
          --marker="✗" \
          --border=rounded \
          --height=~50% \
          --reverse \
  ) || { info "Anulowano."; exit 0; }

  echo ""
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    info "Unstow: ${BOLD}$pkg${RESET}"
    if stow -v -D -d "$DOTFILES_DIR" -t "$TARGET_DIR" "$pkg" 2>&1; then
      ok "$pkg odinstalowany"
    else
      err "$pkg — błąd podczas unstow"
    fi
  done <<< "$selected"
}

cmd_status() {
  local packages
  packages=$(get_packages)

  info "Status pakietów:\n"
  while IFS= read -r pkg; do
    if is_stowed "$pkg"; then
      echo -e "  ${GREEN}●${RESET} $pkg"
    else
      echo -e "  ${RED}○${RESET} $pkg"
    fi
  done <<< "$packages"
  echo ""
  echo -e "  ${GREEN}●${RESET} = zainstalowany   ${RED}○${RESET} = niezainstalowany"
}

cmd_help() {
  echo -e "${BOLD}dotfiles install${RESET} — zarządzanie konfiguracją przez GNU Stow\n"
  echo -e "Użycie: ${CYAN}./install.sh <komenda>${RESET}\n"
  echo -e "Komendy:"
  echo -e "  ${BOLD}setup${RESET}     Bootstrap świeżego Maca (Homebrew + Brewfile + Oh My Zsh)"
  echo -e "  ${BOLD}macos${RESET}     Zastosuj ustawienia systemowe macOS (Dock, Finder, wygląd)"
  echo -e "  ${BOLD}stow${RESET}      Zainstaluj wybrane pakiety (symlinki do \$HOME)"
  echo -e "  ${BOLD}unstow${RESET}    Odinstaluj wybrane pakiety"
  echo -e "  ${BOLD}status${RESET}    Pokaż status wszystkich pakietów"
  echo -e "  ${BOLD}help${RESET}      Wyświetl tę pomoc"
}

# ============================================================================
# Main
# ============================================================================
case "${1:-help}" in
  setup)   cmd_setup ;;
  macos)   cmd_macos ;;
  stow)    cmd_stow ;;
  unstow)  cmd_unstow ;;
  status)  cmd_status ;;
  help|*)  cmd_help ;;
esac
